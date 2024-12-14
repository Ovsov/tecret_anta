module TecretAnta
  class Player < ActiveRecord::Base
    has_many :game_participations
    has_many :games, through: :game_participations

    validates :username, presence: true
    validates :chat_id, presence: true
  end
end
