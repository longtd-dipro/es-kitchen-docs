---
description: Xuất bảng từ file markdown bất kỳ lên Google Sheet qua Google Drive MCP — merge tất cả bảng trong file thành 1 sheet.
---

# Workflow: Export Markdown → Google Sheet

Workflow này đọc file `.md` được tag, parse tất cả bảng markdown trong file, merge thành 1 CSV và upload lên Google Drive — Drive tự động convert thành Google Sheet.

Dùng được cho **mọi file markdown có bảng**: TC, requirements, AC, checklist, v.v.

## Cách dùng

```
@tên_module/tên_file.md /export_to_drive
```

## Input cần từ User

| Input | Bắt buộc | Mô tả |
|-------|----------|-------|
| **File `.md`** | ✅ | Tag bằng `@tên_module/tên_file` |
| **Tên Sheet** | ❌ | Mặc định = `{folder-cha}_{tên-file}` (bỏ `.md`) |
| **Folder ID** | ❌ | ID thư mục Drive để lưu — nếu không có thì lưu vào root Drive |

## Các bước thực hiện

### Bước 1: Đọc file & xác định prefix tên Sheet

1. Đọc toàn bộ nội dung file được tag
2. Nếu không có file được tag → hỏi lại user, dừng
3. Nếu file không có bảng markdown nào → thông báo rõ, dừng
4. Prefix tên Sheet = `{folder-cha-trực-tiếp}_{tên-file-bỏ-md}`
   - Ví dụ: `@tc/login/tc_login_sample.md` → prefix: `login_tc_login_sample`

### Bước 2: Parse từng bảng markdown trong file

1. Tìm tất cả block bảng trong file (các dòng bắt đầu bằng `|`)
2. Với mỗi bảng:
   - Dòng 1 = header row
   - Dòng 2 = separator (`|---|---`) → bỏ qua
   - Các dòng còn lại = data rows
   - **Tên bảng** = heading markdown (`##`, `###`) ngay trên block bảng, đã slugify (thay space bằng `-`, bỏ ký tự đặc biệt); fallback = `bang-{N}`
3. **Tên Sheet** của mỗi bảng:
   - Nếu file có **1 bảng** → tên Sheet = prefix (không thêm suffix)
   - Nếu file có **nhiều bảng** → tên Sheet = `{prefix}_{tên-bảng}`
   - Ví dụ: `login_tc_login_sample_Form-dang-nhap`, `login_tc_login_sample_Validation`

### Bước 3: Convert từng bảng sang CSV

Quy tắc escape bắt buộc cho từng cell:

- Trim whitespace đầu/cuối
- `<br>` → ` | ` (giữ readable trong 1 cell)
- Cell chứa dấu phẩy, dấu ngoặc kép, hoặc newline → wrap toàn bộ trong `"..."`
- Dấu `"` trong cell → escape thành `""`

### Bước 4: Upload từng bảng lên Google Drive

Với mỗi bảng, gọi `mcp__claude_ai_Google_Drive__create_file`:

```
title:           <tên Sheet của bảng đó>
textContent:     <CSV string của bảng đó>
contentMimeType: text/csv
parentId:        <Folder ID nếu user cung cấp>
```

Google Drive tự động convert `text/csv` → Google Sheet.

> Nếu chưa kết nối Google Drive, hệ thống sẽ tự prompt xác thực — QC chỉ cần approve.

### Bước 5: Báo kết quả

```
✅ Export thành công! (N bảng)
📊 login_tc_login_sample_Form-dang-nhap — 🔗 <link>  (X rows)
📊 login_tc_login_sample_Validation     — 🔗 <link>  (Y rows)
...
```

## Quy tắc quan trọng

- ❌ KHÔNG sửa nội dung khi convert — chỉ format, không chỉnh data
- ✅ Nếu user không tag file → hỏi lại, không tự đoán
- ✅ Nếu file không có bảng markdown → thông báo và dừng
