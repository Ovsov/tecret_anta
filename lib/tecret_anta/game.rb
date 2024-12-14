# lib/tecret_anta/game.rb
module TecretAnta
  class Game
    attr_reader :name, :capacity, :players, :exceptions, :admin

    def initialize(name:, capacity:, admin:, passcode:)
      validate_inputs(name, capacity, admin, passcode)

      @name = name
      @capacity = capacity
      @admin = admin
      @passcode = passcode
      @players = [admin] # Admin is automatically first player
      @exceptions = []
      @active = true
      @created_at = Time.now
    end

    def add_player(username)
      return false if any_invalid_player_state?(username)

      @players << username
      true
    end

    def add_exception(user1, user2)
      return false if invalid_exception?(user1, user2)

      @exceptions << [user1, user2]
      true
    end

    def remove_player(username)
      return false if username == @admin

      @players.delete(username)
      true
    end

    def remove_exception(user1, user2)
      @exceptions.delete([user1, user2])
      @exceptions.delete([user2, user1])
    end

    def full?
      @players.length >= @capacity
    end

    def has_player?(username)
      @players.include?(username)
    end

    def active?
      @active
    end

    def deactivate!
      @active = false
    end

    def verify_passcode(code)
      @passcode == code
    end

    def change_passcode(old_code, new_code)
      return false unless verify_passcode(old_code)

      @passcode = new_code
      true
    end

    def player_count
      @players.length
    end

    def slots_left
      @capacity - player_count
    end

    def can_start?
      player_count >= 2 && player_count <= @capacity
    end

    def generate_pairs
      max_attempts = 100
      max_attempts.times do
        pairs = attempt_pair_generation
        return pairs if pairs
      end

      raise "Could not generate valid pairs with given exceptions after #{max_attempts} attempts"
    end

    def to_h
      {
        name: @name,
        capacity: @capacity,
        admin: @admin,
        players: @players,
        exceptions: @exceptions,
        active: @active,
        player_count: player_count,
        slots_left: slots_left,
        created_at: @created_at
      }
    end

    private

    def validate_inputs(name, capacity, admin, passcode)
      raise ArgumentError, 'Name cannot be empty' if name.nil? || name.strip.empty?
      raise ArgumentError, 'Capacity must be at least 2' if capacity.nil? || capacity < 2
      raise ArgumentError, 'Admin username cannot be empty' if admin.nil? || admin.strip.empty?
      raise ArgumentError, 'Passcode cannot be empty' if passcode.nil? || passcode.strip.empty?
    end

    def any_invalid_player_state?(username)
      return true if username.nil? || username.strip.empty?
      return true if full?
      return true if has_player?(username)
      return true unless active?

      false
    end

    def invalid_exception?(user1, user2)
      return true if user1.nil? || user2.nil?
      return true if user1.strip.empty? || user2.strip.empty?
      return true if user1 == user2
      return true if !has_player?(user1) || !has_player?(user2)

      false
    end

    def attempt_pair_generation
      receivers = @players.dup.shuffle
      pairs = {}
      valid = true

      @players.each_with_index do |giver, i|
        receiver = receivers[i]

        if invalid_pair?(giver, receiver)
          valid = false
          break
        end

        pairs[giver] = receiver
      end

      valid ? pairs : nil
    end

    def invalid_pair?(giver, receiver)
      return true if giver == receiver

      @exceptions.any? do |e|
        (e[0] == giver && e[1] == receiver) ||
          (e[0] == receiver && e[1] == giver)
      end
    end
  end
end
