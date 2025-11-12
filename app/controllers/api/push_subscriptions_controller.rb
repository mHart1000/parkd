class Api::PushSubscriptionsController < ApplicationController
  def create
    subscription = PushSubscription.find_or_initialize_by(endpoint: params[:endpoint])
    subscription.update!(
      p256dh_key: params[:keys][:p256dh],
      auth_key: params[:keys][:auth]
    )
    head :ok
  end
end
