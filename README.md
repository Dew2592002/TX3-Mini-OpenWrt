# TX3 Mini OpenWrt builder
1. สร้าง repo ใหม่บน GitHub แล้วอัปโหลดทุกอย่างในโฟลเดอร์นี้ (ต้องมี .github/)
2. (ไม่ต้องหา nvram เอง workflow โหลดให้จาก LibreELEC/armbian)
3. แท็บ Actions -> "Build TX3 Mini OpenWrt" -> Run workflow (ตั้ง SSID/รหัสได้)
4. รอ ~5-10 นาที โหลด `tx3mini-openwrt-wifi.img.gz` จากหน้า Releases -> เขียนลง SD card -> บูต

หมายเหตุ: ถ้าไม่ใช้ GitHub ให้รัน `sudo ./run.sh` บน Linux แทน
