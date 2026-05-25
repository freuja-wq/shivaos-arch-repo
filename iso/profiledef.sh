#!/usr/bin/env bash
# archiso profile ShivaOS

iso_name="shivaos-arch"
iso_label="SHIVAOS_ARCH"
iso_publisher="ShivaOS Team <https://shivaos.com>"
iso_application="ShivaOS Arch — Pure Gaming Ecosystem"
iso_version="$(date +%Y%m%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/root"]="0:0:750"
    ["/root/.automated_script.sh"]="0:0:755"
    ["/usr/local/bin/choose-mirror"]="0:0:755"
    ["/usr/local/bin/Installation_guide"]="0:0:755"
    ["/usr/local/bin/livecd-sound"]="0:0:755"
    ["/usr/local/bin/shivaos-install"]="0:0:755"
    ["/root/Desktop/shiva-commander.desktop"]="0:0:755"
    ["/root/Desktop/shiva-ai.desktop"]="0:0:755"
    ["/root/Desktop/shivaos.desktop"]="0:0:755"
    ["/root/Desktop/install-shivaos.desktop"]="0:0:755"
)
