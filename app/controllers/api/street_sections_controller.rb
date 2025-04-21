module Api
  class StreetSectionsController < ApplicationController
    before_action :authenticate_user!

    def index
    end

    def create
      section = current_user.street_sections.build(street_section_params)
      if section.save
        render json: section, status: :created
      else
        render json: { errors: section.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def show
    end

    def update
    end

    def destroy
    end

    def street_section_params
      params.require(:street_section).permit(
        :coordinates,
        :address,
        :street_direction,
        :side_of_street,
        :center_coordinates,
        parking_rules_attributes: [
          :start_time,
          :end_time,
          :day_of_week,
          :day_of_month,
          :day_parity,
          :start_date,
          :end_date,
          { ordinal: [] }
        ]
      )
    end
  end
end
