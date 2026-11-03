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
  config.tenant_names = -> { Tenant.pluck(:id).map { |id| "localfind_tenant_#{id}" } }
  config.prepend_environment = !Rails.env.production?
end
