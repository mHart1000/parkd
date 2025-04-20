class CreateStreetSections < ActiveRecord::Migration[7.2]
  def change
    create_table :street_sections do |t|
      t.references :user, null: false, foreign_key: true
      t.jsonb :coordinates
      t.jsonb :address
      t.string :street_direction
      t.string :side_of_street
      t.jsonb :center

      t.timestamps
    end
  end
end
