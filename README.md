# hcm_explorer

Required: Flutter + Dart

1. Mở source bằng VS Code.
2. Sao chép `backend/.env.example` thành `backend/.env` và cập nhật thông tin MariaDB, RustFS.
3. Tại thư mục `backend`, chạy `dart pub get`, sau đó `dart run bin/server.dart`.
   Mặc định server lắng nghe trên mọi giao diện tại cổng `8080`; có thể đổi bằng
   biến môi trường `HOST` và `PORT`. Kiểm tra server tại `http://localhost:8080/health`.
4. Tại thư mục dự án, chạy `flutter pub get`, sau đó `flutter run -d chrome`.

Android Emulator tự dùng `http://10.0.2.2:8080` để truy cập server trên máy phát
triển. Khi chạy trên điện thoại thật, đặt `API_BASE_URL` thành địa chỉ IP trong
mạng LAN của máy chạy backend, ví dụ:

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

Điện thoại và máy chạy backend cần cùng mạng; cần cho phép cổng `8080` qua
firewall. Bản Android debug cho phép HTTP để dùng server phát triển; bản phát
hành nên cấu hình `API_BASE_URL` trỏ tới server HTTPS.
