# Workflow

> Mỗi task làm theo 5 bước. Không bỏ bước nào, đặc biệt bước 5.                                                                                                               

---

## Bước 1 — Mở đúng thư mục

  AI cần đọc được toàn bộ source (4 repos) và docs cùng lúc.  
  Nếu mở sai thư mục, AI sẽ không tìm thấy context và đoán mò.                                                                                                                

---

## Bước 2 — Gọi AI bằng đúng vai

  Mỗi vai có quyền và nhiệm vụ khác nhau. Gọi sai vai → AI làm quá scope hoặc thiếu depth.                                                                                      


| Việc cần làm          | Prompt mẫu                                                        |
| --------------------- | ----------------------------------------------------------------- |
| Phân tích yêu cầu mới | `Hãy đóng vai BA. Tôi muốn thêm tính năng: <mô tả ngắn>`          |
| Thiết kế technical    | `Hãy đóng vai Tech Lead (Design). SPEC tại: <path/SPEC.md>`       |
| Tạo task files        | `Hãy đóng vai Tech Lead (Tasks). Feature: <path/feature-folder/>` |
| Lập kế hoạch sprint   | `Hãy đóng vai PM. Feature: <path/feature-folder/>`                |
| **Implement code**    | `Hãy đóng vai Dev. Implement: <path/task-x-y.md>`                 |


  **Ví dụ thực tế — BE developer nhận task:**                                                                                                                                   

  AI sẽ tự đọc: task file → DESIGN.md → source code liên quan → NestJS guidelines → rồi mới bắt đầu code.  
  Dev không cần giải thích thêm gì nếu task file đã đầy đủ.                                                                                                                   

  **Ví dụ thực tế — FE developer nhận task:**                                                                                                                                 

  **Ví dụ thực tế — khi có yêu cầu mới từ client:**                                                                                                                             

  BA sẽ hỏi thêm 10 câu trước khi viết SPEC — đừng ngắt, cứ trả lời hết.                                                                                                        

---

## Bước 3 — Xác nhận scope trước khi AI code

  Trước khi viết dòng code đầu tiên, AI luôn tóm tắt lại kế hoạch:                                                                                                              

- Đúng → `OK, tiến hành`
- Có file sai → Nói rõ: `File đó không thuộc scope task này, bỏ qua`
- Hiểu sai yêu cầu → Giải thích lại ngay, đừng để AI code xong rồi mới phát hiện

---

## Bước 4 — Review output của AI

  AI không bao giờ sai 100% nhưng cũng không bao giờ đúng 100%. Dev phải review.

  **Ví dụ review phát hiện vấn đề:**

  Dev thấy AI dùng `repository.findOne({ where: { id } })` nhưng project pattern dùng QueryBuilder để handle soft-delete. Phản hồi đúng cách:                                   

---

## Bước 5 — Memory Update Gate *(bắt buộc trước khi đóng session)*

  Đây là bước quan trọng nhất để AI session sau không bị mù thông tin.  
  Nếu bỏ qua, đồng nghiệp mở session mới sẽ nhận context lỗi thời.

  Nói với AI sau khi task hoàn thành:                                                                                                                                         

  AI tự kiểm tra và cập nhật đúng file:                                                                                                                                         


| Loại thay đổi                                       | File AI sẽ cập nhật                                   |
| --------------------------------------------------- | ----------------------------------------------------- |
| Thêm endpoint / đổi method, path, request, response | `docs/backend/es-kitchen-api/overview/api-catalog.md` |
| Thêm entity / đổi column / đổi relation             | `docs/backend/es-kitchen-api/overview/erd.md`         |
| Dùng pattern mới chưa có trong docs                 | `docs/.../overview/patterns.md` của repo tương ứng    |
| Thêm module / đổi auth flow / thêm Redis strategy   | `docs/global-overview/overview/architecture.md`       |
| Không có gì thay đổi ở trên                         | Bỏ qua, không cần cập nhật                            |


  **Ví dụ output AI sau Memory Update Gate:**                                                                                                                                 

---

## Khi AI đề xuất sai


| Tình huống                 | Cách phản hồi đúng                                                  |
| -------------------------- | ------------------------------------------------------------------- |
| Sai pattern                | `Sai. Project dùng <pattern X>, xem <path/patterns.md>. Sửa lại.`   |
| Sai endpoint               | `Endpoint này đã có trong api-catalog. Đừng tạo trùng, dùng lại.`   |
| Tạo entity trùng           | `Entity này đã có trong erd.md (tên: X). Dùng lại, không tạo mới.`  |
| Vượt scope                 | `Phần này không thuộc task-x-y. Bỏ qua, chỉ làm đúng scope.`        |
| Muốn refactor code lân cận | `Không. Chỉ làm đúng yêu cầu task. Refactor tách thành task riêng.` |


  Khi phát hiện pattern quan trọng bị AI bỏ qua nhiều lần → yêu cầu cập nhật `patterns.md` để session sau AI không lặp lại lỗi đó.                                              

---

## Docs cần biết trước khi code


| File                                                        | Đọc khi nào                                     |
| ----------------------------------------------------------- | ----------------------------------------------- |
| `docs/backend/es-kitchen-api/overview/api-catalog.md`       | Trước khi tạo endpoint mới — để không tạo trùng |
| `docs/backend/es-kitchen-api/overview/erd.md`               | Trước khi tạo entity / migration                |
| `docs/backend/es-kitchen-api/overview/patterns.md`          | Khi không chắc NestJS pattern của project       |
| `docs/frontend/es-kitchen-web-admin/overview/patterns.md`   | Trước khi viết component E03                    |
| `docs/frontend/es-kitchen-web-company/overview/patterns.md` | Trước khi viết component E02                    |
| `docs/mobile/es-kitchen-payment-app/overview/structure.md`  | Trước khi code Flutter                          |
| `docs/global-overview/overview/tech_stack.md`               | Khi cần xác nhận version / known bugs           |


---

## Flow tóm tắt 1 task

  1. cd PROJECT_ES_KITCHEN → claude

  2. "Đóng vai Dev. Implement: &lt;path/[task-x-y.md](http://task-x-y.md)&gt;"

  3. AI tóm tắt scope → Dev xác nhận                                                                                                                                            

  4. AI code → Dev review (4 checkbox)

  5. "Chạy Memory Update Gate" → AI cập nhật docs                                                                                                                               