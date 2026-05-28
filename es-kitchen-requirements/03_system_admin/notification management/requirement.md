# Chức năng Quản lý Thông báo

## 1. Mục đích

Cho phép quản trị viên tạo và gửi thông báo đến các đối tượng trong hệ thống.

### Đối tượng nhận

* Công ty(Company admin web- hiển thị trên top)
* Người dùng(User app- hiển thị trong list noti + push noti)
* Nhà cung cấp(Supplier web- hiển thị trên top)
* Công ty vận chuyển (Delivery web- hiển thị trên top)
* Driver(driver web- hiển thị trên top)

### Phương thức nhận

* Thông báo trên màn hình TOP của browser
* Email (tùy chọn)

---

# 2. Chức năng chính

## 2-1. Tìm kiếm đối tượng nhận

Có thể lọc đối tượng nhận theo:
* Loại đối tượng
* Tên công ty
* Tên plan
* Trạng thái hợp đồng

* Tháng đặt hàng
* Tên sản phẩm
* Mã sản phẩm

### Điều kiện tìm kiếm sản phẩm

* Hỗ trợ chọn nhiều sản phẩm
* Điều kiện tìm kiếm là OR
Ví dụ:
* Đã đặt sản phẩm A hoặc B

### Mục đích sử dụng

Dùng khi:
* Có lỗi sản phẩm
* Hết hàng
* Cần liên hệ hoặc xin lỗi các đối tượng đã đặt sản phẩm liên quan

---

## 2-2. Tạo thông báo
Có thể nhập:
* Tiêu đề
* Nội dung
* File đính kèm
* Thời gian bắt đầu hiển thị
* Có gửi mail hay không
* Có gửi cho người phụ trách phụ hay không

---

# 3. File đính kèm
## Định dạng cho phép

* PDF
* JPG
* JPEG
* PNG

## Giới hạn
* Tối đa 5MB/file
* Tối đa 5 file
---
# 4. Lưu nháp và phát hành
## Trạng thái

| Trạng thái | Ý nghĩa      |
| ---------- | ------------ |
| DRAFT      | Nháp         |
| PUBLISHED  | Đã phát hành |
| DELETED    | Đã xóa       |

## Hành vi

| Thao tác               | Hành vi                    |
| ---------------------- | -------------------------- |
| Lưu nháp               | Không gửi                  |
| Nhấn phát hành         | Phát hành ngay             |
| Đến thời gian hiển thị | Hiển thị trên màn hình TOP |

---

# 5. Gửi email

## Điều kiện gửi

Khi bật chức năng “Gửi email”.

## Đối tượng nhận mail

| Điều kiện                     | Người nhận                   |
| ----------------------------- | ---------------------------- |
| Chỉ gửi người phụ trách chính | Người phụ trách chính        |
| Bao gồm người phụ trách phụ   | Người phụ trách chính và phụ |

---

# 6. Thông báo trong hệ thống

## Vị trí hiển thị

* Màn hình TOP browser
* Danh sách thông báo

## Điều kiện hiển thị

* Đã phát hành
* Chưa bị xóa
* Đã đến thời gian hiển thị

## Thứ tự hiển thị

* Thông báo mới nhất hiển thị trước

---

# 7. Chức năng đã đọc

## Trạng thái hiển thị

| Trạng thái | Hiển thị        |
| ---------- | --------------- |
| Chưa đọc   | Highlight + NEW |
| Đã đọc     | Màu xám         |

## Thời điểm đánh dấu đã đọc

Khi mở màn hình chi tiết thông báo.

---

# 8. Chỉnh sửa thông báo

## Có thể chỉnh sửa

| Trạng thái | Có thể chỉnh sửa |
| ---------- | ---------------- |
| DRAFT      | Có               |
| PUBLISHED  | Có               |

## Khi chỉnh sửa sau phát hành

| Hạng mục          | Hành vi                    |
| ----------------- | -------------------------- |
| Màn hình TOP      | Hiển thị nội dung mới nhất |
| Gửi lại mail      | Không                      |
| Gửi lại thông báo | Không                      |

---

# 9. Xóa thông báo

## Phương thức

* Logical delete

## Hành vi

| Trạng thái | Hành vi              |
| ---------- | -------------------- |
| DRAFT      | Không được gửi       |
| PUBLISHED  | Ẩn khỏi màn hình TOP |

---

# 10. API chính

| Method | API                       | Nội dung        |
| ------ | ------------------------- | --------------- |
| GET    | /api/notices              | Lấy danh sách   |
| GET    | /api/notices/{id}         | Lấy chi tiết    |
| POST   | /api/notices              | Tạo             |
| PUT    | /api/notices/{id}         | Cập nhật        |
| DELETE | /api/notices/{id}         | Xóa             |
| POST   | /api/notices/{id}/publish | Phát hành       |
| POST   | /api/notices/{id}/read    | Đánh dấu đã đọc |

---

# 11. Validation

| Hạng mục           | Điều kiện                        |
| ------------------ | -------------------------------- |
| Tiêu đề            | <= 255 ký tự                     |
| Nội dung           | <= 5000 ký tự                    |
| File               | <= 5MB                           |
| Extension          | Chỉ format cho phép              |
| Thời gian hiển thị | Không cho phép thời gian quá khứ |

