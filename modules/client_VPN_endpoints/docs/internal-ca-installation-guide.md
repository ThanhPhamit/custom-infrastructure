# Hướng dẫn cài đặt Internal CA cho Workstation & Trình duyệt (SSL Internal Network)

## 1. Tại sao phải dùng Internal CA cho hệ thống internal network dùng SSL?

- **Bảo mật truyền thông nội bộ:** Internal CA (Certificate Authority) giúp mã hóa dữ liệu giữa các dịch vụ nội bộ qua SSL/TLS, đảm bảo thông tin không bị nghe lén hoặc giả mạo.
- **Tin cậy & kiểm soát:** Internal CA cho phép bạn tự kiểm soát, phát hành và thu hồi chứng chỉ cho các server, service nội bộ mà không phụ thuộc vào CA bên ngoài.
- **Tiết kiệm chi phí:** Không cần mua chứng chỉ SSL từ các CA thương mại cho các domain chỉ sử dụng trong mạng nội bộ.
- **Tránh cảnh báo bảo mật:** Khi cài đặt CA nội bộ lên các máy trạm, trình duyệt và hệ điều hành sẽ tin tưởng các chứng chỉ do CA này phát hành, không hiện cảnh báo "untrusted certificate".

## 2. Hướng dẫn cài đặt CA nội bộ trên workstation

### Linux

Chạy lệnh sau trong thư mục chứa file chứng chỉ:

```bash
./install-ca.sh certificates/ca-certificate.crt
```

Script sẽ tự động cài đặt cho hệ điều hành (Ubuntu/Debian/CentOS/Fedora) và trình duyệt Firefox, Chrome/Chromium nếu có.

### macOS

Chạy lệnh sau trong thư mục chứa file chứng chỉ:

```bash
./install-ca.sh certificates/ca-certificate.crt
```

### Windows

Có 2 cách:

#### Cách 1 — PowerShell (tự động, cần quyền admin)

1. Mở PowerShell với quyền Administrator.
2. Chạy lệnh:

   ```powershell
   Import-Certificate -FilePath "certificates/ca-certificate.crt" -CertStoreLocation "Cert:\LocalMachine\Root"
   ```

   (Hoặc thay `LocalMachine` bằng `CurrentUser` nếu chỉ muốn cài cho user hiện tại.)

#### Cách 2 — Thủ công qua giao diện

1. Double-click vào file `ca-certificate.crt`.
2. Chọn **"Install Certificate"**.
3. Chọn **"Local Machine"** (cần admin) hoặc **"Current User"**.
4. Chọn **"Place all certificates in the following store"**.
5. Chọn **"Trusted Root Certification Authorities"**.
6. **Next → Finish**.

### Firefox (nếu chưa tự động nhận)

1. Mở Firefox → **Settings → Privacy & Security**.
2. Kéo xuống mục **"Certificates"** → click **"View Certificates"**.
3. Tab **"Authorities"** → click **"Import..."**.
4. Chọn file `ca-certificate.crt`.
5. Tick **"Trust this CA to identify websites"**.
6. **OK** → restart Firefox.

## 3. Hướng dẫn kiểm tra trên trình duyệt

1. Tắt hoàn toàn và mở lại trình duyệt sau khi cài CA.
2. Clear cache nếu vẫn còn cảnh báo chứng chỉ.
3. Truy cập: <https://staging.welfan.internal>
4. Đảm bảo thấy biểu tượng ổ khóa xanh (không có cảnh báo chứng chỉ).

> Nếu có vấn đề, kiểm tra lại các bước cài đặt hoặc liên hệ quản trị viên hệ thống để được hỗ trợ.
