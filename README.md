# PartyUp

แอป Flutter สำหรับหาเพื่อนร่วมทีม eSports, หาเพื่อนเล่นเกมทั่วไป ดูตารางแข่งขัน และนัดหมายกันผ่านห้องแชท

## ฟีเจอร์

- **หาทีม eSports:** ทีมประกาศรับสมาชิกแยกตามเกม แรงค์ ตำแหน่งที่ขาด สไตล์ทีม และเวลาซ้อม พร้อมติดต่อทีมผ่านห้องแชท
- **หาเพื่อนเล่นเกม:** สร้างปาร์ตี้นัดเล่นเกมทั่วไป ระบุแรงค์ สไตล์ และเวลานัด
- แยกประกาศทีมแข่งขันใน Cloud Firestore collection `esports_teams` และปาร์ตี้ทั่วไปใน `parties`
- ห้องแชทนัดหมายใช้ Firebase Realtime Database แบบเรียลไทม์
- **ตารางแข่ง eSports:** ดึงแมตช์ LIVE และแมตช์ที่กำลังจะเริ่มจาก PandaScore พร้อมรีเฟรชทุก 60 วินาทีขณะเปิดหน้า
- ค้นหาและกรองแต่ละหน้าแยกกันตามเกมและคำค้น
- Responsive layout สำหรับมือถือและจอขนาดใหญ่
- มีข้อมูล DEMO สำหรับประกาศหาเพื่อนเมื่อยังไม่ได้ตั้งค่า Firebase ส่วนตาราง PandaScore จะแจ้งให้ตั้งค่า API key แทนการแสดงข้อมูลแข่งจำลอง

## ตั้งค่า Firebase

1. สร้าง Firebase project และเพิ่มแอป Android/iOS/Web ที่ต้องการ
2. ตั้งค่า FlutterFire/native Firebase ตามแพลตฟอร์ม แล้วเพิ่มไฟล์ config ที่สร้างให้กับโปรเจกต์
3. เปิดใช้ Cloud Firestore และ Realtime Database ใน Firebase Console
4. รัน `flutter pub get` แล้วเปิดแอป

หาก Firebase ยังไม่ได้ตั้งค่า แอปจะเปิดใน DEMO MODE โดยข้อมูลที่เพิ่ม/แก้ไข/ลบจะอยู่ในหน่วยความจำของแอปเท่านั้น

## ตั้งค่า PandaScore

ตารางแข่งดึงข้อมูล LIVE และ UPCOMING แยกตามเกมที่มีในแอปจาก PandaScore และรีเฟรชทุก 60 วินาทีขณะเปิดหน้า ก่อนใช้งานให้ตั้ง token เป็น Dart define:

```sh
flutter run -d emulator-5554 --dart-define=PANDASCORE_API_KEY=your_token
```

หากไม่ระบุ token แอปจะไม่แสดงแมตช์ตัวอย่างปะปนกับตารางจริง ใน VS Code ให้เพิ่ม `--dart-define=PANDASCORE_API_KEY=your_token` ใน `toolArgs` ของ launch configuration ที่ใช้รันแอป แล้วหยุดและเริ่มแอปใหม่

> PandaScore ระบุว่า token เป็นข้อมูลส่วนตัวและไม่ควรฝังในแอปฝั่งผู้ใช้ การใช้งานจริงควรเรียก API ผ่าน backend ของโปรเจกต์และเก็บ token ไว้บน server

## App icon และ Splash Screen

ใช้ไฟล์ `assets/images/app_icon.png` เป็นไอคอน PartyUp, adaptive icon บน Android และโลโก้กลางหน้าเปิดแอป พื้นหลังเป็นสี `#F2F2F7` ใน Light mode และสีดำใน Dark mode

สร้างไฟล์ไอคอนและ splash screen ใหม่หลังเปลี่ยนภาพ:

```sh
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
