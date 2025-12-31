class MakeJtiNotNullOnUsers < ActiveRecord::Migration[7.2]
  def change
    User.where(jti: nil).update_all("jti = gen_random_uuid()")
    change_column_null :users, :jti, false
  end
end
