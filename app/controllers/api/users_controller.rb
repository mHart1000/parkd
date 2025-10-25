module Api
  class UsersController < ApiController
    def create
      user = User.new(user_params)
      if user.save
        render json: user, serializer: UserSerializer, status: :created
      else
        render_error(user.errors.full_messages.join(", "), :unprocessable_entity)
      end
    end

    def show
      render json: current_user, serializer: UserSerializer
    end

    private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end
  end
end
