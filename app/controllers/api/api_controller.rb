module Api
  class ApiController < ApplicationController
    def render_error(message, status = :unprocessable_entity)
      render json: { error: message }, status: status
    end
  end
end
