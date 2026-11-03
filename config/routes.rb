Rails.application.routes.draw do
  # React pages: Rails sends the same page, React Router picks the screen
  root to: redirect("/localFind")
  get "/localFind", to: "catalog#index", as: :local_find
  get "/localFind/products", to: "catalog#index", as: :products
  get "/localFind/products/:id", to: "catalog#index", as: :product
  get "/localFind/admin/dashboard", to: "admin_dashboard#show"
  get "/localFind/admin/security", to: redirect("/localFind/admin/dashboard")
  get "/admin/dashboard", to: redirect("/localFind/admin/dashboard")
  get "/admin/security", to: redirect("/localFind/admin/security")

  get "/favicon.ico", to: redirect("/icon.png")

  # JSON API used by the React pages
  namespace :api do
    namespace :v1 do
      get "me", to: "users#me"
      get "auth/token", to: "auth_tokens#show"
      namespace :internal do
        namespace :admin do
          get :product_references, to: "tenant_data#product_references"
          get :audit_trail, to: "tenant_data#audit_trail"
        end
      end
      resources :categories, only: :index
      resources :products, only: %i[index show]
      resources :discounts, only: [ :index ]

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
  get    "/localFind/signup", to: "registrations#new", as: :signup
  post   "/localFind/signup", to: "registrations#create"
  get    "/localFind/login",  to: "sessions#new", as: :login
  post   "/localFind/login",  to: "sessions#create"
  delete "/localFind/logout", to: "sessions#destroy", as: :logout

  # 2. Single Tenant Admin Store Profile Routes
  # Uses 'resource' (singular) because 1 user admin manages only 1 store profile


  # Send remaining /localFind HTML routes to React for client-side routing.
  get "/localFind/*path", to: "catalog#index", constraints: ->(request) do
    !request.xhr? && request.format.html?
  end
end
