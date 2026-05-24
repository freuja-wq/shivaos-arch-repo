#!/bin/bash
# ═══════════════════════════════════════════════════════
#  ShivaOS Arch — Build repo pacman via container Arch
# ═══════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(dirname "$0")"
ARCH_DIR="$(dirname "$SCRIPT_DIR")"
PKGBUILDS_DIR="$ARCH_DIR/PKGBUILDs"
REPO_DIR="$ARCH_DIR/repo/x86_64"
SOURCES_DIR="/run/media/freuja/WinToUSB/ShivaOS_Project/RPM_BUILD/SOURCES"
REPO_NAME="shivaos"

echo "======================================"
echo "  ShivaOS — Build Repo Pacman (Arch)"
echo "======================================"

mkdir -p "$REPO_DIR"

# Builder chaque paquet dans un container Arch
for pkgdir in "$PKGBUILDS_DIR"/*/; do
    pkg=$(basename "$pkgdir")
    echo ""
    echo "══ $pkg ══"

    # Copier les sources depuis RPM_BUILD/SOURCES
    for src in "$SOURCES_DIR/$pkg"* "$SOURCES_DIR/${pkg//-/_}"*; do
        [ -f "$src" ] && cp "$src" "$pkgdir/" 2>/dev/null || true
    done
    # shiva-store.py spécifiquement
    [ -f "$SOURCES_DIR/$pkg.py" ] && cp "$SOURCES_DIR/$pkg.py" "$pkgdir/"
    [ -f "$SOURCES_DIR/$pkg.svg" ] && cp "$SOURCES_DIR/$pkg.svg" "$pkgdir/"

    # Build dans container Arch rootless
    podman run --rm \
        -v "$pkgdir:/build:z" \
        -w /build \
        archlinux:latest \
        bash -c "
            pacman -Sy --noconfirm base-devel 2>/dev/null | tail -3
            useradd -m builder
            chown -R builder:builder /build
            su builder -c 'makepkg -s --noconfirm --noprogressbar 2>&1'
        " && \
    mv "$pkgdir"/*.pkg.tar.zst "$REPO_DIR/" 2>/dev/null && \
    echo "  ✅ $pkg buildé" || \
    echo "  ❌ $pkg échoué"
done

# Générer la base de données du repo
echo ""
echo "══ Génération repo pacman ══"
cd "$REPO_DIR"
repo-add "$REPO_NAME.db.tar.gz" *.pkg.tar.zst 2>/dev/null || \
podman run --rm \
    -v "$REPO_DIR:/repo:z" \
    -w /repo \
    archlinux:latest \
    bash -c "pacman -Sy --noconfirm 2>/dev/null; repo-add $REPO_NAME.db.tar.gz *.pkg.tar.zst"

# Symlinks standards
ln -sf "$REPO_NAME.db.tar.gz" "$REPO_DIR/$REPO_NAME.db" 2>/dev/null || true
ln -sf "$REPO_NAME.files.tar.gz" "$REPO_DIR/$REPO_NAME.files" 2>/dev/null || true

echo ""
echo "✅ Repo prêt dans $REPO_DIR"
echo "   Ajouter dans /etc/pacman.conf :"
echo "   [shivaos]"
echo "   SigLevel = Optional TrustAll"
echo "   Server = https://freuja-wq.github.io/shivaos-arch-repo/x86_64"
ls -lh "$REPO_DIR"
