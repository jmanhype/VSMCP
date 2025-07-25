#!/bin/bash
# Start VSMCP with Telegram Bot Integration

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            VSMCP Telegram Bot Startup Script                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if token is provided as argument or environment variable
if [ -n "$1" ]; then
    export TELEGRAM_BOT_TOKEN="$1"
    echo "✅ Using provided bot token"
elif [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    echo "✅ Using existing TELEGRAM_BOT_TOKEN environment variable"
else
    echo "❌ Error: No Telegram bot token provided!"
    echo ""
    echo "Usage:"
    echo "  ./start_telegram_vsm.sh YOUR_BOT_TOKEN"
    echo "  or"
    echo "  export TELEGRAM_BOT_TOKEN=YOUR_BOT_TOKEN"
    echo "  ./start_telegram_vsm.sh"
    echo ""
    exit 1
fi

# Ensure RabbitMQ is running
echo ""
echo "🐰 Checking RabbitMQ status..."
if ! rabbitmqctl status > /dev/null 2>&1; then
    echo "❌ RabbitMQ is not running!"
    echo "   Please start RabbitMQ first:"
    echo "   sudo systemctl start rabbitmq-server"
    echo "   or"
    echo "   rabbitmq-server"
    exit 1
else
    echo "✅ RabbitMQ is running"
fi

# Get dependencies
echo ""
echo "📦 Fetching dependencies..."
mix deps.get

# Compile the project
echo ""
echo "🔨 Compiling VSMCP..."
mix compile

# Run the Telegram VSM demo
echo ""
echo "🚀 Starting VSMCP with Telegram integration..."
echo ""
echo "Your bot is starting up. To interact with it:"
echo "1. Open Telegram and search for your bot"
echo "2. Send /help to see available commands"
echo "3. Send messages - they will be processed through S1"
echo "4. Try /spawn_vsm to create recursive sub-VSMs"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Start the application
mix run examples/telegram_vsm_demo.exs --no-halt