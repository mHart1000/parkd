module Api
  class UsersController < ApiController
    def create
      user = User.new(user_params)
      if user.save
        render json: { user: user }, status: :created
      else
        render_error(user.errors.full_messages.join(", "), :unprocessable_entity)
      end
    end

  end
end