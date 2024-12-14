# lib/tecret_anta/models/game_participation.rb
module TecretAnta
  class GameParticipation < ActiveRecord::Base
    belongs_to :game
    belongs_to :player

    validates :game_id, presence: true
    validates :player_id, presence: true
    validates :player_id, uniqueness: { scope: :game_id, message: 'already participating in this game' }
  end
end
