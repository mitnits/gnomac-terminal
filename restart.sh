#!/bin/bash
# Restart GnomacTerminal (kills server and starts fresh)
set -e

echo "Stopping gnomac-terminal-server..."
killall gnomac-terminal-server 2>/dev/null && echo "  Sent SIGTERM" || echo "  Not running"
sleep 1

# Force kill if still running
if pgrep -x gnomac-terminal-server >/dev/null 2>&1; then
    echo "  Force killing..."
    killall -9 gnomac-terminal-server 2>/dev/null || true
    sleep 0.5
fi

# Also kill any lingering client processes
killall gnomac-terminal 2>/dev/null || true

echo "Starting GnomacTerminal..."
gnomac-terminal &
disown

echo "GnomacTerminal restarted (PID: $!)"
echo ""
echo "Check server status:"
echo "  pgrep -a gnomac-terminal-server"
echo ""
echo "Check D-Bus registration:"
echo "  dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames | grep GnomacTerminal"
