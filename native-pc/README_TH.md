# ThaiChatBridge PC Native — ชุดแจก revision 2503

ชุดนี้ใช้แกนข้อความ **PC 1.3 R25 test2** เดิม พร้อม **ThaiChatUpdater 1.0 test2** และหน้าอัปเดต Gradient Spinner แยกจากเครื่องมือ Codec Lab/Bento เลข 2503 เป็น revision ของชุดแจก ไม่ใช่แกนแชตรุ่นใหม่

## ติดตั้งครั้งแรก

ปิดเกมก่อนคัดลอก ThaiChatBridge.asi และ ThaiChatUpdater.asi ลงโฟลเดอร์เกมข้าง gta_sa.exe แล้วรวมโฟลเดอร์ moonloader ของชุดนี้เข้ากับ moonloader ของเกม ต้องมี ASI loader, _chat.asi, MoonLoader และไลบรารีที่เครื่องมือเดิมใช้อยู่ ชุดนี้ไม่ได้รวมตัวเกมหรือตัวโหลดเหล่านั้น

เมื่อใช้แกน standalone แล้ว ไม่ให้เปิดใช้ ThaiChatClaudeProbe.lua หรือ ThaiChatInputStatus.lua รุ่นเก่าซ้ำ สำรองไว้ภายนอกโฟลเดอร์ที่ MoonLoader โหลดก่อนนำออก

## อัปเดตครั้งต่อไป

เปิดเกม พิมพ์ `/thupdate` แล้วกดตรวจสอบอัปเดต หากพบรุ่นใหม่ให้กดติดตั้ง ตัวอัปเดตดาวน์โหลดไฟล์จาก commit ที่ตรึงไว้ ตรวจขนาดและ SHA-256 แล้วรอปิดเกมก่อนแทนไฟล์ ไม่ปิดเกมให้อัตโนมัติ

- `/thupdate close` ปิดหน้าต่าง โดยไม่ยกเลิกงาน
- `/thupdate cancel` ขอยกเลิกที่จุดตรวจถัดไป
- `/thupdate rollback` รอปิดเกมแล้วคืนชุดสำรองล่าสุดของตัวอัปเดต
- `/thcodecui` เปิดเครื่องมือเดิมที่แยกไว้

ค่าเริ่มต้นเก็บสำรองใน `%LOCALAPPDATA%/ThaiChatBridge/backups` เครื่องพัฒนานี้ตั้งให้เก็บใน `C:/PJ ThaiChatBridge/backups` การตั้งค่านั้นไม่รวมในชุดแจก

ช่อง native แยกจาก updates/stable.json เดิม ไม่ได้อัปเกรดชุด R24 เก่าอัตโนมัติ ต้องติดตั้งชุด native ครั้งแรกก่อน UI ยังเป็น Lua/CEF ภายนอก ASI และยังไม่มีพอร์ต Android ของตัวอัปเดตนี้

อ่าน THIRD_PARTY.md และไฟล์ licenses สำหรับไลบรารีและฟอนต์ที่รวมในชุดนี้
