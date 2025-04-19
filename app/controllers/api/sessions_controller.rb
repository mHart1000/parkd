module Api
  class SessionsController < Devise::SessionsController
    respond_to :json

    def create
      Rails.logger.info "RAW PARAMS: #{params.to_unsafe_h.inspect}"
      Rails.logger.info "user params: #{params[:user].inspect}" if params[:user]

      user_params = params.require(:user).permit(:email, :password)
      Rails.logger.info "PERMITTED PARAMS: #{user_params.inspect}"


      # Authenticate the user
      self.resource = warden.authenticate(auth_options.merge(scope: :user))

      Rails.logger.info "Authenticated resource: #{resource.inspect}"
       user = User.find_by(email: user_params[:email])

      Rails.logger.info "User: #{user.inspect}"
      Rails.logger.info "User valid_password?: #{user.valid_password?(user_params[:password]).inspect}"
      if user && user.valid_password?(user_params[:password])
        sign_in(:user, user, store: false)
        Rails.logger.info "User signed in: #{user.inspect}"
        # Set the current user in the request environment


        # Add the JWT token to the response
        token = request.env['warden-jwt_auth.token']
        Rails.logger.info "Generated token: #{token.inspect}"
        Rails.logger.info "request.env: #{request.env.inspect}"
        Rails.logger.info "warden-jwt_auth.token: #{request.env['warden-jwt_auth.token'].inspect}"
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
