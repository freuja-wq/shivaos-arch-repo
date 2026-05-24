#!/bin/bash
# ═══════════════════════════════════════════════════════
#  ShivaOS Arch — Push repo vers GitHub Pages + FTP
# ═══════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ARCH_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="$ARCH_DIR/repo/x86_64"
KEY_FILE="/run/media/freuja/WinToUSB/ShivaOS_Project/key.txt"

# Charger les credentials FTP
FTP_SERVER=$(grep '^FTP_SERVER=' "$KEY_FILE" | cut -d= -f2)
FTP_USER=$(grep '^FTP_USERNAME=' "$KEY_FILE" | cut -d= -f2)
FTP_PASS=$(grep '^FTP_PASSWORD=' "$KEY_FILE" | cut -d= -f2)
FTP_BASE="ftp://${FTP_SERVER}/shivaos.com/arch-repo/x86_64"

echo "======================================"
echo "  ShivaOS — Push Repo Arch"
echo "======================================"

if [ ! -d "$REPO_DIR" ] || [ -z "$(ls "$REPO_DIR"/*.pkg.tar.zst 2>/dev/null)" ]; then
    echo "❌ Repo vide — lance build-repo.sh d'abord"
    exit 1
fi

# ── 1. GitHub Pages ───────────────────────────────────
echo ""
echo "── GitHub Pages ──"
cd "$ARCH_DIR"
git add "repo/x86_64/"
git commit -m "repo: update packages $(date +%Y%m%d)" --allow-empty
git push origin main
echo "✅ GitHub Pages pushé (dispo dans ~2 min)"

# ── 2. FTP O2Switch ───────────────────────────────────
echo ""
echo "── FTP shivaos.com/arch-repo/ ──"

for f in "$REPO_DIR"/*.pkg.tar.zst "$REPO_DIR"/*.db* "$REPO_DIR"/*.files*; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")
    echo "  ↑ $fname"
    curl --ftp-ssl -T "$f" \
        "${FTP_BASE}/${fname}" \
        --user "${FTP_USER}:${FTP_PASS}" \
        --ftp-create-dirs \
        --silent --show-error
done

echo "✅ FTP pushé"

echo ""
echo "════════════════════════════════════"
echo "  Mirrors disponibles :"
echo "  https://freuja-wq.github.io/shivaos-arch-repo/x86_64"
echo "  https://shivaos.com/arch-repo/x86_64"
echo "════════════════════════════════════"
