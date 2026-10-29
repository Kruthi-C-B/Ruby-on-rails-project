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
