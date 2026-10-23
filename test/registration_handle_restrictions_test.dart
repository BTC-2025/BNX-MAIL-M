import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Registration Handle & Username Restrictions', () {
    test('TextInputFormatters enforce max length 15 and lowercase alphanumeric', () {
      final formatters = [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
        LengthLimitingTextInputFormatter(15),
        TextInputFormatter.withFunction(
          (oldValue, newValue) => newValue.copyWith(
            text: newValue.text.toLowerCase(),
            selection: newValue.selection,
          ),
        ),
      ];

      // Test 1: User types input longer than 15 chars like in the screenshot
      // 'ravjuujejenenebeddie' (20 chars) -> truncated to 15 chars
      TextEditingValue value = const TextEditingValue(text: '');
      for (final char in 'ravjuujejenenebeddie'.split('')) {
        var newVal = TextEditingValue(
          text: value.text + char,
          selection: TextSelection.collapsed(offset: value.text.length + 1),
        );
        for (final formatter in formatters) {
          newVal = formatter.formatEditUpdate(value, newVal);
        }
        value = newVal;
      }
      expect(value.text.length, equals(15));
      expect(value.text, equals('ravjuujejeneneb'));

      // Test 2: Uppercase conversion to lowercase
      TextEditingValue upperVal = const TextEditingValue(text: '');
      var newValUpper = const TextEditingValue(text: 'JohnDoe123');
      for (final formatter in formatters) {
        newValUpper = formatter.formatEditUpdate(upperVal, newValUpper);
      }
      expect(newValUpper.text, equals('johndoe123'));

      // Test 3: Disallow special characters and spaces
      var newValSpecial = const TextEditingValue(text: 'user!@# name');
      for (final formatter in formatters) {
        newValSpecial = formatter.formatEditUpdate(upperVal, newValSpecial);
      }
      expect(newValSpecial.text, equals('username'));
    });

    test('Username validation correctly accepts 6-15 chars and rejects invalid formats', () {
      String? validate(String raw) {
        final uName = raw.trim().toLowerCase();
        if (uName.isEmpty) {
          return 'Username is required';
        } else if (uName.length < 6) {
          return 'Username must be at least 6 characters';
        } else if (uName.length > 15) {
          return 'Username cannot exceed 15 characters';
        } else if (!RegExp(r'^[a-z]').hasMatch(uName)) {
          return 'Username must start with a lowercase letter';
        } else if (!RegExp(r'^[a-z0-9]+$').hasMatch(uName)) {
          return 'Only lowercase letters and numbers are allowed';
        }
        return null;
      }

      // Rejections
      expect(validate(''), equals('Username is required'));
      expect(validate('abc'), equals('Username must be at least 6 characters'));
      expect(validate('ravjuujejenenebeddie'), equals('Username cannot exceed 15 characters'));
      expect(validate('123john'), equals('Username must start with a lowercase letter'));
      expect(validate('john_doe'), equals('Only lowercase letters and numbers are allowed'));
      expect(validate('john-doe'), equals('Only lowercase letters and numbers are allowed'));

      // Valid handles
      expect(validate('kumarravi002'), isNull);
      expect(validate('raviravk002'), isNull);
      expect(validate('ravirav2000'), isNull);
      expect(validate('johndoe123'), isNull);
      expect(validate('abc1234'), isNull);
    });

    test('Database truncation and SQL exceptions are sanitized to user-friendly messages', () {
      String sanitize(String rawError) {
        final lower = rawError.toLowerCase();
        if (lower.contains('data truncation') ||
            lower.contains('data too long')) {
          if (lower.contains("column 'first_name'") || lower.contains("'first_name'")) {
            return 'First Name cannot exceed 30 characters';
          }
          if (lower.contains("column 'last_name'") || lower.contains("'last_name'")) {
            return 'Last Name cannot exceed 30 characters';
          }
          if (lower.contains("column 'business_name'") ||
              lower.contains("column 'company_name'") ||
              lower.contains("'business_name'") ||
              lower.contains("'company_name'")) {
            return 'Business Name cannot exceed 50 characters';
          }
          if (lower.contains("column 'username'") || lower.contains("'username'")) {
            return 'Username cannot exceed 15 characters';
          }
          return 'Character limit exceeded for one of the fields';
        }
        if (lower.contains('too long') && lower.contains('username')) {
          return 'Username cannot exceed 15 characters';
        }

        if (lower.contains('taken') ||
            lower.contains('already exist') ||
            lower.contains('already in use')) {
          return 'Username is already taken, please pick another.';
        }
        if (lower.contains('could not execute statement') ||
            lower.contains('sql [') ||
            lower.contains('hibernateexception') ||
            lower.contains('constraintviolation')) {
          return 'Invalid username or registration details. Please choose another username.';
        }
        return rawError;
      }

      const rawSqlError =
          "could not execute statement [Data truncation: Data too long for column 'username' at row 1] [insert into users (aadhaar_name,aadhaar_number,account_type,active,approved,approved_at,approved_by,bio,branch_id,branch_name,created_at,display_name,dob,email,first_name,gender,gstin,home_address,is_primary,is_sub_id,last_login,last_name,nickname,occupation,organization_id,pan_number,parent_user_id,password,phone_number,profile_picture,recovery_email,role,two_factor_enabled,two_factor_secret,updated_at,username,work_address) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)]";

      expect(sanitize(rawSqlError), equals('Username cannot exceed 15 characters'));

      const rawFirstNameSqlError =
          "could not execute statement [Data truncation: Data too long for column 'first_name' at row 1]";
      expect(sanitize(rawFirstNameSqlError), equals('First Name cannot exceed 30 characters'));

      const rawLastNameSqlError =
          "could not execute statement [Data truncation: Data too long for column 'last_name' at row 1]";
      expect(sanitize(rawLastNameSqlError), equals('Last Name cannot exceed 30 characters'));

      const takenError = 'Username is already in use';
      expect(sanitize(takenError), equals('Username is already taken, please pick another.'));

      const genericSqlError = 'could not execute statement [insert into users ...]';
      expect(
        sanitize(genericSqlError),
        equals('Invalid username or registration details. Please choose another username.'),
      );
    });

    test('Name TextInputFormatters enforce max length 30 and allow letters, hyphens, dots', () {
      final nameFormatters = [
        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\.\'\-]")),
        LengthLimitingTextInputFormatter(30),
      ];

      // Test 1: Excessive length input like screenshot (eabfcuibrfycbkirbcibciebfief... 40+ chars)
      const longInput = 'eabfcuibrfycbkirbcibciebfiefextraexcessivestring';
      TextEditingValue value = const TextEditingValue(text: '');
      for (final char in longInput.split('')) {
        var newVal = TextEditingValue(
          text: value.text + char,
          selection: TextSelection.collapsed(offset: value.text.length + 1),
        );
        for (final formatter in nameFormatters) {
          newVal = formatter.formatEditUpdate(value, newVal);
        }
        value = newVal;
      }
      expect(value.text.length, equals(30));
      expect(value.text, equals('eabfcuibrfycbkirbcibciebfiefex'));

      // Test 2: Reject numbers and disallowed symbols
      var newValSpecial = const TextEditingValue(text: 'John123!@# Doe');
      var filtered = const TextEditingValue(text: '');
      for (final formatter in nameFormatters) {
        newValSpecial = formatter.formatEditUpdate(filtered, newValSpecial);
      }
      expect(newValSpecial.text, equals('John Doe'));

      // Test 3: Allow hyphens, apostrophes, and periods
      var newValHyphen = const TextEditingValue(text: "Mary-Jane O'Connor Jr.");
      for (final formatter in nameFormatters) {
        newValHyphen = formatter.formatEditUpdate(filtered, newValHyphen);
      }
      expect(newValHyphen.text, equals("Mary-Jane O'Connor Jr."));
    });

    test('Person Name validation correctly accepts 2-30 chars and validates names', () {
      String? validatePersonName(String value, String fieldName) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return '$fieldName is required';
        if (trimmed.length < 2) return '$fieldName must be at least 2 characters';
        if (trimmed.length > 30) return '$fieldName cannot exceed 30 characters';
        if (!RegExp(r'^[a-zA-Z]').hasMatch(trimmed)) return '$fieldName must start with a letter';
        if (!RegExp(r"^[a-zA-Z\s\.\'\-]+$").hasMatch(trimmed)) {
          return 'Only letters, spaces, hyphens, and dots are allowed';
        }
        return null;
      }

      // Rejections
      expect(validatePersonName('', 'First Name'), equals('First Name is required'));
      expect(validatePersonName('A', 'First Name'), equals('First Name must be at least 2 characters'));
      expect(
        validatePersonName('ThisIsAThirtyOneCharactersLongNameX', 'First Name'),
        equals('First Name cannot exceed 30 characters'),
      );
      expect(validatePersonName('.John', 'First Name'), equals('First Name must start with a letter'));
      expect(validatePersonName('12John', 'First Name'), equals('First Name must start with a letter'));
      expect(validatePersonName('John@Doe', 'First Name'), equals('Only letters, spaces, hyphens, and dots are allowed'));

      // Valid names
      expect(validatePersonName('John', 'First Name'), isNull);
      expect(validatePersonName('Mary-Jane', 'First Name'), isNull);
      expect(validatePersonName("O'Connor", 'Last Name'), isNull);
      expect(validatePersonName('St. John', 'Last Name'), isNull);
      expect(validatePersonName('Ravi Kumar', 'Owner First Name'), isNull);
    });

    test('Business Name validation correctly accepts 2-50 chars and validates names', () {
      String? validateBusinessName(String value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return 'Business Name is required';
        if (trimmed.length < 2) return 'Business Name must be at least 2 characters';
        if (trimmed.length > 50) return 'Business Name cannot exceed 50 characters';
        return null;
      }

      expect(validateBusinessName(''), equals('Business Name is required'));
      expect(validateBusinessName('A'), equals('Business Name must be at least 2 characters'));
      expect(
        validateBusinessName('A' * 51),
        equals('Business Name cannot exceed 50 characters'),
      );
      expect(validateBusinessName('Acme Corp'), isNull);
      expect(validateBusinessName('Tech Solutions Ltd.'), isNull);
    });
  });
}

