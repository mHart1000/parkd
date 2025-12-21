class Api::UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :notification_lead_time_hours
end
