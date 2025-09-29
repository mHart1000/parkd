Rails.application.routes.draw do
  devise_for :users, path: "api/users", defaults: { format: :json }, controllers: {
    sessions: "api/sessions",
    registrations: "api/registrations"
  }

  namespace :api do
    resources :users, only: [ :index, :show, :create, :update, :destroy ]
    resources :street_sections, only: [ :index, :create, :show, :update, :destroy ]
    resources :parking_rules, only: [ :index, :create, :show, :update, :destroy ]
    resources :parking_spots, only: [ :index, :create, :show, :update, :destroy ]
    get "alerts/nearby_upcoming_rules", to: "alerts#nearby_upcoming_rules"
  end

  # Health check endpoint for uptime monitoring
  get "up" => "rails/health#show", as: :rails_health_check
end
