# BNXmail Cashbox Backend API Reference & Specification

**Project:** BNXmail Messaging Platform  
**Module:** Cashbox (Instant Messaging & Direct Communication)  
**Backend Architecture:** Spring Boot 3.x, Spring Security (JWT), Spring Data JPA / MySQL, Spring WebSocket (STOMP / SockJS)  
**Generated At:** 2026-10-17  
**Status:** Verified against Backend Source Code  

---

## Table of Contents

1. [Overview & Authentication](#1-overview--authentication)
2. [Quick Reference API Inventory Table](#2-quick-reference-api-inventory-table)
3. [Core Cashbox Messaging APIs (`/api/casbox`)](#3-core-cashbox-messaging-apis-apicasbox)
   - [API 1: Fetch All Messages](#api-1-fetch-all-messages)
   - [API 2: Fetch Conversation Thread](#api-2-fetch-conversation-thread)
   - [API 3: Send Message](#api-3-send-message)
   - [API 4: Batch Archive / Unarchive Messages](#api-4-batch-archive--unarchive-messages)
   - [API 5: Single Message Archive / Unarchive](#api-5-single-message-archive--unarchive)
   - [API 6: Update Delivery and Read Status](#api-6-update-delivery-and-read-status)
   - [API 7: Mark Unseen Messages as Delivered](#api-7-mark-unseen-messages-as-delivered)
   - [API 8: Edit Sent Message (PATCH)](#api-8-edit-sent-message-patch)
   - [API 9: Edit Sent Message (PUT)](#api-9-edit-sent-message-put)
   - [API 10: Edit Sent Message (Explicit Route)](#api-10-edit-sent-message-explicit-route)
   - [API 11: Delete Conversation](#api-11-delete-conversation)
4. [Contact & Connection APIs (`/api/connections`)](#4-contact--connection-apis-apiconnections)
   - [API 12: Get Accepted Connections](#api-12-get-accepted-connections)
   - [API 13: Get All User Connections](#api-13-get-all-user-connections)
   - [API 14: Update Connection Status](#api-14-update-connection-status)
5. [Contact Customization & Alias APIs (`/api/contact-aliases`)](#5-contact-customization--alias-apis-apicontact-aliases)
   - [API 15: Get All Contact Aliases](#api-15-get-all-contact-aliases)
   - [API 16: Get Single Contact Alias](#api-16-get-single-contact-alias)
   - [API 17: Set or Update Contact Alias](#api-17-set-or-update-contact-alias)
   - [API 18: Delete Contact Alias](#api-18-delete-contact-alias)
6. [Contact Safety & Block APIs (`/api/blocked-contacts`)](#6-contact-safety--block-apis-apiblocked-contacts)
   - [API 19: Get Blocked Contacts List](#api-19-get-blocked-contacts-list)
   - [API 20: Check if Contact is Blocked](#api-20-check-if-contact-is-blocked)
   - [API 21: Block a Contact](#api-21-block-a-contact)
   - [API 22: Unblock a Contact](#api-22-unblock-a-contact)
7. [User Settings & Message Requests (`/api/users/settings`)](#7-user-settings--message-requests-apiuserssettings)
   - [API 23: Fetch User Settings (Casbox Accepted List)](#api-23-fetch-user-settings-casbox-accepted-list)
   - [API 24: Update User Settings (Casbox Accepted List)](#api-24-update-user-settings-casbox-accepted-list)
8. [WebSocket & Real-Time Messaging Reference](#8-websocket--real-time-messaging-reference)
9. [Data Transfer Objects (DTOs) & JSON Schemas](#9-data-transfer-objects-dtos--json-schemas)

---

## 1. Overview & Authentication

### 1.1 Architecture

The Cashbox module is BNXmail's dedicated peer-to-peer messaging system. It is powered by:

- **Relational Persistence:** Dedicated `casbox_messages` table storing message bodies, edit tracking, delivery status (`SENT`, `DELIVERED`, `SEEN`), per-user archive flags (`sender_archived`, `receiver_archived`), and attachment metadata.
- **Access Control:** Integrated with `connections`, `blocked_contacts`, `contact_aliases`, and `user_settings`.
- **Real-Time Push:** In-memory STOMP message broker broadcasting new messages and read-status receipts to user-scoped private queues (`SimpMessagingTemplate`).

### 1.2 Authentication Headers

All REST endpoints require a valid JWT Bearer token:

```http
Authorization: Bearer <jwt_access_token>
Content-Type: application/json
```

The authenticated user's email is resolved securely on the server from `SecurityContextHolder.getContext().getAuthentication().getName()` or `@AuthenticationPrincipal UserDetails`.

---

## 2. Quick Reference API Inventory Table

| No. | Feature | HTTP Method | Complete Path | Controller Method | Status |
| --- | --- | --- | --- | --- | --- |
| **1** | Fetch All Messages | `GET` | `/api/casbox` | `CasboxController.getAllMessages` | **Implemented** |
| **2** | Fetch Conversation Thread | `GET` | `/api/casbox/thread/{contactEmail}` | `CasboxController.getThread` | **Implemented** |
| **3** | Send Cashbox Message | `POST` | `/api/casbox/send` | `CasboxController.sendMessage` | **Implemented** |
| **4** | Batch Archive/Unarchive | `PATCH` | `/api/casbox/archive` | `CasboxController.updateArchiveStatus` | **Implemented** |
| **5** | Single Message Archive | `PATCH` | `/api/casbox/{id}/archive` | `CasboxController.archiveMessage` | **Implemented** |
| **6** | Update Delivery/Read Status | `PATCH` | `/api/casbox/status` | `CasboxController.updateStatus` | **Implemented** |
| **7** | Mark Unseen as Delivered | `POST` | `/api/casbox/delivered` | `CasboxController.markAsDelivered` | **Implemented** |
| **8** | Edit Sent Message | `PATCH` | `/api/casbox/{id}` | `CasboxController.editMessage` | **Implemented** |
| **9** | Edit Sent Message (PUT) | `PUT` | `/api/casbox/{id}` | `CasboxController.editMessagePut` | **Implemented** |
| **10** | Edit Sent Message (Explicit) | `PATCH` | `/api/casbox/{id}/edit` | `CasboxController.editMessageExplicit` | **Implemented** |
| **11** | Delete Conversation | `DELETE` | `/api/casbox/conversation/{contactEmail}` | `CasboxController.deleteConversation` | **Implemented** |
| **12** | Get Accepted Connections | `GET` | `/api/connections/accepted` | `ConnectionController.getAcceptedConnections` | **Implemented** |
| **13** | Get All User Connections | `GET` | `/api/connections` | `ConnectionController.getMyConnections` | **Implemented** |
| **14** | Update Connection Status | `PATCH` / `PUT` | `/api/connections/{connectionId}/status` | `ConnectionController.updateConnectionStatus` | **Implemented** |
| **15** | Get All Contact Aliases | `GET` | `/api/contact-aliases` | `ContactAliasController.getAllAliases` | **Implemented** |
| **16** | Get Single Contact Alias | `GET` | `/api/contact-aliases/{contactUserId}` | `ContactAliasController.getAlias` | **Implemented** |
| **17** | Set / Update Contact Alias | `PUT` | `/api/contact-aliases/{contactUserId}` | `ContactAliasController.setAlias` | **Implemented** |
| **18** | Delete Contact Alias | `DELETE` | `/api/contact-aliases/{contactUserId}` | `ContactAliasController.deleteAlias` | **Implemented** |
| **19** | Get Blocked Contacts List | `GET` | `/api/blocked-contacts` | `BlockedContactController.getBlockedContacts` | **Implemented** |
| **20** | Check if Contact is Blocked | `GET` | `/api/blocked-contacts/check` | `BlockedContactController.isBlocked` | **Implemented** |
| **21** | Block a Contact | `POST` | `/api/blocked-contacts` | `BlockedContactController.blockContact` | **Implemented** |
| **22** | Unblock a Contact | `DELETE` | `/api/blocked-contacts/{email}` | `BlockedContactController.unblockContact` | **Implemented** |
| **23** | Get User Settings | `GET` | `/api/users/settings` | `UserController.getSettings` | **Implemented** |
| **24** | Update Accepted Senders | `PATCH` | `/api/users/settings` | `UserController.patchSettings` | **Implemented** |

---

## 3. Core Cashbox Messaging APIs (`/api/casbox`)

### API 1: Fetch All Messages

- **Description:** Retrieves all messages sent or received by the authenticated user, excluding messages from contacts that have been disconnected.
- **HTTP Method:** `GET`
- **Path:** `/api/casbox`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.getAllMessages(Authentication authentication)`
- **Service Method:** `com.btctech.mailapp.service.CasboxService.getAllMessages(String userEmail)`
- **Request Parameters:** None
- **Request Body:** None
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
[
  {
    "id": 1042,
    "senderEmail": "alice@bnxmail.com",
    "receiverEmail": "bob@bnxmail.com",
    "subject": "Project Proposal Updates",
    "body": "Hey Bob, please find the latest terms attached.",
    "attachmentsJson": "[{\"name\":\"Terms.pdf\",\"size\":154200,\"url\":\"https://bnxmail.com/files/terms.pdf\"}]",
    "status": "DELIVERED",
    "timestamp": "2026-10-17T09:30:00.000+00:00",
    "senderUsername": "alice",
    "receiverUsername": "bob",
    "senderDisplayName": "Alice Johnson",
    "receiverDisplayName": "Bob",
    "contactDisplayName": "Alice Johnson",
    "contactUsername": "alice",
    "contactUserId": 8,
    "customName": null,
    "isArchived": false,
    "senderArchived": false,
    "receiverArchived": false,
    "isAccepted": true,
    "isEdited": false
  }
]
```

- **Database Tables Affected:** `casbox_messages` (SELECT), `connections` (SELECT)
- **Frontend File & Function:** `Casbox.jsx` -> `fetchMessages()` calling `casboxAPI.getAllMessages()`

---

### API 2: Fetch Conversation Thread

- **Description:** Retrieves the chronological conversation history between the authenticated user and a specific contact email.
- **HTTP Method:** `GET`
- **Path:** `/api/casbox/thread/{contactEmail}`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.getThread(@PathVariable String contactEmail, Authentication authentication)`
- **Service Method:** `com.btctech.mailapp.service.CasboxService.getThread(String userEmail, String contactEmail)`
- **Path Parameters:**
  - `contactEmail` (String, required): Email address of the conversation partner.
- **Request Body:** None
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
[
  {
    "id": 1040,
    "senderEmail": "alice@bnxmail.com",
    "receiverEmail": "bob@bnxmail.com",
    "subject": "Meeting",
    "body": "Are we still on for 3 PM?",
    "attachmentsJson": null,
    "status": "SEEN",
    "timestamp": "2026-10-17T08:00:00.000+00:00",
    "isArchived": false,
    "isAccepted": true,
    "isEdited": false
  },
  {
    "id": 1041,
    "senderEmail": "bob@bnxmail.com",
    "receiverEmail": "alice@bnxmail.com",
    "subject": "Meeting",
    "body": "Yes, see you in Conference Room A.",
    "attachmentsJson": null,
    "status": "SEEN",
    "timestamp": "2026-10-17T08:05:00.000+00:00",
    "isArchived": false,
    "isAccepted": true,
    "isEdited": false
  }
]
```

- **Database Tables Affected:** `casbox_messages` (SELECT ordered by `timestamp ASC`)
- **Frontend File & Function:** `Casbox.jsx` -> `loadThread()` calling `casboxAPI.getThread(contactEmail)`

---

### API 3: Send Message

- **Description:** Validates connection permissions and safety block checks, persists message, and broadcasts real-time STOMP notification to both sender and recipient private queues.
- **HTTP Method:** `POST`
- **Path:** `/api/casbox/send`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.sendMessage(@Valid @RequestBody CasboxSendRequest request, Authentication authentication)`
- **Service Method:** `com.btctech.mailapp.service.CasboxService.sendMessage(String senderEmail, CasboxSendRequest request)`
- **Request Body Example:**

```json
{
  "receiverEmail": "alice@bnxmail.com",
  "subject": "Product Delivery Notes",
  "body": "The final build has been pushed to the staging server.",
  "attachmentsJson": "[{\"name\":\"build_log.txt\",\"size\":4820,\"url\":\"https://bnxmail.com/files/build.txt\"}]"
}
```

- **Response Status:** `200 OK`
- **Response Body Example:**

```json
{
  "id": 1045,
  "senderEmail": "bob@bnxmail.com",
  "receiverEmail": "alice@bnxmail.com",
  "subject": "Product Delivery Notes",
  "body": "The final build has been pushed to the staging server.",
  "attachmentsJson": "[{\"name\":\"build_log.txt\",\"size\":4820,\"url\":\"https://bnxmail.com/files/build.txt\"}]",
  "status": "SENT",
  "timestamp": "2026-10-17T11:00:00.000+00:00",
  "isArchived": false,
  "isAccepted": true,
  "isEdited": false
}
```

- **WebSocket Broadcast:**
  - Destination: `/user/{receiverEmail}/queue/casbox/messages`
  - Destination: `/user/{senderEmail}/queue/casbox/messages`
- **Error Codes:**
  - `400 Bad Request`: `Cannot send message to this user` (if blocked or disconnected) or `Receiver email and body are required`.
  - `401 Unauthorized`: Unauthenticated.
- **Database Tables Affected:** `casbox_messages` (INSERT), `blocked_contacts` (SELECT check), `connections` (SELECT check)
- **Frontend File & Function:** `Casbox.jsx` -> `handleSendMessage()` calling `casboxAPI.sendMessage(data)`

---

### API 4: Batch Archive / Unarchive Messages

- **Description:** Toggles the archived state for a list of message IDs for the authenticated user without impacting the other conversation participant.
- **HTTP Method:** `PATCH`
- **Path:** `/api/casbox/archive`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.updateArchiveStatus(@RequestBody CasboxArchiveRequest request, Authentication authentication)`
- **Service Method:** `com.btctech.mailapp.service.CasboxService.updateArchiveStatus(List<Long> messageIds, Boolean archived, String userEmail)`
- **Request Body Example:**

```json
{
  "messageIds": [1040, 1041],
  "archived": true
}
```

- **Response Status:** `200 OK` (Empty body)
- **Database Tables Affected:** `casbox_messages` (UPDATE `sender_archived` / `receiver_archived`)
- **Frontend File & Function:** `Casbox.jsx` -> `handleArchiveMessages()` calling `casboxAPI.updateArchiveStatus(ids, bool)`

---

### API 5: Single Message Archive / Unarchive

- **Description:** Archives or unarchives a single message by ID.
- **HTTP Method:** `PATCH`
- **Path:** `/api/casbox/{id}/archive?archived={bool}`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.archiveMessage(@PathVariable Long id, @RequestParam(defaultValue = "true") boolean archived, Authentication authentication)`
- **Path Parameters:**
  - `id` (Long, required): Target message ID.
- **Query Parameters:**
  - `archived` (Boolean, optional, default: `true`): `true` to archive, `false` to unarchive.
- **Response Status:** `200 OK` (Empty body)
- **Database Tables Affected:** `casbox_messages` (UPDATE)
- **Frontend File & Function:** `Casbox.jsx` calling `casboxAPI.archiveMessage(id, archived)`

---

### API 6: Update Delivery and Read Status

- **Description:** Receiver updates the status of one or more messages to `DELIVERED` or `SEEN`. Sender is notified in real time over WebSocket.
- **HTTP Method:** `PATCH`
- **Path:** `/api/casbox/status`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.updateStatus(@Valid @RequestBody CasboxStatusRequest request, Authentication authentication)`
- **Service Method:** `com.btctech.mailapp.service.CasboxService.updateStatus(List<Long> messageIds, String status, String receiverEmail)`
- **Request Body Example:**

```json
{
  "messageIds": [1040, 1041],
  "status": "SEEN"
}
```

- **Response Status:** `200 OK` (Empty body)
- **WebSocket Broadcast:**
  - Destination: `/user/{senderEmail}/queue/casbox/status`
  - Payload: `CasboxMessageDto` with updated status
- **Database Tables Affected:** `casbox_messages` (UPDATE `status = :status` WHERE `receiver_email = :userEmail`)
- **Frontend File & Function:** `Casbox.jsx` -> `markAsRead()` calling `casboxAPI.updateStatus(data)`

---

### API 7: Mark Unseen Messages as Delivered

- **Description:** Automatically transitions all pending `SENT` messages addressed to the authenticated user into `DELIVERED` status upon logging in or establishing connection.
- **HTTP Method:** `POST`
- **Path:** `/api/casbox/delivered`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.markAsDelivered(Authentication authentication)`
- **Service Method:** `com.btctech.mailapp.service.CasboxService.markUnseenAsDelivered(String receiverEmail)`
- **Request Body:** None
- **Response Status:** `200 OK` (Empty body)
- **WebSocket Broadcast:**
  - Destination: `/user/{senderEmail}/queue/casbox/status`
- **Database Tables Affected:** `casbox_messages` (UPDATE `status = 'DELIVERED'` WHERE `receiver_email = :receiverEmail` AND `status = 'SENT'`)
- **Frontend File & Function:** `Casbox.jsx` calling `casboxAPI.markAsDelivered()`

---

### API 8: Edit Sent Message (PATCH)

- **Description:** Allows the original sender to edit a sent message within **5 minutes (300 seconds)** of its creation timestamp. Broadcasts the updated message over WebSocket to both sender and recipient.
- **HTTP Method:** `PATCH`
- **Path:** `/api/casbox/{id}`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.editMessage(@PathVariable Long id, @RequestBody CasboxEditRequest request, Authentication authentication)`
- **Service Method:** `com.btctech.mailapp.service.CasboxService.editMessage(Long messageId, CasboxEditRequest request, String userEmail)`
- **Path Parameters:**
  - `id` (Long, required): Target message ID.
- **Request Body Example:**

```json
{
  "body": "Updated content: Meeting moved to Room B."
}
```

*(Supports both `"body"` and `"content"` in the request DTO).*

- **Response Status:** `200 OK`
- **Response Body Example:**

```json
{
  "id": 1041,
  "senderEmail": "bob@bnxmail.com",
  "receiverEmail": "alice@bnxmail.com",
  "subject": "Meeting",
  "body": "Updated content: Meeting moved to Room B.",
  "attachmentsJson": null,
  "status": "SEEN",
  "timestamp": "2026-10-17T08:05:00.000+00:00",
  "isEdited": true
}
```

- **Error Codes:**
  - `400 Bad Request`: `Messages can only be edited within 5 minutes of sending` or `Message content cannot be empty`.
  - `403 Forbidden`: `You can only edit your own messages`.
  - `404 Not Found`: `Message not found`.
- **Database Tables Affected:** `casbox_messages` (UPDATE `body`, `is_edited = true`)
- **Frontend File & Function:** `Casbox.jsx` -> `handleSaveEdit()` calling `casboxAPI.editMessage(id, body)`

---

### API 9: Edit Sent Message (PUT)

- **Description:** Idempotent `PUT` method alias for message editing.
- **HTTP Method:** `PUT`
- **Path:** `/api/casbox/{id}`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.editMessagePut`
- **Behavior:** Identical to [API 8](#api-8-edit-sent-message-patch).

---

### API 10: Edit Sent Message (Explicit Route)

- **Description:** Explicit action route alias for message editing.
- **HTTP Method:** `PATCH`
- **Path:** `/api/casbox/{id}/edit`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.editMessageExplicit`
- **Behavior:** Identical to [API 8](#api-8-edit-sent-message-patch).

---

### API 11: Delete Conversation

- **Description:** Deletes the complete conversation thread between the authenticated user and a contact partner. Also accepts a numeric message ID to infer the counterpart.
- **HTTP Method:** `DELETE`
- **Supported Paths:**
  - `/api/casbox/conversation/{contactEmail}` (Primary)
  - `/api/casbox/conversation?email={email}`
  - `/api/casbox/messages/{contactEmail}`
  - `/api/casbox/{contactEmail}`
- **Controller Method:** `com.btctech.mailapp.controller.CasboxController.deleteConversation`
- **Service Method:** `com.btctech.mailapp.service.CasboxService.deleteConversation(String userEmail, String contactEmailOrId)`
- **Response Status:** `200 OK` (Empty body)
- **Database Tables Affected:** `casbox_messages` (DELETE where `(sender = user AND receiver = contact) OR (sender = contact AND receiver = user)`)
- **Frontend File & Function:** `Casbox.jsx` -> `handleDeleteConversation()` calling `casboxAPI.deleteConversation(targetContact)`

---

## 4. Contact & Connection APIs (`/api/connections`)

### API 12: Get Accepted Connections

- **Description:** Returns all contacts with active `CONNECTED` status. Populates the "Accepted" contacts list in Cashbox.
- **HTTP Method:** `GET`
- **Path:** `/api/connections/accepted`
- **Controller Method:** `com.btctech.mailapp.controller.ConnectionController.getAcceptedConnections()`
- **Service Method:** `com.btctech.mailapp.service.ConnectionService.getAcceptedConnections(Long userId)`
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
[
  {
    "id": 12,
    "userId": 5,
    "userEmail": "bob@bnxmail.com",
    "userName": "Bob Smith",
    "connectedUserId": 8,
    "connectedUserEmail": "alice@bnxmail.com",
    "connectedUserName": "Alice Johnson",
    "status": "CONNECTED",
    "createdAt": "2026-10-10T12:00:00",
    "updatedAt": "2026-10-10T12:00:00"
  }
]
```

- **Database Tables Affected:** `connections`, `users`, `user_settings`, `user_casbox_accepted`
- **Frontend File & Function:** `Casbox.jsx` -> `fetchConnections()` calling `connectionAPI.getAccepted()`

---

### API 13: Get All User Connections

- **Description:** Returns all connection entries (`CONNECTED` and `DISCONNECTED`) for the user.
- **HTTP Method:** `GET`
- **Path:** `/api/connections`
- **Controller Method:** `com.btctech.mailapp.controller.ConnectionController.getMyConnections()`
- **Service Method:** `com.btctech.mailapp.service.ConnectionService.getConnectionsForUser(Long userId)`
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
[
  {
    "id": 12,
    "userId": 5,
    "userEmail": "bob@bnxmail.com",
    "userName": "Bob Smith",
    "connectedUserId": 8,
    "connectedUserEmail": "alice@bnxmail.com",
    "connectedUserName": "Alice Johnson",
    "status": "CONNECTED"
  },
  {
    "id": 13,
    "userId": 5,
    "userEmail": "bob@bnxmail.com",
    "userName": "Bob Smith",
    "connectedUserId": 14,
    "connectedUserEmail": "stranger@bnxmail.com",
    "connectedUserName": "Stranger",
    "status": "DISCONNECTED"
  }
]
```

- **Database Tables Affected:** `connections`
- **Frontend File & Function:** `connectionAPI.getAll()`

---

### API 14: Update Connection Status

- **Description:** Disconnects or reconnects a contact by updating the connection status.
- **HTTP Method:** `PATCH` / `PUT`
- **Path:** `/api/connections/{connectionId}/status`
- **Controller Method:** `com.btctech.mailapp.controller.ConnectionController.updateConnectionStatus(@PathVariable Long connectionId, @RequestBody ConnectionStatusUpdateRequest request)`
- **Service Method:** `com.btctech.mailapp.service.ConnectionService.updateConnectionStatus(Long userId, Long connectionId, ConnectionStatus status)`
- **Path Parameters:**
  - `connectionId` (Long, required): Connection entry ID.
- **Request Body Example:**

```json
{
  "status": "DISCONNECTED"
}
```

- **Response Status:** `200 OK`
- **Database Tables Affected:** `connections` (UPDATE `status = :status`)
- **Frontend File & Function:** `Casbox.jsx` calling `connectionAPI.updateStatus(id, status)`

---

## 5. Contact Customization & Alias APIs (`/api/contact-aliases`)

### API 15: Get All Contact Aliases

- **Description:** Retrieves all personalized contact names configured by the authenticated user.
- **HTTP Method:** `GET`
- **Path:** `/api/contact-aliases`
- **Controller Method:** `com.btctech.mailapp.controller.ContactAliasController.getAllAliases()`
- **Service Method:** `com.btctech.mailapp.service.ContactAliasService.getAliasesForUser(Long userId)`
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
[
  {
    "id": 1,
    "userId": 5,
    "contactUserId": 8,
    "customName": "Alice (CEO Office)"
  }
]
```

- **Database Tables Affected:** `contact_aliases`
- **Frontend File & Function:** `Casbox.jsx` -> `fetchAliases()` calling `contactAliasAPI.getAllAliases()`

---

### API 16: Get Single Contact Alias

- **Description:** Retrieves the custom alias for a specific contact user ID.
- **HTTP Method:** `GET`
- **Path:** `/api/contact-aliases/{contactUserId}`
- **Controller Method:** `com.btctech.mailapp.controller.ContactAliasController.getAlias(@PathVariable Long contactUserId)`
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
{
  "id": 1,
  "userId": 5,
  "contactUserId": 8,
  "customName": "Alice (CEO Office)"
}
```

- **Database Tables Affected:** `contact_aliases`
- **Frontend File & Function:** `contactAliasAPI.getAlias(contactUserId)`

---

### API 17: Set or Update Contact Alias

- **Description:** Creates or updates a custom display name for a contact.
- **HTTP Method:** `PUT`
- **Path:** `/api/contact-aliases/{contactUserId}`
- **Controller Method:** `com.btctech.mailapp.controller.ContactAliasController.setAlias(@PathVariable Long contactUserId, @RequestBody ContactAliasRequest request)`
- **Service Method:** `com.btctech.mailapp.service.ContactAliasService.setAlias(Long userId, Long contactUserId, String customName)`
- **Request Body Example:**

```json
{
  "customName": "Alice (CEO Office)"
}
```

- **Response Status:** `200 OK`
- **Database Tables Affected:** `contact_aliases` (UPSERT)
- **Frontend File & Function:** `Casbox.jsx` -> `handleSaveAlias()` calling `contactAliasAPI.setAlias(id, customName)`

---

### API 18: Delete Contact Alias

- **Description:** Removes a custom display name, restoring default username display.
- **HTTP Method:** `DELETE`
- **Path:** `/api/contact-aliases/{contactUserId}`
- **Controller Method:** `com.btctech.mailapp.controller.ContactAliasController.deleteAlias(@PathVariable Long contactUserId)`
- **Service Method:** `com.btctech.mailapp.service.ContactAliasService.deleteAlias(Long userId, Long contactUserId)`
- **Response Status:** `204 No Content` (Empty body)
- **Database Tables Affected:** `contact_aliases` (DELETE)
- **Frontend File & Function:** `contactAliasAPI.deleteAlias(contactUserId)`

---

## 6. Contact Safety & Block APIs (`/api/blocked-contacts`)

### API 19: Get Blocked Contacts List

- **Description:** Lists all email addresses blocked by the authenticated user.
- **HTTP Method:** `GET`
- **Path:** `/api/blocked-contacts`
- **Controller Method:** `com.btctech.mailapp.controller.BlockedContactController.getBlockedContacts(Authentication authentication)`
- **Service Method:** `com.btctech.mailapp.service.BlockedContactService.getBlockedContacts(Long userId)`
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
[
  {
    "id": 4,
    "userId": 5,
    "blockedEmail": "spammer@external.com",
    "reason": "Unsolicited spam advertising",
    "blockedAt": "2026-10-15T10:14:00"
  }
]
```

- **Database Tables Affected:** `blocked_contacts`
- **Frontend File & Function:** `Casbox.jsx` calling `blockedContactsAPI.getBlocked()`

---

### API 20: Check if Contact is Blocked

- **Description:** Checks if a specific email address is blocked by the user or vice-versa.
- **HTTP Method:** `GET`
- **Path:** `/api/blocked-contacts/check?email={email}`
- **Controller Method:** `com.btctech.mailapp.controller.BlockedContactController.isBlocked(Authentication authentication, @RequestParam String email)`
- **Query Parameters:**
  - `email` (String, required): Email address to verify.
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
{
  "blocked": true
}
```

- **Database Tables Affected:** `blocked_contacts`
- **Frontend File & Function:** `Casbox.jsx` checks block status to disable message composer.

---

### API 21: Block a Contact

- **Description:** Blocks an email address from sending future Cashbox messages to the authenticated user.
- **HTTP Method:** `POST`
- **Path:** `/api/blocked-contacts`
- **Controller Method:** `com.btctech.mailapp.controller.BlockedContactController.blockContact(Authentication authentication, @RequestBody BlockContactRequest request)`
- **Service Method:** `com.btctech.mailapp.service.BlockedContactService.blockContact(Long userId, String email, String reason)`
- **Request Body Example:**

```json
{
  "email": "spammer@external.com",
  "reason": "Unwanted spam advertising"
}
```

- **Response Status:** `200 OK`
- **Response Body Example:**

```json
{
  "id": 4,
  "userId": 5,
  "blockedEmail": "spammer@external.com",
  "reason": "Unwanted spam advertising",
  "blockedAt": "2026-10-17T11:05:00"
}
```

- **Database Tables Affected:** `blocked_contacts` (INSERT)
- **Frontend File & Function:** `Casbox.jsx` -> `handleBlockContact()` calling `blockedContactsAPI.blockSender(email)`

---

### API 22: Unblock a Contact

- **Description:** Removes an email address from the user's blocked contacts list.
- **HTTP Method:** `DELETE`
- **Path:** `/api/blocked-contacts/{email}`
- **Controller Method:** `com.btctech.mailapp.controller.BlockedContactController.unblockContact(Authentication authentication, @PathVariable String email)`
- **Service Method:** `com.btctech.mailapp.service.BlockedContactService.unblockContact(Long userId, String email)`
- **Path Parameters:**
  - `email` (String, required): Email address to unblock.
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
{
  "success": true
}
```

- **Database Tables Affected:** `blocked_contacts` (DELETE)
- **Frontend File & Function:** `Casbox.jsx` -> `handleUnblockContact()` calling `blockedContactsAPI.unblockSender(email)`

---

## 7. User Settings & Message Requests (`/api/users/settings`)

### API 23: Fetch User Settings (Casbox Accepted List)

- **Description:** Returns the user's settings, including `casboxAccepted` approved email addresses used to categorize conversations into "Messages" vs "Message Requests".
- **HTTP Method:** `GET`
- **Path:** `/api/users/settings`
- **Controller Method:** `com.btctech.mailapp.controller.UserController.getSettings()`
- **Service Method:** `com.btctech.mailapp.service.UserService.getSettings(Long userId)`
- **Response Status:** `200 OK`
- **Response Body Example:**

```json
{
  "id": 5,
  "casboxAccepted": [
    "alice@bnxmail.com",
    "charlie@bnxmail.com"
  ],
  "soundEnabled": true,
  "notificationsEnabled": true
}
```

- **Database Tables Affected:** `user_settings`, `user_casbox_accepted`
- **Frontend File & Function:** `Casbox.jsx` calling `userAPI.getSettings()`

---

### API 24: Update User Settings (Casbox Accepted List)

- **Description:** Adds or removes senders from the `casboxAccepted` list when accepting or rejecting message requests.
- **HTTP Method:** `PATCH`
- **Path:** `/api/users/settings`
- **Controller Method:** `com.btctech.mailapp.controller.UserController.patchSettings(@RequestBody UserSettingsDto request)`
- **Service Method:** `com.btctech.mailapp.service.UserService.updateSettings(Long userId, ...)`
- **Request Body Example:**

```json
{
  "casboxAccepted": [
    "alice@bnxmail.com",
    "charlie@bnxmail.com",
    "david@partner.com"
  ]
}
```

- **Response Status:** `200 OK`
- **Database Tables Affected:** `user_settings`, `user_casbox_accepted`
- **Frontend File & Function:** `Casbox.jsx` -> "Accept Request" calling `userAPI.patchSettings(data)`

---

## 8. WebSocket & Real-Time Messaging Reference

Configured in `WebSocketConfig.java` using Spring WebSocket (STOMP sub-protocol) and SockJS fallback.

### 8.1 Handshake & Authentication

- **Endpoint:** `/ws` (or `/ws/` for SockJS)
- **Access Rule:** `permitAll()` at HTTP handshake layer in `SecurityConfig.java`.
- **STOMP Connect Header:**

  ```http
  Authorization: Bearer <jwt_access_token>
  ```

- **App Destination Prefix:** `/app`
- **User Destination Prefix:** `/user`
- **Broker Prefixes:** `/topic`, `/queue`

### 8.2 Client Subscriptions

#### 1. Inbound Messages & Edits

- **Destination:** `/user/queue/casbox/messages`
- **Trigger:** Backend executes `template.convertAndSendToUser(receiverEmail, "/queue/casbox/messages", dto)` on message send or edit.
- **Payload Example:**

```json
{
  "id": 1045,
  "senderEmail": "alice@bnxmail.com",
  "receiverEmail": "bob@bnxmail.com",
  "subject": "Discussion",
  "body": "Hello Bob, are you available for a quick sync?",
  "attachmentsJson": null,
  "status": "SENT",
  "timestamp": "2026-10-17T11:10:00.000+00:00",
  "isEdited": false
}
```

#### 2. Delivery & Read Status Updates

- **Destination:** `/user/queue/casbox/status`
- **Trigger:** Backend executes `template.convertAndSendToUser(senderEmail, "/queue/casbox/status", dto)` on read status transition.
- **Payload Example:**

```json
{
  "id": 1045,
  "senderEmail": "alice@bnxmail.com",
  "receiverEmail": "bob@bnxmail.com",
  "status": "SEEN",
  "timestamp": "2026-10-17T11:10:00.000+00:00"
}
```

---

## 9. Data Transfer Objects (DTOs) & JSON Schemas

### `CasboxSendRequest`

```java
public class CasboxSendRequest {
    @NotBlank(message = "Receiver email is required")
    private String receiverEmail;
    private String subject;
    @NotBlank(message = "Body is required")
    private String body;
    private String attachmentsJson;
}
```

### `CasboxEditRequest`

```java
public class CasboxEditRequest {
    private String body;
    private String content; // alias for body
}
```

### `CasboxArchiveRequest`

```java
public class CasboxArchiveRequest {
    private List<Long> messageIds;
    private Boolean archived = true;
}
```

### `CasboxStatusRequest`

```java
public class CasboxStatusRequest {
    @NotEmpty(message = "Message IDs cannot be empty")
    private List<Long> messageIds;
    @NotBlank(message = "Status is required")
    private String status; // DELIVERED, SEEN
}
```

### `CasboxMessageDto` (Complete Response Model)

```json
{
  "id": 1042,
  "senderEmail": "bob@bnxmail.com",
  "receiverEmail": "alice@bnxmail.com",
  "subject": "Discussion",
  "body": "Hello Alice, please review the document.",
  "attachmentsJson": "[{\"name\":\"doc.pdf\",\"size\":102400,\"url\":\"https://...\"}]",
  "status": "DELIVERED",
  "timestamp": "2026-10-17T09:30:00.000+00:00",
  "senderUsername": "bob",
  "receiverUsername": "alice",
  "senderDisplayName": "Bob",
  "receiverDisplayName": "Alice (CEO Office)",
  "contactDisplayName": "Alice (CEO Office)",
  "contactUsername": "alice",
  "contactUserId": 8,
  "customName": "Alice (CEO Office)",
  "isArchived": false,
  "senderArchived": false,
  "receiverArchived": false,
  "isAccepted": true,
  "isEdited": false
}
```

New API listings :

Casbox
Archive APIs
Batch Archive / Unarchive Messages:

Method: PATCH
Endpoint: /api/casbox/archive
Service:

casboxAPI.updateArchiveStatus(messageIds, archived)
Request Body:
json
{
  "messageIds": [101, 102],
  "archived": true
}
Backend Controller:

CasboxController.updateArchiveStatus
Single Message Archive / Unarchive:

Method: PATCH
Endpoint: /api/casbox/{id}/archive?archived=true (or false)
Service:

casboxAPI.archiveMessage(id, archived)
Backend Controller:

CasboxController.archiveMessage
Client-side State / Cache Keys:

bnx_casbox_archived_message_ids (stores array of archived message IDs)
bnx_casbox_unarchived_message_ids (stores array of unarchived message IDs)
Star APIs
Casbox In-App Message Starring:
In Casbox, individual chat messages are starred and persisted via user-scoped localStorage:
bnx_casbox_starred_map_${userKey} & bnx_casbox_starred_map (stores message objects mapped by key)
bnx_casbox_starred_messages_${userKey} & bnx_casbox_starred_messages (stores list of starred message IDs)
Linked Email / Thread Starring:
When a message is synchronized with IMAP mail:
Method: POST
Endpoint: /api/mail/star (Query: ?uid={uid}&folder={folder})
Service: mailAPI.toggleStar(uid, folder)
2. Colab (Groups & Direct Chat)
Archive APIs
Colab Archived Messages / Groups (

src/pages/Groups.jsx
):
Casbox Messages in Colab Archive:
Method: PATCH
Endpoint: /api/casbox/archive
Service:

casboxAPI.updateArchiveStatus(targetIds, false)
Colab Groups Archive:
Service: chatAPI.archiveGroup(chatId) / chatAPI.archiveChat(chatId)
Client Storage Key: bnx_colab_archived_group_ids / bnx_colab_archived_group_ids_${userKey}
Star APIs
Colab Starred Groups (

src/pages/Groups.jsx
):
Service: chatAPI.toggleStarGroup(chat.id) or chatAPI.starGroup(chat.id, isStarred)
Client Storage Key: bnx_colab_starred_group_ids (stores set of starred group chat IDs)
