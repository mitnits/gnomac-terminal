#!/bin/bash
# Verify GnomacTerminal installation and coexistence with system gnome-terminal
PASS=0
FAIL=0
WARN=0

check() {
    local desc="$1" result="$2"
    if [ "$result" = "0" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

warn() {
    echo "  WARN: $1"
    WARN=$((WARN + 1))
}

echo "=== GnomacTerminal Verification ==="
echo ""

echo "1. Binary existence:"
which gnomac-terminal >/dev/null 2>&1; check "gnomac-terminal in PATH" $?
test -x /usr/libexec/gnomac-terminal-server; check "gnomac-terminal-server exists" $?
test -x /usr/libexec/gnomac-terminal-preferences; check "gnomac-terminal-preferences exists" $?

echo ""
echo "2. Private VTE library:"
test -f /usr/lib/gnomac-terminal/libvte-gnomac-2.91.so.0; check "libvte-gnomac-2.91.so.0 exists" $?

if [ -x /usr/libexec/gnomac-terminal-server ]; then
    readelf -d /usr/libexec/gnomac-terminal-server 2>/dev/null | grep -q 'libvte-gnomac-2.91'
    check "server links libvte-gnomac-2.91" $?

    readelf -d /usr/libexec/gnomac-terminal-server 2>/dev/null | grep -q 'RUNPATH.*gnomac-terminal'
    check "server RUNPATH set to /usr/lib/gnomac-terminal" $?

    ldd /usr/libexec/gnomac-terminal-server 2>/dev/null | grep 'libvte' | grep -v 'gnomac' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        warn "Server also links system VTE (unexpected)"
    else
        echo "  PASS: Server only uses private VTE"
        PASS=$((PASS + 1))
    fi
fi

echo ""
echo "3. D-Bus service:"
test -f /usr/share/dbus-1/services/org.gnome.GnomacTerminal.service; check "D-Bus service file exists" $?
if [ -f /usr/share/dbus-1/services/org.gnome.GnomacTerminal.service ]; then
    grep -q 'org.gnome.GnomacTerminal' /usr/share/dbus-1/services/org.gnome.GnomacTerminal.service
    check "D-Bus service has correct bus name" $?
fi

echo ""
echo "4. Systemd service:"
test -f /usr/lib/systemd/user/gnomac-terminal-server.service; check "systemd user service exists" $?

echo ""
echo "5. GSettings schemas:"
test -f /usr/share/glib-2.0/schemas/org.gnome.GnomacTerminal.gschema.xml; check "GSettings schema installed" $?
gsettings list-schemas 2>/dev/null | grep -q 'org.gnome.GnomacTerminal'
check "GSettings schema registered" $?

echo ""
echo "6. Desktop files:"
test -f /usr/share/applications/org.gnome.GnomacTerminal.desktop; check "Desktop file exists" $?
test -f /usr/share/applications/org.gnome.GnomacTerminal.Preferences.desktop; check "Preferences desktop file exists" $?

echo ""
echo "7. Icons:"
test -f /usr/share/icons/hicolor/scalable/apps/org.gnome.GnomacTerminal.svg; check "Scalable icon exists" $?

echo ""
echo "8. Coexistence check:"
if test -f /usr/share/dbus-1/services/org.gnome.Terminal.service; then
    echo "  INFO: System gnome-terminal is also installed (coexistence mode)"
    diff <(cat /usr/share/dbus-1/services/org.gnome.Terminal.service) <(cat /usr/share/dbus-1/services/org.gnome.GnomacTerminal.service) >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "  PASS: D-Bus services are distinct"
        PASS=$((PASS + 1))
    else
        warn "D-Bus services appear identical!"
    fi
else
    echo "  INFO: System gnome-terminal not installed"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $WARN warnings ==="
if [ $FAIL -gt 0 ]; then
    exit 1
fi
