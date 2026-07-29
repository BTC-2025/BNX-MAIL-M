# Group (Colab) & Casbox API Reference

This document covers the request bodies, query variables, path parameters, headers, and response formats for both the **Group Chat / Colab** and **Casbox (Direct Message Box)** backend modules, along with their matching frontend JavaScript client mappings.

---

# 1. Group & Chat APIs (Colab)
These endpoints serve the Colab (Group Collaboration) client interfaces on the frontend.

## 1.1 Create Group Chat (Colab Channel)
Registers a new collaborative group workspace.
*   **Frontend Client Call**: `chatAPI.createGroupChat(data)`
*   **Method & Path**: `POST /api/chat/group`
*   **Headers**: `Authorization: Bearer <accessToken>`
*   **Request Body**:
    ```json
    {
      "name": "Project Apollo",
      "members": [
        "developer1@bnxmail.com",
        "developer2@bnxmail.com"
      ]
    }
    ```
*   **Response (200 OK)**:
    ```json
    {
      "id": 12,
      "name": "Project Apollo",
      "type": "GROUP",
      "memberEmails": [
        "sridharan05@bnxmail.com",
        "developer1@bnxmail.com",
        "developer2@bnxmail.com"
      ],
      "lastMessage": "",
      "lastMessageTime": "",
      "unreadCount": 0,
      "creatorEmail": "sridharan05@bnxmail.com"
    }
    ```

## 1.2 Get User Conversations List
Fetch all active group conversations for a specific user email.
*   **Frontend Client Call**: `chatAPI.getUserChats(email)`
*   **Method & Path**: `GET /api/chat/user/{email}`
*   **Response (200 OK)**:
    ```json
    [
      {
        "id": 12,
        "name": "Project Apollo",
        "type": "GROUP",
        "memberEmails": [
          "sridharan05@bnxmail.com",
          "developer1@bnxmail.com",
          "developer2@bnxmail.com"
        ],
        "lastMessage": "Initial setup done.",
        "lastMessageTime": "2026-07-28T11:45:00",
        "unreadCount": 0,
        "creatorEmail": "sridharan05@bnxmail.com"
      }
    ]
    ```

## 1.3 Get Chat Message History
Fetch the message archive of a specific group chat channel.
*   **Frontend Client Call**: `chatAPI.getMessageHistory(chatId)`
*   **Method & Path**: `GET /api/chat/{chatId}/messages`
*   **Response (200 OK)**:
    ```json
    [
      {
        "id": 352,
        "chatId": 12,
        "sender": "sridharan05@bnxmail.com",
        "content": "Initial setup done.",
        "timestamp": "2026-07-28T11:45:00",
        "attachmentsJson": "[]"
      }
    ]
    ```

## 1.4 Send Message via HTTP REST
Post a text or media message to a group conversation.
*   **Frontend Client Call**: `chatAPI.sendMessage(data)`
*   **Method & Path**: `POST /api/chat/message`
*   **Request Body**:
    ```json
    {
      "chatId": 12,
      "sender": "sridharan05@bnxmail.com",
      "message": "Let's align tomorrow",
      "attachmentsJson": "[]"
    }
    ```
*   **Response (200 OK)**:
    ```json
    {
      "id": 353,
      "chatId": 12,
      "sender": "sridharan05@bnxmail.com",
      "content": "Let's align tomorrow",
      "timestamp": "2026-07-28T11:46:12",
      "attachmentsJson": "[]"
    }
    ```

## 1.5 Add Members to Group Chat
Invite additional members to an active group chat.
*   **Frontend Client Call**: `chatAPI.addMembers(chatId, data)`
*   **Method & Path**: `POST /api/chat/{chatId}/members`
*   **Headers**: `Authorization: Bearer <accessToken>`
*   **Request Body**:
    ```json
    {
      "emails": ["newjoiner@bnxmail.com"]
    }
    ```
*   **Response (200 OK)**:
    ```json
    {
      "id": 12,
      "name": "Project Apollo",
      "type": "GROUP",
      "memberEmails": [
        "sridharan05@bnxmail.com",
        "developer1@bnxmail.com",
        "developer2@bnxmail.com",
        "newjoiner@bnxmail.com"
      ],
      "lastMessage": "Let's align tomorrow",
      "lastMessageTime": "2026-07-28T11:46:12",
      "unreadCount": 0,
      "creatorEmail": "sridharan05@bnxmail.com"
    }
    ```

## 1.6 List Group Members
*   **Frontend Client Call**: `chatAPI.getMembers(chatId)`
*   **Method & Path**: `GET /api/chat/{chatId}/members`
*   **Response (200 OK)**:
    ```json
    [
      "sridharan05@bnxmail.com",
      "developer1@bnxmail.com",
      "developer2@bnxmail.com",
      "newjoiner@bnxmail.com"
    ]
    ```

## 1.7 Manage Pending Invitations
*   **List Invitations**: `chatAPI.getInvitations()`
    *   **Method & Path**: `GET /api/chat/invitations`
    *   **Headers**: `Authorization: Bearer <accessToken>`
    *   **Response**:
        ```json
        [
          {
            "id": 4,
            "chatId": 12,
            "chatName": "Project Apollo",
            "chatType": "GROUP",
            "inviterEmail": "sridharan05@bnxmail.com",
            "status": "PENDING",
            "createdAt": "2026-07-28T11:46:12"
          }
        ]
        ```
*   **Accept Invitation**: `chatAPI.acceptInvitation(id)`
    *   **Method & Path**: `POST /api/chat/invitations/{id}/accept`
    *   **Headers**: `Authorization: Bearer <accessToken>`
    *   **Response**: *200 OK (Empty response body)*
*   **Reject Invitation**: `chatAPI.rejectInvitation(id)`
    *   **Method & Path**: `POST /api/chat/invitations/{id}/reject`
    *   **Headers**: `Authorization: Bearer <accessToken>`
    *   **Response**: *200 OK (Empty response body)*

## 1.8 Send/Get Broadcasts
*   **Send Broadcast**: `chatAPI.sendBroadcast(chatId, data)`
    *   **Method & Path**: `POST /api/chat/{chatId}/broadcast`
    *   **Headers**: `Authorization: Bearer <accessToken>`
    *   **Request Body**:
        ```json
        {
          "subject": "System downtime notice",
          "body": "System will be down for maintenance at 10 PM tonight.",
          "attachmentsJson": "[]"
        }
        ```
    *   **Response (200 OK)**:
        ```json
        {
          "id": 9,
          "subject": "System downtime notice",
          "body": "System will be down for maintenance at 10 PM tonight.",
          "from": "sridharan05@bnxmail.com",
          "sentDate": "2026-07-28T11:48:00",
          "attachmentsJson": "[]"
        }
        ```
*   **Get Broadcasts**: `chatAPI.getBroadcasts(chatId)`
    *   **Method & Path**: `GET /api/chat/{chatId}/broadcasts`
    *   **Response (200 OK)**:
        ```json
        [
          {
            "id": 9,
            "subject": "System downtime notice",
            "body": "System will be down for maintenance at 10 PM tonight.",
            "from": "sridharan05@bnxmail.com",
            "sentDate": "2026-07-28T11:48:00",
            "attachmentsJson": "[]"
          }
        ]
        ```

## 1.9 Manage Group Settings
*   **Leave Group Chat**: `chatAPI.leaveGroup(chatId)`
    *   **Method & Path**: `POST /api/chat/{id}/leave`
    *   **Headers**: `Authorization: Bearer <accessToken>`
    *   **Response**: `{"message": "Left chat successfully"}`
*   **Delete Group Chat (Creator only)**: `chatAPI.deleteGroup(chatId)`
    *   **Method & Path**: `DELETE /api/chat/{id}`
    *   **Headers**: `Authorization: Bearer <accessToken>`
    *   **Response**: `{"message": "Chat deleted successfully"}`
*   **Rename Group**: `chatAPI.renameGroup(chatId, name)`
    *   **Method & Path**: `PATCH /api/chat/{id}/name`
    *   **Headers**: `Authorization: Bearer <accessToken>`
    *   **Request Body**: `{"name": "New Group Name"}`
    *   **Response**: *Returns updated ChatDTO object*

---

# 2. Casbox APIs (Direct Messaging & Contact Verification)
These endpoints handle instant messaging, delivery reporting, status mapping, and contact verification/friend request handling.

## 2.1 Get All Messages (Overview)
*   **Frontend Client Call**: `casboxAPI.getAllMessages()`
*   **Method & Path**: `GET /api/casbox`
*   **Headers**: `Authorization: Bearer <accessToken>`
*   **Response (200 OK)**:
    ```json
    [
      {
        "id": 105,
        "senderEmail": "sridharan05@bnxmail.com",
        "receiverEmail": "moniraj4914@bnxmail.com",
        "subject": "Discussion",
        "body": "Hey, did you review the latest release?",
        "attachmentsJson": "[]",
        "status": "SENT",
        "timestamp": "2026-07-28T11:32:00"
      }
    ]
    ```

## 2.2 Get Chat Thread with Contact
*   **Frontend Client Call**: `casboxAPI.getThread(contactEmail)`
*   **Method & Path**: `GET /api/casbox/thread/{contactEmail}`
*   **Headers**: `Authorization: Bearer <accessToken>`
*   **Response (200 OK)**:
    ```json
    [
      {
        "id": 104,
        "senderEmail": "moniraj4914@bnxmail.com",
        "receiverEmail": "sridharan05@bnxmail.com",
        "subject": "Discussion",
        "body": "Yes, I will check it in 5 mins",
        "attachmentsJson": "[]",
        "status": "SEEN",
        "timestamp": "2026-07-28T11:30:15"
      }
    ]
    ```

## 2.3 Send Message (Casbox)
*   **Frontend Client Call**: `casboxAPI.sendMessage(data)`
*   **Method & Path**: `POST /api/casbox/send`
*   **Headers**: `Authorization: Bearer <accessToken>`
*   **Request Body**:
    ```json
    {
      "receiverEmail": "moniraj4914@bnxmail.com",
      "subject": "Discussion",
      "body": "Hey, did you review the latest release?",
      "attachmentsJson": "[]"
    }
    ```
*   **Response (200 OK)**:
    ```json
    {
      "id": 105,
      "senderEmail": "sridharan05@bnxmail.com",
      "receiverEmail": "moniraj4914@bnxmail.com",
      "subject": "Discussion",
      "body": "Hey, did you review the latest release?",
      "attachmentsJson": "[]",
      "status": "SENT",
      "timestamp": "2026-07-28T11:32:00"
    }
    ```

## 2.4 Update Messages Status (Read Receipt)
*   **Frontend Client Call**: `casboxAPI.updateStatus(data)`
*   **Method & Path**: `PATCH /api/casbox/status`
*   **Headers**: `Authorization: Bearer <accessToken>`
*   **Request Body**:
    ```json
    {
      "messageIds": [104, 105],
      "status": "SEEN"
    }
    ```
*   **Response (200 OK)**: *200 OK (Empty response body)*

## 2.5 Report Delivered Status (All Unseen Messages)
*   **Frontend Client Call**: `casboxAPI.markAsDelivered()`
*   **Method & Path**: `POST /api/casbox/delivered`
*   **Headers**: `Authorization: Bearer <accessToken>`
*   **Response (200 OK)**: *200 OK (Empty response body)*

## 2.6 Accept Chat Request
Accepts an incoming chat request from a new contact.
*   **Frontend Client Call**: `userAPI.updateSettings({ casboxAccepted: newAccepted })`
*   **Method & Path**: `PATCH /api/users/settings`
*   **Headers**: `Authorization: Bearer <accessToken>`
*   **Request Body** (Includes the updated list of accepted sender emails):
    ```json
    {
      "casboxAccepted": [
        "sender1@bnxmail.com",
        "sender2@bnxmail.com"
      ]
    }
    ```
*   **Response (200 OK)**: *Returns full UserSettingsDTO response*

## 2.7 Block Chat Request
Blocks a sender from initiating conversations.
*   **Frontend Client Call**: `userAPI.updateSettings({ casboxBlocked: newBlocked })`
*   **Method & Path**: `PATCH /api/users/settings`
*   **Headers**: `Authorization: Bearer <accessToken>`
*   **Request Body** (Includes the updated list of blocked sender emails):
    ```json
    {
      "casboxBlocked": [
        "sender1@bnxmail.com",
        "sender2@bnxmail.com"
      ]
    }
    ```
*   **Response (200 OK)**: *Returns full UserSettingsDTO response*
