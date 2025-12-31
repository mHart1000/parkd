class Api::ParkingRulesController < Api::ApiController
  def index
    rules = ParkingRule.all
    rules = rules.where(street_section_id: params[:street_section_id]) if params[:street_section_id].present?
    render json: rules
  end

  def create
  end

  def show
  end

  def update
    rule = current_user.parking_rules.find(params[:id])
    if rule.update(parking_rule_params)
      render json: rule
    else
      render json: { errors: rule.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
  end

  private

  def parking_rule_params
    params.require(:parking_rule).permit(
      :day_of_week,
      :start_time,
      :end_time,
      :day_of_month,
      :even_odd,
      :start_date,
      :end_date,
      ordinal: []
    )
  end
end
