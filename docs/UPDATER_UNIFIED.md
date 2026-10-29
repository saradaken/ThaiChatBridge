# Unified updater: ไฟล์ที่เปลี่ยนบ่อยแยกจาก ASI

## ส่วนประกอบ

- `ThaiChatBridge` เป็นแกนข้อความ ไม่ใช่ตัว updater
- `ThaiChatUpdater.asi` มี native API และฝัง PowerShell helper + Lua bootstrap/controller/CEF transport/JSON module + UI fallback
- MoonLoader รัน bootstrap ที่ ASI จัดเตรียม จึงยังต้องมี MoonLoader
- JS/CSS ใช้งานจริงเป็นไฟล์ภายนอก อัปเดตได้บ่อยโดยไม่ rebuild ASI

## ช่องอัปเดต

`updates/unified-pc.json` สำหรับชุดรวมใหม่นี้ แยกจาก `updates/native-pc.json` และ `updates/stable.json` ของรุ่นเก่า

manifest ระบุ revision/version, commit SHA 40 หลัก และ path/size/SHA-256 ของแต่ละไฟล์ ดึง asset จาก `native-pc/<path>` ที่ commit นั้น ไม่ดึง asset แบบ main ที่อาจเปลี่ยนระหว่างดาวน์โหลด

## การติดตั้ง

ดาวน์โหลดครบและตรวจทุกไฟล์ก่อนเปลี่ยนปลายทาง ทำ ZIP backup ตรวจ original snapshot และใช้ replacement ทีละไฟล์พร้อม journal/rollback ไม่ได้อ้างว่า transaction ทั้งชุดเป็น atomic ครั้งเดียว

Hot apply อนุญาตเฉพาะ release ที่ทุกไฟล์เป็น:

```text
moonloader/resource/thaichat-updater-ui.js
moonloader/resource/thaichat-updater.css
```

กรณีนี้ไม่ต้องออกเกม UI controller reload หน้า CEF หนึ่งครั้งต่อ asset revision หลัง helper ติดตั้งเสร็จ ถ้ามี ASI หรือไฟล์ชนิดอื่นใน release ทั้งชุดจะรอ game exit เพื่อไม่ให้ UI กับ ASI คนละรุ่น

Repair ตรวจ UI assets แยกและไม่ทำให้ core ledger ถอยรุ่น ช่องที่เก่ากว่า core จะไม่ถูกเสนอให้ทับ core รุ่นใหม่

## ไฟล์ที่หาย

ตอนเริ่มเกมและตอนเปิด UI จะตรวจจัดเตรียม bootstrap/ไฟล์ UI ที่ขาดจากสำเนาใน ASI ก่อน ถ้า UI หายจะขอ repair จากช่องที่กำหนดด้วย ไม่ทำ startup network request จากเงื่อนไขนี้เมื่อไฟล์ UI มีครบ

ไม่เขียนทับ UI ภายนอกทุกครั้ง เพราะอาจเป็นรุ่นใหม่กว่าที่ฝังใน ASI และไม่เขียนทับ bootstrap ชื่อชนที่ไม่มี generated-file header ของระบบนี้

## ผลตรวจและสิ่งที่ยังต้องตรวจ

ผ่าน fixture: validation/path/hash, stage, backup, original-edit/tamper guard, install/rollback, ASI replacement หลัง parent exit, UI-only hot apply, missing-file repair และ reload-once

ผ่านเกมจริงก่อนเผยแพร่ช่อง: bootstrap โหลด, CEF_READY, ปุ่ม check ส่งถึง ASI/helper, manual reload และแสดงข้อผิดพลาดช่องที่ยังไม่มีได้

การเปิดใช้ช่องออนไลน์ต้องตรวจดาวน์โหลด hash จาก public URL และทดสอบปุ่มในเกมเพิ่ม ไม่ถือว่า fixture เป็นการติดตั้งออนไลน์ในเกมจริงแล้ว

ยังไม่มี Android port และไม่รวมระบบคำแปล
