Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get "security/login_audits", to: "security/login_audits#index"
    end
  end
end
