Rails.application.routes.draw do
  # Devise authentication routes for API
  namespace :api do
    devise_for :users, defaults: { format: :json }, controllers: {
      sessions: 'api/sessions',
      registrations: 'api/registrations'
    }

    # Define your API resources here
    resources :users, only: [:index, :show, :create, :update, :destroy]
    # Add other resources as needed
  end

  # Health check endpoint for uptime monitoring
  get "up" => "rails/health#show", as: :rails_health_check
end
