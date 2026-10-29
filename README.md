# README

This README would normally document whatever steps are necessary to get the
application up and running.

## Tenant databases and purchase history

Tenant-specific product listings and purchase history are stored in the
tenant's Apartment database. Shared `listing_references` rows connect catalog
products and cart items to tenant-local listings.

Run migrations from the Rails Docker service after pulling schema changes:

```sh
docker compose exec web bundle exec rails db:migrate
```

The listing migrations provision databases for existing tenants and transfer
their legacy product listings. They also remove unused copies of shared tables
from existing tenant databases. New store tenants are provisioned without those
shared-table copies.

Checkout writes each store's purchase history and PaperTrail versions to that
store's tenant database; a cart containing products from multiple stores is
recorded separately in each store database. Cart discounts are rounded to cents
and allocated across tenant-local purchase rows so order history records the
actual amount paid. The discount-total migration also corrects completed
discounted orders created before this change.

## Login audit microfrontend

The admin login audit screen is a standalone single-spa microfrontend under
`mfe/login-audit`. Rails serves the `/admin/security` page and its JSON API;
the browser loads the MFE separately from port 8500 in development.

After starting Rails on port 3000, start the MFE with Docker Compose:

```sh
docker compose up -d login-audit
docker compose logs -f login-audit
```

Sign in as a platform admin and open `http://localhost:3000/admin/security`.
For a production asset, run `npm run build` in `mfe/login-audit` and copy
`mfe/login-audit/dist/localfind-login-audit.js` to
`public/mfe/localfind-login-audit.js`.

## Reusable React UI components

Shared UI primitives and product components live in
`app/javascript/components/ui` and `app/javascript/components/product`. The
React app loads their shared styles through `Root/catalog.css`. Import the
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
