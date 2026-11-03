# README

This README would normally document whatever steps are necessary to get the
application up and running.

## Tenant databases and purchase history

Tenant-specific product listings and purchase history are stored in the
tenant's Apartment database. Shared `listing_references` rows connect catalog
products and cart items to tenant-local listings.

Run schema migrations from the Rails Docker service after pulling schema changes:

```sh
docker compose exec web bundle exec rails db:migrate
```

Checkout writes each store's purchase history and PaperTrail versions to that
store's tenant database; a cart containing products from multiple stores is
recorded separately in each store database. Cart discounts are rounded to cents
and allocated across tenant-local purchase rows so order history records the
actual amount paid. The discount-total migration also corrects completed
discounted orders created before this change.

Tenant databases use the stable `localfind_tenant_<id>` name (with a
non-production environment prefix), so store owners can change slugs without
moving or renaming data. New databases receive a tenant-ID ownership marker.
Provisioning refuses databases without a matching marker, and it does not copy
legacy data during normal requests.

Tenant slugs now allow ASCII letters only. Check existing records before
releasing the validation change:

```sh
docker compose exec web bundle exec rails tenant_databases:check_slugs
```

Resolve any reported slugs manually; the application does not rewrite existing
store URLs. The migration clears prior `database_migrated_at` values because
those values were set without verifiable ownership or copy checks.

Legacy databases have no ownership marker, so the migration intentionally
requires an operator to verify each database from a trusted backup/inventory
before attesting ownership. `adopt` only writes ownership metadata; it never
copies or deletes application data. Supply the exact database name as MySQL
reports it (including the environment prefix in development/test):

```sh
docker compose exec -e TENANT_ID=42 -e DATABASE=development_cornerstore -e CONFIRM_TENANT_ID=42 web bundle exec rails tenant_databases:adopt
docker compose exec -e TENANT_ID=42 -e DATABASE=development_localfind_tenant_42 -e CONFIRM_TENANT_ID=42 web bundle exec rails tenant_databases:adopt
```

After attesting both the source and target database ownership, run the
idempotent copy-and-verify task. If the slug has changed, provide the legacy
database name explicitly. A missing legacy database requires an explicit
confirmation:

```sh
docker compose exec -e TENANT_ID=42 web bundle exec rails tenant_databases:migrate
docker compose exec -e TENANT_ID=42 -e LEGACY_DATABASE=development_oldstore web bundle exec rails tenant_databases:migrate
docker compose exec -e TENANT_ID=42 -e NO_LEGACY=1 web bundle exec rails tenant_databases:migrate
docker compose exec web bundle exec rails tenant_databases:verify
```

Back up the shared and tenant databases before this process, and stop or drain
any application instances that could still write to the legacy databases while
the copy runs. Do not attest a database based only on its name. The source
database is retained, and copy conflicts or mismatched rows stop the migration
without setting its completion marker. `tenant_databases:verify` is read-only.
API errors use an `errors` array, including authentication and not-found
responses.

## Admin dashboard microfrontend

The platform admin dashboard is a standalone single-spa microfrontend under
`mfe/admin-dashboard`. Its API is the `admin-dashboard-api` service under
`services/admin-dashboard-api`. Security Logs is a separately built child
microfrontend under `mfe/security-logs`, loaded and mounted by the dashboard
when that tab is selected. Other dashboard tabs call the `admin-dashboard-api`
service; the child MFE calls its own `security-logs-api` service. Rails owns
browser login and session validation and issues short-lived JWTs that each
backend validates, including the admin role.

Start the Rails app, API service, and dashboard MFE with Docker Compose:

```sh
docker compose up -d web admin-dashboard-api admin-dashboard security-logs security-logs-api
docker compose logs -f admin-dashboard-api admin-dashboard security-logs security-logs-api
```

The parent dashboard MFE is served on port `8500`; the nested Security Logs MFE
is served independently on port `8501`, and its dedicated micro-backend runs
on port `3101`.

Sign in as a platform admin and open
`http://localhost:3000/localFind/admin/dashboard`. The old `/admin/dashboard`
and `/admin/security` URLs redirect to their prefixed dashboard paths.

For a production asset, run `npm run build` in `mfe/admin-dashboard` and copy
`mfe/admin-dashboard/dist/localfind-admin-dashboard.js` to
`public/mfe/localfind-admin-dashboard.js`. Build the child bundle in
`mfe/security-logs` and copy
`mfe/security-logs/dist/localfind-security-logs.js` to
`public/mfe/localfind-security-logs.js`.

## Reusable React UI components

Shared UI primitives and product components live in
`app/javascript/components/ui` and `app/javascript/components/product`. The
React app loads their shared styles through
`app/javascript/components/pages/shop/catalog.css`. Shopper and store-owner
screens are grouped under `app/javascript/components/pages`. Import the
primitives from the UI barrel:

```jsx
import { Badge, Button, Card, Input, PageContainer } from "../ui";

<PageContainer>
  <Card title="Store information" description="Your public store details">
    <p>Store details go here.</p>
    <Button variant="primary">Edit store</Button>
    <Badge>Active</Badge>
  </Card>
  <Input label="Store name" value={name} onChange={handleNameChange} />
</PageContainer>
```

Component rendering tests can be run with
`node --test test/ui_components.test.cjs`.
