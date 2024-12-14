module TecretAnta
  class Exception < ActiveRecord::Base
    belongs_to :game
    belongs_to :pope, class_name: 'Player'
    belongs_to :caliph, class_name: 'Player'

    validates :game_id, presence: true
    validates :pope_id, presence: true
    validates :caliph_id, presence: true
    validate :players_in_same_game
    validate :players_are_different
    validate :no_duplicate_exception_in_game

    private

    def players_in_same_game
      return if game.has_player?(pope.username) && game.has_player?(caliph.username)

        errors.add(:base, 'Both players must be in the game')
    end

    def players_are_different
      return unless pope_id == caliph_id

        errors.add(:base, 'Cannot create exception for same player')
    end

    def no_duplicate_exception_in_game
      return unless game_id && pope_id && caliph_id

      duplicate = game.exceptions.where(
        '(pope_id = ? AND caliph_id = ?) OR (pope_id = ? AND caliph_id = ?)',
        pope_id, caliph_id,
        caliph_id, pope_id
      ).where.not(id: id).exists?

      return unless duplicate

        errors.add(:base, 'Exception between these players already exists in this game')
    end
  end
end
