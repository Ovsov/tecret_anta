# Tecret Anta

A Telegram bot for organizing Secret Santa games with features like:
- Password-protected games
- Multiple simultaneous games
- Exception pairs (people who shouldn't be matched)
- Admin controls

## Installation

1. Clone the repository:
```bash
git clone https://github.com/Ovsov/tecret_anta.git
cd tecret_anta
```

2. Install dependencies:
```bash
bundle install
```

3. Set up your environment:
   - Create a `.env` file in the project root
   - Get a bot token from [@BotFather](https://t.me/botfather)
   - Add your token to `.env`:
     ```
     TELEGRAM_BOT_TOKEN=your_bot_token_here
     ```

## Usage

Run the bot:
```bash
./bin/bot
```

### Bot Commands
- `/start` - Start the bot and see main menu
- `/help` - Show help message
- `/rollout` - Start Secret Santa pairs generation (admin only)

### Creating a Game (Admin)
1. Click "Create New Game (Admin)"
2. Enter unique game name
3. Set a passcode for players to join
4. Specify maximum number of players
5. Add exception pairs (optional)

### Joining a Game
1. Click "Join Existing Game"
2. Select a game
3. Enter the game's passcode
4. Wait for the admin to start the rollout

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Ovsov/tecret_anta.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).