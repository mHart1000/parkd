module Api
  class ApiController < ApplicationController
    before_action :authenticate_user!

    def render_error(message, status = :unprocessable_entity)
      render json: { error: message }, status: status
    end
  end
end
