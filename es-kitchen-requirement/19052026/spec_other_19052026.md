# I/ IEPIC 03 : Web-SystemAdmin

## IP access restriction (whitelist)

- Granting admin privileges
  - Account List
  - Add/Edit Account Information
  - Delete/Disable

## Access control

- List of permissions
- Add/Edit/Delete Roles
- Danh sách roles lấy trừ web-admin hiện tại

## Personalization

- Email : gửi notification qua email cho các epic khác

---

# II/ EPIC 04: Website Suplier

## Authentication

- Login
- Logout
- Forgot password
- Change password

## Email notification

- Nhận email từ admin

---

# III/ EPIC 05: Website Outsource

## Authentication

- Login
- Logout
- Forgot password
- Change password

---

# IV/ EPIC 06 : Driver app_Webapp

## Log in

- Enter your ID and password
- Forgot your password?

## Log out

---

# V/ Common

# 1. Version Management

## Overview

- Chức năng quản lý version app trên mobile và admin
- Mobile có thể connect tới API dev/stg/prod phụ thuộc vào mobile đang ở version nào
- Admin có thể setup environment mapping trên admin portal

---

## Version Management Screen

### Columns

- ACTION
- VERSION NAME
- VERSION CODE
- ENVIRONMENT
- PLATFORM
- DESCRIPTION
- FORCE UPDATE

---

## Features

- Filter by Platform
- Create New Version
- Edit Version
- Delete Version
- Enable/Disable Force Update

---

## New Version Form

### Fields

- Platform
  - iOS
  - Android

- Version Name

- Version Code

- Environment
  - development
  - staging
  - production
  - pre-production

- Description

- Download URL

- Force Update

---

## Actions

- Create version
- Update version
- Delete version
- Filter by platform

---

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

# VI/ Common Rules

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