#!/bin/bash
# ═══════════════════════════════════════════════════════
#  ShivaOS Arch — Build ISO via archiso (container Arch)
# ═══════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ISO_PROFILE="$SCRIPT_DIR/iso"
FINAL_OUTPUT_DIR="$SCRIPT_DIR/output"
# Work et output sur FS Linux (pas NTFS) pour les mount chroot + gros fichier ISO
WORK_DIR="/tmp/shivaos-iso-work"
OUTPUT_DIR="/tmp/shivaos-iso-output"
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

mkdir -p "$OUTPUT_DIR" "$FINAL_OUTPUT_DIR" "$WORK_DIR"

# Copier le profiledef + pacman.conf dans un répertoire temporaire propre
# (mkarchiso nécessite les fichiers au bon endroit)
TMPPROFILE=$(mktemp -d /tmp/shivaos-iso-XXXXX)
SUDO_PASS_TRAP=$(grep '^SUDO_PASSWORD=' /run/media/freuja/WinToUSB/ShivaOS_Project/key.txt | cut -d= -f2-)
trap "echo '$SUDO_PASS_TRAP' | sudo -S rm -rf $TMPPROFILE 2>/dev/null || rm -rf $TMPPROFILE 2>/dev/null" EXIT
cp -r "$ISO_PROFILE"/* "$TMPPROFILE/"

# Créer les symlinks systemd pour le boot graphique + réseau
# (impossible sur NTFS — fait ici dans TMPPROFILE sur ext4)
mkdir -p "$TMPPROFILE/airootfs/etc/systemd/system"
ln -sf /usr/lib/systemd/system/graphical.target \
    "$TMPPROFILE/airootfs/etc/systemd/system/default.target"
ln -sf /usr/lib/systemd/system/sddm.service \
    "$TMPPROFILE/airootfs/etc/systemd/system/display-manager.service"
# NetworkManager — réseau live fonctionnel (LAN + WiFi)
mkdir -p "$TMPPROFILE/airootfs/etc/systemd/system/network-online.target.wants"
mkdir -p "$TMPPROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "$TMPPROFILE/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-wait-online.service \
    "$TMPPROFILE/airootfs/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"

# Synchroniser le repo local dans le profil
mkdir -p "$TMPPROFILE/airootfs/var/cache/pacman/pkg"

echo ""
echo "══ Build ISO via podman archiso ══"

SUDO_PASS=$(grep '^SUDO_PASSWORD=' /run/media/freuja/WinToUSB/ShivaOS_Project/key.txt | cut -d= -f2-)
echo "$SUDO_PASS" | sudo -S podman run --rm --privileged \
    -v "$TMPPROFILE:/profile:z" \
    -v "$OUTPUT_DIR:/output:z" \
    -v "$WORK_DIR:/work:z" \
    -v "$REPO_DIR:/shivaos-repo:z" \
    archlinux:latest \
    bash -c "
        set -e
        # Initialiser le keyring Arch complet avant tout
        pacman-key --init
        pacman-key --populate archlinux
        pacman -Sy --noconfirm archiso 2>&1 | tail -5

        # SigLevel Never global — le keyring chroot mkarchiso n'est pas initialisé
        sed -i 's/^SigLevel = Required DatabaseOptional$/SigLevel = Never/' /profile/pacman.conf
        sed -i 's/^LocalFileSigLevel = Optional$/LocalFileSigLevel = Never/' /profile/pacman.conf
        # Remplacer les URLs web du repo shivaos par le chemin local
        sed -i 's|Server = https://shivaos.com/arch-repo/x86_64|Server = file:///shivaos-repo|' /profile/pacman.conf
        sed -i '/Server = https:\/\/freuja-wq.github.io/d' /profile/pacman.conf
        # Nettoyer l'ancien SigLevel shivaos (plus nécessaire avec SigLevel global)
        sed -i '/SigLevel = Required DatabaseOptional TrustAll/d' /profile/pacman.conf

        # Build ISO
        mkarchiso -v -w /work -o /output /profile/

        echo ''
        echo '✅ ISO buildée dans /output'
        ls -lh /output/*.iso 2>/dev/null || true
    "

echo ""
echo "── Copie ISO vers $FINAL_OUTPUT_DIR ──"
cp "$OUTPUT_DIR"/*.iso "$FINAL_OUTPUT_DIR/" 2>/dev/null && echo "✅ Copié" || echo "⚠️  Copie échouée"

echo ""
echo "✅ ISO ShivaOS Arch générée dans $FINAL_OUTPUT_DIR"
ls -lh "$FINAL_OUTPUT_DIR"/*.iso 2>/dev/null || echo "  (aucun fichier .iso trouvé)"
