class Api::ParkingSpotsController < Api::ApiController
  def index
    if params[:active] == "true"
      spot = current_user.parking_spots.find_by(active: true)
      if spot
        render json: spot
      else
        head :no_content
      end
    else
      render json: current_user.parking_spots
    end
  end

  def create
    spot_params = parking_spot_params

    if spot_params[:geometry].present?
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      lng, lat = spot_params[:geometry][:coordinates]
      spot_params[:geometry] = factory.point(lng, lat)
    end

    current_user.parking_spots.update_all(active: false)

    spot = current_user.parking_spots.new(spot_params)

    if spot.save
      render json: spot, status: :created
    else
      render json: { errors: spot.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def parking_spot_params
    params.require(:parking_spot).permit(:side_of_street, :active, geometry: {}, coordinates: {}, address: {})
  end
end
