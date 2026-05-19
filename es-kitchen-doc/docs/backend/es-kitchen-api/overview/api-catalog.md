# es-kitchen-api — API Catalog

> Tổng hợp toàn bộ REST endpoints từ source code thực tế.  
> Cập nhật khi thêm/đổi endpoint — đây là nguồn sự thật duy nhất cho FE/Mobile.

---

## Kiến trúc 3 module

| Module | Prefix | Guard | Client |
|---|---|---|---|
| `admin` | `/admin/...` | `AdminGuard` (JWT admin) | `es-kitchen-web-admin` (E03) |
| `admin-company` | `/admin-company/...` | `AdminCompanyGuard` (JWT company admin) | `es-kitchen-web-company` (E02) |
| `user` | `user/...` hoặc `/auth/user/...` | `JwtAuthGuard` (JWT user) | `es-kitchen-payment-app` (E01) |

> ⚠️ `admin` và `admin-company` dùng prefix khác nhau hoàn toàn — không copy endpoint giữa hai module.

---

## Module: Admin (E03 — System Admin)

### Auth `/admin/auth`

| Method | Path | Mô tả |
|---|---|---|
| POST | `/admin/auth` | Login — trả về access/refresh token |
| POST | `/admin/auth/forgot-password/request` | Gửi OTP reset password |
| POST | `/admin/auth/forgot-password/verify-otp` | Xác thực OTP |
| POST | `/admin/auth/forgot-password/reset-password` | Đặt lại mật khẩu |
| POST | `/admin/auth/logout` | Logout — xóa refresh token |

### Companies `/admin/companies`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/companies` | Danh sách companies (phân trang, filter) |
| POST | `/admin/companies` | Tạo company mới |
| POST | `/admin/companies/bulk-issue-accounts` | Phát hành tài khoản hàng loạt |
| POST | `/admin/companies/export-qr` | Export QR code cho company |
| GET | `/admin/companies/import` | (CSV import flow — xem bên dưới) |
| POST | `/admin/companies/import` | Import company từ CSV |
| GET | `/admin/companies/:id/basic-info` | Thông tin cơ bản company |
| PATCH | `/admin/companies/:id/basic-info` | Cập nhật thông tin cơ bản |
| GET | `/admin/companies/:id/contracts` | Danh sách contract của company |
| GET | `/admin/companies/:id/contacts` | Thông tin liên hệ company |
| PATCH | `/admin/companies/:id/contacts` | Cập nhật thông tin liên hệ |
| GET | `/admin/companies/:id/history` | Lịch sử thay đổi company |
| DELETE | `/admin/companies/:id` | Xóa company (soft delete) |

### Contracts `/admin/contracts`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/contracts` | Danh sách contracts (phân trang, filter) |
| GET | `/admin/contracts/:id` | Chi tiết contract |
| PATCH | `/admin/contracts/:id` | Cập nhật contract |
| GET | `/admin/contracts/:id/payment` | Thông tin thanh toán contract |
| PATCH | `/admin/contracts/:id/payment` | Cập nhật thanh toán contract |
| GET | `/admin/contracts/:id/equipments` | Thiết bị trong contract |
| PATCH | `/admin/contracts/:id/equipments` | Cập nhật thiết bị |
| GET | `/admin/contracts/:id/history` | Lịch sử thay đổi contract |

### Accounts `/admin/accounts`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/accounts/me` | Profile admin đang đăng nhập |
| GET | `/admin/accounts` | Danh sách operation accounts |
| POST | `/admin/accounts` | Tạo operation account mới |
| GET | `/admin/accounts/:id` | Chi tiết account |
| PATCH | `/admin/accounts/:id` | Cập nhật account |
| DELETE | `/admin/accounts/:id` | Xóa account (soft delete) |
| GET | `/admin/accounts/:userId/purchase-history` | Lịch sử mua hàng của user |

### Products `/admin/products`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/products` | Danh sách sản phẩm (phân trang, filter) |
| GET | `/admin/products/suppliers` | Danh sách suppliers |
| GET | `/admin/products/:id` | Chi tiết sản phẩm |
| PATCH | `/admin/products/:id` | Cập nhật sản phẩm |
| DELETE | `/admin/products/:id` | Xóa sản phẩm (soft delete) |
| GET | `/admin/products/:id/history` | Lịch sử thay đổi sản phẩm |
| POST | `/admin/products/import` | Import sản phẩm từ CSV |

### Orders `/admin/orders`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/orders` | Danh sách đơn hàng (phân trang, filter) |
| GET | `/admin/orders/:orderNumber` | Chi tiết đơn hàng |
| POST | `/admin/orders/:id/refund` | Hoàn tiền đơn hàng |

### Sales Analytics `/admin/sales-analytics`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/sales-analytics/company` | Phân tích doanh thu theo company |
| GET | `/admin/sales-analytics/company/export-csv` | Export CSV phân tích theo company |
| GET | `/admin/sales-analytics/product` | Phân tích doanh thu theo sản phẩm |
| GET | `/admin/sales-analytics/product/export-csv` | Export CSV phân tích theo sản phẩm |

### Dashboard `/admin/dashboard`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/dashboard/monthly-sales` | Doanh thu theo tháng |
| GET | `/admin/dashboard/favorites-vs-sales` | So sánh yêu thích vs doanh thu |
| GET | `/admin/dashboard/sales-by-payment-method` | Doanh thu theo phương thức thanh toán |

### Notifications `/admin/notifications`

| Method | Path | Mô tả |
|---|---|---|
| POST | `/admin/notifications/test-push` | Gửi push notification test |
| POST | `/admin/notifications/publish-menu` | Publish menu và gửi notification |

### Categories `/admin/categories`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/categories` | Danh sách categories |
| POST | `/admin/categories` | Tạo category |
| PATCH | `/admin/categories/:id` | Cập nhật category |
| DELETE | `/admin/categories/:id` | Xóa category |

### Payment Methods `/admin/payment-methods`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/payment-methods` | Danh sách phương thức thanh toán |

### Menus `/admin/menus`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/menus` | Danh sách menus (filter theo year_month, type, status) |
| GET | `/admin/menus/:id` | Chi tiết menu |
| PATCH | `/admin/menus/:id` | Cập nhật menu |
| DELETE | `/admin/menus/:id` | Xóa menu (soft delete) |
| POST | `/admin/menus/import/preview` | Preview CSV import (multipart/form-data, max 10MB) |
| POST | `/admin/menus/import/confirm` | Xác nhận import menu |

### Favorites Ranking `/admin/favorites-ranking`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin/favorites-ranking/latest-months` | Lấy danh sách tháng gần nhất có dữ liệu favorite |
| GET | `/admin/favorites-ranking` | Ranking sản phẩm theo lượt yêu thích (phân trang) |
| GET | `/admin/favorites-ranking/export` | Export CSV ranking (toàn bộ, không phân trang) |

---

## Module: Admin-Company (E02 — Company Admin)

### Auth `/admin-company/auth`

| Method | Path | Mô tả |
|---|---|---|
| POST | `/admin-company/auth/login` | Login company admin |
| POST | `/admin-company/auth/forgot-password/request` | Gửi OTP reset password |
| POST | `/admin-company/auth/forgot-password/verify-otp` | Xác thực OTP |
| POST | `/admin-company/auth/forgot-password/confirm` | Đặt lại mật khẩu |

### Users `/admin-company/users`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin-company/users/linked` | Danh sách users đã link với company |
| GET | `/admin-company/users/linked/:userCode` | Chi tiết user theo userCode |
| DELETE | `/admin-company/users/linked/:userCode` | Unlink user khỏi company |
| POST | `/admin-company/users/linked/:userCode/restrict` | Hạn chế user |
| POST | `/admin-company/users/linked/:userCode/unrestrict` | Gỡ hạn chế user |
| GET | `/admin-company/users/linked/:userCode/purchase-history` | Lịch sử mua hàng của user |

### Orders `/admin-company/orders`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin-company/orders` | Danh sách đơn hàng của company |
| GET | `/admin-company/orders/export` | Export CSV đơn hàng |
| GET | `/admin-company/orders/summary` | Tổng hợp doanh thu |
| GET | `/admin-company/orders/:orderNumber` | Chi tiết đơn hàng |

### Company `/admin-company/company`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin-company/company/me` | Thông tin company đang quản lý |

### Payment Methods `/admin-company/payment-methods`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/admin-company/payment-methods` | Danh sách phương thức thanh toán |

---

## Module: User (E01 — Mobile App)

### Auth `/auth/user`

| Method | Path | Mô tả |
|---|---|---|
| POST | `/auth/user/login` | Login |
| POST | `/auth/user/logout` | Logout |
| POST | `/auth/user/register` | Đăng ký tài khoản |
| POST | `/auth/user/verify-otp` | Xác thực OTP đăng ký |
| POST | `/auth/user/resend-otp` | Gửi lại OTP |
| POST | `/auth/user/forgot-password` | Yêu cầu reset password |
| POST | `/auth/user/forgot-password/verify-otp` | Xác thực OTP reset password |
| POST | `/auth/user/reset-password` | Đặt lại mật khẩu |

### User Profile `/user`

| Method | Path | Guard | Mô tả |
|---|---|---|---|
| GET | `/user/me` | JwtAuthGuard | Profile user hiện tại |
| PUT | `/user/me` | JwtAuthGuard | Cập nhật profile |
| DELETE | `/user/me` | JwtAuthGuard | Xóa tài khoản (soft delete) |

### Orders `/user/orders`

| Method | Path | Mô tả |
|---|---|---|
| POST | `/user/orders/checkout` | Đặt hàng — tạo order + payment |
| PUT | `/user/orders/:orderId/cancel` | Hủy đơn hàng |
| POST | `/user/orders/:orderId/retry-payment` | Thử thanh toán lại |
| GET | `/user/orders/validate-company` | Kiểm tra company hợp lệ |
| GET | `/user/orders/check-limit` | Kiểm tra giới hạn đặt hàng tháng |
| GET | `/user/orders/history` | Lịch sử đơn hàng |
| GET | `/user/orders` | Danh sách đơn hàng đang chờ |
| GET | `/user/orders/:id` | Chi tiết đơn hàng |

### Cart `/user/cart`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/user/cart` | Lấy giỏ hàng |
| DELETE | `/user/cart` | Xóa toàn bộ giỏ hàng |
| POST | `/user/cart/items` | Thêm sản phẩm vào giỏ |
| PUT | `/user/cart/items/:id` | Cập nhật số lượng sản phẩm |
| DELETE | `/user/cart/items/:id` | Xóa sản phẩm khỏi giỏ |
| GET | `/user/cart/reset-status` | Kiểm tra trạng thái reset giỏ hàng |
| POST | `/user/cart/reset-ack` | Xác nhận đã thấy thông báo reset |

### Menu `/user/menu`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/user/menu/products` | Danh sách sản phẩm trong menu hiện tại |
| GET | `/user/menu/products/:id` | Chi tiết sản phẩm theo id |
| GET | `/user/menu/products/jan/:janCode` | Tìm sản phẩm theo JAN code |

### Favorites `/user/favorites`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/user/favorites` | Danh sách sản phẩm yêu thích |
| POST | `/user/favorites/:productId` | Toggle yêu thích (thêm nếu chưa có, xóa nếu đã có) |

### Notifications `/user/notifications`

| Method | Path | Mô tả |
|---|---|---|
| POST | `/user/notifications/device-token` | Đăng ký FCM device token |
| GET | `/user/notifications` | Danh sách notifications (phân trang) |
| GET | `/user/notifications/unread-count` | Số lượng notification chưa đọc |
| GET | `/user/notifications/:id` | Chi tiết notification |
| PUT | `/user/notifications/:id/read` | Đánh dấu đã đọc |
| PUT | `/user/notifications/read-all` | Đánh dấu tất cả đã đọc |

### Refunds `/user/refunds`

| Method | Path | Mô tả |
|---|---|---|
| POST | `/user/refunds` | Yêu cầu hoàn tiền |

### Payment Methods `/user/payment-methods`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/user/payment-methods` | Danh sách phương thức thanh toán (filter CASH theo company) |
| GET | `/user/payment-methods/my-default` | Phương thức thanh toán mặc định của user |
| PATCH | `/user/payment-methods/my-default` | Đặt phương thức thanh toán mặc định |
| GET | `/user/payment-methods/credit-cards` | Danh sách thẻ tín dụng đã lưu (Elepay) |
| POST | `/user/payment-methods/credit-card` | Thêm thẻ tín dụng (tạo Elepay source) |
| PUT | `/user/payment-methods/credit-cards/:sourceId` | Đặt thẻ tín dụng mặc định |
| DELETE | `/user/payment-methods/credit-cards/:sourceId` | Xóa thẻ tín dụng |

### Allergens `/user/allergens`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/user/allergens` | Danh sách allergens (sắp xếp theo sort ASC) |

### Categories `/user/categories`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/user/categories` | Danh sách categories |

### User Preferences `/user/preferences`

| Method | Path | Mô tả |
|---|---|---|
| GET | `/user/preferences/cart-popup` | Kiểm tra có hiện popup xác nhận checkout không |
| POST | `/user/preferences/cart-popup/hide` | Ẩn popup trong 1 tháng |

### Legal `/user/legal` — Public (không cần auth)

| Method | Path | Mô tả |
|---|---|---|
| GET | `/user/legal/terms` | Điều khoản dịch vụ hiện hành |
| GET | `/user/legal/privacy` | Chính sách bảo mật hiện hành |

### App Version `/app/version` — Public

| Method | Path | Mô tả |
|---|---|---|
| GET | `/app/version` | Kiểm tra phiên bản app (force/recommended update) |

### Contact `/contact` — Optional auth

| Method | Path | Guard | Mô tả |
|---|---|---|---|
| POST | `/contact` | OptionalJwtAuthGuard | Gửi yêu cầu liên hệ (auth tùy chọn) |

### Elepay Webhooks `/user/elepay` — Internal

| Method | Path | Mô tả |
|---|---|---|
| POST | `/user/elepay/webhook` | Xử lý charge.* và refund.* events từ Elepay |
| POST | `/user/elepay/verification-credit-card` | Xử lý source.activated / source.inactivated |
| GET | `/user/elepay/verify-easy-code-payment` | Redirect handler sau khi thanh toán QR |
| GET | `/user/elepay/public-key` | Lấy Elepay public key |

### Health Check

| Method | Path | Mô tả |
|---|---|---|
| GET | `/health` | Health check endpoint |

---

## Quy tắc đặt endpoint

- Admin endpoints: `GET /admin/<resource>s` → list, `GET /admin/<resource>s/:id` → detail
- Không dùng `/admin/...` cho Company Admin — phải dùng `/admin-company/...`
- User endpoints: prefix `user/` cho tất cả authenticated user routes
- Auth routes nằm ngoài prefix module: `/auth/user/...`
- Webhook routes không expose trong Swagger (`@ApiExcludeEndpoint()`)

---

> Cập nhật file này mỗi khi thêm/đổi/xóa controller method.
