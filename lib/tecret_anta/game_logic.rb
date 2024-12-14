module TecretAnta
  class GameLogic
    class GameError < StandardError; end

    def initialize(game)
      @game = game
    end

    def verify_passcode(code)
      @game.passcode == code
    end

    def can_join?(username)
      return false if @game.full?
      return false if @game.has_player?(username)
      return false unless @game.active?
      true
    end

    def add_player(username, chat_id)
      return false unless can_join?(username)
      
      @game.transaction do
        player = Player.find_or_create_by!(username: username) do |p|
          p.chat_id = chat_id
        end
        
        @game.game_participations.create!(player: player)
        @game.increment!(:player_count)
      end
      true
    rescue ActiveRecord::RecordInvalid => e
      false
    end

    def add_exception(username1, username2)
      player1 = @game.players.find_by(username: username1)
      player2 = @game.players.find_by(username: username2)

      return false unless player1 && player2
      return false if @game.has_exception?(username1, username2)
      
      @game.exceptions.create!(
        pope: player1,
        caliph: player2
      )
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    def generate_pairs
      return false unless @game.can_start?

      pairs = attempt_pairing
      raise GameError, "Could not generate valid pairs after multiple attempts" unless pairs

      save_pairs(pairs)
      format_pairs(pairs)
    end

    def game_status
      {
        name: @game.name,
        admin: @game.admin_username,
        player_count: @game.player_count,
        capacity: @game.capacity,
        active: @game.active?,
        players: @game.players.pluck(:username),
        exceptions: format_exceptions,
        created_at: @game.created_at
      }
    end

    private

    def attempt_pairing
      max_attempts = 100
      participants = @game.game_participations.includes(:player).to_a

      max_attempts.times do
        shuffled = participants.map(&:player).shuffle
        pairs = {}
        valid = true

        participants.each_with_index do |participation, i|
          giver = participation.player
          receiver = shuffled[i]

          if invalid_pair?(giver, receiver)
            valid = false
            break
          end

          pairs[participation] = receiver
        end

        return pairs if valid
      end

      nil
    end

    def invalid_pair?(giver, receiver)
      return true if giver.id == receiver.id
      @game.has_exception?(giver.username, receiver.username)
    end

    def save_pairs(pairs)
      @game.transaction do
        pairs.each do |participation, receiver|
          participation.update!(assigned_to_username: receiver.username)
        end
        @game.update!(active: false)
      end
    end

    def format_pairs(pairs)
      pairs.map do |participation, receiver|
        {
          giver: {
            username: participation.player.username,
            chat_id: participation.player.chat_id
          },
          receiver: receiver.username
        }
      end
    end

    def format_exceptions
      @game.exceptions.map do |exception|
        {
          pope: exception.pope.username,
          caliph: exception.caliph.username
        }
      end
    end

    def validate_player_in_game(username)
      @game.has_player?(username)
    end

    def validate_exception(username1, username2)
      return false if username1 == username2
      return false unless validate_player_in_game(username1)
      return false unless validate_player_in_game(username2)
      true
    end
  end
end