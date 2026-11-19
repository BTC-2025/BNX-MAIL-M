import '../config/endpoint_descriptor.dart';

/// Central registry listing all module APIs in Bit Tool (excluding login APIs).
///
/// Provides programmatic introspection, searchable lists, and JSON serialization
/// for host apps (like Cliks Business) integrating Bit Tool as a side feature.
class BitToolApiRegistry {
  BitToolApiRegistry._();

  /// Comprehensive catalog of all module API endpoints.
  static const List<EndpointDescriptor> allEndpoints = [
    // ==========================================
    // 1. Contacts Module
    // ==========================================
    EndpointDescriptor(
      module: 'Contacts',
      title: 'Get Paginated Contacts',
      method: 'GET',
      path: '/get',
      fullUrl: 'https://api.bit-tool.com/api/contacts/get?page=1&limit=20',
      description: 'Retrieves a paginated list of contacts with optional keyword search.',
      requiresAuth: true,
      queryParameters: {
        'page': 'Page number (default: 1)',
        'limit': 'Items per page (default: 20)',
        'search': 'Optional search term to filter by name, email, or phone',
      },
      sampleResponse: {
        'data': [
          {
            'id': 'contact_123',
            'firstName': 'Sarah',
            'lastName': 'Jenkins',
            'email': 'sarah@cliks.com',
            'phone': '+91 9876543210',
            'company': 'Cliks Business',
            'role': 'Finance Lead',
          }
        ],
        'count': 1,
        'page': 1,
        'limit': 20,
      },
    ),
    EndpointDescriptor(
      module: 'Contacts',
      title: 'Get All Contacts (Cross-App)',
      method: 'GET',
      path: '/get-all',
      fullUrl: 'https://api.bit-tool.com/api/contacts/get-all?offset=0&limit=100',
      description: 'Fetches the complete contact collection across all integrated workspaces with automatic pagination.',
      requiresAuth: true,
      queryParameters: {
        'offset': 'Starting index offset (default: 0)',
        'limit': 'Batch size (default: 100)',
      },
      sampleResponse: {
        'data': [
          {
            'id': 'contact_123',
            'firstName': 'Alex',
            'lastName': 'Rivera',
            'email': 'alex@cliks.com',
            'company': 'Cliks Business',
            'role': 'Auditor',
          }
        ],
        'totalCount': 25,
      },
    ),
    EndpointDescriptor(
      module: 'Contacts',
      title: 'Get Contact By ID',
      method: 'GET',
      path: '/get/:id',
      fullUrl: 'https://api.bit-tool.com/api/contacts/get/contact_123',
      description: 'Retrieves the complete profile and details of a single contact by unique ID.',
      requiresAuth: true,
      sampleResponse: {
        'data': {
          'id': 'contact_123',
          'firstName': 'James',
          'lastName': 'Miller',
          'email': 'james@cliks.com',
          'phone': '+91 9123456789',
          'company': 'Cliks Business',
          'role': 'Account Manager',
          'notes': 'Preferred contact for commercial lease',
        }
      },
    ),
    EndpointDescriptor(
      module: 'Contacts',
      title: 'Create Contact',
      method: 'POST',
      path: '/add',
      fullUrl: 'https://api.bit-tool.com/api/contacts/add',
      description: 'Creates a new contact record.',
      requiresAuth: true,
      requestBodySchema: {
        'firstName': 'string (required)',
        'lastName': 'string (required)',
        'email': 'string (optional)',
        'phone': 'string (optional)',
        'company': 'string (optional)',
        'role': 'string (optional)',
        'notes': 'string (optional)',
      },
      sampleResponse: {
        'success': true,
        'data': {
          'id': 'contact_456',
          'firstName': 'Sarah',
          'lastName': 'Jenkins',
          'email': 'sarah@cliks.com',
        }
      },
    ),
    EndpointDescriptor(
      module: 'Contacts',
      title: 'Update Contact',
      method: 'PUT',
      path: '/update/:id',
      fullUrl: 'https://api.bit-tool.com/api/contacts/update/contact_123',
      description: 'Updates specified fields of an existing contact.',
      requiresAuth: true,
      requestBodySchema: {
        'firstName': 'string (optional)',
        'lastName': 'string (optional)',
        'email': 'string (optional)',
        'phone': 'string (optional)',
        'company': 'string (optional)',
        'role': 'string (optional)',
        'notes': 'string (optional)',
      },
      sampleResponse: {
        'success': true,
        'data': {'id': 'contact_123', 'notes': 'Updated notes'},
      },
    ),
    EndpointDescriptor(
      module: 'Contacts',
      title: 'Delete Contact',
      method: 'DELETE',
      path: '/delete/:id',
      fullUrl: 'https://api.bit-tool.com/api/contacts/delete/contact_123',
      description: 'Permanently removes a contact record.',
      requiresAuth: true,
      sampleResponse: {'success': true, 'message': 'Contact deleted successfully'},
    ),

    // ==========================================
    // 2. Notes Module
    // ==========================================
    EndpointDescriptor(
      module: 'Notes',
      title: 'Get Notes',
      method: 'GET',
      path: '/',
      fullUrl: 'https://api.bit-tool.com/api/notes?allApps=true',
      description: 'Fetches notes list, with cross-app support for notes created in other apps.',
      requiresAuth: true,
      queryParameters: {
        'allApps': 'Set to true to fetch notes across all applications',
      },
      sampleResponse: {
        'data': [
          {
            'id': 'note_101',
            'title': 'Q4 Commercial Rent Schedule',
            'content': 'Office lease payable on 1st of every month',
            'color': '#A7F3D0',
            'isPinned': true,
            'applicationName': 'Cliks Business',
          }
        ]
      },
    ),
    EndpointDescriptor(
      module: 'Notes',
      title: 'Get Note By ID',
      method: 'GET',
      path: '/:id',
      fullUrl: 'https://api.bit-tool.com/api/notes/note_101',
      description: 'Retrieves single note details and contents.',
      requiresAuth: true,
      sampleResponse: {
        'data': {
          'id': 'note_101',
          'title': 'Q4 Commercial Rent Schedule',
          'content': 'Office lease payable on 1st of every month',
          'color': '#A7F3D0',
          'isPinned': true,
        }
      },
    ),
    EndpointDescriptor(
      module: 'Notes',
      title: 'Create Note',
      method: 'POST',
      path: '/create',
      fullUrl: 'https://api.bit-tool.com/api/notes/create',
      description: 'Creates a new note with color coding, pin status, and originating application name.',
      requiresAuth: true,
      requestBodySchema: {
        'title': 'string (required)',
        'content': 'string (required)',
        'color': 'hex string (e.g., #A7F3D0)',
        'isPinned': 'boolean (default: false)',
        'applicationName': 'string (e.g. Cliks Business)',
      },
      sampleResponse: {
        'data': {
          'id': 'note_102',
          'title': 'Vendor Follow-up',
          'content': 'Follow up on internet leased line billing invoice',
        }
      },
    ),
    EndpointDescriptor(
      module: 'Notes',
      title: 'Update Note',
      method: 'PUT',
      path: '/update/:id',
      fullUrl: 'https://api.bit-tool.com/api/notes/update/note_101',
      description: 'Updates note title, content, pin state, archive state, or color.',
      requiresAuth: true,
      requestBodySchema: {
        'title': 'string (optional)',
        'content': 'string (optional)',
        'color': 'hex string (optional)',
        'isPinned': 'boolean (optional)',
        'isArchived': 'boolean (optional)',
      },
      sampleResponse: {
        'data': {'id': 'note_101', 'isPinned': false},
      },
    ),
    EndpointDescriptor(
      module: 'Notes',
      title: 'Delete Note',
      method: 'DELETE',
      path: '/delete/:id',
      fullUrl: 'https://api.bit-tool.com/api/notes/delete/note_101',
      description: 'Deletes a note record by ID.',
      requiresAuth: true,
      sampleResponse: {'success': true, 'message': 'Note deleted successfully'},
    ),

    // ==========================================
    // 3. Calendar Module
    // ==========================================
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Get Event Categories',
      method: 'GET',
      path: '/categories',
      fullUrl: 'https://api.bit-tool.com/api/calendar/categories',
      description: 'Fetches all custom or default event categories with assigned color hex codes.',
      requiresAuth: true,
      sampleResponse: {
        'data': [
          {'id': 'cat_1', 'name': 'Finance & Billing', 'color': '#10B981'},
          {'id': 'cat_2', 'name': 'Client Meeting', 'color': '#3B82F6'},
        ]
      },
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Create Event Category',
      method: 'POST',
      path: '/categories',
      fullUrl: 'https://api.bit-tool.com/api/calendar/categories',
      description: 'Creates a new category for tagging calendar events.',
      requiresAuth: true,
      requestBodySchema: {
        'name': 'string (required)',
        'color': 'hex color string (required, e.g. #3B82F6)',
      },
      sampleResponse: {
        'data': {'id': 'cat_3', 'name': 'Audit', 'color': '#EF4444'},
      },
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Get Month Events',
      method: 'GET',
      path: '/events/month',
      fullUrl: 'https://api.bit-tool.com/api/calendar/events/month?year=2026&month=11',
      description: 'Fetches all scheduled calendar events for a specific month and year.',
      requiresAuth: true,
      queryParameters: {
        'year': '4-digit year (e.g. 2026)',
        'month': '2-digit month (01-12)',
      },
      sampleResponse: {
        'data': [
          {
            'id': 'evt_201',
            'title': 'Commercial Office Rent Due',
            'startTime': '2026-11-01T10:00:00.000Z',
            'endTime': '2026-11-01T11:00:00.000Z',
            'categoryId': 'cat_1',
            'description': 'Disburse Rs 45,000 for office rent',
          }
        ]
      },
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Create Calendar Event',
      method: 'POST',
      path: '/events',
      fullUrl: 'https://api.bit-tool.com/api/calendar/events',
      description: 'Creates a new calendar event with date range and category.',
      requiresAuth: true,
      requestBodySchema: {
        'title': 'string (required)',
        'startTime': 'ISO 8601 string (required)',
        'endTime': 'ISO 8601 string (required)',
        'categoryId': 'string (required)',
        'description': 'string (optional)',
        'location': 'string (optional)',
      },
      sampleResponse: {
        'data': {'id': 'evt_202', 'title': 'GST Filing Deadline'},
      },
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Update Calendar Event',
      method: 'PUT',
      path: '/events/:id',
      fullUrl: 'https://api.bit-tool.com/api/calendar/events/evt_201',
      description: 'Updates an existing event schedule, title, or category.',
      requiresAuth: true,
      requestBodySchema: {
        'title': 'string (optional)',
        'startTime': 'ISO 8601 string (optional)',
        'endTime': 'ISO 8601 string (optional)',
        'categoryId': 'string (optional)',
        'description': 'string (optional)',
      },
      sampleResponse: {
        'data': {'id': 'evt_201', 'title': 'Updated Title'},
      },
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Delete Calendar Event',
      method: 'DELETE',
      path: '/events/:id',
      fullUrl: 'https://api.bit-tool.com/api/calendar/events/evt_201',
      description: 'Deletes a scheduled event by ID.',
      requiresAuth: true,
      sampleResponse: {'success': true},
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Get Reminders by Date',
      method: 'GET',
      path: '/reminders',
      fullUrl: 'https://api.bit-tool.com/api/calendar/reminders?date=2026-11-10',
      description: 'Fetches reminders scheduled for a specific date (YYYY-MM-DD).',
      requiresAuth: true,
      queryParameters: {
        'date': 'Date in YYYY-MM-DD format',
      },
      sampleResponse: {
        'data': [
          {
            'id': 'rem_301',
            'title': 'Internet Leased Line Bill Payment',
            'date': '2026-11-10',
            'time': '14:30',
            'isCompleted': false,
          }
        ]
      },
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Create Reminder',
      method: 'POST',
      path: '/reminders',
      fullUrl: 'https://api.bit-tool.com/api/calendar/reminders',
      description: 'Creates a reminder item for a specific date and time.',
      requiresAuth: true,
      requestBodySchema: {
        'title': 'string (required)',
        'date': 'YYYY-MM-DD string (required)',
        'time': 'HH:mm string (required)',
        'description': 'string (optional)',
      },
      sampleResponse: {
        'data': {'id': 'rem_302', 'title': 'Pay vendor invoice'},
      },
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Update Reminder',
      method: 'PUT',
      path: '/reminders/:id',
      fullUrl: 'https://api.bit-tool.com/api/calendar/reminders/rem_301',
      description: 'Updates reminder title, time, or date.',
      requiresAuth: true,
      sampleResponse: {'data': {'id': 'rem_301', 'time': '16:00'}},
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Complete Reminder',
      method: 'PUT',
      path: '/reminders/:id/complete',
      fullUrl: 'https://api.bit-tool.com/api/calendar/reminders/rem_301/complete',
      description: 'Marks a reminder as completed.',
      requiresAuth: true,
      sampleResponse: {'data': {'id': 'rem_301', 'isCompleted': true}},
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Delete Reminder',
      method: 'DELETE',
      path: '/reminders/:id',
      fullUrl: 'https://api.bit-tool.com/api/calendar/reminders/rem_301',
      description: 'Deletes a reminder item.',
      requiresAuth: true,
      sampleResponse: {'success': true},
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Get Date-Linked Notes',
      method: 'GET',
      path: '/notes',
      fullUrl: 'https://api.bit-tool.com/api/calendar/notes?date=2026-11-01',
      description: 'Fetches notes linked specifically to a calendar date.',
      requiresAuth: true,
      queryParameters: {'date': 'YYYY-MM-DD string'},
      sampleResponse: {
        'data': [
          {'id': 'dnote_1', 'title': 'Rent Memo', 'content': 'Paid via HDFC NEFT'}
        ]
      },
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Create Date-Linked Note',
      method: 'POST',
      path: '/notes',
      fullUrl: 'https://api.bit-tool.com/api/calendar/notes',
      description: 'Creates a note tied to a calendar date.',
      requiresAuth: true,
      requestBodySchema: {
        'title': 'string (required)',
        'date': 'YYYY-MM-DD string (required)',
        'content': 'string (required)',
      },
      sampleResponse: {'data': {'id': 'dnote_2', 'title': 'Tax Note'}},
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Update Date-Linked Note',
      method: 'PUT',
      path: '/notes/:id',
      fullUrl: 'https://api.bit-tool.com/api/calendar/notes/dnote_1',
      description: 'Updates date-linked note content or title.',
      requiresAuth: true,
      sampleResponse: {'data': {'id': 'dnote_1', 'content': 'Updated memo'}},
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Delete Date-Linked Note',
      method: 'DELETE',
      path: '/notes/:id',
      fullUrl: 'https://api.bit-tool.com/api/calendar/notes/dnote_1',
      description: 'Deletes a date-linked note.',
      requiresAuth: true,
      sampleResponse: {'success': true},
    ),
    EndpointDescriptor(
      module: 'Calendar',
      title: 'Global Calendar Search',
      method: 'GET',
      path: '/search',
      fullUrl: 'https://api.bit-tool.com/api/calendar/search?query=Office+Rent',
      description: 'Searches across all events, reminders, and date notes.',
      requiresAuth: true,
      queryParameters: {'query': 'Search keyword'},
      sampleResponse: {
        'events': [{'id': 'evt_201', 'title': 'Commercial Office Rent'}],
        'reminders': [],
        'notes': [],
      },
    ),

    // ==========================================
    // 4. Calculator Module
    // ==========================================
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Get Standard Calculator History',
      method: 'GET',
      path: '/history',
      fullUrl: 'https://api.bit-tool.com/api/calculator/history',
      description: 'Fetches saved calculation tape sessions for the authenticated user.',
      requiresAuth: true,
      sampleResponse: {
        'data': [
          {
            'id': 'sess_501',
            'title': 'Monthly Office Expenses',
            'mode': 'business',
            'currency': 'INR',
            'totalAmount': 49200.0,
            'itemCount': 2,
          }
        ]
      },
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Get Cross-App Calculator History',
      method: 'GET',
      path: '/history/all',
      fullUrl: 'https://api.bit-tool.com/api/calculator/history/all',
      description: 'Fetches calculation history sessions across all applications (e.g. Cliks Business, BNX Mail, Bit Tool).',
      requiresAuth: true,
      sampleResponse: {
        'data': [
          {
            'id': 'sess_502',
            'title': 'Invoice #4010 Breakdown',
            'applicationName': 'Cliks Business',
            'totalAmount': 45000.0,
          }
        ]
      },
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Get Specific Session with Tape Items',
      method: 'GET',
      path: '/sessions/:id',
      fullUrl: 'https://api.bit-tool.com/api/calculator/sessions/sess_501',
      description: 'Fetches detailed tape sequence and steps of a calculation session.',
      requiresAuth: true,
      sampleResponse: {
        'data': {
          'id': 'sess_501',
          'title': 'Office Expenses',
          'items': [
            {'sequence': 1, 'operator': '=', 'value': 45000, 'runningTotal': 45000, 'label': 'Rent'},
            {'sequence': 2, 'operator': '+', 'value': 4200, 'runningTotal': 49200, 'label': 'Internet'},
          ]
        }
      },
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Create Calculator Session',
      method: 'POST',
      path: '/sessions',
      fullUrl: 'https://api.bit-tool.com/api/calculator/sessions',
      description: 'Creates a new tape session header.',
      requiresAuth: true,
      requestBodySchema: {
        'title': 'string (required)',
        'mode': 'string (business / gst / discount, default: business)',
        'currency': 'string (default: INR)',
        'applicationName': 'string (optional, e.g. Cliks Business)',
      },
      sampleResponse: {
        'data': {'id': 'sess_503', 'title': 'Tape - New Session'},
      },
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Add Tape Item to Session',
      method: 'POST',
      path: '/sessions/:sessionId/items',
      fullUrl: 'https://api.bit-tool.com/api/calculator/sessions/sess_501/items',
      description: 'Appends a calculation operation step to the tape.',
      requiresAuth: true,
      requestBodySchema: {
        'sequence': 'integer (step order, e.g. 1)',
        'value': 'number (e.g. 45000)',
        'operator': 'string (+, -, *, /, =)',
        'runningTotal': 'number (e.g. 45000)',
        'label': 'string (optional description)',
      },
      sampleResponse: {
        'data': {'id': 'item_1', 'sequence': 1, 'runningTotal': 45000},
      },
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Delete Calculator Session',
      method: 'DELETE',
      path: '/sessions/:id',
      fullUrl: 'https://api.bit-tool.com/api/calculator/sessions/sess_501',
      description: 'Deletes a calculator session and its associated tape entries.',
      requiresAuth: true,
      sampleResponse: {'success': true},
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Clear All Standard Sessions',
      method: 'DELETE',
      path: '/sessions',
      fullUrl: 'https://api.bit-tool.com/api/calculator/sessions',
      description: 'Clears all standard calculator sessions for the user.',
      requiresAuth: true,
      sampleResponse: {'success': true},
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Get Compare History',
      method: 'GET',
      path: '/compare/history',
      fullUrl: 'https://api.bit-tool.com/api/calculator/compare/history',
      description: 'Fetches history of price comparison sessions.',
      requiresAuth: true,
      sampleResponse: {
        'data': [
          {'id': 'cmp_1', 'title': 'Leased Line Vendor Compare', 'mode': 'compare'}
        ]
      },
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Create Compare Session',
      method: 'POST',
      path: '/compare/sessions',
      fullUrl: 'https://api.bit-tool.com/api/calculator/compare/sessions',
      description: 'Creates a new comparison session.',
      requiresAuth: true,
      requestBodySchema: {
        'title': 'string (required)',
        'mode': 'compare',
        'currency': 'INR',
      },
      sampleResponse: {'data': {'id': 'cmp_2', 'title': 'Vendor Comparison'}},
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Add Compare Item',
      method: 'POST',
      path: '/compare/sessions/:sessionId/items',
      fullUrl: 'https://api.bit-tool.com/api/calculator/compare/sessions/cmp_1/items',
      description: 'Adds a comparison row with Side A vs Side B prices, quantities, and discounts.',
      requiresAuth: true,
      requestBodySchema: {
        'description': 'string (e.g. 500Mbps Leased Line)',
        'valueA': 'number (Price vendor A)',
        'valueB': 'number (Price vendor B)',
        'qtyA': 'number (default: 1)',
        'qtyB': 'number (default: 1)',
        'discountA': 'number percentage (default: 0)',
        'discountB': 'number percentage (default: 0)',
        'sequence': 'integer (order)',
      },
      sampleResponse: {'data': {'id': 'cmp_item_1', 'finalA': 4200, 'finalB': 4500}},
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Update Compare Item',
      method: 'PUT',
      path: '/compare/sessions/:sessionId/items/:itemId',
      fullUrl: 'https://api.bit-tool.com/api/calculator/compare/sessions/cmp_1/items/cmp_item_1',
      description: 'Updates values or quantities on a comparison row.',
      requiresAuth: true,
      sampleResponse: {'data': {'id': 'cmp_item_1', 'updated': true}},
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Delete Compare Item',
      method: 'DELETE',
      path: '/compare/sessions/:sessionId/items/:itemId',
      fullUrl: 'https://api.bit-tool.com/api/calculator/compare/sessions/cmp_1/items/cmp_item_1',
      description: 'Removes a row from comparison session.',
      requiresAuth: true,
      sampleResponse: {'success': true},
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Delete Compare Session',
      method: 'DELETE',
      path: '/compare/sessions/:id',
      fullUrl: 'https://api.bit-tool.com/api/calculator/compare/sessions/cmp_1',
      description: 'Deletes an entire comparison session.',
      requiresAuth: true,
      sampleResponse: {'success': true},
    ),
    EndpointDescriptor(
      module: 'Calculator',
      title: 'Clear All Compare History',
      method: 'DELETE',
      path: '/compare/history',
      fullUrl: 'https://api.bit-tool.com/api/calculator/compare/history',
      description: 'Clears all comparison sessions.',
      requiresAuth: true,
      sampleResponse: {'success': true},
    ),

    // ==========================================
    // 5. Notifications Module
    // ==========================================
    EndpointDescriptor(
      module: 'Notifications',
      title: 'Get All Notifications',
      method: 'GET',
      path: '/notifications',
      fullUrl: 'https://api.bit-tool.com/api/notifications',
      description: 'Fetches notifications for the authenticated user.',
      requiresAuth: true,
      sampleResponse: {
        'data': [
          {
            'id': 'notif_1',
            'title': 'Rent Scheduled Payment Pending',
            'message': 'Commercial Office Rent of Rs 45,000 is pending verification',
            'isRead': false,
            'createdAt': '2026-11-13T09:00:00.000Z',
          }
        ]
      },
    ),
    EndpointDescriptor(
      module: 'Notifications',
      title: 'Mark Single Notification as Read',
      method: 'PUT',
      path: '/notifications/:id/read',
      fullUrl: 'https://api.bit-tool.com/api/notifications/notif_1/read',
      description: 'Marks a specific notification as read.',
      requiresAuth: true,
      sampleResponse: {'status': 'success', 'message': 'Notification marked as read'},
    ),
    EndpointDescriptor(
      module: 'Notifications',
      title: 'Mark All Notifications as Read',
      method: 'PUT',
      path: '/notifications/read-all',
      fullUrl: 'https://api.bit-tool.com/api/notifications/read-all',
      description: 'Marks all notifications for the user as read.',
      requiresAuth: true,
      sampleResponse: {'status': 'success', 'message': 'All notifications marked as read'},
    ),

    // ==========================================
    // 6. Weather & Geocoding Module (External)
    // ==========================================
    EndpointDescriptor(
      module: 'Weather',
      title: 'Get Live Weather Forecast',
      method: 'GET',
      path: '/forecast',
      fullUrl: 'https://api.open-meteo.com/v1/forecast?latitude=12.9716&longitude=77.5946&daily=weathercode,temperature_2m_max,temperature_2m_min&hourly=temperature_2m&current=temperature_2m,is_day,relative_humidity_2m,wind_speed_10m&timezone=auto',
      description: 'Fetches current temperature, humidity, wind, and multi-day forecast from Open-Meteo.',
      requiresAuth: false,
      queryParameters: {
        'latitude': 'Decimal latitude (e.g. 12.9716)',
        'longitude': 'Decimal longitude (e.g. 77.5946)',
      },
      sampleResponse: {
        'current': {'temperature_2m': 28.5, 'relative_humidity_2m': 62, 'weathercode': 1},
      },
    ),
    EndpointDescriptor(
      module: 'Weather',
      title: 'Reverse Geocoding to City / Region',
      method: 'GET',
      path: '/reverse-geocode-client',
      fullUrl: 'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=12.9716&longitude=77.5946&localityLanguage=en',
      description: 'Resolves GPS coordinates into city name, state, and country via BigDataCloud.',
      requiresAuth: false,
      queryParameters: {
        'latitude': 'Decimal latitude',
        'longitude': 'Decimal longitude',
      },
      sampleResponse: {
        'city': 'Bengaluru',
        'principalSubdivision': 'Karnataka',
        'countryName': 'India',
      },
    ),

    // ==========================================
    // 7. Currency Converter Module (External)
    // ==========================================
    EndpointDescriptor(
      module: 'Currency',
      title: 'Get Supported Currencies',
      method: 'GET',
      path: '/currencies',
      fullUrl: 'https://api.frankfurter.dev/v2/currencies',
      description: 'Lists all available international currencies from Frankfurter API.',
      requiresAuth: false,
      sampleResponse: {
        'INR': 'Indian Rupee',
        'USD': 'United States Dollar',
        'EUR': 'Euro',
        'GBP': 'British Pound',
      },
    ),
    EndpointDescriptor(
      module: 'Currency',
      title: 'Get Live Exchange Rate',
      method: 'GET',
      path: '/rates',
      fullUrl: 'https://api.frankfurter.dev/v2/rates?base=USD&quotes=INR',
      description: 'Fetches real-time currency conversion rates.',
      requiresAuth: false,
      queryParameters: {
        'base': 'Base currency code (e.g. USD)',
        'quotes': 'Target currency code (e.g. INR)',
      },
      sampleResponse: {
        'base': 'USD',
        'date': '2026-11-13',
        'rates': {'INR': 88.5},
      },
    ),

    // ==========================================
    // 8. User Profile Context Module (Read-only, NO LOGIN)
    // ==========================================
    EndpointDescriptor(
      module: 'User Profile',
      title: 'Get Authenticated User Profile',
      method: 'GET',
      path: '/users/me',
      fullUrl: 'https://api.bnxmail.com/api/users/me',
      description: 'Fetches the current user profile, organization details, and role using the host app\'s bearer token. (Login API is excluded).',
      requiresAuth: true,
      sampleResponse: {
        'success': true,
        'data': {
          'id': 28,
          'email': 'ravinew2004@cliks.com',
          'firstName': 'Ravi',
          'role': 'ORG_ADMIN',
          'accountType': 'BUSINESS',
          'organization': {'id': 6, 'name': 'Cliks Business'},
        }
      },
    ),
  ];

  /// Returns all available modules.
  static List<String> get availableModules {
    final modules = <String>{};
    for (final ep in allEndpoints) {
      modules.add(ep.module);
    }
    return modules.toList();
  }

  /// Filters endpoints by module name.
  static List<EndpointDescriptor> getEndpointsByModule(String module) {
    final clean = module.trim().toLowerCase();
    return allEndpoints
        .where((e) => e.module.toLowerCase() == clean)
        .toList();
  }

  /// Searches endpoints across module, title, path, and description.
  static List<EndpointDescriptor> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allEndpoints;
    return allEndpoints.where((e) {
      return e.module.toLowerCase().contains(q) ||
          e.title.toLowerCase().contains(q) ||
          e.path.toLowerCase().contains(q) ||
          e.method.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();
  }

  /// Generates a structured JSON map of all modules and their endpoints.
  static Map<String, dynamic> toJson() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final ep in allEndpoints) {
      map.putIfAbsent(ep.module, () => []).add(ep.toJson());
    }
    return {
      'generatedFor': 'Host Application Integration (e.g. Cliks Business)',
      'totalEndpoints': allEndpoints.length,
      'authStrategy': 'Host-provided Bearer token (no login API included)',
      'modules': map,
    };
  }

  /// Generates Markdown summary of all endpoints.
  static String generateMarkdownTable() {
    final buffer = StringBuffer();
    buffer.writeln('| Module | Method | Endpoint Path | Description | Auth Required |');
    buffer.writeln('| :--- | :--- | :--- | :--- | :--- |');

    for (final ep in allEndpoints) {
      buffer.writeln(
        '| **${ep.module}** | `${ep.method}` | `${ep.path}` | ${ep.description} | ${ep.requiresAuth ? "Yes (Bearer)" : "No"} |',
      );
    }
    return buffer.toString();
  }
}

