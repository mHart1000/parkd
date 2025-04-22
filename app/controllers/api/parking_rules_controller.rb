class Api::ParkingRulesController < ApplicationController
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
  end

  def destroy
  end
end
