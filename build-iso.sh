#!/bin/bash
# ═══════════════════════════════════════════════════════
#  ShivaOS Arch — Build ISO via archiso (container Arch)
# ═══════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ISO_PROFILE="$SCRIPT_DIR/iso"
OUTPUT_DIR="$SCRIPT_DIR/output"
WORK_DIR="$SCRIPT_DIR/work"
REPO_DIR="$SCRIPT_DIR/repo/x86_64"

echo "======================================"
echo "  ShivaOS Arch — Build ISO"
echo "======================================"

# Vérifier que le repo local contient les paquets shiva
if [ ! -d "$REPO_DIR" ] || [ -z "$(ls "$REPO_DIR"/*.pkg.tar.zst 2>/dev/null)" ]; then
    echo "⚠️  Repo local vide — build les paquets d'abord :"
    echo "   ./scripts/build-repo.sh"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Copier le profiledef + pacman.conf dans un répertoire temporaire propre
# (mkarchiso nécessite les fichiers au bon endroit)
TMPPROFILE=$(mktemp -d /tmp/shivaos-iso-XXXXX)
trap "rm -rf $TMPPROFILE" EXIT
cp -r "$ISO_PROFILE"/* "$TMPPROFILE/"

# Synchroniser le repo local dans le profil
mkdir -p "$TMPPROFILE/airootfs/var/cache/pacman/pkg"

echo ""
echo "══ Build ISO via podman archiso ══"

podman run --rm --privileged \
    -v "$TMPPROFILE:/profile:z" \
    -v "$OUTPUT_DIR:/output:z" \
    -v "$WORK_DIR:/work:z" \
    -v "$REPO_DIR:/shivaos-repo:z" \
    archlinux:latest \
    bash -c "
        set -e
        pacman -Sy --noconfirm archiso 2>&1 | tail -5

        # Ajouter le repo ShivaOS local
        cat >> /profile/pacman.conf << 'REPOEOF'

[shivaos-local]
SigLevel = Optional TrustAll
Server = file:///shivaos-repo
REPOEOF

        # Build ISO
        mkarchiso -v -w /work -o /output /profile/

        echo ''
        echo '✅ ISO buildée dans /output'
        ls -lh /output/*.iso 2>/dev/null || true
    "

echo ""
echo "✅ ISO ShivaOS Arch générée dans $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.iso 2>/dev/null || echo "  (aucun fichier .iso trouvé)"
