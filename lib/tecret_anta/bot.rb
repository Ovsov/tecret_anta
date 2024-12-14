# lib/tecret_anta/bot.rb
require 'telegram/bot'
require 'logger'

module TecretAnta
  class Bot
    TEXTS = {
      welcome: "🎄 Добро пожаловать в Secret Santa Bot!\nЧто вы хотите сделать?",
      create_game: 'Создать новую игру (Админ)',
      join_game: 'Присоединиться к игре',
      need_username: 'Пожалуйста, установите username в Telegram для участия!',
      enter_game_name: 'Введите уникальное название для вашей игры:',
      enter_passcode: 'Введите пароль для игры. Игроки будут использовать его для входа:',
      enter_capacity: 'Укажите максимальное количество игроков (минимум 2):',
      game_exists: 'Игра с таким названием уже существует. Выберите другое название:',
      join_enter_passcode: "Введите пароль для игры '%<name>s':",
      wrong_passcode: '❌ Неверный пароль! Попробуйте еще раз или выберите другую игру.',
      too_many_attempts: '❌ Слишком много неудачных попыток. Начните процесс входа заново.',
      enter_exceptions: "Введите пары, которые не должны быть matched (одна пара на сообщение) в формате 'username1,username2'\nИли отправьте /done для завершения.",
      exception_added: "✅ Исключение добавлено: %<user1>s ↔ %<user2>s\nДобавьте еще или отправьте /done",
      invalid_exception: "Неверный формат. Используйте 'username1,username2' или отправьте /done",
      game_created: "✅ Игра '%<name>s' создана!\nИгроки могут присоединиться используя это название.",
      no_games: 'Нет доступных игр для присоединения.',
      game_not_found: 'Игра не найдена.',
      already_in_game: 'Вы уже участвуете в этой игре!',
      game_full: 'Эта игра уже заполнена!',
      joined_game: '✅ Вы присоединились к игре %<name>s!',
      not_admin: 'Только администратор может выполнить это действие!',
      rollout_success: '✅ Жеребьевка для игры %<name>s завершена! Все игроки получили уведомления.',
      santa_assignment: "🎅 В игре '%<game>s' вы дарите подарок для: %<receiver>s"
    }.freeze

    def initialize(token)
      @token = token
      @games = {}
      @user_states = {}
      @admin_chat_ids = {}
      @join_attempts = {}
      @logger = Logger.new(STDOUT)
    end

    def start
      @logger.info 'Bot starting...'

      Telegram::Bot::Client.run(@token) do |bot|
        bot.listen do |message|
          case message
          when Telegram::Bot::Types::Message
            handle_message(bot, message)
          when Telegram::Bot::Types::CallbackQuery
            handle_callback(bot, message)
          end
        rescue StandardError => e
          @logger.error "Error: #{e.message}\n#{e.backtrace.join("\n")}"
          send_message(bot, message.try(:chat)&.id || message.try(:from)&.id, 'Произошла ошибка. Попробуйте еще раз.')
        end
      end
    end

    private

    def handle_message(bot, message)
      user_id = message.from.id

      case message.text
      when '/start'
        send_welcome_message(bot, message)
      when '/help'
        send_help_message(bot, message)
      when '/rollout'
        handle_rollout_command(bot, message)
      when '/done'
        handle_done_command(bot, message)
      else
        handle_text_input(bot, message)
      end
    end

    def send_welcome_message(bot, message)
      return send_message(bot, message.chat.id, TEXTS[:need_username]) unless message.from.username

      keyboard = [
        [{ text: TEXTS[:create_game], callback_data: 'create_game' }],
        [{ text: TEXTS[:join_game], callback_data: 'join_game' }]
      ]

      send_message(bot, message.chat.id, TEXTS[:welcome], keyboard)
    end

    def handle_callback(bot, query)
      case query.data
      when 'create_game'
        start_game_creation(bot, query)
      when 'join_game'
        show_available_games(bot, query)
      when /^join_(.+)/
        handle_join_game(bot, query, ::Regexp.last_match(1))
      when /^rollout_(.+)/
        perform_rollout(bot, query, ::Regexp.last_match(1))
      end
    end

    def handle_text_input(bot, message)
      user_id = message.from.id
      return unless @user_states[user_id]

      case @user_states[user_id][:state]
      when 'awaiting_game_name'
        handle_game_name(bot, message)
      when 'awaiting_passcode'
        handle_passcode_creation(bot, message)
      when 'awaiting_capacity'
        handle_capacity(bot, message)
      when 'awaiting_exceptions'
        handle_exceptions(bot, message)
      when 'joining_game'
        handle_join_passcode(bot, message)
      end
    end

    def start_game_creation(bot, query)
      user_id = query.from.id
      @user_states[user_id] = { state: 'awaiting_game_name' }
      @admin_chat_ids[query.from.username] = query.message.chat.id
      edit_message(bot, query.message, TEXTS[:enter_game_name])
    end

    def handle_game_name(bot, message)
      if @games[message.text]
        send_message(bot, message.chat.id, TEXTS[:game_exists])
        return
      end

      @user_states[message.from.id].update(
        state: 'awaiting_passcode',
        game_name: message.text
      )
      send_message(bot, message.chat.id, TEXTS[:enter_passcode])
    end

    def handle_passcode_creation(bot, message)
      @user_states[message.from.id].update(
        state: 'awaiting_capacity',
        passcode: message.text
      )
      send_message(bot, message.chat.id, TEXTS[:enter_capacity])
    end

    def handle_capacity(bot, message)
      capacity = message.text.to_i
      user_state = @user_states[message.from.id]

      begin
        game = Game.new(
          name: user_state[:game_name],
          capacity: capacity,
          admin: message.from.username,
          passcode: user_state[:passcode]
        )

        @games[game.name] = game
        @user_states[message.from.id] = { state: 'awaiting_exceptions' }

        send_message(
          bot,
          message.chat.id,
          TEXTS[:enter_exceptions]
        )
      rescue ArgumentError => e
        send_message(bot, message.chat.id, e.message)
      end
    end

    def handle_exceptions(bot, message)
      return if message.text == '/done'

      begin
        user1, user2 = message.text.split(',').map(&:strip)
        game_name = @games.values.find { |g| g.admin == message.from.username }&.name

        if game_name && @games[game_name].add_exception(user1, user2)
          send_message(
            bot,
            message.chat.id,
            format(TEXTS[:exception_added], user1: user1, user2: user2)
          )
        else
          send_message(bot, message.chat.id, TEXTS[:invalid_exception])
        end
      rescue StandardError
        send_message(bot, message.chat.id, TEXTS[:invalid_exception])
      end
    end

    def handle_done_command(bot, message)
      user_id = message.from.id
      return unless @user_states[user_id]&.[](:state) == 'awaiting_exceptions'

      game_name = @games.values.find { |g| g.admin == message.from.username }&.name
      return unless game_name

      @user_states.delete(user_id)
      send_message(
        bot,
        message.chat.id,
        format(TEXTS[:game_created], name: game_name)
      )
    end

    def show_available_games(bot, query)
      available_games = @games.select { |_, game| !game.full? && game.active? }

      if available_games.empty?
        edit_message(bot, query.message, TEXTS[:no_games])
        return
      end

      keyboard = available_games.map do |name, _|
        [{ text: name, callback_data: "join_#{name}" }]
      end

      edit_message(bot, query.message, TEXTS[:select_game], keyboard)
    end

    def handle_join_game(bot, query, game_name)
      return edit_message(bot, query.message, TEXTS[:need_username]) unless query.from.username
      return edit_message(bot, query.message, TEXTS[:game_not_found]) unless @games[game_name]

      @user_states[query.from.id] = {
        state: 'joining_game',
        game_name: game_name
      }

      edit_message(
        bot,
        query.message,
        format(TEXTS[:join_enter_passcode], name: game_name)
      )
    end

    def handle_join_passcode(bot, message)
      user_id = message.from.id
      state = @user_states[user_id]
      return unless state && state[:state] == 'joining_game'

      game = @games[state[:game_name]]

      if game.verify_passcode(message.text)
        handle_successful_join(bot, message, game)
      else
        handle_failed_join_attempt(bot, message, user_id)
      end
    end

    def handle_successful_join(bot, message, game)
      if game.add_player(message.from.username)
        send_message(
          bot,
          message.chat.id,
          format(TEXTS[:joined_game], name: game.name)
        )
        notify_admin_about_new_player(bot, game, message.from.username)
      else
        send_message(
          bot,
          message.chat.id,
          game.full? ? TEXTS[:game_full] : TEXTS[:already_in_game]
        )
      end
      @user_states.delete(message.from.id)
    end

    def handle_failed_join_attempt(bot, message, user_id)
      @join_attempts[user_id] ||= 0
      @join_attempts[user_id] += 1

      if @join_attempts[user_id] >= 3
        send_message(bot, message.chat.id, TEXTS[:too_many_attempts])
        @user_states.delete(user_id)
        @join_attempts.delete(user_id)
      else
        send_message(bot, message.chat.id, TEXTS[:wrong_passcode])
      end
    end

    def notify_admin_about_new_player(bot, game, username)
      admin_chat_id = @admin_chat_ids[game.admin]
      return unless admin_chat_id

      text = "🎅 Новый игрок в игре!\n" \
             "Игра: #{game.name}\n" \
             "Игрок: #{username}\n" \
             "Всего игроков: #{game.player_count}/#{game.capacity}"

      send_message(bot, admin_chat_id, text)

      return unless game.full?

      keyboard = [[{ text: 'Начать жеребьевку', callback_data: "rollout_#{game.name}" }]]
      send_message(
        bot,
        admin_chat_id,
        "🎄 Игра #{game.name} заполнена!\n" \
        'Можно начинать жеребьевку.',
        keyboard
      )
    end

    def perform_rollout(bot, query, game_name)
      game = @games[game_name]
      return edit_message(bot, query.message, TEXTS[:game_not_found]) unless game
      return edit_message(bot, query.message, TEXTS[:not_admin]) if query.from.username != game.admin

      begin
        pairs = game.generate_pairs
        pairs.each do |giver, receiver|
          chat_id = @admin_chat_ids[giver]
          next unless chat_id

          send_message(
            bot,
            chat_id,
            format(TEXTS[:santa_assignment], game: game_name, receiver: receiver)
          )
        end

        game.deactivate!
        edit_message(
          bot,
          query.message,
          format(TEXTS[:rollout_success], name: game_name)
        )
      rescue StandardError => e
        @logger.error "Rollout error: #{e.message}"
        edit_message(bot, query.message, "Ошибка при жеребьевке: #{e.message}")
      end
    end

    def send_message(bot, chat_id, text, keyboard = nil)
      return unless chat_id

      markup = keyboard ? Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard) : nil
      bot.api.send_message(chat_id: chat_id, text: text, reply_markup: markup)
    rescue StandardError => e
      @logger.error "Send message error: #{e.message}"
    end

    def edit_message(bot, message, text, keyboard = nil)
      markup = keyboard ? Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard) : nil
      bot.api.edit_message_text(
        chat_id: message.chat.id,
        message_id: message.message_id,
        text: text,
        reply_markup: markup
      )
    rescue StandardError => e
      @logger.error "Edit message error: #{e.message}"
    end
  end
end
