# แยกชื่อและล้างตัวทดลอง

ใช้ชื่อ ThaiChatBridge = แกนข้อความ, ThaiChatUpdater = อัปเดต, ThaiChatTools = เครื่องมือ Codec Lab/Bento แยกเอกสารใน projects/ โดยไม่เปลี่ยน URL อัปเดต

ตรวจ main ก่อนจัดครั้งนี้ (ecf5eb52a242a10dd8c1fac51c77f74f7083db29): ไม่มี native/pc-3d-codex หรือชุด Codex 3D เก่าที่เลิกใช้ จึงไม่มีไฟล์ทดลองกลุ่มนี้ให้ลบจาก GitHub ไม่เหมารวมแพ็กเกจ legacy ที่ใช้งานได้ว่าเป็นการทดลองล้มเหลว

ในเครื่องพัฒนา สำรอง ZIP ตรวจความสมบูรณ์แล้ว และนำตัวรัน Codex 3D เก่าที่เลิกใช้/compiled outputs 17 ไฟล์ออกจากโฟลเดอร์งาน เก็บ source, regression tests, หลักฐาน และงานระบบแปลภาษาของผู้ช่วยอื่นไว้ ชุดเก่าไม่ผ่านการยืนยันภาพเกมเป็น runtime ปัจจุบัน แต่ unit tests บางส่วนผ่านแล้ว

ไม่มีการเปลี่ยน codec, hook, manifest, package หรือ binary ใน commit จัดชื่อครั้งนี้
