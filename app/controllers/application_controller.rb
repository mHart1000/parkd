class ApplicationController < ActionController::API
  before_action :set_cors_headers

  rescue_from StandardError, with: :handle_standard_error

  private

  def set_default_response_format
    quest.format = :json
  end

  def set_cors_headers
    response.set_header('Access-Control-Allow-Origin', 'http://localhost:9000')
    response.set_header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD')
    response.set_header('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization, Token')
    response.set_header('Access-Control-Allow-Credentials', 'true')
  end

  def handle_standard_error(exception)
    Rails.logger.error "Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    render_error("An unexpected error occurred. Please try again later.", :internal_server_error)
  end
end
