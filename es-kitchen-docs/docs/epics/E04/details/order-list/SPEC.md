# SPEC: Order List (E04 Supplier Web)

> **Loại:** Single-repo (es-kitchen-web-supplier + es-kitchen-api)
> **Actor chính:** Supplier (E04)
> **Ngày:** 19/05/2026
> **Status:** Draft — có Open Questions cần confirm với khách hàng (xem Section 9)
> **Source:** `es-kitchen-requirement/orderlist_19052026/spec.md`

---

## 1. Mô tả nghiệp vụ

Supplier (E04) cần xem và quản lý danh sách đơn hàng nhận từ Company, được phân loại theo trạng thái xử lý. Màn hình hiển thị theo dạng **tab**, mỗi tab tương ứng một nhóm trạng thái, cho phép Supplier nắm bắt nhanh số đơn cần xử lý và tra cứu theo điều kiện lọc.

Trạng thái đơn hàng được **tự động cập nhật** dựa trên hành động của Supplier — không cần thao tác thủ công riêng để chuyển trạng thái.

---

## 2. Actors & Preconditions

| Actor | Vai trò | Precondition |
|---|---|---|
| Supplier (E04) | Xem và xử lý đơn hàng | Đã đăng nhập vào Supplier Web, tài khoản ở trạng thái Active |

---

## 3. Luồng nghiệp vụ — Trạng thái & Chuyển trạng thái

```
[Đơn hàng tạo bởi Company]
           ↓
┌──────────────────────────────────────────┐
│  Waiting for Delivery Date Response      │  Tab 1
│  (Chờ Supplier phản hồi ngày giao hàng) │
└──────────────────┬───────────────────────┘
                   │ Supplier nhập Scheduled Shipment Date
                   │ → hệ thống tự động cập nhật trạng thái
                   ↓
┌──────────────────────────────────────────┐
│  Waiting for Shipment                    │  Tab 2
│  (Chờ xuất hàng)                        │
└──────────────────┬───────────────────────┘
                   │ Supplier xác nhận xuất hàng
                   │ (nhập Tracking Number + Shipment Date)
                   ↓
┌──────────────────────────────────────────┐
│  Shipped                                 │  Tab 3
│  (Đã xuất hàng)                         │
└──────────────────────────────────────────┘
```

> **[TBD - OQ-01]** "Delivery Date Response Provided" trong spec gốc: là status nội bộ của trạng thái Tab 2 ("Waiting for Shipment") hay là một trạng thái trung gian riêng biệt? → **Cần confirm khách hàng.**

---

## 4. Happy Path — Xem danh sách đơn hàng

1. Supplier đăng nhập vào Supplier Web → vào màn hình **Order List**
2. Màn hình hiển thị mặc định tại **Tab 1: Waiting for Delivery Date Response** *(TBD - OQ-07)*
3. Mỗi tab hiển thị **badge số đơn mới / chưa xử lý** *(TBD - OQ-04, OQ-05)*
4. Danh sách hiển thị các cột sau:

| Cột | Mô tả |
|---|---|
| Order No. | Mã đơn hàng |
| Order Date | Ngày đặt hàng |
| Product Name | Tên sản phẩm *(TBD - OQ-06: nhiều sản phẩm hiển thị như thế nào?)* |
| Order Status | Trạng thái hiện tại |
| Desired Delivery Date | Ngày giao hàng mong muốn (từ phía Company) |
| Scheduled Shipment Date | Ngày giao hàng dự kiến (Supplier phản hồi) |
| Shipment Date | Ngày thực tế xuất hàng *(TBD - OQ-08)* |
| Quantity | Số lượng |
| Tracking Number | Mã vận đơn *(TBD - OQ-03: nhập tay hay từ Yamato/Sagawa API?)* |

5. Supplier click vào đơn để vào trang **Order Detail** *(TBD - OQ-09: có inline action hay chỉ xem Detail?)*

---

## 5. Happy Path — Chuyển Tab

- Supplier click tab → danh sách tự động lọc theo trạng thái tương ứng
- Đơn hàng chỉ xuất hiện ở **đúng 1 tab** tương ứng trạng thái hiện tại
- Sau khi Supplier thực hiện hành động cập nhật trạng thái → đơn **tự động rời tab cũ**, xuất hiện ở **tab mới**
  - Ví dụ: Nhập Scheduled Shipment Date tại Tab 1 → đơn biến mất khỏi Tab 1, xuất hiện tại Tab 2

---

## 6. Happy Path — Tìm kiếm & Lọc

1. Supplier nhập điều kiện tìm kiếm:
   - **Shipping Date**: chọn khoảng ngày (from – to) *(TBD - OQ-02: range hay single date?)*
   - **Status**: dropdown chọn trạng thái
     - Waiting for Delivery Date Response *(TBD - OQ-10: tên nhất quán với tab)*
     - Waiting for Shipment
     - Shipped
2. Nhấn **Search** → danh sách cập nhật theo điều kiện đã chọn
3. Kết quả tìm kiếm có thể **span qua nhiều tab** nếu lọc theo Status cụ thể

---

## 7. Alternative Flows & Edge Cases

| Tình huống | Xử lý |
|---|---|
| Không có đơn hàng trong tab | Hiển thị empty state: "No orders found" |
| Badge số đơn mới = 0 | Không hiển thị badge (hoặc hiển thị 0) |
| Supplier tìm kiếm không có kết quả | Hiển thị empty state: "No orders match your search criteria" |
| Tracking Number chưa có | Cột để trống (không hiển thị "-") *(TBD - OQ-03)* |
| Shipment Date chưa có | Cột để trống |
| Đơn hàng bị hủy bởi Company | Xử lý theo spec Cancel Order riêng — **Out of Scope màn hình này** |

---

## 8. Acceptance Criteria

| # | Criteria |
|---|---|
| AC-01 | Màn hình Order List có 3 tab: "Waiting for Delivery Date Response" / "Waiting for Shipment" / "Shipped" |
| AC-02 | Mỗi tab hiển thị đúng các đơn hàng tương ứng trạng thái của tab đó |
| AC-03 | Mỗi tab hiển thị badge số đơn mới/chưa xử lý |
| AC-04 | Sau khi Supplier nhập Scheduled Shipment Date → đơn tự động chuyển từ Tab 1 sang Tab 2, không cần reload thủ công |
| AC-05 | Sau khi Supplier xác nhận xuất hàng → đơn tự động chuyển từ Tab 2 sang Tab 3 |
| AC-06 | Danh sách hiển thị đầy đủ 9 cột: Order No., Order Date, Product Name, Order Status, Desired Delivery Date, Scheduled Shipment Date, Shipment Date, Quantity, Tracking Number |
| AC-07 | Tìm kiếm theo Shipping Date (khoảng ngày) hoạt động đúng |
| AC-08 | Tìm kiếm theo Status (dropdown) hoạt động đúng |
| AC-09 | Khi không có đơn hàng trong tab / không có kết quả tìm kiếm → hiển thị empty state |
| AC-10 | Chỉ Supplier đã đăng nhập mới truy cập được màn hình này |

---

## 9. Open Questions — Cần confirm với khách hàng

| # | Câu hỏi | Ảnh hưởng đến |
|---|---|---|
| OQ-01 | "Delivery Date Response Provided" là tên status nội bộ của Tab 2 hay là trạng thái trung gian riêng? Có cần tab thứ 4 không? | Số tab, status flow |
| OQ-02 | Search "Shipping date" — chọn khoảng ngày (from–to) hay chỉ 1 ngày? | Search form design |
| OQ-03 | Tracking Number: Supplier nhập tay hay lấy từ carrier API (Yamato YBM / Sagawa Smart)? | Scope tích hợp carrier |
| OQ-04 | Badge "đơn mới": reset khi Supplier **mở tab** hay khi **thực hiện hành động** trên đơn? | Logic badge counter |
| OQ-05 | Badge đếm đơn **mới trong ngày** hay đơn **chưa xử lý tích lũy**? | Logic badge counter |
| OQ-06 | Nếu 1 đơn có nhiều sản phẩm, cột "Product Name" hiển thị như thế nào? | UI column design |
| OQ-07 | Tab mặc định khi mở màn hình là tab nào? | Default state |
| OQ-08 | "Shipment Date" — ngày thực tế xuất hàng hay ngày dự kiến? (Đã có "Scheduled Shipment Date") | Field mapping |
| OQ-09 | Từ danh sách, Supplier có thể thực hiện action inline (nhập ngày, xác nhận xuất) hay phải vào trang Order Detail? | Screen scope |
| OQ-10 | Search filter dùng "Waiting for delivery date **confirmation**" — có phải tên đồng nghĩa với tab "Waiting for Delivery Date **Response**" không? | Consistent naming |

---

## 10. Out of Scope

- Hủy đơn hàng (Cancel Order)
- Xem chi tiết đơn hàng (Order Detail) — màn hình riêng
- Tạo mới đơn hàng từ phía Supplier
- Export danh sách đơn hàng ra file
- Real-time notification khi có đơn mới (push notification / WebSocket)
- Phân trang *(TBD - OQ-11: xác nhận có cần pagination không?)*
