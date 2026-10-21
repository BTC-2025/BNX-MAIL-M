# BNX Account & Auth — Mobile App Developer API Reference

Comprehensive API documentation for integrating BNX Account Creation, Authentication, Sub-ID/Branch Management, and Profile endpoints into Android and iOS mobile applications.

---

## 1. General Specifications

### Base URLs
- **Production:** `https://api.bnxmail.com/api`
- **Development / Local:** `http://localhost:8080/api`

### Common Headers
```http
Content-Type: application/json
Accept: application/json
```
For authenticated endpoints, pass the Bearer JWT token:
```http
Authorization: Bearer <ACCESS_TOKEN>
```

### Standard Response Envelope
All APIs return an `ApiResponse` envelope:

**Success Response:**
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": { ... }
}
```

**Error Response:**
```json
{
  "success": false,
  "message": "Detailed error message here",
  "data": null
}
```

---

## 2. Account Creation APIs

Account creation in BNX is a 2-step process for standalone accounts (Personal, Business, Child):
1. **Step 1:** Call `/auth/register` to create credentials $\rightarrow$ Receive `tempToken`.
2. **Step 2:** Call `/emails/create` with `Authorization: Bearer <tempToken>` $\rightarrow$ Provisions mailbox.

*(Note: Sub-IDs are created in a single call via `/subid/create`).*

---

### 2.1 Personal Account Creation

> **Handle Rule:** The `username` for Personal accounts must be exactly 10 characters (7 letters and 3 digits, e.g. `johnram123`).

#### Step 1: Register Personal Account
- **Endpoint:** `POST /auth/register`
- **Request Body:**
```json
{
  "username": "johnram123",
  "password": "Password123!",
  "firstName": "John",
  "lastName": "Ramesh",
  "phoneNumber": "+919876543210",
  "dob": "1998-05-15",
  "mode": "PERSONAL"
}
```
- **Response (200 OK):**
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "userId": 42,
    "username": "johnram123",
    "accountType": "PUBLIC",
    "tempToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### Step 2: Create Personal Mailbox
- **Endpoint:** `POST /emails/create`
- **Headers:** `Authorization: Bearer <tempToken>`
- **Request Body:**
```json
{
  "emailName": "johnram123",
  "password": "Password123!",
  "isPrimary": true
}
```
- **Response (200 OK):**
```json
{
  "success": true,
  "message": "Email created successfully",
  "data": {
    "emailId": 89,
    "email": "johnram123@bnxmail.com",
    "isPrimary": true
  }
}
```

---

### 2.2 Business Account Creation

#### Optional Pre-Verification (GSTIN)
- **Endpoint:** `POST /auth/verify-business`
- **Request Body:**
```json
{
  "type": "GSTIN",
  "gstin": "33AAAAA0000A1Z5"
}
```

#### Step 1: Register Business Account
- **Endpoint:** `POST /auth/register`
- **Request Body:**
```json
{
  "username": "acmeenterprise",
  "password": "Password123!",
  "firstName": "Ramesh",
  "lastName": "Kumar",
  "phoneNumber": "+919876543210",
  "mode": "BUSINESS",
  "businessFlow": "primary",
  "businessName": "Acme Enterprises Pvt Ltd",
  "businessType": "Private Limited Company",
  "domain": "bnxmail.com",
  "businessSize": "small",
  "companySize": "11-50",
  "industry": "Retail & Trade",
  "gstin": "33AAAAA0000A1Z5",
  "registrationNumber": "U74999TN2020PTC123456",
  "businessWebsite": "https://acme.com",
  "businessAddress": "123 Anna Salai, Chennai, TN"
}
```
- **Response (200 OK):**
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "userId": 55,
    "username": "acmeenterprise",
    "accountType": "BUSINESS",
    "tempToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### Step 2: Create Business Email
- **Endpoint:** `POST /emails/create`
- **Headers:** `Authorization: Bearer <tempToken>`
- **Request Body:**
```json
{
  "emailName": "contact",
  "password": "Password123!",
  "isPrimary": true
}
```
- **Response (200 OK):**
```json
{
  "success": true,
  "message": "Email created successfully",
  "data": {
    "emailId": 90,
    "email": "contact@bnxmail.com",
    "isPrimary": true
  }
}
```

---

### 2.3 Child / Family Account Creation

Tied to a registered parent account with verification.

#### Step A: Send OTP to Parent Email
- **Endpoint:** `POST /auth/child/send-parent-otp`
- **Request Body:**
```json
{
  "parentEmail": "parent@bnxmail.com"
}
```

#### Step B: Verify Parent OTP
- **Endpoint:** `POST /auth/child/verify-parent-otp`
- **Request Body:**
```json
{
  "parentEmail": "parent@bnxmail.com",
  "otp": "123456"
}
```

#### Step C: Register Child Account
- **Endpoint:** `POST /auth/register`
- **Request Body:**
```json
{
  "username": "kidaccount1",
  "password": "Password123!",
  "firstName": "Aarav",
  "lastName": "Kumar",
  "dob": "2014-08-20",
  "parentEmail": "parent@bnxmail.com",
  "mode": "CHILD"
}
```

#### Step D: Create Mailbox
- **Endpoint:** `POST /emails/create` (using `tempToken` from Step C).

---

### 2.4 Sub-ID Account Creation (Single-Step API)
Used by Business owners to create isolated accounts for employees, showroom managers, and cashiers. Automatically provisions both user credentials and mailbox.

- **Endpoint:** `POST /subid/create`
- **Headers:** `Authorization: Bearer <PARENT_ACCESS_TOKEN>`
- **Request Body:**
```json
{
  "prefix": "cashier",
  "password": "Password123!",
  "firstName": "Ramesh",
  "lastName": "Kumar",
  "accountType": "BUSINESS",
  "branchId": 3,
  "branchName": "Tambaram Branch",
  "permissions": [600, 210, 211]
}
```
- **Field Descriptions:**
  - `prefix` *(Required)*: Creates username `{prefix}.{parentUsername}` (e.g. `cashier.acmeenterprise`).
  - `password` *(Required)*: Temporary password (min 8 characters).
  - `accountType` *(Required)*: `"BUSINESS"` or `"PERSONAL"`.
  - `branchId` *(Optional)*: Assigned showroom/branch integer ID.
  - `branchName` *(Optional)*: Assigned branch name.
  - `permissions` *(Optional)*: Array of module permission IDs.

- **Response (200 OK):**
```json
{
  "success": true,
  "message": "Sub-ID created successfully",
  "data": {
    "subUsername": "cashier.acmeenterprise",
    "branchId": 3,
    "branchName": "Tambaram Branch"
  }
}
```

---

## 3. Authentication & Login APIs

### 3.1 Login (Email / Username + Password)
- **Endpoint:** `POST /auth/login`
- **Request Body:**
```json
{
  "identifier": "cashier.acmeenterprise@bnxmail.com",
  "password": "Password123!"
}
```

- **Success Response (200 OK):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "requires2FA": false,
    "user": {
      "id": 12,
      "username": "cashier.acmeenterprise",
      "email": "cashier.acmeenterprise@bnxmail.com",
      "firstName": "Ramesh",
      "lastName": "Kumar",
      "accountType": "BUSINESS",
      "role": "SUB_USER",
      "branchId": 3,
      "branchName": "Tambaram Branch"
    }
  }
}
```

*Note: If 2FA is enabled, `requires2FA` will be `true`, returning a `tempToken` to verify via `/auth/login/2fa`.*

### 3.2 Refresh Token
- **Endpoint:** `POST /auth/refresh`
- **Request Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 3.3 Logout
- **Endpoint:** `POST /auth/logout`
- **Headers:** `Authorization: Bearer <ACCESS_TOKEN>`

---

## 4. User Profile & Details APIs

### 4.1 Get Logged-In User Details
Retrieves current session user information, permissions, quota, and branch context.

- **Endpoint:** `GET /users/me`
- **Headers:** `Authorization: Bearer <ACCESS_TOKEN>`
- **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 12,
    "username": "cashier.acmeenterprise",
    "firstName": "Ramesh",
    "lastName": "Kumar",
    "fullName": "Ramesh Kumar",
    "email": "cashier.acmeenterprise@bnxmail.com",
    "recoveryEmail": null,
    "phoneNumber": "+919876543210",
    "accountType": "BUSINESS",
    "role": "SUB_USER",
    "isSubId": true,
    "parentAccount": "acmeenterprise@bnxmail.com",
    "branchId": 3,
    "branchName": "Tambaram Branch",
    "permissions": [600, 210, 211],
    "storageUsed": 204800,
    "storageLimit": 10737418240,
    "profilePictureUrl": "/api/users/profile-picture/cashier.acmeenterprise"
  }
}
```

### 4.2 Update Profile
- **Endpoint:** `PATCH /users/profile`
- **Headers:** `Authorization: Bearer <ACCESS_TOKEN>`
- **Request Body:**
```json
{
  "firstName": "Ramesh",
  "lastName": "Kumar",
  "displayName": "Ramesh K",
  "nickname": "Ram",
  "dob": "1995-10-12",
  "gender": "Male",
  "recoveryEmail": "ramesh.personal@gmail.com",
  "phoneNumber": "+919876543210",
  "homeAddress": "45 Park Street, Chennai",
  "workAddress": "Tambaram Showroom",
  "occupation": "Senior Cashier",
  "bio": "Managing billing and counter operations."
}
```

---

## 5. Team & Sub-ID Management APIs

### 5.1 List All Sub-IDs
Returns all team members and sub-accounts created under the parent business.

- **Endpoint:** `GET /subid/list`
- **Headers:** `Authorization: Bearer <PARENT_ACCESS_TOKEN>`
- **Response (200 OK):**
```json
{
  "success": true,
  "message": "Fetched Sub-IDs",
  "data": [
    {
      "id": 12,
      "username": "cashier.acmeenterprise",
      "firstName": "Ramesh",
      "lastName": "Kumar",
      "accountType": "BUSINESS",
      "role": "SUB_USER",
      "branchId": 3,
      "branchName": "Tambaram Branch",
      "active": true,
      "approved": true,
      "permissions": [600, 210, 211]
    },
    {
      "id": 15,
      "username": "manager.acmeenterprise",
      "firstName": "Suresh",
      "lastName": "Raina",
      "accountType": "BUSINESS",
      "role": "SUB_USER",
      "branchId": 4,
      "branchName": "Velachery Branch",
      "active": true,
      "approved": true,
      "permissions": [110, 210, 310, 410, 600]
    }
  ]
}
```

### 5.2 Update Sub-ID Branch Assignment
Reassigns a sub-user to a different branch.

- **Endpoint:** `PUT /subid/{subId}/branch`
- **Headers:** `Authorization: Bearer <PARENT_ACCESS_TOKEN>`
- **Request Body:**
```json
{
  "branchId": 4,
  "branchName": "Velachery Branch"
}
```
- **Response (200 OK):**
```json
{
  "success": true,
  "message": "Branch updated successfully",
  "data": null
}
```

### 5.3 Update Sub-ID Permissions
- **Endpoint:** `PUT /subid/{subId}/permissions`
- **Headers:** `Authorization: Bearer <PARENT_ACCESS_TOKEN>`
- **Request Body:**
```json
[600, 210, 211, 212]
```
- **Response (200 OK):**
```json
{
  "success": true,
  "message": "Permissions updated successfully",
  "data": null
}
```

---

## 6. Email Identities & Mailbox Management

### 6.1 List User Emails
- **Endpoint:** `GET /emails/list`
- **Headers:** `Authorization: Bearer <ACCESS_TOKEN>`
- **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "count": 2,
    "emails": [
      {
        "id": 89,
        "emailName": "acmeenterprise",
        "email": "acmeenterprise@bnxmail.com",
        "isPrimary": true,
        "active": true
      },
      {
        "id": 92,
        "emailName": "support",
        "email": "support@bnxmail.com",
        "isPrimary": false,
        "active": true
      }
    ]
  }
}
```

### 6.2 Create Additional Email / Alias ID
- **Endpoint:** `POST /emails/create`
- **Headers:** `Authorization: Bearer <ACCESS_TOKEN>`
- **Request Body:**
```json
{
  "emailName": "support",
  "isPrimary": false
}
```

---

## 7. Business Module Permission Code Reference

Use these IDs in the `permissions` array for Business Sub-IDs:

| Module | ID | Permission Description |
| :--- | :--- | :--- |
| **Finance** | `110` | Full Accounting Access |
| | `111` | P&L Statement |
| | `112` | Balance Sheet |
| | `114` | Expense Management |
| | `130` | Full Tax / GST |
| **Sales** | `210` | Sales Invoices & Orders |
| | `211` | Create Sales Invoice |
| | `220` | Customer CRM |
| **Purchases** | `310` | Purchase Orders & Bills |
| | `320` | Supplier Management |
| **Inventory**| `410` | Stock & Warehouses |
| | `411` | Product Catalog |
| **POS** | `600` | POS Counter Billing |
| **Reports** | `700` | Analytics & Reports |
