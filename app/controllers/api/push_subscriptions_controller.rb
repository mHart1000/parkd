class Api::PushSubscriptionsController < ApplicationController
  def create
    data = params[:push_subscription] || params

    endpoint = data[:endpoint]
    keys = data[:keys] || params[:keys]

    subscription = PushSubscription.find_or_initialize_by(endpoint: endpoint)

    subscription.p256dh_key = keys[:p256dh]
    subscription.auth_key = keys[:auth]

    subscription.save!

    head :ok
  end

  def index
    @push_subscriptions = PushSubscription.all
    render json: @push_subscriptions
  end
end
