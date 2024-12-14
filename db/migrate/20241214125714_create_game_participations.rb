class CreateGameParticipations < ActiveRecord::Migration[7.0]
  def change
    create_table :game_participations do |t|
      t.belongs_to :game, index: true
      t.belongs_to :player, index: true
      t.string :assigned_to_username

      t.timestamps
    end

    add_index :game_participations, %i[game_id player_id], unique: true
  end
end
