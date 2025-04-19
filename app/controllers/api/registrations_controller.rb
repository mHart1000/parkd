module Api
  class RegistrationsController < Devise::RegistrationsController
    respond_to :json

    # Prevent Devise from signing in the user (which tries to write to the session)
    def create
      build_resource(sign_up_params)

      if resource.save
        render json: {
          message: 'User created successfully.',
          user: {
            id: resource.id,
            email: resource.email,
            name: resource.name
          }
        }, status: :created
      else
        render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def sign_up_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end

  end
end
