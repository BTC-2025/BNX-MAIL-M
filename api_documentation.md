# BNX Mail API Documentation (Complete Reference)

This document outlines all the API endpoints, payloads, and general flows used in the BNX Mail application based on the frontend `api.js`.

> [!NOTE]
> All endpoints expect JSON payloads (`application/json`) unless they involve file uploads (which require `multipart/form-data`). Most endpoints (except authentication) require a valid JWT Bearer token in the `Authorization` header.

---

## 1. Authentication & Registration APIs

### `POST /api/auth/register`

**Body:** `{ "mode": "PERSONAL|BUSINESS|CHILD", "username": "string", "password": "...", "firstName": "...", "lastName": "...", "dob": "..." }`
**Response:** `{ "success": true, "data": { "tempToken": "..." } }`

### `POST /api/auth/login`

**Headers:** `X-Device-Name: string` (Optional)
**Body:** `{ "email": "user@bnxmail.com", "password": "..." }`
**Response:** `{ "success": true, "data": { "accessToken": "...", "refreshToken": "...", "status": "SUCCESS" } }`

### `POST /api/auth/login/2fa`

**Headers:** `X-Device-Name: string`
**Body:** `{ "tempToken": "...", "otp": "..." }`

### `POST /api/auth/login/2fa/send-otp`

**Body:** `{ "tempToken": "..." }`

### `POST /api/auth/login/2fa/verify-otp`

**Body:** `{ "tempToken": "...", "otp": "..." }`

### `POST /api/auth/refresh`

**Body:** `{ "refreshToken": "..." }`

### `POST /api/auth/logout`

**Body:** `{ "refreshToken": "..." }`

### `GET /api/auth/sessions`

Retrieves all active sessions for the user.

### `POST /api/auth/change-password`

**Body:** `{ "currentPassword": "...", "newPassword": "..." }`

### `GET /api/auth/forgot-password/options?identifier={email}`

Retrieves options for password reset.

### `POST /api/auth/forgot-password/send-otp`

**Body:** `{ "identifier": "...", "method": "email|phone" }`

### `POST /api/auth/forgot-password/verify-otp`

**Body:** `{ "identifier": "...", "otp": "..." }`

### `POST /api/auth/reset-password`

**Body:** `{ "identifier": "...", "token": "...", "newPassword": "..." }`

### `GET /api/auth/username-suggestions`

**Query Params:** `?firstName={...}&lastName={...}&dob={...}`
**Response:** `{ "success": true, "data": ["johndoe1", "johndoe89"] }`

### `POST /api/auth/child/send-parent-otp`

**Body:** `{ "parentEmail": "..." }`

### `POST /api/auth/child/verify-parent-otp`

**Body:** `{ "parentEmail": "...", "otp": "..." }`

---

## 2. Mailbox Management APIs

### `POST /api/emails/create`

**Headers:** `Authorization: Bearer <tempToken>`
**Body:** `{ "emailName": "...", "password": "...", "isPrimary": true }`

### `GET /api/emails/list`

Lists all mailboxes associated with the account.

### `POST /api/emails/:emailId/set-primary`

Sets a specific mailbox as the primary sending address.

---

## 3. Mail & Folders APIs

### `GET /api/mail/inbox?limit={limit}`

### `GET /api/mail/sent?limit={limit}`

### `GET /api/mail/draft?limit={limit}`

### `GET /api/mail/starred?limit={limit}`

### `GET /api/mail/trash?limit={limit}`

### `GET /api/mail/spam?limit={limit}`

### `GET /api/mail/snoozed?limit={limit}`

### `GET /api/mail/archive?limit={limit}`

### `GET /api/mail/scheduled`

Retrieves lists of emails in specific folders.

### `GET /api/mail/email/{uid}`

Retrieves a specific email by UID.

### `GET /api/mail/{uid}/attachments/{fileName}?folder={folder}`

Downloads an attachment (Returns Blob).

### `POST /api/mail/send`

**Body:** `{ "to": ["..."], "cc": [], "bcc": [], "subject": "...", "content": "...", "isHtml": true, "attachments": [] }`

### `POST /api/mail/schedule?sendAt={timestamp}`

**Body:** Same as `/api/mail/send`

### `DELETE /api/mail/scheduled/{id}`

Cancels a scheduled email.

### `POST /api/mail/read/{uid}`

### `POST /api/mail/unread/{uid}`

Marks email as read/unread.

### `POST /api/mail/star/{uid}?folder={folder}`

Toggles starred status.

### `POST /api/mail/trash/{uid}?folder={folder}`

Moves email to trash.

### `POST /api/mail/restore/{uid}`

Restores email from trash.

### `DELETE /api/mail/permanent/{uid}`

Permanently deletes email.

### `POST /api/mail/snooze/{uid}?wakeUpAt={timestamp}`

Snoozes an email.

### `POST /api/mail/archive/{uid}?folder={folder}`

Moves email to archive.

### `POST /api/mail/unarchive/{uid}`

Removes email from archive.

### `POST /api/mail/spam/{uid}?folder={folder}`

### `POST /api/mail/restore-spam/{uid}`

Manages spam status.

### `POST /api/mail/unsubscribe?senderEmail={email}`

### `POST /api/mail/subscribe?senderEmail={email}`

### `GET /api/mail/subscriptions`

Manages newsletter subscriptions.

---

## 4. Drafts APIs

### `POST /api/mail/drafts`

Creates a draft in the database.
**Body:** Similar to send email payload.

### `POST /api/mail/drafts/{id}/attachments`

**Headers:** `Content-Type: multipart/form-data`
Uploads attachment to a draft.

### `DELETE /api/mail/drafts/{id}/attachments/{fileName}`

Removes attachment from a draft.

### `POST /api/mail/drafts/{id}/send`

Sends an existing draft.

---

## 5. Labels & Categories APIs

### `GET /api/mail/labels`

Lists custom labels.

### `POST /api/mail/labels`

**Body:** `{ "name": "LabelName", "color": "#hex" }`

### `PUT /api/mail/labels/{id}`

### `DELETE /api/mail/labels/{id}`

### `POST /api/mail/labels/apply/{uid}?labelId={id}&folder={folder}`

### `DELETE /api/mail/labels/remove/{uid}?labelId={id}&folder={folder}`

### `GET /api/mail/category/{category}`

Categories include: `primary`, `social`, `promotions`, `updates`.

---

## 6. Business APIs

### `POST /api/business/register`

**Body:** `{ "businessName": "...", "domain": "..." }`

### `GET /api/business/domains`

Lists registered business domains.

### `POST /api/business/domain/{id}/verify`

Triggers domain verification process.

### `POST /api/business/onboard`

**Body:** `{ "industry": "...", "companySize": "...", "businessWebsite": "..." }`

---

## 7. Groups (Colab) APIs

### `GET /api/groups/`

### `POST /api/groups/create`

**Body:** `{ "name": "...", "description": "..." }`

### `GET /api/groups/{id}/members`

### `POST /api/groups/{id}/members`

**Body:** `{ "members": ["email1", "email2"] }`

### `POST /api/groups/{id}/send`

Broadcasts an email to the group.

---

## 8. User & Settings APIs

### `GET /api/users/settings`

### `PATCH /api/users/settings`

**Body:** `{ "themeMode": "dark", "twoFactorEnabled": true, ... }`

### `GET /api/users/activity-logs`

### `GET /api/users/recovery`

### `PATCH /api/users/recovery`

**Body:** `{ "recoveryEmail": "...", "phoneNumber": "..." }`

### `POST /api/users/profile-picture`

**Headers:** `Content-Type: multipart/form-data`

### `GET /api/signatures`

### `POST /api/signatures`

**Body:** `{ "name": "...", "content": "...", "isDefault": true }`

### `PUT /api/signatures/{id}`

### `DELETE /api/signatures/{id}`

### `PATCH /api/signatures/{id}/default`

---

## 9. Casbox (Customer Support/Ticketing) APIs

### `GET /api/casbox`

### `GET /api/casbox/thread/{contactEmail}`

### `POST /api/casbox/send`

**Body:** `{ "contactEmail": "...", "message": "..." }`

### `PATCH /api/casbox/status`

**Body:** `{ "threadId": 1, "status": "RESOLVED" }`

### `POST /api/casbox/delivered`

---

## 10. Template APIs

### `GET /api/templates?userEmail={email}`

### `POST /api/templates?userEmail={email}`

**Body:** `{ "name": "...", "subject": "...", "content": "..." }`

### `PUT /api/templates/{id}?userEmail={email}`

### `DELETE /api/templates/{id}?userEmail={email}`
