module Api
  class SessionsController < Devise::SessionsController
    respond_to :json

    def create
      Rails.logger.info "Attempting to sign in with params: #{params[:user].inspect}"
      user_params = params.require(:user).permit(:email, :password)
      self.resource = warden.authenticate!(auth_options.merge(scope: :user))
      if self.resource
        sign_in(resource_name, resource)
        respond_with(resource, location: after_sign_in_path_for(resource))
      else
        render json: { error: 'Invalid credentials' }, status: :unauthorized
      end
    end

    private

    def respond_with(resource, _opts = {})
      if resource.persisted?
        render json: { user: resource }, status: :ok
      else
        render json: { error: 'Invalid credentials' }, status: :unauthorized
      end
    end

    def respond_to_on_destroy
      head :no_content
    end

    def auth_options
      { scope: resource_name }
    end
  end
end