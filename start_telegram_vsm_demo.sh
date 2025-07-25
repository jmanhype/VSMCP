#!/bin/bash
# Start VSMCP with Telegram Bot properly configured

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Starting VSMCP Telegram VSM Queen Bot                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Set the bot token
export TELEGRAM_BOT_TOKEN="7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"
echo "✅ Bot token configured"

# Check RabbitMQ
echo ""
echo "🐰 Checking RabbitMQ..."
if pgrep -x "beam.smp" | grep -q rabbitmq; then
    echo "✅ RabbitMQ is running"
else
    echo "❌ RabbitMQ is not running!"
    echo "   Please start RabbitMQ first"
    exit 1
fi

# Kill any existing VSMCP processes
echo ""
echo "🧹 Cleaning up existing processes..."
pkill -f "mix run.*telegram" 2>/dev/null || true
sleep 2

# Start with IEx for interactive mode
echo ""
echo "🚀 Starting VSMCP with Telegram integration..."
echo ""
echo "Once started:"
echo "1. Open Telegram and search for your bot"
echo "2. Send /help to see available commands"
echo "3. Send messages - they will be processed through S1"
echo "4. Try /spawn_vsm to create recursive sub-VSMs"
echo ""
echo "Press Ctrl+C twice to stop"
echo ""

# Start in interactive mode
iex -S mix