#!/bin/bash
set -e
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building GnomacTerminal ==="

# Step 1: Build private VTE
echo ""
echo "--- Step 1: Building VTE (private libvte-gnomac-2.91) ---"
cd "$BASEDIR/vte"

if [ ! -d builddir ]; then
    meson setup builddir --prefix=/usr \
        --libdir=lib/gnomac-terminal \
        -Dgtk3=true -Dgtk4=false \
        -Dgir=false -Dvapi=false -Ddocs=false
else
    echo "VTE builddir exists, reusing (use --clean to rebuild from scratch)"
fi

meson compile -C builddir

echo "Installing VTE to staging..."
rm -rf "$BASEDIR/vte/install"
DESTDIR="$BASEDIR/vte/install" meson install -C builddir

# Create build-time pkg-config override with staging paths
STAGING="$BASEDIR/vte/install/usr"
cat > "$STAGING/lib/gnomac-terminal/pkgconfig/vte-gnomac-2.91.pc" << PKGEOF
prefix=$STAGING
includedir=\${prefix}/include
libdir=\${prefix}/lib/gnomac-terminal

exec_prefix=\${prefix}

Name: vte
Description: VTE widget for GTK+ 3.0
Version: 0.80.1
Requires: cairo >= 1.0, gio-2.0 >= 2.72.0, glib-2.0 >= 2.72.0, gobject-2.0, pango >= 1.22.0, gtk+-3.0 >= 3.24.0
Libs: -L\${libdir} -lvte-gnomac-2.91
Cflags: -I\${includedir}/vte-gnomac-2.91
PKGEOF

echo "VTE build complete."

# Step 2: Build GnomacTerminal
echo ""
echo "--- Step 2: Building GnomacTerminal ---"
cd "$BASEDIR/mac-terminal"

export PKG_CONFIG_PATH="$STAGING/lib/gnomac-terminal/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="$STAGING/lib/gnomac-terminal:${LD_LIBRARY_PATH:-}"

if [ ! -d builddir ]; then
    meson setup builddir --prefix=/usr \
        -Dnautilus_extension=false \
        -Dsearch_provider=true \
        -Ddocs=false
else
    echo "GnomacTerminal builddir exists, reusing"
fi

meson compile -C builddir

echo ""
echo "--- Step 3: Verification ---"
echo ""
echo "Checking linkage..."
for bin in gnomac-terminal-server gnomac-terminal gnomac-terminal-preferences; do
    if [ -f "builddir/src/$bin" ]; then
        VTE_LIB=$(readelf -d "builddir/src/$bin" | grep 'NEEDED.*libvte' | awk '{print $NF}')
        echo "  $bin links: $VTE_LIB"
    fi
done

echo ""
echo "=== Build complete ==="
echo "Binaries are in: $BASEDIR/mac-terminal/builddir/src/"
echo ""
echo "To build .deb package: cd $BASEDIR && ./package.sh"
echo "To test locally: LD_LIBRARY_PATH=$STAGING/lib/gnomac-terminal builddir/src/gnomac-terminal"
