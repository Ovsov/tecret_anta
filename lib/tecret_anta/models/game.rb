# lib/tecret_anta/models/game.rb
module TecretAnta
  class Game < ActiveRecord::Base
    # Relations
    has_many :game_participations, dependent: :destroy
    has_many :players, through: :game_participations
    has_many :exceptions, dependent: :destroy

    # Validations
    validates :name, presence: true, uniqueness: true
    validates :capacity, numericality: { greater_than_or_equal_to: 2 }
    validates :passcode, presence: true
    validates :admin_username, presence: true

    # Scopes
    scope :active, -> { where(active: true) }
    scope :by_admin, ->(username) { where(admin_username: username) }
    scope :available_to_join, -> { active.where('player_count < capacity') }

    # Game state methods
    def full?
      player_count >= capacity
    end

    def active?
      active
    end

    def can_start?
      player_count >= 2 && player_count <= capacity
    end

    # Player management methods
    def add_player(username, chat_id)
      return false if full? || has_player?(username)

      player = Player.find_or_create_by(username: username) do |p|
        p.chat_id = chat_id
      end

      game_participations.create(player: player)
      update_player_count
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    def remove_player(username)
      return false if username == admin_username

      player = players.find_by(username: username)
      return false unless player

      game_participations.find_by(player: player)&.destroy
      update_player_count
      true
    end

    def has_player?(username)
      players.exists?(username: username)
    end

    # Exception management methods
    def add_exception(username1, username2)
      pope = players.find_by(username: username1)
      caliph = players.find_by(username: username2)

      return false unless pope && caliph
      return false if has_exception?(pope, caliph)

      exceptions.create!(
        pope: pope,
        caliph: caliph
      )
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    def has_exception?(player1, player2)
      exceptions.exists?(
        '(pope_id = ? AND caliph_id = ?) OR (pope_id = ? AND caliph_id = ?)',
        player1.id, player2.id, player2.id, player1.id
      )
    end

    def remove_exception(username1, username2)
      pope = players.find_by(username: username1)
      caliph = players.find_by(username: username2)

      return false unless pope && caliph

      exception = exceptions.find_by(
        '(pope_id = ? AND caliph_id = ?) OR (pope_id = ? AND caliph_id = ?)',
        pope.id, caliph.id, caliph.id, pope.id
      )

      exception&.destroy.present?
    end

    # Game mechanics methods
    def generate_pairs
      return false unless can_start?

      max_attempts = 100
      participations = game_participations.includes(:player).to_a

      max_attempts.times do
        pairs = attempt_pair_generation(participations)
        if pairs
          save_pairs(pairs)
          return true
        end
      end

      raise "Could not generate valid pairs after #{max_attempts} attempts"
    end

    # Authentication methods
    def verify_passcode(code)
      passcode == code
    end

    def change_passcode(old_code, new_code)
      return false unless verify_passcode(old_code)

      update(passcode: new_code)
    end

    # Stats methods
    def player_count
      game_participations.count
    end

    def slots_left
      capacity - player_count
    end

    def to_h
      {
        name: name,
        capacity: capacity,
        admin: admin_username,
        player_count: player_count,
        slots_left: slots_left,
        active: active,
        players: players.pluck(:username),
        created_at: created_at
      }
    end

    private

    def attempt_pair_generation(participations)
      receivers = participations.map(&:player).shuffle
      pairs = {}
      valid = true

      participations.each_with_index do |participation, i|
        giver = participation.player
        receiver = receivers[i]

        if invalid_pair?(giver, receiver)
          valid = false
          break
        end

        pairs[participation] = receiver
      end

      valid ? pairs : nil
    end

    def invalid_pair?(giver, receiver)
      return true if giver.id == receiver.id

      has_exception?(giver, receiver)
    end

    def save_pairs(pairs)
      game_participations.transaction do
        pairs.each do |participation, receiver|
          participation.update!(assigned_to_username: receiver.username)
        end
        update!(active: false)
      end
    end

    def update_player_count
      update_column(:player_count, game_participations.count)
    end
  end
end
