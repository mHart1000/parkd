module Api
  class StreetSectionsController < ApplicationController
    before_action :authenticate_user!

    def index
      features = current_user.street_sections.map do |s|
        next unless s.coordinates.present?

        {
          type: "Feature",
          geometry: s.coordinates["geometry"],
          properties: {
            id: s.id,
            side_of_street: s.side_of_street,
            street_direction: s.street_direction,
            address: s.address,
            center: s.center
          }
        }
      end.compact

      render json: {
        type: "FeatureCollection",
        features: features
      }
    end

    def create
      Rails.logger.debug "########## street sections create ############"
      Rails.logger.debug params
      section = current_user.street_sections.build(street_section_params)
      Rails.logger.debug section.inspect
      Rails.logger.debug section.parking_rules.first&.inspect
      if section.save
        render json: section, status: :created
      else
        render json: { errors: section.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def show
    end

    def update
      section = current_user.street_sections.find(params[:id])
      if section.update(street_section_params)
        render json: section
      else
        render json: { errors: section.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
    end

    def street_section_params
      params.require(:street_section).permit(
        :street_direction,
        :side_of_street,
        address: {},
        center: [],
        coordinates: {},
        parking_rules_attributes: [
          :id,
          :start_time,
          :end_time,
          :day_of_week,
          :day_of_month,
          :even_odd,
          :start_date,
          :end_date,
          { ordinal: [] }
        ]
      )
    end
  end
end
