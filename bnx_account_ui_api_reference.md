# BNX Account UI - Mobile API Reference

This document outlines the API endpoints used by the `bnx-account-ui` (the authenticated account dashboard) so that you can implement the equivalent functionality in the mobile app.

- **Base URL:** `http(s)://<server>:8080`
- **Authentication:** Pass the JWT access token in the header: `Authorization: Bearer <accessToken>` (where noted).

**Standard Response Wrapper:**

Unless noted otherwise, all JSON responses use the following wrapper format:

```json
{
  "success": true, // or false on error
  "message": "Operation successful",
  "data": { ... }, // the actual payload
  "timestamp": 1712836200000
}
```

---

## 1. User & Profile APIs

### 1.1 Get Current User Profile

Fetch the current logged-in user's profile and account state.

- **Endpoint:** `GET /api/users/me`
- **Auth Required:** Yes
- **Body:** None

**Response `data`:**

```json
{
  "userId": 1,
  "username": "siva",
  "email": "siva@bnxmail.com",
  "firstName": "Siva",
  "lastName": "Kumar",
  "role": "PUBLIC",
  "accountType": "PERSONAL",
  "isPrimary": true,
  "profilePicture": "file.png",
  "mailboxes": [{ "emailId": 1, "email": "siva@bnxmail.com", "isPrimary": true }]
}
```

### 1.2 Update User Profile

Update profile fields for the logged-in user.

- **Endpoint:** `PATCH /api/users/profile`
- **Auth Required:** Yes

**Body:**

```json
{
  "firstName": "NewName",
  "lastName": "NewLastName",
  "recoveryEmail": "backup@example.com",
  "phoneNumber": "9876543210"
}
```

**Response `data`:** The updated user object.

### 1.3 Upload Profile Picture

Upload or replace the user's avatar.

- **Endpoint:** `POST /api/users/profile-picture`
- **Auth Required:** Yes
- **Content-Type:** `multipart/form-data`
- **Body:**
  - `file`: The image file (binary).

**Response `data`:**

```json
{
  "profilePicture": "filename.png",
  "profilePictureUrl": "/api/users/profile-picture/siva"
}
```

### 1.4 Delete Profile Picture

Remove the user's avatar.

- **Endpoint:** `DELETE /api/users/profile-picture`
- **Auth Required:** Yes
- **Body:** None
- **Response `data`:** `null`

---

## 2. Mailbox & Storage APIs

### 2.1 Get Email Aliases / Mailboxes

List all mailboxes attached to the user's account.

- **Endpoint:** `GET /api/emails/list`
- **Auth Required:** Yes
- **Body:** None

**Response `data`:**

```json
{
  "count": 1,
  "emails": [
    {
      "id": 1,
      "email": "siva@bnxmail.com",
      "isPrimary": true,
      "active": true
    }
  ]
}
```

### 2.2 Get Storage Quota

Fetch the used and available storage space for the user's emails.

- **Endpoint:** `GET /api/mail/storage-quota`
- **Auth Required:** Yes
- **Body:** None

**Response `data`:**

```json
{
  "email": "siva@bnxmail.com",
  "storageLimit": 5368709120,    // in bytes (e.g., 5GB)
  "storageUsed": 1048576,        // in bytes
  "storagePercentage": 0.02
}
```

---

## 3. Two-Factor Authentication (2FA)

### 3.1 Initiate 2FA Setup

Generates the secret and QR code URI for authenticator apps.

- **Endpoint:** `POST /api/users/2fa/setup`
- **Auth Required:** Yes
- **Body:** `{}` (Empty JSON object)

**Response `data`:**

```json
{
  "secret": "JBSWY3DPEHPK3PXP",
  "qrCodeUri": "otpauth://totp/BNXMail:siva?secret=JBSWY3DPEHPK3PXP&issuer=BNXMail"
}
```

### 3.2 Verify and Enable 2FA

Verify the code from the authenticator app to fully enable 2FA.

- **Endpoint:** `POST /api/users/2fa/verify`
- **Auth Required:** Yes

**Body:**

```json
{
  "code": "123456" // The 6-digit TOTP code
}
```

**Response `data`:** `null` (Success message in wrapper)

### 3.3 Disable 2FA

Turn off two-factor authentication.

- **Endpoint:** `POST /api/users/2fa/disable`
- **Auth Required:** Yes
- **Body:** `{}` (Empty JSON object)
- **Response `data`:** `null`

*(Note: There is also an older `/api/users/2fa/enable` route that might be called before `/verify` depending on the exact flow used, but typically `setup` -> `verify` is the standard).*

---

## 4. Sub-ID (Sub-account) Management

### 4.1 List Sub-IDs

Get a list of child accounts created by this primary user.

- **Endpoint:** `GET /api/subid/list`
- **Auth Required:** Yes
- **Body:** None

**Response `data`:** Array of User objects (similar to the `/users/me` response).

```json
[
  {
    "userId": 2,
    "username": "child.siva",
    "email": "child.siva@bnxmail.com",
    "accountType": "SUB_ID"
  }
]
```

### 4.2 Create Sub-ID

Create a new sub-account under the current user's domain/prefix.

- **Endpoint:** `POST /api/subid/create`
- **Auth Required:** Yes

**Body:**

```json
{
  "prefix": "child",            // Will create child.siva@bnxmail.com
  "password": "SecurePassword123"
}
```

**Response `data`:** Details of the newly created sub-user account.

---

## 5. Account Verification

### 5.1 Initiate Email Verification

Trigger a verification email to be sent to a specific mailbox.

- **Endpoint:** `GET /api/verification/initiate/{emailId}`
- **Auth Required:** Yes
- **Body:** None
- **Response `data`:** `null`

---

## 6. Payment & Subscription (External API)

The `bnx-account-ui` fetches active subscription details to display in the Billing tab. Note that this endpoint points to a different service domain.

### 6.1 Get Active Subscription

Fetches the active Cliks Business subscription details for the user.

- **Endpoint:** `GET https://cliks.beta-softnet.com/api/v1/business/subscription/{userEmail}`
- **Auth Required:** No (in the frontend implementation, it makes a direct GET request)
- **Body:** None

**Response:**

```json
{
  "success": true,
  "message": "Subscription retrieved",
  "data": {
    "plan_name": "Pro Business Plan",
    "subscription_days_remaining": 34,
    "when_subscribed": "2026-09-01T10:00:00Z",
    "next_due_date": "2026-11-04T10:00:00Z",
    "email": "user@example.com"
  }
}
```

*(Note: If the user is on the "Free Plan" or `subscription_days_remaining` is 0, the UI will display a prompt to upgrade instead).*
