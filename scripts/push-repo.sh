#!/bin/bash
# ═══════════════════════════════════════════════════════
#  ShivaOS Arch — Push repo vers GitHub Pages + FTP
# ═══════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ARCH_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="$ARCH_DIR/repo/x86_64"
WEBSITE_DIR="$ARCH_DIR/website"
KEY_FILE="/run/media/freuja/WinToUSB/ShivaOS_Project/key.txt"

# Charger les credentials depuis key.txt
FTP_SERVER=$(grep '^FTP_SERVER='   "$KEY_FILE" | cut -d= -f2-)
FTP_USER=$(grep   '^FTP_USERNAME=' "$KEY_FILE" | cut -d= -f2-)
FTP_PASS=$(grep   '^FTP_PASSWORD=' "$KEY_FILE" | cut -d= -f2-)
GITHUB_PAT=$(grep '^GITHUB_PAT='  "$KEY_FILE" | cut -d= -f2-)

FTP_BASE="ftp://${FTP_SERVER}/shivaos.com/arch-repo/x86_64"
FTP_ARCH_ROOT="ftp://${FTP_SERVER}/shivaos.com/arch-repo"
FTP_SITE="ftp://${FTP_SERVER}/arch.shivaos.com"

echo "======================================"
echo "  ShivaOS — Push Repo + Site Arch"
echo "======================================"

if [ ! -d "$REPO_DIR" ] || [ -z "$(ls "$REPO_DIR"/*.pkg.tar.zst 2>/dev/null)" ]; then
    echo "❌ Repo vide — lance build-repo.sh d'abord"
    exit 1
fi

# ── 1. GitHub Pages ───────────────────────────────────
echo ""
echo "── GitHub Pages ──"
cd "$ARCH_DIR"
git config user.email "freuja@gmail.com"
git config user.name "Cédric"
git add "repo/x86_64/" "website/" 2>/dev/null || true
git commit -m "repo: update packages $(date +%Y%m%d)" \
    --author="Cédric <freuja@gmail.com>" --allow-empty
git push "https://freuja-wq:${GITHUB_PAT}@github.com/freuja-wq/shivaos-arch-repo.git" main
echo "✅ GitHub Pages pushé (dispo dans ~2 min)"

# ── 2. FTP repo pacman ────────────────────────────────
echo ""
echo "── FTP shivaos.com/arch-repo/ ──"

for f in "$REPO_DIR"/*.pkg.tar.zst "$REPO_DIR"/*.pkg.tar.zst.sig \
          "$REPO_DIR"/shivaos.db.tar.gz "$REPO_DIR"/shivaos.files.tar.gz; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")
    printf "  ↑ %-55s" "$fname"
    curl --ftp-ssl -T "$f" "${FTP_BASE}/${fname}" \
        --user "${FTP_USER}:${FTP_PASS}" \
        --ftp-create-dirs --silent --show-error && echo "✅" || echo "❌"
done

echo "  ↑ shivaos.gpg"
curl --ftp-ssl -T "$ARCH_DIR/repo/shivaos.gpg" \
    "${FTP_ARCH_ROOT}/shivaos.gpg" \
    --user "${FTP_USER}:${FTP_PASS}" \
    --ftp-create-dirs --silent --show-error && echo "✅" || echo "❌"

echo "✅ FTP repo pushé"

# ── 3. Site arch.shivaos.com ──────────────────────────
if [ -d "$WEBSITE_DIR" ] && ls "$WEBSITE_DIR"/*.html "$WEBSITE_DIR"/*.js &>/dev/null 2>&1; then
    echo ""
    echo "── FTP arch.shivaos.com ──"
    for f in "$WEBSITE_DIR"/*; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        printf "  ↑ %-30s" "$fname"
        curl --ftp-ssl -T "$f" "${FTP_SITE}/${fname}" \
            --user "${FTP_USER}:${FTP_PASS}" \
            --ftp-create-dirs --silent --show-error && echo "✅" || echo "❌"
    done
    echo "✅ Site arch.shivaos.com pushé"
fi

echo ""
echo "════════════════════════════════════"
echo "  Repo pacman :"
echo "  https://shivaos.com/arch-repo/x86_64  (primaire)"
echo "  https://freuja-wq.github.io/shivaos-arch-repo/x86_64  (fallback)"
echo ""
echo "  Site :"
echo "  https://arch.shivaos.com"
echo "════════════════════════════════════"
