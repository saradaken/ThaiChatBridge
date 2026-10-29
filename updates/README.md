# ช่องอัปเดต

| Manifest | ผู้ใช้งาน |
|---|---|
| `unified-pc.json` | ThaiChatUpdater 1.1 Unified; ช่องใหม่สำหรับ UI ที่ hot reload ได้ |
| `native-pc.json` | Native updater รุ่นเดิม R25 / Native Update 1 |
| `stable.json` | Legacy Lua/CEF updater สำหรับ R24 |

อย่าสลับ manifest ข้ามรุ่นเพียงเพราะชื่อคล้ายกัน ทุก manifest ตรึง assets ด้วย immutable commit และ SHA-256

เก็บช่องเก่าไว้เพื่อให้การติดตั้งเดิมตรวจอัปเดตได้ตามเงื่อนไขเดิม
