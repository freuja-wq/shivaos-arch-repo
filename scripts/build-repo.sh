#!/bin/bash
# ═══════════════════════════════════════════════════════
#  ShivaOS Arch — Build repo pacman via container Arch
# ═══════════════════════════════════════════════════════
set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ARCH_DIR="$(dirname "$SCRIPT_DIR")"
PKGBUILDS_DIR="$ARCH_DIR/PKGBUILDs"
REPO_DIR="$ARCH_DIR/repo/x86_64"
SOURCES_DIR="/run/media/freuja/WinToUSB/ShivaOS_Project/RPM_BUILD/SOURCES"
REPO_NAME="shivaos"
GPG_KEY="contact@shivaos.com"

echo "======================================"
echo "  ShivaOS — Build Repo Pacman (Arch)"
echo "======================================"

mkdir -p "$REPO_DIR"

# Mapping sources → paquets
declare -A PKG_SOURCES=(
    ["shiva-store"]="shiva-store.py shiva-store.svg"
    ["shiva-ai"]="shiva-assistant.py shiva-repair.py shiva-gaming-optimizer.py shiva-bug-detector.py shiva-fps-coach.py shiva-crash-reporter.py shiva-update-oracle.py shiva-compatibility-scout.py shiva-session-report.py"
    ["shiva-ai-overlay"]="shiva-ai-overlay.py"
    ["shiva-amd"]="shiva-amd.py shiva-amd.svg"
    ["shiva-nvidia"]="shiva-nvidia.py shiva-nvidia.svg"
    ["shiva-pulse"]="shiva-pulse.py"
    ["shiva-welcome"]="shiva-welcome.py"
    ["shiva-branding"]="shivaos-wallpaper.png shivaos-wallpaper-1920x1080.png shivaos-wallpaper-2560x1440.png shivaos-wallpaper-3440x1440.png shivaos-logo.png shivaos-logo-64.png shivaos-logo-128.png shivaos-logo-256.png shivaos-logo-512.png shivaos.plymouth shivaos.script shivaos-plymouth-logo-256.png shivaos-sddm-Main.qml shivaos-neon-grid-1920x1080.png shivaos-neon-grid-3440x1440.png shivaos-deep-space-1920x1080.png shivaos-deep-space-3440x1440.png shivaos-lava-core-1920x1080.png shivaos-lava-core-3440x1440.png shivaos-cyber-rain-1920x1080.png shivaos-cyber-rain-3440x1440.png shivaos-aurora-1920x1080.png shivaos-aurora-3440x1440.png shivaos-void-1920x1080.png shivaos-void-3440x1440.png shivaos-manga-01.jpg shivaos-manga-02.jpg shivaos-manga-03.jpg shivaos-manga-04.jpg shivaos-manga-05.jpg shivaos-manga-06.jpg shivaos-manga-07.jpg shivaos-manga-08.jpg shivaos-manga-09.jpg shivaos-manga-10.jpg shivaos-manga-11.jpg shivaos-manga-12.jpg shivaos-manga-13.jpg"
    ["linux-shivaos"]="bore-7.0.patch"
)

BUILT=0
FAILED=0

for pkgdir in "$PKGBUILDS_DIR"/*/; do
    pkg=$(basename "$pkgdir")
    [ -f "$pkgdir/PKGBUILD" ] || continue

    echo ""
    echo "══ Building: $pkg ══"

    # Copier les sources depuis RPM_BUILD/SOURCES
    if [ -n "${PKG_SOURCES[$pkg]}" ]; then
        for src in ${PKG_SOURCES[$pkg]}; do
            if [ -f "$SOURCES_DIR/$src" ]; then
                cp "$SOURCES_DIR/$src" "$pkgdir/"
                echo "  📄 $src"
            else
                echo "  ⚠️  $src non trouvé dans SOURCES"
            fi
        done
    fi

    # Pour linux-shivaos, vérifier que bore patch est là
    if [ "$pkg" = "linux-shivaos" ] && [ ! -f "$pkgdir/bore-7.0.patch" ]; then
        echo "  ❌ bore-7.0.patch manquant — cherche dans rpmbuild/SOURCES..."
        BORE_PATH=$(find /var/home /home -name "bore-7.0.patch" 2>/dev/null | head -1)
        [ -n "$BORE_PATH" ] && cp "$BORE_PATH" "$pkgdir/" && echo "  ✅ Trouvé: $BORE_PATH"
    fi

    # Build dans container Arch rootless
    podman run --rm \
        -v "$pkgdir:/build:z" \
        -v "$REPO_DIR:/repo:z" \
        -w /build \
        archlinux:latest \
        bash -c "
            set -e
            pacman -Sy --noconfirm base-devel > /dev/null 2>&1
            useradd -m builder 2>/dev/null || true
            echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
            cp -r /build /home/builder/pkgbuild
            chown -R builder:builder /home/builder/pkgbuild
            # Installer les makedepends (pas les depends runtime) en root
            MAKEDEPS=\$(bash -c 'source /home/builder/pkgbuild/PKGBUILD 2>/dev/null && echo \"\${makedepends[*]}\"' 2>/dev/null || true)
            [ -n \"\$MAKEDEPS\" ] && pacman -S --noconfirm --needed \$MAKEDEPS > /dev/null 2>&1 || true
            cd /home/builder/pkgbuild
            # -d = skip dep check (deps runtime comme shiva-core non dispo en container)
            su builder -c 'makepkg -d --noconfirm --noprogressbar --skipchecksums 2>&1'
            cp /home/builder/pkgbuild/*.pkg.tar.zst /build/ 2>/dev/null || true
        " && {
        # Signer et déplacer les paquets buildés
        for pkg_file in "$pkgdir"/*.pkg.tar.zst; do
            [ -f "$pkg_file" ] || continue
            gpg --detach-sign --use-agent -u "$GPG_KEY" "$pkg_file" 2>/dev/null && \
                echo "  🔏 Signé: $(basename "$pkg_file")" || \
                echo "  ⚠️  Signature échouée (clé absente?)"
            mv "$pkg_file" "$REPO_DIR/"
            [ -f "${pkg_file}.sig" ] && mv "${pkg_file}.sig" "$REPO_DIR/"
        done
        echo "  ✅ $pkg buildé"
        BUILT=$((BUILT + 1))
    } || {
        echo "  ❌ $pkg échoué"
        FAILED=$((FAILED + 1))
    }
done

echo ""
echo "══ Résumé : $BUILT buildés, $FAILED échoués ══"
echo ""

# Générer la base de données du repo
echo "══ Génération repo pacman ══"
if command -v repo-add &>/dev/null && ls "$REPO_DIR"/*.pkg.tar.zst &>/dev/null; then
    cd "$REPO_DIR"
    repo-add --sign --key "$GPG_KEY" "$REPO_NAME.db.tar.gz" *.pkg.tar.zst
else
    podman run --rm \
        -v "$REPO_DIR:/repo:z" \
        -w /repo \
        archlinux:latest \
        bash -c "
            pacman -Sy --noconfirm 2>/dev/null
            ls *.pkg.tar.zst 2>/dev/null | xargs repo-add $REPO_NAME.db.tar.gz
        "
fi

# Symlinks standards
cd "$REPO_DIR"
ln -sf "$REPO_NAME.db.tar.gz" "$REPO_NAME.db" 2>/dev/null || true
ln -sf "$REPO_NAME.files.tar.gz" "$REPO_NAME.files" 2>/dev/null || true

echo ""
echo "✅ Repo prêt dans $REPO_DIR"
echo ""
echo "   Ajouter dans /etc/pacman.conf :"
echo "   [shivaos]"
echo "   SigLevel = Optional TrustAll"
echo "   Server = https://freuja-wq.github.io/shivaos-arch-repo/x86_64"
echo ""
ls -lh "$REPO_DIR"
