# ติดตั้ง ThaiChatUpdater 1.1 Unified test1

## ครั้งแรก

1. ปิดเกมและสำรองตัว updater/launcher เดิม
2. วาง `ThaiChatUpdater.asi` ข้าง `gta_sa.exe`
3. ถ้ามี `moonloader/ThaiChatUpdaterUI.lua` เก่า ให้ย้ายไปสำรองนอกโฟลเดอร์โหลดสคริปต์ เพื่อไม่ให้คำสั่งซ้ำ
4. เปิดเกมใหม่ แล้วพิมพ์ `/thupdate`

ASI จัดเตรียมไฟล์ต่อไปนี้ให้เอง:

```text
moonloader/ThaiChatUpdaterBootstrap.lua
moonloader/resource/thaichat-updater-ui.js
moonloader/resource/thaichat-updater.css
```

ต้องมี ASI Loader, MoonLoader และ CEF ของ Arizona รุ่นที่รองรับอยู่แล้ว ถ้า updater ASI ไม่ถูกโหลด มันจะซ่อมตัวเองไม่ได้

ZIP มี JS/CSS ให้ด้วยสำหรับผู้ที่ต้องการวางไฟล์ครบชุด แต่ ASI มีสำเนาสำรองสำหรับเริ่มต้นได้

## ใช้งานประจำ

เปิด `/thupdate` แล้วกดตรวจสอบอัปเดต หากมีรุ่นใหม่หรือไฟล์ไม่ครบ กดติดตั้ง หน้าแจ้งสถานะจะแยกว่าต้องปิดเกมหรือใช้ต่อได้

ปุ่มตรวจทำหน้าที่ตรวจเวอร์ชันและตรวจไฟล์ของ manifest ด้วย ไม่จำเป็นต้องพิมพ์ repair แยกในงานปกติ

| คำสั่งเสริม | หน้าที่ |
|---|---|
| `/thupdate reload` | อ่าน JS/CSS แล้วเปิดหน้าใหม่ |
| `/thupdate close` | ปิดหน้า |
| `/thupdate repair` | ขอซ่อมเฉพาะ updater JS/CSS จากช่องอัปเดต |
| `/thupdate cancel` | ขอหยุดงานในจุดที่ยกเลิกได้ |
| `/thupdate rollback` | ขอคืน backup ล่าสุด; rollback ยังรอปิดเกม |

อย่าแก้ bootstrap เพื่อเปลี่ยน UI ถาวร เพราะ ASI เป็นเจ้าของ generated file ให้แก้ไฟล์ JS/CSS ภายนอกแทน

## ไฟล์สถานะและสำรอง

สถานะ/stage/ledger อยู่ใน `<game>/.thaichat-updater/` ZIP สำรองค่าเริ่มต้นอยู่ `%LOCALAPPDATA%/ThaiChatBridge/backups/` สามารถตั้ง `backup_directory` เป็น absolute path ภายนอก moonloader ใน `.thaichat-updater/settings.json`

หากพบ 404 ให้ตรวจว่าติดตั้ง updater ที่ใช้ช่องถูกต้องและ manifest เผยแพร่แล้ว หากตรวจ hash ไม่ผ่าน ระบบจะไม่แทนไฟล์นั้น

## ขอบเขต

ไม่ได้ดาวน์โหลดเกมทั้งเกม ไม่ติดตั้ง `_chat.asi`/MoonLoader/CEF ให้ และไม่เปลี่ยนระบบคำแปล ชุด updater ไม่จำเป็นต้องแจกพร้อม core R26 ทดลองเพื่อใช้อัปเดต UI
