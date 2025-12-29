module Api
  class UsersController < ApiController
    def show
      render json: current_user, serializer: UserSerializer
    end

    def update
      if current_user.update(user_params)
        render json: current_user, serializer: UserSerializer
      else
        render_error(current_user.errors.full_messages.join(", "), :unprocessable_entity)
      end
    end

    private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation, :notification_lead_time_hours)
    end
  end
end
