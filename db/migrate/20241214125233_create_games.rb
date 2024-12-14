class CreateGames < ActiveRecord::Migration[7.0]
  def change
    create_table :games do |t|
      t.string :name, null: false
      t.integer :capacity, null: false
      t.string :passcode, null: false
      t.string :admin_username, null: false
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :games, :name, unique: true
  end
end
