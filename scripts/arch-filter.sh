# Sourced by setup.sh and install-slow-packages.sh.
# Many AUR packages only build for x86_64, so on ARM (e.g. Apple Silicon Macs)
# drop the ones that can't install here. On x86_64 everything passes through.

ARCH=$(uname -m)

# Reads AUR package names on stdin and prints the ones that build for $ARCH.
filter_aur_for_arch() {
    local pkg arches
    while read -r pkg; do
        [ -z "$pkg" ] && continue
        if [ "$ARCH" = "x86_64" ]; then
            echo "$pkg"
            continue
        fi
        arches=$(curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=$pkg" 2>/dev/null \
            | awk '$1 == "arch" {print $3}')
        if grep -qxE "$ARCH|any" <<< "$arches"; then
            echo "$pkg"
        else
            echo "   ⚠️  Skipping $pkg (no $ARCH build on the AUR, or the AUR could not be reached)" >&2
        fi
    done
}
