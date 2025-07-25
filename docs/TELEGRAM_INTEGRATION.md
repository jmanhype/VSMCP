# Telegram Integration for VSMCP

## Overview

The Telegram bot integration follows Stafford Beer's Viable System Model principles by implementing the bot as a System 1 (S1) operational unit. This ensures that external variety (user messages) flows correctly through the VSM hierarchy.

## Key Principles

### Correct VSM Flow

```
External World (Telegram Users)
       ↓ (variety)
    System 1 (Operations) ← Telegram bot lives here!
       ↓
    System 2 (Coordination)
       ↓
    System 3 (Control)
       ↓
    System 4 (Intelligence) ← Scans trends, NOT operations
       ↓
    System 5 (Policy)
```

### What This Means

1. **Telegram messages are OPERATIONAL VARIETY** - They enter through S1, not S4
2. **S1 processes user requests** - The actual work happens in System 1
3. **S4 scans for patterns** - Environmental intelligence, not individual messages
4. **Algedonic signals** - Urgent messages bypass hierarchy

## Configuration

### Environment Variables

```bash
# Required
export TELEGRAM_BOT_TOKEN=your_bot_token_here

# Optional (for production)
export TELEGRAM_WEBHOOK_URL=https://your-domain.com/telegram/webhook
```

### Runtime Configuration

The bot token can be configured in `config/runtime.exs`:

```elixir
config :vsmcp, :telegram,
  bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
  webhook_url: System.get_env("TELEGRAM_WEBHOOK_URL")
```

## Bot Commands

### User Commands

- `/status` - Show VSM system status
- `/help` - Display available commands
- `/spawn_vsm <name>` - Spawn a recursive sub-VSM

### Regular Messages

All non-command messages are processed as operational variety through System 1.

### Urgent Messages

Messages containing keywords like "urgent", "emergency", "critical", or "alert" trigger algedonic signals that bypass the normal hierarchy.

## Architecture

### S1 Integration

The Telegram bot registers itself as an S1 operational capability:

```elixir
System1.register_capability("telegram_interface", &handle_telegram_operation/1)
```

### Message Flow

1. **User sends message** → Telegram API
2. **Bot receives update** → `handle_info({:telegram_update, ...})`
3. **Create operation** → Package as S1 operation
4. **Send to S1** → `NervousSystem.send_command(:telegram_unit, :system1, operation)`
5. **S1 processes** → Executes operational logic
6. **Response sent** → Back to user via Telegram

### Coordination Triggers

Complex requests trigger S2 coordination:
- Messages with "and", "then", "after", "multiple"
- Messages longer than 100 characters

### Environmental Scanning

S4 performs periodic environmental scans:
- Message pattern analysis
- User growth trends
- Complexity forecasting
- Policy recommendations

## AMQP Integration

The Telegram bot integrates with the VSM nervous system:

### Channels Used

- **Command Channel** - S1 operations
- **Audit Channel** - Operation results
- **Algedonic Channel** - Urgent messages
- **Intel Channel** - Environmental scans

### Message Examples

```elixir
# S1 Operation
NervousSystem.send_command(:telegram_unit, :system1, %{
  capability: "telegram_interface",
  type: "user_request",
  params: %{text: "Hello", user_id: 123}
})

# Algedonic Signal
NervousSystem.broadcast_algedonic(%{
  source: "telegram_unit",
  signal: "user_urgency",
  intensity: 0.8
})
```

## Recursive VSM Spawning

Users can spawn sub-VSMs through Telegram:

```
/spawn_vsm MyProjectVSM
```

This creates a complete recursive VSM with:
- Its own S1-S5 hierarchy
- MCP server for tool exposure
- Autonomous operation capability

## Monitoring and Analytics

### S1 Metrics
- Total operations executed
- Response times
- Success/failure rates

### S4 Intelligence
- Message pattern trends
- User behavior analysis
- Variety predictions

### Example Status Output

```
📊 VSM System Status

S1 (Operations): 1,247 executions
S2 (Coordination): Active
S3 (Control): Monitoring
S4 (Intelligence): 5 sources
S5 (Policy): Active

Variety Gap: 12%
```

## Best Practices

### DO:
- Route all user messages through S1
- Use S4 for trend analysis only
- Trigger algedonic signals for urgent matters
- Let S2 coordinate complex operations
- Monitor variety gaps

### DON'T:
- Send operational messages to S4
- Bypass the S1→S2→S3 flow
- Handle individual messages in S4
- Ignore coordination requirements

## Troubleshooting

### Bot Not Starting

1. Check token is set: `echo $TELEGRAM_BOT_TOKEN`
2. Verify token with BotFather
3. Check logs: `grep -i telegram _build/dev/lib/vsmcp/ebin/*.log`

### Messages Not Processing

1. Verify AMQP is running: `rabbitmqctl status`
2. Check S1 is active: `Vsmcp.Systems.System1.status()`
3. Monitor AMQP channels: `rabbitmqctl list_exchanges`

### Performance Issues

1. Check variety gap: Too many messages?
2. Monitor S2 coordination: Bottlenecks?
3. Review S4 predictions: Capacity planning needed?

## Example Integration

```elixir
# Start VSMCP with Telegram
{:ok, _} = Application.ensure_all_started(:vsmcp)

# Check if Telegram is running
if Vsmcp.Interfaces.TelegramSupervisor.running?() do
  IO.puts "Telegram bot active!"
end

# Get bot status
{:ok, status} = Vsmcp.Interfaces.TelegramSupervisor.status()
```

## Security Considerations

1. **Token Security** - Never commit tokens to version control
2. **User Authorization** - Implement user whitelisting if needed
3. **Rate Limiting** - S2 coordination prevents overload
4. **Audit Trail** - All operations logged via audit channel

## Future Enhancements

- Webhook support for production
- Multi-language support
- Rich media handling
- Inline keyboards for complex operations
- Bot analytics dashboard
- Integration with other messaging platforms