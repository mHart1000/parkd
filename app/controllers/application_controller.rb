class ApplicationController < ActionController::API
  before_action :set_cors_headers

  private

  def set_cors_headers
    response.set_header('Access-Control-Allow-Credentials', 'true')
  end
end
