# Bit Tool API Documentation

This document outlines all the APIs utilized by the Bit Tool Frontend. All internal API requests require standard authentication headers unless otherwise noted.

## Global Headers

Most API endpoints require the following headers:

```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer <bnx_auth_token>"
}
```

---

## 1. Authentication & User Profile

The frontend relies on an SSO token provided via a URL redirect parameter (`?token=...`), which is then stored in `localStorage` as `bnx_auth_token`.

### Get Current User Profile

* **Endpoint:** `GET https://api.bnxmail.com/api/users/me`
* **Response (Success):**

```json
{
    "success": true,
    "message": "User profile retrieved successfully",
    "data": {
        "id": 28,
        "email": "user@example.com",
        "firstName": "First",
        "lastName": "Last",
        "fullName": "First Last",
        "profilePictureUrl": null,
        "role": "ORG_ADMIN",
        "accountType": "BUSINESS",
        "storageUsed": 0,
        "storageLimit": 16106127360,
        "isPrimary": true,
        "phoneNumber": null,
        "recoveryEmail": null,
        "dob": null,
        "organization": {
            "id": 6,
            "name": "Organization Name"
        }
    }
}
```

---

## 2. Notifications API

Base URL defined in environment as `VITE_API_BASE_URL`.

### Get All Notifications

* **Endpoint:** `GET /notifications`
* **Response:** Array of notification objects.

### Mark Single Notification as Read

* **Endpoint:** `PUT /notifications/:id/read`
* **Response:** `{ "status": "success", "message": "..." }`

### Mark All Notifications as Read

* **Endpoint:** `PUT /notifications/read-all`
* **Response:** `{ "status": "success", "message": "..." }`

---

## 3. Contacts API

Base URL defined in environment as `VITE_CONTACT_API_BASE_URL`.

### Get Paginated Contacts

* **Endpoint:** `GET /get`

### Get All Contacts

* **Endpoint:** `GET /get-all`

### Get Single Contact

* **Endpoint:** `GET /get/:id`

### Create Contact

* **Endpoint:** `POST /add`
* **Body:**

```json
{
  "firstName": "string",
  "lastName": "string",
  "email": "string",
  "phone": "string",
  "company": "string",
  "notes": "string"
}
```

### Update Contact

* **Endpoint:** `PUT /update/:id`
* **Body:** Fields to update (same schema as Create).

### Delete Contact

* **Endpoint:** `DELETE /delete/:id`

---

## 4. Notes API

Base URL defined in environment as `VITE_NOTES_API_BASE_URL`.

### Get Notes

* **Endpoint:** `GET /`
* **Query Parameters:** `?allApps=true`

### Create Note

* **Endpoint:** `POST /create`
* **Body:**

```json
{
  "title": "string",
  "content": "string",
  "color": "#ffffff",
  "isPinned": boolean,
  "applicationName": "string (optional)"
}
```

### Update Note

* **Endpoint:** `PUT /update/:id`
* **Body:** Partial updates supported.

```json
{
  "title": "string",
  "content": "string",
  "color": "#ffffff",
  "isPinned": boolean,
  "isArchived": boolean
}
```

### Delete Note

* **Endpoint:** `DELETE /delete/:id`

### Get Note by ID

* **Endpoint:** `GET /:id`

---

## 5. Calendar API

Base URL is `https://api.bit-tool.com/api/calendar`.

### Events

* `GET /events/month?year={YYYY}&month={MM}`
* `POST /events`
  * Body: `{ title, date, startTime, endTime, categoryId, description }`
* `PUT /events/:id`
* `DELETE /events/:id`

### Categories

* `GET /categories`
* `POST /categories`
  * Body: `{ name, color }`

### Reminders

* `GET /reminders?date={YYYY-MM-DD}`
* `POST /reminders`
  * Body: `{ title, date, time, description }`
* `PUT /reminders/:id`
* `PUT /reminders/:id/complete` - Marks reminder as completed.
* `DELETE /reminders/:id`

### Notes (Date-linked)

* `GET /notes?date={YYYY-MM-DD}`
* `POST /notes`
* `PUT /notes/:id`
* `DELETE /notes/:id`

### Global Calendar Search

* `GET /search?query={search_term}`

---

## 6. Calculator API

Base URL defined in environment as `VITE_CALCULATOR_API_BASE_URL`.

### Standard Calculator History

* **Get History:** `GET /history`
* **Create Session:** `POST /sessions`
  * Body: `{ "title": "Tape - Timestamp", "mode": "business", "currency": "INR" }`
* **Add Tape Item to Session:** `POST /sessions/:sessionId/items`
  * Body: `{ "sequence": 1, "value": 100, "operator": "+", "runningTotal": 100, "label": "" }`
* **Get Specific Session:** `GET /sessions/:id`
* **Delete Session:** `DELETE /sessions/:id`
* **Clear All Sessions:** `DELETE /sessions`

### Compare Mode History

* **Get Compare History:** `GET /compare/history`
* **Create Compare Session:** `POST /compare/sessions`
* **Add Compare Item:** `POST /compare/sessions/:sessionId/items`
* **Update Compare Item:** `PUT /compare/sessions/:sessionId/items/:itemId`
* **Delete Compare Item:** `DELETE /compare/sessions/:sessionId/items/:itemId`
* **Delete Compare Session:** `DELETE /compare/sessions/:id`
* **Clear All Compare History:** `DELETE /compare/history`

---

## 7. External Third-Party APIs (No Auth Required)

### Weather Data

* **Endpoint:** `GET https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&daily=weathercode,temperature_2m_max,temperature_2m_min&hourly=temperature_2m&current=temperature_2m,is_day,relative_humidity_2m,wind_speed_10m&timezone=auto`

### Reverse Geocoding (Location Name)

* **Endpoint:** `GET https://api.bigdatacloud.net/data/reverse-geocode-client?latitude={lat}&longitude={lon}&localityLanguage=en`
