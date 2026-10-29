# Runtime assets สำหรับ updater

โฟลเดอร์นี้เป็นปลายทาง URL ของ assets ที่ manifest ตรึง commit ไว้ ไม่ใช่ installer ให้คัดลอกทั้งโฟลเดอร์

รุ่น updater ปัจจุบัน: `ThaiChatUpdater.asi` 1.1 Unified test1 และ updater JS/CSS ใน `moonloader/resource/`

ไฟล์ core/Lua บางส่วนยังเป็นรุ่นเก่าที่ต้องเก็บเพื่อ compatibility ผู้ใช้ใหม่ให้เริ่มจาก [แพ็กเกจแยกรุ่น](../packages/) และ [คู่มือ](../docs/INSTALL_UPDATER.md)

manifest เก่าอ้าง commit เก่า จึงยังดาวน์โหลด bytes รุ่นเดิมได้แม้ assets บน main เปลี่ยน
