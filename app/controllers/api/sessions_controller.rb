module Api
  class SessionsController < Devise::SessionsController
    include RackSessionsFix
    respond_to :json


    def create
      self.resource = warden.authenticate!(auth_options)
      sign_in(resource_name, resource)

      token = request.env["warden-jwt_auth.token"]
      Rails.logger.info "JWT Token: #{token}"

      render json: { user: resource, token: token }, status: :ok
    end

    private

    def respond_with(resource, _opts = {})
      render json: {
        user: resource,
        token: request.env["warden-jwt_auth.token"]
      }, status: :ok
    end


    def respond_to_on_destroy
      # Ensure proper response on logout
      if current_user
        head :no_content
      else
        render json: { error: "User not logged in" }, status: :unauthorized
      end
    end

    def auth_options
      { scope: resource_name }
    end
  end
end
