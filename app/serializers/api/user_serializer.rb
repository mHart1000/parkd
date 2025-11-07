class Api::UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email
end
