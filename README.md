# ThaiChatBridge

ปลั๊กอินข้อความภาษาไทยสำหรับ Arizona RP / SA-MP บน PC และระบบอัปเดตไฟล์แยกจากแกนข้อความ

## เลือกสิ่งที่จะใช้

| ส่วน | หน้าที่ | สถานะ |
|---|---|---|
| [ThaiChatBridge](projects/ThaiChatBridge/README.md) | แชตไทย บับเบิล ฟอนต์ และ codec | ชุด native R25 ในช่องเดิม; R26 3D เป็นการทดลองแยก |
| [ThaiChatUpdater 1.1 Unified test1](projects/ThaiChatUpdater/README.md) | ตรวจ/ดาวน์โหลด/สำรอง/อัปเดตไฟล์ พร้อม UI | ชุด updater ปัจจุบันในหน้านี้ |
| [ThaiChatTools — Codec Lab / Bento](projects/ThaiChatTools/README.md) | เครื่องมือทดลอง codec และตั้งค่า | ชุด Lua/CEF เดิม เก็บไว้สำหรับรุ่นที่ตรงกัน |

## ดาวน์โหลดตัวอัปเดตใหม่

- [แพ็กเกจ ThaiChatUpdater 1.1 Unified test1](packages/ThaiChatUpdater-1.1-Unified-test1.zip)
- [ASI ตัวเดียว](native-pc/ThaiChatUpdater.asi)
- [วิธีติดตั้งและคำสั่ง](docs/INSTALL_UPDATER.md)
- [หลักการอัปเดตและข้อจำกัด](docs/UPDATER_UNIFIED.md)

ตัว updater **ไม่ใช่ตัวติดตั้งเกมและไม่ใช่แกนข้อความไทย** ต้องมี ASI Loader, MoonLoader และ CEF ของเกมอยู่แล้ว

ASI ฝัง Lua bridge และ UI สำรองไว้ เมื่อเริ่มเกมจะจัดเตรียม bootstrap ให้เอง ส่วน JS/CSS ภายนอกเปลี่ยนและ reload ได้ การฝังนี้ยังใช้ MoonLoader รัน Lua ไม่ใช่ native CEF bridge ทั้งหมด

## การใช้งาน

```text
/thupdate          เปิด/ปิดหน้าต่างอัปเดต
/thupdate reload   โหลดหน้า UI จากไฟล์ภายนอกใหม่
```

กด **ตรวจสอบอัปเดต** แล้ว **ติดตั้ง** ตามสถานะ:

- UI อย่างเดียว: ตรวจ hash และติดตั้งระหว่างเล่น แล้ว reload หน้า CEF
- มี ASI/ไฟล์ที่ต้อง restart: ดาวน์โหลดและสำรองก่อน รอปิดเกมตามปกติแล้วจึงแทนไฟล์
- ไฟล์ในรุ่นเดิมหายหรือ hash ไม่ตรง: เสนอ repair ได้จากปุ่มตรวจเช่นกัน ไม่ต้องจำคำสั่ง repair ในการใช้งานทั่วไป

ช่อง unified ปัจจุบันเป็น **UI-only revision 2604 (UI Update 2)** ไม่เปลี่ยนแกนแชต R26 หรือไฟล์คำแปล

## โครงสร้าง repository

| โฟลเดอร์ | เก็บอะไร |
|---|---|
| [`packages/`](packages/) | ZIP ติดตั้งที่แยกรุ่นชัดเจน |
| [`docs/`](docs/) | วิธีใช้และรายละเอียดระบบ |
| [`updates/`](updates/) | manifest ของแต่ละช่องอัปเดต |
| [`native-pc/`](native-pc/) | runtime assets สำหรับ URL ที่ manifest ตรึง commit ไว้ |
| [`pc/moonloader/`](pc/moonloader/) | legacy Lua/CEF channel ของ R24; ไม่ควรคัดลอกปนชุดใหม่ |
| [`design/`](design/) | แบบ UI และเอกสารต้นแบบเดิม |

`native-pc` เก็บ assets หลายรุ่นตามประวัติ ไม่ใช่ installer ที่ให้คัดลอกทั้งโฟลเดอร์ ใช้ ZIP และคู่มือของรุ่นที่เลือก

ไฟล์ legacy และช่องเก่ายังคง path เดิมเพื่อไม่ทำให้ผู้ใช้รุ่นก่อนอัปเดตไม่ได้ ดู [README รุ่นเก่า](docs/legacy/README-before-unified.md)

## ความเข้ากันได้

- อย่าเปิด `ThaiChatUpdaterUI.lua` รุ่นเดิมคู่กับ generated `ThaiChatUpdaterBootstrap.lua` เพราะลงทะเบียน `/thupdate` ซ้ำ สำรองและปิดใช้ launcher เก่าก่อนย้าย
- อย่าโหลด ASI core ThaiChatBridge สองรุ่นพร้อมกัน
- ตัว updater ไม่ได้แปลภาษารัสเซียเป็นไทย และแพ็กเกจนี้ไม่รวมฐานคำแปล
- ระบบอัปเดต Android ยังไม่อยู่ในชุดนี้

ดาวน์โหลดผ่าน HTTPS และตรวจขนาด/SHA-256 ตาม manifest ที่ระบุ commit แน่นอน ความน่าเชื่อถือยังขึ้นกับบัญชี/repository นี้ ไม่ใช่ระบบลายเซ็นแยกต่างหาก

ดู [THIRD_PARTY.md](THIRD_PARTY.md) สำหรับแหล่งข้อมูลและ license ที่เกี่ยวข้อง
