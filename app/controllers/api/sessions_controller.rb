module Api
  class SessionsController < Devise::SessionsController
    respond_to :json

    def create
      Rails.logger.info "Attempting to sign in with params: #{params[:user].inspect}"
      user_params = params.require(:user).permit(:email, :password)

      # Authenticate the user
      self.resource = warden.authenticate!(auth_options.merge(scope: :user))
      if self.resource
        sign_in(resource_name, resource)

        # Add the JWT token to the response
        token = request.env['warden-jwt_auth.token']
        render json: { user: resource, token: token }, status: :ok
      else
        render json: { error: 'Invalid credentials' }, status: :unauthorized
      end
    end

    private

    def respond_with(resource, _opts = {})
      if resource.persisted?
        token = request.env['warden-jwt_auth.token']
        render json: { user: resource, token: token }, status: :ok
      else
        render json: { error: 'Invalid credentials' }, status: :unauthorized
      end
    end

    def respond_to_on_destroy
      # Ensure proper response on logout
      if current_user
        head :no_content
      else
        render json: { error: 'User not logged in' }, status: :unauthorized
      end
    end

    def auth_options
      { scope: resource_name }
    end
  end
end
