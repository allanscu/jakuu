class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :address_1
      t.string :address_2
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :country
      t.string :phone
      t.string :authy_id
      t.float :latitude
      t.float :longitude
      t.boolean :verified, default: false

      t.timestamps null: false
    end
  end
end
