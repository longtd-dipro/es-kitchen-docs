# es-kitchen-api — Cấu trúc Source

> Repo: `es-kitchen-api` · Stack: NestJS / TypeScript / PostgreSQL / Redis
> Epic: Core API — phục vụ E01, E02, E03

---

## Cấu trúc thư mục

```
es-kitchen-api/
├── src/
│   ├── modules/              ← 4 NestJS modules, mỗi module = 1 domain
│   │   ├── admin/            ← E03 System Admin API
│   │   ├── admin-company/    ← E02 Company Admin API
│   │   ├── user/             ← E01 Mobile User API
│   │   └── file-upload/      ← S3 upload (shared)
│   │
│   ├── entities/             ← TypeORM entities (flat, không phân nhóm)
│   ├── auth/                 ← JWT guards, strategies, decorators dùng chung
│   │   ├── guards/           ← JwtAuthGuard, OptionalJwtAuthGuard
│   │   ├── strategies/
│   │   ├── decorators/
│   │   ├── dto/
│   │   └── interfaces/
│   │
│   ├── commons/              ← Shared utilities
│   │   ├── abstracts/
│   │   ├── constants/
│   │   ├── decorators/
│   │   ├── enums/
│   │   ├── events/
│   │   ├── framework/
│   │   ├── helpers/
│   │   └── utiliz/
│   │       ├── aws/          ← Cognito, Parameter Store
│   │       ├── mail/         ← AWS SES module
│   │       └── pdf/
│   │
│   ├── assets/
│   │   └── templates/        ← Email templates (HTML)
│   │
│   └── i18n/
│       ├── en/
│       └── ja/               ← Nhật Bản là ngôn ngữ chính
│
├── config/                   ← JWT config, database config
├── test/
└── migrations/               ← TypeORM migration files — KHÔNG tự sửa
```

---

## Module Structure (pattern nhất quán)

Mỗi module trong `src/modules/<domain>/` theo cấu trúc:

```
<module>/
├── <module>.module.ts        ← NestJS @Module()
├── guards/
│   └── <module>.guard.ts     ← JWT Strategy riêng per module
├── http/
│   ├── controllers/          ← @Controller(), @Get/@Post/@Put/@Delete
│   ├── requests/             ← DTO request (class-validator)
│   └── responses/            ← DTO response
├── services/                 ← Business logic
├── dtos/                     ← Shared DTOs trong module (admin-company)
└── listeners/                ← NestJS EventEmitter listeners
```

---

## Modules chi tiết

### `modules/admin/` — E03 System Admin

Controllers:
- `AuthController` — login, OTP, refresh token
- `AccountController` — quản lý accounts (operation + user)
- `CompanyController` — CRUD company, import CSV
- `ContractController` — quản lý hợp đồng
- `MenuController` — tạo/quản lý monthly menu
- `ProductController` — CRUD products, import CSV
- `CategoryController` — product categories
- `OrderController` — xem orders
- `SalesAnalyticsController` — báo cáo doanh thu
- `DashboardController` — dashboard metrics
- `NotificationController` — push notifications
- `FavoritesRankingController` — ranking sản phẩm yêu thích
- `AdminPaymentMethodController` — quản lý payment methods
- `FileUploadController` — upload S3

Services tương ứng + scheduler: `MenuSchedulerService` (cron jobs menu)

### `modules/admin-company/` — E02 Company Admin

Controllers:
- `AuthController` — login OTP, reset password
- `UserController` — quản lý user trong company
- `OrderController` — xem orders của company
- `CompanyController` — xem/sửa thông tin company
- `PaymentMethodController` — payment methods

Có `AdminCompanyListener` — lắng nghe events từ module khác.

### `modules/user/` — E01 Mobile App

```
user/
├── http/controllers/    ← user-facing endpoints
├── http/requests/
├── http/responses/
└── services/
    └── payment-strategies/   ← Strategy pattern cho elepay/Alipay/WeChat
```

### `modules/file-upload/` — Shared

Upload file lên AWS S3. Dùng chung bởi AdminModule.

---

## Entities (flat, trong `src/entities/`)

| Entity | Bảng | Ghi chú |
|---|---|---|
| `User` | `users` | End user (E01) |
| `PendingUser` | `pending_users` | Chờ verify |
| `CompanyAdmin` | `company_admins` | Admin E02 |
| `Company` | `companies` | |
| `CompanyContract` | `company_contracts` | |
| `ContractEquipment` | `contract_equipments` | |
| `ContractPaymentItem` | `contract_payment_items` | |
| `Menu` | `menus` | Monthly menu |
| `MenuProduct` | `menu_products` | Menu ↔ Product |
| `Product` | `products` | |
| `ProductHistory` | `product_histories` | Audit log |
| `Order` | `orders` | |
| `OrderDetail` | `order_details` | |
| `Cart` | `carts` | |
| `CartItem` | `cart_items` | |
| `CartResetEvent` | `cart_reset_events` | |
| `Notification` | `notifications` | |
| `UserNotification` | `user_notifications` | |
| `UserFavorite` | `user_favorites` | |
| `Payment` | `payments` | |
| `PaymentMethod` | `payment_methods` | |
| `ElepayCustomer` | `elepay_customers` | |
| `ElepayCustomerSource` | `elepay_customer_sources` | |
| `Otp` | `otps` | |
| `AppVersion` | `app_versions` | Mobile version check |
| `LegalDocument` | `legal_documents` | Terms/Privacy |

---

## Auth Architecture

- **3 JWT strategies** — mỗi module dùng strategy riêng:
  - `AdminStrategy` (`modules/admin/guards/admin.guard.ts`)
  - `AdminCompanyStrategy` (`modules/admin-company/guards/admin-company.guard.ts`)
  - `UserStrategy` (user module)
- `JwtAuthGuard` và `OptionalJwtAuthGuard` trong `src/auth/guards/`
- Token lưu: cookie (withCredentials) từ phía web client
- Header: `Authorization: Bearer <token>`

---

## Commons / Utilities

| Path | Nội dung |
|---|---|
| `commons/utiliz/aws/cognito.service.ts` | AWS Cognito user pool |
| `commons/utiliz/aws/user-pool.factory.ts` | |
| `commons/utiliz/mail/mail.module.ts` | AWS SES email |
| `commons/utiliz/pdf/pdf-preview.service.ts` | PDF generation |
| `commons/events/` | NestJS EventEmitter event classes |
| `i18n/ja/` | Nhật ngữ i18n — ngôn ngữ mặc định |
