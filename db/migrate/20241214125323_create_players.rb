class CreatePlayers < ActiveRecord::Migration[7.0]
  def change
    create_table :players do |t|
      t.belongs_to :game
      t.string :username, null: false
      t.integer :chat_id, null: false

      t.timestamps
    end
  end
end
