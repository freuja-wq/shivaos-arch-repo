#!/bin/bash
# ═══════════════════════════════════════════════════════
#  ShivaOS Arch — Push repo vers GitHub Pages
# ═══════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ARCH_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="$ARCH_DIR/repo/x86_64"

echo "======================================"
echo "  ShivaOS — Push Repo GitHub Pages"
echo "======================================"

if [ ! -d "$REPO_DIR" ] || [ -z "$(ls "$REPO_DIR"/*.pkg.tar.zst 2>/dev/null)" ]; then
    echo "❌ Repo vide — lance build-repo.sh d'abord"
    exit 1
fi

# Commit et push git
cd "$ARCH_DIR"
git add "repo/x86_64/"
git status
echo ""
echo "── Commit repo ──"
git commit -m "repo: update packages $(date +%Y%m%d)" --allow-empty
git push origin main

echo ""
echo "✅ Repo pushé !"
echo "   URL : https://freuja-wq.github.io/shivaos-arch-repo/x86_64"
echo "   Disponible dans ~2 min (GitHub Pages deploy)"
