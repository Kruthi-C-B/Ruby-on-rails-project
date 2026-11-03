Apartment.configure do |config|
  config.excluded_models = %w[
    User
    Tenant
    Product
    Category
    ListingReference
    Cart
    CartItem
    Discount
    LoginAudit
    LoginAttempt
  ]
  config.tenant_names = -> { Tenant.pluck(:slug) }
  config.prepend_environment = !Rails.env.production?
end
