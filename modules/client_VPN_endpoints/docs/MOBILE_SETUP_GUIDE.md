# Mobile setup vpn and install CA certificate

# Hướng Dẫn Cài Đặt VPN và CA Certificate cho Mobile

Tài liệu này hướng dẫn cách thiết lập kết nối VPN và cài đặt CA Certificate để truy cập các website nội bộ của Welfan trên thiết bị di động (Android và iOS).

---

## 📋 Tổng Quan

Để truy cập các website nội bộ của Welfan từ bên ngoài mạng công ty, bạn cần:

1. **Cài đặt OpenVPN** - Để kết nối vào mạng nội bộ
2. **Cài đặt CA Certificate** - Để trình duyệt tin tưởng các website nội bộ

---

## 📱 Hướng Dẫn Cho Android

### Bước 1: Cài Đặt OpenVPN

> ⚠️ Lưu ý quan trọng: Nếu bạn đang ở trong mạng nội bộ công ty (Private Network), BỎ QUA bước này và chuyển sang Bước 2.

1. Mở **Google Play Store**
2. Tìm kiếm "**OpenVPN Connect**"
3. Tải và cài đặt app từ **OpenVPN Inc.**
4. Mở app **OpenVPN Connect**
5. Nhấn vào biểu tượng **+** hoặc **Import Profile**
6. Chọn **File** → Tìm đến file `client.ovpn` đã tải về
7. Nhấn **Import** → **Add**
8. Nhấn **Connect** để kết nối VPN

✅ **Kết nối thành công** khi thấy biểu tượng chìa khóa trên thanh trạng thái.

---

### Bước 2: Cài Đặt CA Certificate (Android)

### 2.1 Tải CA Certificate

https://drive.google.com/drive/folders/1mFnyyEpniLAJC2g-Bkz7uk3VLw2RokRa?usp=sharing

1. Mở trình duyệt và truy cập Google Drive link ở trên
2. Tải về CA certificate tương ứng với môi trường bạn cần truy cập:
   - `install-ca-development/certificates/ca-certificate.crt` - Cho Development (\*.dev.welfan.internal)
   - `install-ca-staging/certificates/ca-certificate.crt`- Cho Staging (\*.staging.welfan.internal)
   - `install-ca-production/certificates/ca-certificate.crt` - Cho Production (\*.welfan.internal)

### 2.2 Cài Đặt CA Certificate

**Cài đặt qua Settings**

1. Mở **Settings** (Cài đặt)
2. Tìm kiếm "**Certificate**" hoặc vào:
   - **Security** → **More security settings** → **Encryption & credentials**
   - Hoặc: **Biometrics and security** → **Other security settings**
3. Nhấn **Install from device storage** hoặc **Install certificates**
4. Chọn **CA Certificate**
5. Nhấn **Install anyway** (nếu có cảnh báo)
6. Tìm và chọn file `.crt` đã tải
7. Đặt tên cho certificate và nhấn **OK**

### 2.3 Xác Nhận Cài Đặt Thành Công

1. Vào **Settings** → **Security** → **Encryption & credentials**
2. Nhấn **Trusted credentials** hoặc **User credentials**
3. Chuyển sang tab **User**
4. Kiểm tra xem certificate vừa cài có trong danh sách không

> 💡 Mẹo: Lặp lại bước 2 cho mỗi môi trường bạn cần truy cập (Dev, Staging, Production).

---

## 🍎 Hướng Dẫn Cho iOS (iPhone/iPad)

### Bước 1: Cài Đặt OpenVPN

> ⚠️ Lưu ý quan trọng: Nếu bạn đang ở trong mạng nội bộ công ty (Private Network), BỎ QUA bước này và chuyển sang Bước 2.

1. Mở **App Store**
2. Tìm kiếm "**OpenVPN Connect**"
3. Tải và cài đặt app từ **OpenVPN Inc.**
4. Mở app **Files** trên iPhone
5. Tải file `client.ovpn` từ Google Drive về **On My iPhone**
6. Nhấn vào file `client.ovpn`
7. Chọn **Share** → **OpenVPN** (hoặc nhấn giữ → Open in OpenVPN)
8. Trong app OpenVPN, nhấn **Add** để thêm profile
9. Nhấn nút **Connect** để kết nối
10. Cho phép thêm VPN configuration khi được hỏi

✅ **Kết nối thành công** khi thấy biểu tượng **VPN** trên thanh trạng thái.

---

### Bước 2: Cài Đặt CA Certificate (iOS)

### 2.1 Tải CA Certificate

1. Truy cập Google Drive link ở trên
2. Tải về CA certificate tương ứng với môi trường:
   - `install-ca-development/certificates/ca-certificate.crt` - Cho Development (\*.dev.welfan.internal)
   - `install-ca-staging/certificates/ca-certificate.crt`- Cho Staging (\*.staging.welfan.internal)
   - `install-ca-production/certificates/ca-certificate.crt` - Cho Production (\*.welfan.internal)

### 2.2 Cài Đặt Profile

https://drive.google.com/drive/folders/1mFnyyEpniLAJC2g-Bkz7uk3VLw2RokRa?usp=sharing

1. Nhấn vào file .`crt` trong ứng dụng Files
2. Nhấn **Close** khi thấy thông báo "Profile Downloaded"

### 2.3 Cài Đặt Certificate trong Settings

1. Mở **Settings** (Cài đặt)
2. Bạn sẽ thấy mục **Profile Downloaded** ở đầu trang (hoặc vào **General** → **VPN & Device Management**)
3. Nhấn vào profile vừa tải (ví dụ: "Development Welfan Internal Organization Root CA")
4. Nhấn **Install** ở góc trên phải
5. Nhập **Passcode** của iPhone
6. Nhấn **Install** → **Install** (xác nhận)
7. Nhấn **Done**

### 2.4 Bật Trust cho CA Certificate ⚠️ QUAN TRỌNG

> 🔴 Bước này BẮT BUỘC! Nếu không làm bước này, certificate sẽ không hoạt động.

1. Mở **Settings** (Cài đặt)
2. Vào **General** (Cài đặt chung)
3. Cuộn xuống và nhấn **About** (Giới thiệu)
4. Cuộn xuống cuối và nhấn **Certificate Trust Settings** (Cài đặt tin cậy chứng chỉ)
5. Tìm certificate vừa cài (ví dụ: "Development Welfan Internal Organization Root CA")
6. **BẬT công tắc** sang màu xanh
7. Nhấn **Continue** khi có cảnh báo

### 2.5 Xác Nhận Cài Đặt Thành Công

1. Vào **Settings** → **General** → **VPN & Device Management**
2. Trong phần **Configuration Profile**, kiểm tra certificate đã được cài
3. Vào **Settings** → **General** → **About** → **Certificate Trust Settings**
4. Kiểm tra certificate đã được **bật** (công tắc màu xanh)

> 💡 Mẹo: Lặp lại bước 2 cho mỗi môi trường bạn cần truy cập (Dev, Staging, Production).

---

## ✅ Kiểm Tra Kết Nối

Sau khi hoàn tất cài đặt, hãy kiểm tra:

### 1. Kiểm tra VPN

- Đảm bảo VPN đang kết nối (có biểu tượng VPN/chìa khóa trên thanh trạng thái)

### 2. Truy cập Website

Mở trình duyệt và truy cập các website tương ứng:

| Môi trường  | URL                               | CA Certificate cần cài  |
| ----------- | --------------------------------- | ----------------------- |
| Development | `https://dev.welfan.internal`     | ca-certificate-dev.crt  |
| Staging     | `https://staging.welfan.internal` | ca-certificate-stg.crt  |
| Production  | `https://welfan.internal`         | ca-certificate-prod.crt |

### 3. Kiểm tra Certificate

- Website phải hiển thị **ổ khóa màu xanh** 🔒
- Không có cảnh báo "Not Secure" hoặc "Certificate Error"

---

## ❓ Xử Lý Sự Cố

### Vấn đề: Website vẫn hiện "Not Secure"

| Nguyên nhân             | Giải pháp                                                               |
| ----------------------- | ----------------------------------------------------------------------- |
| Chưa cài CA Certificate | Cài đặt CA certificate theo hướng dẫn                                   |
| iOS: Chưa bật Trust     | Vào Settings → General → About → Certificate Trust Settings → Bật trust |
| Sai môi trường          | Kiểm tra đang truy cập đúng URL với CA đã cài                           |
| Cache trình duyệt       | Xóa cache và cookies, khởi động lại trình duyệt                         |

### Vấn đề: Không tải được file .crt trên iOS

- **Phải dùng Safari** hoặc để tải file certificate
- Chrome/Firefox không hỗ trợ cài đặt profile trên iOS

### Vấn đề: Không thấy "Profile Downloaded" trên iOS

1. Vào **Settings** → **General** → **VPN & Device Management**
2. Kiểm tra trong phần **Downloaded Profile**
3. Nếu không thấy, tải lại file bằng Safari

---

## 📝 Lịch Sử Cập Nhật

| Ngày       | Phiên bản | Nội dung             |
| ---------- | --------- | -------------------- |
| 2025-11-26 | 1.0       | Tạo tài liệu ban đầu |
