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
      section_params = street_section_params
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      if section_params[:geometry].present?
        coords = section_params[:geometry]['coordinates']
        ring_coords = coords.first
Rails.logger.debug "########## GEOMETRY DEBUG ##########"
Rails.logger.debug coords.inspect
Rails.logger.debug coords.first.inspect
Rails.logger.debug coords.first == coords.first&.dup
Rails.logger.debug "########## GEOMETRY DEBUG ##########"

        # Ensure ring is closed (first and last point are equal)
        if ring_coords.first != ring_coords.last
          ring_coords << ring_coords.first
        end

        if ring_coords.length < 4
          return render json: { error: "Invalid polygon: must have at least 4 points" }, status: :unprocessable_entity
        end

        ring = factory.linear_ring(ring_coords.map { |lng, lat| factory.point(lng, lat) })
        polygon = factory.polygon(ring)
        section_params[:geometry] = polygon
      end

      section = current_user.street_sections.new(section_params)

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
        geometry: {},
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
