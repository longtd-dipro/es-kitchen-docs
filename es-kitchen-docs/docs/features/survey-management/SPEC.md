# SPEC: Survey Management (Questionnaire Collection and Analysis)

> **Loại:** Cross-repo
> **Repos liên quan:** `es-kitchen-api` · `es-kitchen-web-admin` (E03) · `es-kitchen-payment-app` (E01)
> **Actor chính:** System Admin (E03) — tạo và phân phối; End User (E01) — nhận và trả lời
> **Ngày:** 19/05/2026
> **Status:** Draft — có Open Questions cần confirm với khách hàng (xem Section 9)
> **Source:** `es-kitchen-requirement/survey.md`

---

## 1. Mô tả nghiệp vụ

System Admin (E03) có thể tạo và phân phối khảo sát (survey) đến khách hàng — bao gồm người dùng thuộc doanh nghiệp (Corporations) hoặc người dùng cá nhân (Individuals). Survey được gửi qua ứng dụng E01 Payment App (Flutter), người dùng trả lời trực tiếp trên app.


Admin có thể xem lịch sử phân phối và phân tích kết quả phản hồi thông qua biểu đồ và số liệu tổng hợp tự động.

**3 loại survey (nội dung câu hỏi cố định theo từng loại — xem Section 6):**
1. Service Satisfaction Survey
2. Menu Improvement Request Survey
3. Optional Services You Would Like to See in the Future

---

## 2. Actors & Preconditions

| Actor | Vai trò | Precondition |
|---|---|---|
| System Admin (E03) | Tạo, lên lịch phân phối, xem lịch sử, xem kết quả phân tích | Đã đăng nhập Admin Web, có quyền Survey Management |
| End User (E01) | Nhận thông báo survey, trả lời và submit | Đã đăng nhập E01 Payment App, thuộc đối tượng được phân phối |

---

## 3. Luồng nghiệp vụ tổng quan

```
Admin (E03)
  │
  ├── Chọn loại survey
  ├── Đặt thời gian phân phối (Immediate / Scheduled)
  ├── Chọn đối tượng (Corporations / Individuals)
  ├── [Corporations] Chọn danh sách công ty
  └── Xác nhận phân phối
           │
           ▼ (tại thời điểm phân phối)
    Hệ thống gửi Push Notification đến E01 app
           │
           ▼
    End User (E01)
      ├── Nhận thông báo survey
      ├── Mở và trả lời survey
      └── Submit câu trả lời
           │
           ▼
    Admin (E03)
      └── Xem Distribution History → Xem Response Analysis (tổng hợp + biểu đồ)
```

---

## 4. Happy Path — Admin tạo Survey Distribution

1. Admin vào màn hình **Survey Management** → click **"Create Distribution"**
2. Chọn **Survey Type** từ dropdown (3 loại cố định)
3. Chọn **Distribution Time**:
   - **Send immediately**: gửi ngay sau khi confirm
   - **Schedule**: chọn ngày + giờ cụ thể
4. Chọn **Target Audience**:
   - **Corporations**: hiển thị thêm bước chọn danh sách công ty
   - **Individuals**: áp dụng cho tất cả end user không thuộc công ty *(TBD - OQ-11)*
5. [Nếu Corporations] Admin chọn **1 hoặc nhiều công ty** từ danh sách multi-select
6. Admin click **Confirm** → hệ thống tạo distribution record với status:
   - `Scheduled` nếu chọn thời gian tương lai
   - `Sent` nếu gửi ngay
7. Hệ thống gửi **Push Notification** đến E01 app của users thuộc đối tượng đã chọn *(TBD - OQ-8)*

---

## 5. Happy Path — End User trả lời Survey (E01)

1. User nhận **Push Notification** trên E01 app: "You have a new survey"
2. User tap notification → mở màn hình **Survey Form** trong app
3. App hiển thị tiêu đề survey và từng câu hỏi theo thứ tự
4. User trả lời các câu hỏi (xem format tại Section 6)
5. User nhấn **Submit** → hệ thống lưu response, hiển thị màn hình **Thank You**
6. Survey không thể submit lần 2 (mỗi user chỉ trả lời 1 lần / 1 distribution) *(TBD - OQ-7)*

---

## 6. Nội dung Survey — Đề xuất cho khách hàng *(TBD - OQ-4)*

> **Lưu ý:** Nội dung câu hỏi bên dưới là **đề xuất từ BA**, chưa được khách hàng confirm.
> Format câu trả lời: `rating` (1–5 ⭐) · `nps` (0–10) · `single_choice` · `multi_choice` · `free_text`

### Survey Type 1: Service Satisfaction Survey

| # | Câu hỏi | Format |
|---|---|---|
| Q1 | Overall, how satisfied are you with our service? | Rating 1–5 ⭐ |
| Q2 | How would you rate the quality of the meals? | Rating 1–5 ⭐ |
| Q3 | How would you rate the delivery timeliness? | Rating 1–5 ⭐ |
| Q4 | How likely are you to recommend our service to others? | NPS 0–10 |
| Q5 | Any comments or suggestions for improvement? | Free text (optional) |

### Survey Type 2: Menu Improvement Request Survey

| # | Câu hỏi | Format |
|---|---|---|
| Q1 | Which meal categories would you like to see more variety in? | Multi-choice: Main dish / Side dish / Dessert / Drinks / Soup |
| Q2 | What types of cuisine would you like added to the menu? | Multi-choice: Japanese / Western / Chinese / Korean / Vegetarian / Other |
| Q3 | Do you have any dietary preferences or restrictions? | Multi-choice: Vegetarian / Halal / Gluten-free / Low-calorie / No preference |
| Q4 | How satisfied are you with current portion sizes? | Single-choice: Too small / Just right / Too large |
| Q5 | Please describe specific menu items you would like to request. | Free text (optional) |

### Survey Type 3: Optional Services You Would Like to See in the Future

| # | Câu hỏi | Format |
|---|---|---|
| Q1 | Which optional services would you be interested in? | Multi-choice: Customizable meal plans / Allergy-aware menus / Late-night delivery / Weekend delivery / Catering for events / Nutritional info display |
| Q2 | How important is each feature to you? (per item from Q1) | Rating 1–5 per item |
| Q3 | How much extra would you be willing to pay for premium services? | Single-choice: Not willing / Up to ¥500/month / ¥500–¥1,000 / ¥1,000+ |
| Q4 | Any other services you would like to see in the future? | Free text (optional) |

---

## 7. Happy Path — Admin xem Distribution History

1. Admin vào màn hình **Survey Management** → tab **Distribution History**
2. Danh sách hiển thị các distribution đã tạo, gồm các cột: *(TBD - OQ-5)*

| Cột | Mô tả |
|---|---|
| Survey Type | Loại survey |
| Distribution Time | Ngày giờ phân phối |
| Target | Corporations / Individuals |
| Companies | Số công ty được chọn (nếu Corporations) |
| Responses | X / Y (số đã trả lời / tổng số đã gửi) |
| Status | Scheduled / Sent |

3. Admin click vào một distribution → xem **Response Analysis**

---

## 8. Happy Path — Admin xem Response Analysis

1. Admin click vào distribution trong History → màn hình **Response Analysis**
2. Header hiển thị: Survey Type, Distribution Time, Response Rate (X/Y — X%)
3. Với mỗi câu hỏi, hệ thống **tự động tổng hợp và hiển thị**:
   - **Numerical summary**: số lượng và tỷ lệ % từng lựa chọn
   - **Chart**: biểu đồ trực quan *(TBD - OQ-6)*

| Answer Format | Chart gợi ý |
|---|---|
| `rating` (1–5) | Bar chart hoặc Average score display |
| `nps` (0–10) | NPS gauge / Bar chart phân nhóm Detractor/Passive/Promoter |
| `single_choice` | Pie chart hoặc Bar chart |
| `multi_choice` | Bar chart (count per option) |
| `free_text` | Hiển thị danh sách text responses |
| `rating_per_item` | Grouped bar chart |

4. Admin có thể xem kết quả tổng hợp tất cả hoặc lọc theo công ty *(TBD - OQ-9)*

---

## 9. Alternative Flows & Edge Cases

| Tình huống | Xử lý |
|---|---|
| Distribution scheduled → Admin hủy trước giờ gửi | *(TBD - OQ-12: có cho phép cancel scheduled distribution không?)* |
| User không trả lời survey trong thời hạn | *(TBD - OQ-10: có deadline không? Hệ thống xử lý thế nào?)* |
| User đã trả lời → không thể submit lần 2 | App ẩn survey hoặc hiển thị "Already submitted" |
| 0 responses | Response Analysis hiển thị empty state: "No responses yet" |
| Không có công ty nào được chọn (Corporations) | Không cho phép confirm — validate bắt buộc |
| Distribution History không có record | Hiển thị empty state |

---

## 10. Acceptance Criteria

| # | Criteria |
|---|---|
| AC-01 | Admin có thể tạo distribution với 3 loại survey cố định |
| AC-02 | Admin có thể chọn "Send immediately" hoặc đặt lịch theo ngày/giờ cụ thể |
| AC-03 | Admin có thể chọn đối tượng: Corporations hoặc Individuals |
| AC-04 | Khi chọn Corporations, Admin có thể multi-select nhiều công ty |
| AC-05 | Hệ thống gửi push notification đến E01 app của users thuộc đối tượng đã chọn đúng thời điểm |
| AC-06 | End User nhận và có thể trả lời survey trực tiếp trong E01 Payment App |
| AC-07 | Mỗi user chỉ submit được 1 lần cho mỗi distribution |
| AC-08 | Màn hình Distribution History hiển thị danh sách đầy đủ với Response Rate |
| AC-09 | Màn hình Response Analysis tự động tổng hợp câu trả lời và hiển thị biểu đồ |
| AC-10 | Numerical summary hiển thị số lượng và % từng lựa chọn |
| AC-11 | Chỉ Admin có quyền Survey Management mới tạo và xem được survey |

---

## 11. Open Questions — Cần confirm với khách hàng

| # | Câu hỏi | Tầm quan trọng | Ảnh hưởng đến |
|---|---|---|---|
| OQ-4 | Nội dung câu hỏi của 3 survey types (xem đề xuất Section 6) — khách hàng có confirm không? | 🔴 Critical | Toàn bộ survey form, aggregation logic |
| OQ-5 | Distribution History hiển thị những cột nào? (Gợi ý đã có ở Section 7) | 🟡 High | History screen design |
| OQ-6 | Loại biểu đồ cụ thể cho từng format câu trả lời? (Gợi ý đã có ở Section 8) | 🟡 High | FE chart component effort |
| OQ-7 | Một công ty / user có thể nhận cùng loại survey nhiều lần không? Có giới hạn tần suất không? | 🟡 High | Distribution validation logic |
| OQ-8 | Survey gửi qua kênh nào: Push Notification, Email, hay cả hai? | 🟡 High | API integration scope |
| OQ-9 | Admin có thể xem response theo từng công ty riêng lẻ hay chỉ xem tổng hợp? | 🟠 Medium | Analysis screen scope |
| OQ-10 | Survey có deadline response không? Sau deadline xử lý thế nào? | 🟠 Medium | Distribution model, reminder logic |
| OQ-11 | "Individuals" target: áp dụng cho tất cả end user không thuộc công ty, hay Admin vẫn phải chọn danh sách cụ thể? | 🟠 Medium | Distribution create flow |
| OQ-12 | Admin có thể cancel một distribution đang Scheduled không? | 🟠 Medium | Distribution management scope |

---

## 12. Out of Scope

- Tạo câu hỏi survey tùy chỉnh (custom questions) — nội dung cố định theo từng loại
- Export kết quả survey ra file (CSV / Excel)
- Gửi reminder tự động đến user chưa trả lời
- Survey analytics cross-distribution (so sánh nhiều lần phân phối)
- Company Admin (E02) tạo hoặc xem survey
