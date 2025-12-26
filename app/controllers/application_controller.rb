class ApplicationController < ActionController::API
  include Devise::Controllers::Helpers

  before_action :set_default_response_format
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from StandardError, with: :handle_standard_error

  private

  def set_default_response_format
    request.format = :json
  end

  def handle_standard_error(exception)
    Rails.logger.error "Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    render json: { error: exception.message }, status: :internal_server_error
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :email, :password ])
  end
end
