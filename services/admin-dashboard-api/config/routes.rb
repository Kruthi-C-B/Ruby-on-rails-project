Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      namespace :admin do
        resources :categories, only: %i[index create update destroy]
        resources :products, only: %i[index create update destroy]
        resources :discounts, only: %i[index create update destroy]
        get :users, to: "platform#users"
        get :stores, to: "platform#stores"
        get :audit_trail, to: "platform#audit_trail"
        get :cart_metrics, to: "platform#cart_metrics"
      end
    end
  end
end
