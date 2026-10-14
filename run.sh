#!/usr/bin/env bash
# run.sh - สั่งครั้งเดียวจบ ไม่ต้องใช้บัญชี GitHub / ไม่ต้องสร้าง repo
# ใช้บน Linux (Ubuntu/Debian หรือ WSL) :  sudo ./run.sh
# ตัวเลือก: SSID=ชื่อ PSK=รหัส DTB=meson-gxl-s905w-tx3-mini.dtb sudo -E ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" -eq 0 ] || { echo "รันด้วย: sudo ./run.sh"; exit 1; }
command -v curl >/dev/null || { apt-get update && apt-get install -y curl; }
command -v gunzip >/dev/null || apt-get install -y gzip

mkdir -p firmware work
if [ ! -f work/base.img.gz ]; then
  echo "[*] หาอิมเมจ OpenWrt S905W ล่าสุด"
  url=$(curl -fsSL "https://api.github.com/repos/ophub/amlogic-s9xxx-openwrt/releases?per_page=30" \
        | grep -o 'https://[^"]*openwrt_s905w_[^"]*\.img\.gz' | head -n1)
  [ -n "$url" ] || { echo "หาอิมเมจไม่เจอ โหลดเองแล้ววางเป็น work/base.img.gz"; exit 1; }
  echo "    $url"
  curl -fL "$url" -o work/base.img.gz
fi

command -v fdtget >/dev/null || apt-get install -y device-tree-compiler || true
LE=https://raw.githubusercontent.com/LibreELEC/brcmfmac_sdio-firmware/master
AR=https://raw.githubusercontent.com/armbian/firmware/master
get() { n="$1"; shift; [ -s "firmware/$n" ] && return 0
  for u in "$@"; do curl -fsSL "$u" -o "firmware/$n" && [ -s "firmware/$n" ] && { echo "[*] $n <- $u"; return 0; }; rm -f "firmware/$n"; done; return 1; }
get brcmfmac4330-sdio.bin "$LE/brcmfmac4330-sdio.bin" "$AR/brcm/brcmfmac4330-sdio.bin" \
  https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/brcm/brcmfmac4330-sdio.bin \
  || { echo "โหลด .bin ไม่ได้"; exit 1; }
get brcmfmac4330-sdio.txt "$LE/brcmfmac4330-sdio.txt" "$AR/rkwifi/nvram_AP6330.txt" "$AR/brcm/brcmfmac-ap6330-sdio.txt" \
  || { echo "โหลด nvram .txt ไม่ได้"; exit 1; }

./build-tx3mini-openwrt.sh work/base.img.gz firmware
gzip -f tx3mini-openwrt-wifi.img
echo
echo "ได้ไฟล์: $(pwd)/tx3mini-openwrt-wifi.img.gz  (เขียนลง SD ด้วย balenaEtcher ได้เลย)"
