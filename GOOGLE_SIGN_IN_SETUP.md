# Cấu hình đăng nhập Google

Ứng dụng xác minh Google ID token ở backend bằng OAuth Web client ID. Tạo OAuth consent screen và các OAuth client phù hợp trong Google Cloud Console.

Tạo Android OAuth client với application ID com.example.hcm_explorer và SHA-1 của khóa ký ứng dụng. Tạo thêm Web OAuth client. Nếu chạy iOS hoặc macOS, tạo OAuth client theo bundle ID tương ứng.

Trong backend/.env, đặt Web client ID:

    GOOGLE_CLIENT_ID=409118219902-lf23rdn9l3sheeekl9cjod3e2kin6lh5.apps.googleusercontent.com

Khởi động lại backend để nạp biến môi trường.

Chạy Flutter với cùng Web client ID:

    flutter run --dart-define="GOOGLE_CLIENT_ID=409118219902-lf23rdn9l3sheeekl9cjod3e2kin6lh5.apps.googleusercontent.com"

Đối với iOS hoặc macOS, có thể truyền thêm client ID riêng của nền tảng nếu chưa cấu hình trong plist:

    flutter run --dart-define="GOOGLE_CLIENT_ID=409118219902-lf23rdn9l3sheeekl9cjod3e2kin6lh5.apps.googleusercontent.com" --dart-define="GOOGLE_IOS_CLIENT_ID=IOS_CLIENT_ID" --dart-define="GOOGLE_MACOS_CLIENT_ID=MACOS_CLIENT_ID"

Tài khoản có email được Google xác minh sẽ được liên kết theo Google subject hoặc email và lưu trong bảng users của MariaDB. Tài khoản mới có username tạo từ email và password hash ngẫu nhiên; lần đăng nhập sau vẫn xác thực qua Google. Tài khoản admin không dùng được luồng Google.

## Flutter Web

The Google button uses Google's web-rendered sign-in button. In Google Cloud Console, add the address used by your local Flutter web server under the Web OAuth client's Authorized JavaScript origins. For the command below, add http://localhost:7357.

Run the app with the same Web client ID used by the backend:

    flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define="GOOGLE_CLIENT_ID=409118219902-lf23rdn9l3sheeekl9cjod3e2kin6lh5.apps.googleusercontent.com"

The GOOGLE_CLIENT_ID value must be a real OAuth Web client ID. The button remains visible without it, but Google sign-in cannot start until the value and authorized origin are configured.

## Ch?y b?ng VS Code

Trong thanh ch?n c?u h?nh ch?y c?a VS Code, ch?n hcm_explorer (Chrome), r?i b?m Run ho?c nh?n F5. C?u h?nh n?y t? truy?n GOOGLE_CLIENT_ID v? ch?y ? c?ng 7357.
