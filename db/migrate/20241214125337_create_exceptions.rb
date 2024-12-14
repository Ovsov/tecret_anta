class CreateExceptions < ActiveRecord::Migration[7.0]
  def change
    create_table :exceptions do |t|
      t.belongs_to :game
      t.string :pope, null: false
      t.string :caliph, null: false

      t.timestamps
    end

    execute <<-SQL
      CREATE UNIQUE INDEX index_unique_exceptions_per_game ON exceptions (
        game_id,
        LEAST(pope_id, caliph_id),
        GREATEST(pope_id, caliph_id)
      )
    SQL
  end
end
