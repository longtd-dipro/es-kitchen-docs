# BÁO CÁO ĐÁNH GIÁ CHẤT LƯỢNG DỰ ÁN ES KITCHEN PHASE 1
**Kỳ báo cáo:** Tổng kết Phase 1 & Kế hoạch Phase 2

**Quy mô dự án Phase 1:** 22.52 MM

**Tài liệu tham chiếu**: https://docs.google.com/spreadsheets/d/1hGsdIYiU7-JB36Hm67OhJZozMUdk3hxKe4UTzimh9M0/edit?gid=1374254418#gid=1374254418

---

### DỮ LIỆU ĐẦU VÀO ĐỂ TÍNH TOÁN

| Tiêu chí | Dữ liệu chi tiết | Nguồn (Link Backlog) |
| :--- | :--- | :--- |
| **Tổng công số (Billable Effort)** | 22.52 MM | |
| **Số bug Khách hàng (UAT) phát hiện** | 14 bugs | [Link Backlog UAT](https://dipro-vn.backlog.com/find/ESKITCHEN?allOver=false&createdUserId=2077018&fixedVersionId=1599006&issueTypeId=3636206&limit=20&offset=0&order=true&projectId=684621&simpleSearch=false&sort=VERSION) |
| **Số bug Tester (QC nội bộ) phát hiện** | 185 | [Link Backlog QC](https://dipro-vn.backlog.com/find/ESKITCHEN?allOver=false&issueTypeId=3636205&limit=20&limitDateRange.end=2026%2F05%2F20&offset=0&order=true&projectId=684621&simpleSearch=false&sort=VERSION) |


## PHẦN I. TỔNG QUAN CHỈ SỐ CHẤT LƯỢNG (KPI TESTING)

Dựa trên số liệu tổng hợp (14 lỗi Khách hàng phát hiện và 185 lỗi nội bộ phát hiện), dự án ghi nhận các chỉ số đo lường như sau:

| Chỉ số đo lường | Kết quả | Đánh giá so với Tiêu chuẩn                                                                                      |
| :--- | :--- |:----------------------------------------------------------------------------------------------------------------|
| **Leakage**<br>*(Tỷ lệ bug lọt ra Khách hàng)* | **0.62** bugs/MM | 🟢 **ĐẠT TỐT** (Tiêu chuẩn công ty: <= 1.0).<br>Dự án đã kiểm soát tốt các lỗi nghiêm trọng trước khi bàn giao. |
| **Defect Leakage**<br>*(Tỷ lệ lọt lưới bug của QC)* | **7.04%** | 🟡 **CẦN CẢI THIỆN** (Tiêu chuẩn cơ bản: <= 5%.                                                                 |

---

## PHẦN II. PHÂN TÍCH VÀ PHÂN LOẠI LỖI (BUG CATEGORIZATION)

Tổng số 185 bugs của Phase 1 được phân loại dựa trên 8 danh mục tiêu chuẩn của quy trình Testing:

| Phân loại Bug | Số lượng | Tỷ lệ | Hiện trạng thực tế tại dự án                                                                                                       |
| :--- | :---: | :---: |:-----------------------------------------------------------------------------------------------------------------------------------|
| **1. Functional (Lỗi Chức năng)** | 101 | **54.6%** | Lỗi Sort/Filter xuất hiện hàng loạt ở nhiều màn hình; Tính toán tự động sai logic; Không reload trang sau khi thao tác thành công. |
| **2. UI (Lỗi Giao diện)** | 42 | **22.7%** | Vỡ layout khi nội dung dài, sai kích thước font/tiêu đề, lệch các trường dữ liệu.                                                  |
| **3. Validation (Lỗi Dữ liệu đầu vào)** | 41 | **22.2%** | Lỗi tràn số (numeric field overflow); Cho phép nhập chữ vào trường số; Thiếu message báo lỗi chính xác.                            |
| **4. Performance (Lỗi Hiệu năng)** | 1 | **0.5%** | Lỗi chưa chặn Spam click dẫn đến gọi API liên tục.                                                                                 |
| **Các lỗi khác** (Security, REQ...) | 0 | **0%** | Không ghi nhận. Hoặc test chưa ra.                                                                                                 |


---

### Tổng số 14 bugs UAT của Phase 1:

| Phân loại Bug | Số lượng | Tỷ lệ (%) | Hiện trạng thực tế tại dự án                                                                          |
| :--- | :---: | :---: |:------------------------------------------------------------------------------------------------------|
| **1. Lỗi Logic & Liên kết dữ liệu** | 6 | 43% | Sai luồng nghiệp vụ khi thao tác liên màn hình (lỗi khi xóa dữ liệu, gửi email, tính toán tổng tiền). |
| **2. Lỗi Trải nghiệm người dùng (UX/UI)** | 5 | 36% | Thiếu trạng thái chờ (Loading UI) khi hệ thống xử lý tác vụ nặng; Validate đầu vào quá cứng nhắc.     |
| **3. Lỗi Đặc tả yêu cầu (REQ/Spec)** | 3 | 21% | Tài liệu Spec thiếu định nghĩa rõ ràng về giá trị mặc định (default values) và câu từ thông báo.      |
| **TỔNG CỘNG** | **14** | **100%** |                                                                                                       |
---

## PHẦN III. PHÂN TÍCH NGUYÊN NHÂN GỐC RỄ (ROOT CAUSES)

Từ các dữ liệu trên, dự án đang đối mặt với những vấn đề cốt lõi sau, chiếm tới gần **77%** rủi ro (Nằm ở nhóm lỗi Functional và Validation):

**1. Về phía Đội ngũ Phát triển (Dev):**
*   **Lỗ hổng Logic Query/Base Code:** Luồng Search/Sort/Filter bị lỗi lặp đi lặp lại. Điều này cho thấy Backend xử lý câu lệnh truy vấn dữ liệu sai và tái sử dụng cái sai đó ở nhiều nơi.
*   **Phớt lờ ràng buộc Database (Validation):** Không thiết lập các rào chắn kiểm tra định dạng và độ dài dữ liệu ở cả Frontend lẫn Backend, dẫn đến lỗi Database trả về (`numeric overflow`) khi người dùng nhập sai quy định.

**2. Về phía Đội ngũ Kiểm thử (QC):**
*   **Thiếu độ bao phủ kiểm thử (Test Coverage):** Tỷ lệ lọt lưới bug cao (7.04%) cho thấy team QC đang bị cuốn vào luồng thao tác chuẩn (Happy cases) mà bỏ qua các trường hợp ngoại lệ (Edge cases).
*   **Phân tích giá trị biên kém:** Việc để lọt lỗi tràn số ra Khách hàng chứng tỏ bộ kịch bản Test chưa bao phủ hết các tình huống nhập liệu rác, số âm, hoặc vượt quá giới hạn độ dài.

---

### 📌 HIGHLIGHTS: 14 BUG UAT (KHÁCH HÀNG PHÁT HIỆN)

**1. Tính chất lỗi tập trung vào UX và Business Logic**
* Lỗi chủ yếu xoay quanh Trải nghiệm người dùng (UX) và sự thiếu của Luồng nghiệp vụ liên kết, thay vì các lỗi chức năng cơ bản (như vỡ layout hay lỗi API).

**2. Đội dự án thiếu kịch bản Test luồng liên kết (Cross-state)**
* QC có xu hướng chỉ test thành công trên 1 màn hình đơn lẻ mà quên kiểm tra các tác động chéo đến màn hình khác.
* *Ví dụ:* Xóa Company nhưng các User thuộc Company đó không được xử lý triệt để; Reset Password thành công nhưng bỏ sót việc gửi mail cho các người phụ trách phụ.

**3. Bỏ quên Trạng thái chờ (Loading State) và xử lý UX kém**
* *Ví dụ:* Không khóa màn hình (Block UI) khi hệ thống đang xử lý tác vụ nặng như Import CSV; Validate dữ liệu quá cứng nhắc gây khó chịu (báo lỗi sai định dạng URL hợp lệ, ép nhập chữ in hoa cho Company ID).

**4. Spec (BA/BrSE) thiếu chi tiết**
* Tài liệu yêu cầu thiếu định nghĩa rõ ràng về các giá trị mặc định, dẫn đến việc Dev tự code theo cảm tính và bị khách hàng bắt lỗi.
* *Ví dụ:* Trường "Số tiền tối đa" khách hàng muốn mặc định là `null` thay vì `0`; Tiêu đề thông báo thiếu chữ "Năm" theo kỳ vọng của khách hàng.


## PHẦN IV. GIẢI PHÁP & HÀNH ĐỘNG CHO PHASE 2 (ACTION PLAN)


### Dành cho TechLead / Team Dev:
1.  **Chuẩn hóa Common Utilities (Hàm dùng chung):** BẮT BUỘC rà soát, viết lại và Review chéo các Base Controller dùng chung cho tính năng Search, Sort, Pagination và Import CSV. 
2.  **Thiết lập Base Validation Rules:** Frontend và Backend phải thống nhất cấu hình file Validation chung. Mọi trường nhập liệu tính toán tiền bạc, số lượng đều phải có Regex chặn nhập chữ và giới hạn `maxlength`.
3.  **Unit Test trước khi Merge:** Cần bổ sung bước viết Unit Test để kiểm tra tính hợp lệ của Data API (Đặc biệt với luồng Payment và Delivery) nhằm giảm thiểu rủi ro quá tải cho QC.

### Dành cho Team QA / QC:
1.  **Đo lường Quality Rate (Tỷ lệ Testcase Pass):** Nếu tỷ lệ Pass `<= 50%`, yêu cầu QC dừng test và trả code về cho Dev làm lại
2.  **Cập nhật Checklist Kiểm thử:** Bổ sung kỹ thuật **Phân tích giá trị biên (Boundary Value Analysis)** và **Đoán lỗi (Error Guessing)** vào toàn bộ kịch bản test Phase 2 để quét sạch các lỗi tràn số, âm số và bỏ trống trường bắt buộc.
3.  **Test tích hợp theo Role:** Với Phase 2 có nhiều phân quyền phức tạp (Sales, CS, Logistic), QC cần thiết kế kịch bản test tích hợp đi xuyên suốt từ khi đặt hàng đến giao hàng, thay vì chỉ test chức năng đơn lẻ. Scenario Testing !!!

### Dành cho BA/BRSE/DESIGNER:
1. Hoàn thành SPEC - FIGMA : cần có buổi TRANSFER SPEC với team đội sản xuất để thảo luận và hướng dẫn 
2. DESIGNER có trách nhiệm mô tả - hương dẫn - transfer thông tin vẽ tới toàn bộ team. Đảm bảo phần mô tả Detail Design đúng vơi cac designer thiết kế : vi dụ ô này chỉ được nhập email

# Phần V: KẾ HOẠCH CHỈ SỐ CHẤT LƯỢNG & KPI KIỂM SOÁT LỖI PHASE 2 (70 MM)

| Tiêu chí / Chỉ số | Đề xuất Tỷ lệ KPI | Bug QC nội bộ cần bắt (KPI Tối thiểu) | Bug UAT Khách hàng (Giới hạn Tối đa) |
| :--- | :---: | :---: | :---: |
| **A. Chỉ số Leakage** | <= 1.0 bugs / MM | - | **70 bugs** |
| **B. Chỉ số Defect Leakage** | <= 5% | **>= 1,330 bugs** | - |
| **1. Functional Bug** | ~40% - 45% | ~ 532 - 598 bugs | - |
| **2. Bug UI** | ~20% - 25% | ~ 266 - 332 bugs | - |
| **3. Validation Bug** | < 15% | < 199 bugs | **0 bugs** |
| **4. Performance Bug** | < 5% | < 66 bugs | - |
| **Các lỗi khác** | ~10% | ~ 133 bugs | - |


### CHỈ SỐ DEFECT RATE (MẬT ĐỘ LỖI)

**Công thức tính:** `Defect Rate = (Số bug QC bắt được + Số bug Khách hàng bắt được) / Tổng số MM`

| Giai đoạn | Tính toán Defect Rate (Tổng Bug / MM) | Dữ liệu KPI | Đánh giá chất lượng Code của Dev |
| :--- | :--- |:-----------:| :--- |
| **Thực tế Phase 1** | (185 bugs QC + 14 bugs UAT) / 22.52 MM = **8.83 bugs/MM** | **10-15%**  | **KHÁ TỐT.** Trung bình cứ 1 MM code, Dev sinh ra chưa tới 9 lỗi. |
| **Đề xuất Phase 2** | (~1,330 bugs QC + tối đa 70 bugs UAT) / 70 MM = **~ 20 bugs/MM** | **10-20%**  | Phase 2 có độ phức tạp về phân quyền lớn hơn rất nhiều.  |
