#!/usr/bin/env bash
# build-tx3mini-openwrt.sh
# สร้างอิมเมจ OpenWrt สำหรับ TX3 Mini (S905W, บอร์ด CS_905W_TX_3D_V1.4)
# โดยเอาอิมเมจของ ophub มาใส่ firmware WiFi (SP6330 / AP6330 = BCM4330) ให้
#
# ใช้บน Linux (Ubuntu/Debian) ด้วยสิทธิ์ root:
#   sudo ./build-tx3mini-openwrt.sh openwrt_s905w_xxx.img.gz [โฟลเดอร์firmware]
#
# เตรียมก่อน:
#  1) โหลด openwrt_s905w_k*.img.gz จาก
#     https://github.com/ophub/amlogic-s9xxx-openwrt/releases
#  2) โฟลเดอร์ firmware/ ต้องมีไฟล์
#       brcmfmac4330-sdio.bin   (จาก linux-firmware หรือ Android stock ROM)
#       brcmfmac4330-sdio.txt   (nvram ของบอร์ด ดึงจาก stock ROM:
#                                /system/etc/wifi/ หรือ /vendor/etc/wifi/ เช่น nvram_ap6330.txt)
#     (ถ้ามี) brcmfmac4330-sdio.clm_blob
#  3) ถ้าอยากบังคับ DTB:  DTB=meson-gxl-s905w-tx3-mini.dtb sudo -E ./build...sh ...
#
# ตัวแปรปรับแต่งได้: SSID, PSK, COUNTRY, LAN_IP

set -euo pipefail

IMG_GZ="${1:?usage: sudo $0 openwrt_s905w_xxx.img.gz [firmware_dir]}"
FW_DIR="${2:-./firmware}"
OUT="${OUT:-tx3mini-openwrt-wifi.img}"
SSID="${SSID:-TX3-OpenWrt}"
PSK="${PSK:-12345678}"
COUNTRY="${COUNTRY:-TH}"
LAN_IP="${LAN_IP:-192.168.1.1}"
DTB="${DTB:-}"

[ "$(id -u)" -eq 0 ] || { echo "ต้องรันด้วย sudo"; exit 1; }
[ -f "$IMG_GZ" ] || { echo "ไม่เจอ $IMG_GZ"; exit 1; }
[ -f "$FW_DIR/brcmfmac4330-sdio.bin" ] || { echo "ไม่เจอ $FW_DIR/brcmfmac4330-sdio.bin"; exit 1; }
[ -f "$FW_DIR/brcmfmac4330-sdio.txt" ] || echo "คำเตือน: ไม่มี brcmfmac4330-sdio.txt (nvram) WiFi อาจไม่ขึ้น"

echo "[1/5] แตกอิมเมจ"
case "$IMG_GZ" in
  *.gz) gunzip -c "$IMG_GZ" > "$OUT" ;;
  *.img) cp "$IMG_GZ" "$OUT" ;;
  *) echo "รองรับ .img หรือ .img.gz"; exit 1 ;;
esac

LOOP="$(losetup -Pf --show "$OUT")"
BOOT_MNT="$(mktemp -d)"; ROOT_MNT="$(mktemp -d)"
cleanup() {
  sync || true
  umount "$BOOT_MNT" 2>/dev/null || true
  umount "$ROOT_MNT" 2>/dev/null || true
  losetup -d "$LOOP" 2>/dev/null || true
  rmdir "$BOOT_MNT" "$ROOT_MNT" 2>/dev/null || true
}
trap cleanup EXIT

echo "[2/5] เมานต์พาร์ทิชัน ($LOOP)"
mount "${LOOP}p1" "$BOOT_MNT"
mount "${LOOP}p2" "$ROOT_MNT"

if [ -n "$DTB" ]; then
  echo "[3/5] ตั้ง DTB = $DTB"
  if grep -q '^FDT=' "$BOOT_MNT/uEnv.txt"; then
    sed -i "s#^FDT=.*#FDT=/dtb/amlogic/${DTB}#" "$BOOT_MNT/uEnv.txt"
  else
    echo "FDT=/dtb/amlogic/${DTB}" >> "$BOOT_MNT/uEnv.txt"
  fi
else
  echo "[3/5] ใช้ DTB ตามค่าเริ่มต้นของอิมเมจ:"
  grep -E '^FDT=' "$BOOT_MNT/uEnv.txt" || echo "  (ไม่พบบรรทัด FDT ใน uEnv.txt)"
fi

echo "[4/5] ใส่ firmware WiFi"
FW_DST="$ROOT_MNT/lib/firmware/brcm"
mkdir -p "$FW_DST"
cp -f "$FW_DIR"/brcmfmac4330-sdio.* "$FW_DST"/
# kernel มองหาไฟล์ชื่อ brcmfmac4330-sdio.<compatible ของบอร์ด>.{bin,txt}
# อ่านค่า compatible จาก DTB ที่อิมเมจใช้จริง (ต้องมี fdtget) + เผื่อชื่อทั่วไป
FDT_NAME="${DTB:-$(sed -n 's#^FDT=/dtb/amlogic/##p' "$BOOT_MNT/uEnv.txt" | head -n1)}"
COMPAT="amlogic,p212 amlogic,s905w amlogic,tx3-mini amlogic,gxl"
DTB_FILE="$(find "$BOOT_MNT" "$ROOT_MNT" -name "${FDT_NAME:-__none__}" 2>/dev/null | head -n1 || true)"
if [ -n "$DTB_FILE" ] && command -v fdtget >/dev/null; then
  DTB_COMPAT="$(fdtget -t s "$DTB_FILE" / compatible 2>/dev/null || true)"
  echo "    compatible จาก DTB: $DTB_COMPAT"
  COMPAT="$DTB_COMPAT $COMPAT"
else
  echo "    (อ่าน compatible จาก DTB ไม่ได้ ใช้ชื่อทั่วไปแทน; apt install device-tree-compiler จะดีกว่า)"
fi
for c in $COMPAT; do
  for ext in bin txt clm_blob; do
    [ -f "$FW_DST/brcmfmac4330-sdio.$ext" ] && \
      ln -sf "brcmfmac4330-sdio.$ext" "$FW_DST/brcmfmac4330-sdio.${c}.${ext}"
  done
done
mkdir -p "$ROOT_MNT/etc/modules.d"
echo "brcmfmac" > "$ROOT_MNT/etc/modules.d/30-brcmfmac"

echo "[5/5] ตั้งค่าเริ่มต้น (WiFi / LAN) ครั้งแรกที่บูต"
mkdir -p "$ROOT_MNT/etc/uci-defaults"
cat > "$ROOT_MNT/etc/uci-defaults/90-tx3mini-setup" <<EOF
#!/bin/sh
uci set network.lan.ipaddr='${LAN_IP}'
uci commit network

# สร้างค่า wifi ถ้ายังไม่มี
[ -s /etc/config/wireless ] || wifi config
for r in \$(uci show wireless | grep "=wifi-device" | cut -d. -f2 | cut -d= -f1); do
  uci set wireless.\$r.country='${COUNTRY}'
  uci set wireless.\$r.disabled='0'
done
for i in \$(uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1); do
  uci set wireless.\$i.mode='ap'
  uci set wireless.\$i.network='lan'
  uci set wireless.\$i.ssid='${SSID}'
  uci set wireless.\$i.encryption='psk2'
  uci set wireless.\$i.key='${PSK}'
done
uci commit wireless
exit 0
EOF
chmod +x "$ROOT_MNT/etc/uci-defaults/90-tx3mini-setup"

echo
echo "เสร็จแล้ว: $OUT"
echo "เขียนลง SD card:  sudo dd if=$OUT of=/dev/sdX bs=4M conv=fsync status=progress"
echo "บูตจาก SD แล้วเช็ก:  dmesg | grep -i -E 'brcm|sdio|mmc' ; iw dev"
echo "ติดตั้งลง eMMC: เข้า LuCI > Services > Amlogic Service > Install OpenWrt"
echo "จอ LED หน้าเครื่อง: ใช้คำสั่ง openwrt-openvfd"
