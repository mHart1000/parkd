Rails.application.routes.draw do
  namespace :api do
    devise_for :users, defaults: { format: :json }, controllers: {
      sessions: 'api/sessions',
      registrations: 'api/registrations'
    }

    resources :users, only: [:index, :show, :create, :update, :destroy]
    resources :street_sections, only: [:index, :create, :show, :update, :destroy]
    resources :parking_rules, only: [:index, :create, :show, :update, :destroy]
   end

  # Health check endpoint for uptime monitoring
  get "up" => "rails/health#show", as: :rails_health_check
end
