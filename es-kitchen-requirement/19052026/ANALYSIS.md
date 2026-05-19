# BA Analysis — Requirements 19/05/2026

> Nguồn: `spec_other_19052026.md` + mockup images
> Người phân tích: BA (Claude)
> Ngày: 19/05/2026

---

## 1. Tổng quan — Reuse vs. New

| Epic | Feature | Trạng thái | DESIGN.md |
|---|---|---|---|
| E03 | IP Whitelist | ✅ Done | `epics/E03/.../es-kitchen-api/DESIGN.md` |
| E03 | Admin Account Management | ✅ Done | `epics/E03/.../es-kitchen-web-admin/DESIGN.md` |
| E03 | Role & Permission System | ✅ Done | `epics/E03/.../es-kitchen-web-admin/DESIGN.md` |
| **E03** | **Notification / Announcement** | 🆕 Cần SPEC | — |
| E04 | Supplier Authentication | ✅ Done | `epics/E04/.../DESIGN.md` |
| **E04** | **Email notification (receive)** | 🆕 Phụ thuộc E03 Notification | — |
| E05 | Outsource Authentication | ✅ Done | `epics/E05/.../DESIGN.md` |
| E06 | Driver Authentication | ✅ Done | `epics/E06/.../DESIGN.md` |
| Common | Version Management | ✅ Done | `features/version-management/DESIGN.md` |
| Common | Maintain Management | ✅ Done | `features/maintain-management/DESIGN.md` |

**Kết luận:** 8/10 features đã có DESIGN. Chỉ cần tạo SPEC mới cho **E03 Notification**.

---

## 2. Phase 1 — Components tái sử dụng

### 2.1 Backend (es-kitchen-api)

| Component | Tái sử dụng cho |
|---|---|
| `AdminGuard` + `AdminPermissionGuard` | Guard tất cả endpoint Notification |
| `admin_email_notification_settings` entity | Mở rộng events, không tạo bảng mới |
| `AdminEmailNotificationSetting` service | Gọi lại để check event settings khi send |
| `admins` table + `admin_roles` | Lọc recipients theo role |
| Auth flow (login/JWT/session) | E04, E05, E06 — đã design xong |

### 2.2 Frontend (es-kitchen-web-admin)

| Component | Tái sử dụng cho |
|---|---|
| `TwoStepConfirmModal` | Confirm gửi bulk email, xóa notice |
| Table pattern (`AdminTable`) | Danh sách announcements — cùng cấu trúc columns |
| Modal pattern (`CreateAdminModal`) | Create Notice modal |
| `useQuery` / `useMutation` pattern | API calls cho Notification |
| Ant Design `Upload` (mới) | Attach file trong Create Notice |

### 2.3 Frontend (es-kitchen-web-supplier — E04)

| Component | Tái sử dụng cho |
|---|---|
| Auth pages (Login, Forgot Password) | ✅ Design xong, implement trực tiếp |
| Email notification inbox | 🆕 Nhận email từ admin — UI đơn giản |

---

## 3. Feature mới cần SPEC — E03 Notification

### 3.1 Actors & Flow

```
Admin (E03) → Tạo Announcement → Gửi email → Recipient (Company / User / Supplier / Driver)
```

### 3.2 Màn hình & Functions

#### Screen 1: List of Announcements

| # | Function | Mô tả |
|---|---|---|
| F1 | Filter | Recipients (5 loại), Company name, Plan name, Eligible product filter |
| F2 | View list | Hiển thị danh sách thông báo đã gửi/nháp |

**Conditional Search recipients:**
- Corporations (Company)
- Users (End User)
- Suppliers
- Contracted delivery companies
- Drivers

#### Screen 2: Create a Notice

| # | Function | Mô tả |
|---|---|---|
| F3 | Nhập tiêu đề & nội dung | text fields |
| F4 | Đính kèm file | Upload attachment |
| F5 | Gửi thông báo | Trigger in-system + email (nếu email category enabled) |

#### Screen 3: Email Sending Category (Settings)

| # | Function | Mô tả |
|---|---|---|
| F6 | Bật/Tắt email category | Toggle per category — khi ON → gửi bulk email kèm theo notification |
| F7 | Multi-contact rule | Nếu company có nhiều contacts → gửi tất cả |

---

## 4. Open Questions cần confirm trước SPEC

| # | Câu hỏi | Người trả lời |
|---|---|---|
| OQ-1 | "Filter orders for eligible products in monthly orders" — điều kiện lọc cụ thể là gì? | PM / Client |
| OQ-2 | Notice có trạng thái Draft / Sent? Hay chỉ gửi ngay? | Client |
| OQ-3 | Attachment file: giới hạn dung lượng, loại file? | Client |
| OQ-4 | Email Sending Category là gì? Danh sách categories là gì (tên cụ thể)? | Client |
| OQ-5 | E04 — email notification receive: chỉ hiển thị email inbox trong portal hay còn in-app notification? | Client |
| OQ-6 | E05 Outsource / E06 Driver — có FE repo riêng hay dùng chung repo? | PM / Dev Lead |

---

## 5. Scope không thay đổi (xác nhận lại)

- **E03 IP Whitelist**: đã design đầy đủ — không cần thêm gì
- **E03 Admin Account + Role**: đã design đầy đủ — không cần thêm gì
- **E04/E05/E06 Auth**: đã design đầy đủ — chuyển thẳng sang implement
- **Version Management** + **Maintain Management**: đã design đầy đủ

---

## 6. Bước tiếp theo (đề xuất)

| Bước | Action | Output |
|---|---|---|
| 1 | Confirm OQ-1 → OQ-6 với client | Answers |
| 2 | `/create-spec e03-notification` | `SPEC.md` cho Notification |
| 3 | `/create-design SPEC.md` | `DESIGN.md` cho api + web-admin |
| 4 | Implement E04/E05/E06 Auth | Code (DESIGN đã sẵn) |
| 5 | Implement E03 Auth features (Admin Account, Role, IP) | Code (DESIGN đã sẵn) |