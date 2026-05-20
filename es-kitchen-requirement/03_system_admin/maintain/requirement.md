# 2. Maintain Management

## Overview

- Maintain theo môi trường
- App nhận thông tin maintain thì show popup đang maintain
- API trả về thông tin maintain cho phía mobile

---

## Admin Maintain Management

### Features

- Chọn platform
    - iOS
    - Android

- Chọn environment
    - dev
    - stg
    - prod

- Bật / Tắt maintain
- Popup confirm trước khi thực hiện

---

## Mobile Behavior

- Mobile gọi API check maintain status
- Nếu maintain ON:
    - show popup maintain
    - block usage

---

# Common Rules

## Admin Confirmation

- Tất cả action phía admin phải có:
    - popup warning
    - popup confirm

### Examples

- Delete
- Disable
- Update version
- Enable force update
- Enable maintain
- Disable maintain