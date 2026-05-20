## 1. Nguyên tắc cốt lõi


| Policy                       | Nội dung                                                                    |
| ---------------------------- | --------------------------------------------------------------------------- |
| **Không đoán mò**            | Khi thiếu thông tin → hỏi lại, không tự bịa                                 |
| **Đọc trước, hành động sau** | Luôn đọc docs + tilth trước khi sinh code/đề xuất                           |
| **Stateless**                | Mỗi session độc lập — mọi context đọc từ file `.md`                         |
| **Tool-first**               | Bắt buộc dùng `tilth_*` để xác nhận thực tế, không grep/cat thủ công        |
| **Blast radius check**       | BẮT BUỘC `tilth_deps` trước khi thay đổi bất kỳ interface/method public nào |


---

## 2. Phân quyền Action theo Persona


| Action          | BA  | TechLead | PM  | Dev                  |
| --------------- | --- | -------- | --- | -------------------- |
| Tạo / sửa `.md` | ✅   | ✅        | ✅   | ✅                    |
| Sửa source code | ❌   | ❌        | ❌   | ✅ (trong scope task) |
| Commit code     | ❌   | ❌        | ❌   | ❌*                   |
| Push remote     | ❌   | ❌        | ❌   | ❌                    |


> *Dev chỉ commit khi user yêu cầu rõ ràng.                                                                                                                                   

---

## 3. AI không được phép

  ❌ Tự commit / push khi không được yêu cầu  
  ❌ Refactor ngoài scope task được giao  
  ❌ Hard-code secret / API key                                                                                                                                                 ─  
  ❌ Bypass lint/test (--no-verify, eslint-disable)  
  ❌ Sửa linter config, test config, migration files  
  ❌ Đoán mò tech stack — phải tilth_search xác nhận                                                                                                                            ─  
  ❌ BA / TechLead / PM sửa source code

---

## 4. Khi AI thiếu thông tin → BẮT BUỘC hỏi lại

  Mỗi persona có checklist câu hỏi riêng trước khi hành động.  
  **Không bao giờ tự giả định.**