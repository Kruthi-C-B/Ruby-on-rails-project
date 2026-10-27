# frozen_string_literal: true

# You can have Apartment route to the appropriate Tenant by adding some Rack middleware.
# Apartment can support many different "Elevators" that can take care of this routing to your data.
# Require whichever Elevator you're using below or none if you have a custom one.
#
# require 'apartment/elevators/generic'
# require 'apartment/elevators/domain'
# require "apartment/elevators/subdomain"
# require 'apartment/elevators/first_subdomain'
# require 'apartment/elevators/host'

#
# Apartment Configuration
#

# frozen_string_literal: true

# frozen_string_literal: true

Apartment.configure do |config|
  config.excluded_models = %w[
    User
    Tenant
    Product
    Category
    Cart
    CartItem
    Discount
    LoginAudit
    LoginAttempt
  ]

  config.tenant_names = -> { Tenant.pluck(:slug) }

  config.prepend_environment = !Rails.env.production?
end


# Setup a custom Tenant switching middleware. The Proc should return the name of the Tenant that
# you want to switch to.
# Rails.application.config.middleware.use Apartment::Elevators::Generic, lambda { |request|
#   request.host.split('.').first
# }

# Rails.application.config.middleware.use Apartment::Elevators::Domain
# Rails.application.config.middleware.use(Apartment::Elevators::Subdomain)
# Rails.application.config.middleware.use Apartment::Elevators::FirstSubdomain
# Rails.application.config.middleware.use Apartment::Elevators::Host
