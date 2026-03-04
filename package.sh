#!/bin/bash
# Build a .deb package from already-compiled GnomacTerminal + VTE
set -e
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

VERSION="3.56.2"
ARCH=$(dpkg --print-architecture)
PKGNAME="gnomac-terminal"
PKGDIR="$BASEDIR/${PKGNAME}_${VERSION}-1_${ARCH}"

echo "=== Packaging GnomacTerminal $VERSION ($ARCH) ==="

# Clean previous package dir
rm -rf "$PKGDIR"

# Install GnomacTerminal to package dir
echo "Installing GnomacTerminal..."
cd "$BASEDIR/mac-terminal"
DESTDIR="$PKGDIR" meson install -C builddir 2>/dev/null

# Install private VTE library
echo "Installing private VTE..."
install -d "$PKGDIR/usr/lib/gnomac-terminal"
cp -a "$BASEDIR/vte/install/usr/lib/gnomac-terminal/libvte-gnomac-2.91.so"* \
    "$PKGDIR/usr/lib/gnomac-terminal/"

# Remove files we don't need in the package
rm -rf "$PKGDIR/usr/include"
rm -rf "$PKGDIR/usr/lib/gnomac-terminal/pkgconfig"
rm -rf "$PKGDIR/usr/share/glade"
rm -f "$PKGDIR/usr/share/applications/org.gnome.Vte"*

# Create DEBIAN control
install -d "$PKGDIR/DEBIAN"

# Calculate installed size
INSTALLED_SIZE=$(du -sk "$PKGDIR" | cut -f1)

cat > "$PKGDIR/DEBIAN/control" << EOF
Package: gnomac-terminal
Version: ${VERSION}-1
Section: gnome
Priority: optional
Architecture: ${ARCH}
Installed-Size: ${INSTALLED_SIZE}
Depends: libglib2.0-0 (>= 2.52.0), libgtk-3-0 (>= 3.22.27), libhandy-1-0 (>= 1.6.0), libcairo2, libpango-1.0-0, libx11-6, libuuid1, libpcre2-8-0, gsettings-desktop-schemas, dbus
Maintainer: GnomacTerminal Developer <dev@example.com>
Description: GnomacTerminal - customized terminal emulator
 GnomacTerminal is a fork of GNOME Terminal with a custom bundled VTE
 library. It can coexist with the system gnome-terminal installation.
 Designed for customizing modifier key behavior.
EOF

# Post-install script
cat > "$PKGDIR/DEBIAN/postinst" << 'SCRIPT'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true
    gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi
SCRIPT
chmod 755 "$PKGDIR/DEBIAN/postinst"

# Post-remove script
cat > "$PKGDIR/DEBIAN/postrm" << 'SCRIPT'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true
    gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi
SCRIPT
chmod 755 "$PKGDIR/DEBIAN/postrm"

# Build the .deb
echo "Building .deb..."
dpkg-deb --build --root-owner-group "$PKGDIR"

DEB_FILE="${PKGDIR}.deb"
echo ""
echo "=== Package built: $DEB_FILE ==="
echo "Size: $(ls -lh "$DEB_FILE" | awk '{print $5}')"
echo ""
echo "Install with: sudo dpkg -i $DEB_FILE"
echo "Remove with:  sudo dpkg -r gnomac-terminal"

# Clean up
rm -rf "$PKGDIR"
