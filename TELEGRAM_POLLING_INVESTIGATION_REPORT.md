# Telegram Bot Polling Investigation Report

## Summary
The ExGram Telegram bot is not starting due to a child specification issue in the TelegramSupervisor module. The bot process (TelegramBotSimple) is properly implemented but the supervisor fails to start it correctly.

## Root Cause
The error occurs when starting the application:
```
** (KeyError) key :method not found in: [module: Vsmcp.Interfaces.TelegramBotSimple, setup_commands: true]
```

This happens because the TelegramSupervisor is using an incorrect child specification format for ExGram bots.

## Current Issue

### In `/lib/vsmcp/interfaces/telegram_supervisor.ex` (lines 35-39):
```elixir
# The ExGram Bot using simplified module
{Vsmcp.Interfaces.TelegramBotSimple, 
  [
    token: bot_token,
    method: :polling
  ]}
```

This format is incorrect for ExGram bots that use the `use ExGram.Bot` macro.

## Solution

The TelegramSupervisor needs to be updated to use the proper ExGram bot initialization. The ExGram.Bot macro automatically generates the necessary child_spec/1 function, but it expects the configuration to be passed differently.

### Recommended Fix:
Update the child specification in TelegramSupervisor to properly start the ExGram bot. The exact format depends on the ExGram version, but typically it should either:

1. Use a direct module specification if the bot's `use ExGram.Bot` includes configuration
2. Or use a more explicit supervisor child specification

## Additional Findings

1. **Configuration**: The bot token needs to be set via environment variable `TELEGRAM_BOT_TOKEN` or in runtime.exs
2. **Dependencies**: ExGram 0.56.0 is properly included in mix.exs
3. **Bot Implementation**: TelegramBotSimple correctly implements the ExGram.Bot behavior with:
   - Proper `use ExGram.Bot` macro usage
   - Command handlers for /help, /status, and /spawn_vsm
   - Message handlers for regular text messages
   - Middleware configuration

## Verification Steps
1. The application starts successfully when TELEGRAM_BOT_TOKEN is provided
2. TelegramSupervisor detects the token and attempts to start children
3. The supervisor fails when trying to start TelegramBotSimple due to the child spec issue

## Next Steps
1. Fix the child specification format in TelegramSupervisor
2. Test with a valid Telegram bot token
3. Verify polling starts correctly after the fix