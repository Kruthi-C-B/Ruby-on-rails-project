Rails.application.routes.draw do
  # React pages: Rails sends the same page, React Router picks the screen
  root "catalog#index"
  get "/products", to: "catalog#index", as: :products
  get "/products/:id", to: "catalog#index", as: :product

  # JSON API used by the React pages
  namespace :api do
    namespace :v1 do
      get "me", to: "users#me"
      resources :categories, only: :index
      resources :products, only: %i[index show]
      resources :discounts, only: [ :index ]

      namespace :admin do
        resources :categories, only: [ :create ]
        resources :products, only: [ :create ]
        resources :discounts, only: [ :create ]
        resources :login_audits, only: [ :index ]
        get :cart_metrics, to: "cart_metrics#index"
        get :users, to: "platform#users"
        get :stores, to: "platform#stores"
        get :audit_trail, to: "platform#audit_trail"
      end

      namespace :users do
        # Shared Cart (Available to all logged-in users)
        resource :cart, only: [ :show ] do
          post :apply_discount
          post :checkout
          get :orders # Shoppers can still see their own past orders
          resources :items, only: [ :create ], controller: "cart_items"
        end

        # Sub-domain: Store Owners
        namespace :store_owners do
          resources :product_listings, only: [ :index, :create, :update, :destroy ]
          get :analytics, to: "product_listings#analytics" # Store owner sales audit
          resource :tenant, only: [ :new, :create, :update ]
        end

        # Sub-domain: Shoppers (Ready for future features)
        namespace :shoppers do
          # e.g., resources :wishlists
        end
      end
    end
  end

  # 1. Admin Authentication Routes
  get    "/signup", to: "registrations#new"
  post   "/signup", to: "registrations#create"
  get    "/login",  to: "sessions#new"
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # 2. Single Tenant Admin Store Profile Routes
  # Uses 'resource' (singular) because 1 user admin manages only 1 store profile


  # Catch-all route: Send all other HTML requests to React
  get "*path", to: "catalog#index", constraints: ->(request) do
    !request.xhr? && request.format.html?
  end
end
