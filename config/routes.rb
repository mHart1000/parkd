Rails.application.routes.draw do
  # Devise authentication routes for API
  devise_for :users, defaults: { format: :json }

  # Health check endpoint for uptime monitoring
  get "up" => "rails/health#show", as: :rails_health_check

  # Namespace for API routes
  namespace :api do
    # Define your API resources here
    resources :users, only: [:index, :show, :create, :update, :destroy]
    # Add other resources as needed
  end
end
