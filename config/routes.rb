Rails.application.routes.draw do
  # Public Root Placeholder (Shopper catalog home)
  root "products#index"
  resources :products, only: [ :index, :show ]

  # 1. Admin Authentication Routes
  get    "/signup", to: "registrations#new"
  post   "/signup", to: "registrations#create"
  get    "/login",  to: "sessions#new"
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # 2. Single Tenant Admin Store Profile Routes
  # Uses 'resource' (singular) because 1 user admin manages only 1 store profile
  resource :tenant, only: [ :new, :create, :edit, :update ]

  # 3. Store Product Inventory Management Routes (CRUD)
  resources :product_listings, only: [ :index, :new, :create, :edit, :update, :destroy ]
end
