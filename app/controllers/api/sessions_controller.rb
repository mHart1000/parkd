module Api
  class SessionsController < Devise::SessionsController
    include RackSessionsFix
    respond_to :json

    def create
      self.resource = warden.authenticate!(auth_options)
      sign_in(resource_name, resource)

      token = request.env["warden-jwt_auth.token"]

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
      head :no_content
    end

    def auth_options
      { scope: resource_name }
    end
  end
end
