class Api::PushSubscriptionsController < ApplicationController
  def create
    data = params[:push_subscription]

    endpoint = data[:endpoint]
    keys = params[:keys]
    return head :bad_request unless endpoint && keys

    user = current_user
    return head :unauthorized unless user

    subscription = user.push_subscriptions.find_or_initialize_by(endpoint: endpoint)

    subscription.p256dh_key = keys[:p256dh]
    subscription.auth_key = keys[:auth]

    if subscription.save
      head :ok
    else
      render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def index
    @push_subscriptions = PushSubscription.all
    render json: @push_subscriptions
  end
end
