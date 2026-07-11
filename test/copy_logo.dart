import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Copy logo and generate base64 data', () async {
    final sourceFile = File(r'C:\Users\RAVI KUMAR C\.gemini\antigravity-ide\brain\ffc2f011-4ab5-4123-997d-5ff6094d169a\media__1782899402953.jpg');
    
    if (!await sourceFile.exists()) {
      print('Source logo file does not exist at specified path.');
      return;
    }
    
    // 1. Copy to assets folder
    final assetsDir = Directory('assets');
    if (!await assetsDir.exists()) {
      await assetsDir.create();
    }
    final destFile = File('assets/logo.jpg');
    final bytes = await sourceFile.readAsBytes();
    await destFile.writeAsBytes(bytes);
    print('Logo copied successfully to assets/logo.jpg.');

    // 2. Generate Base64 Dart file
    final base64String = base64Encode(bytes);
    final outputDir = Directory('lib/core/constants');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    
    final dartFile = File('lib/core/constants/logo_base64.dart');
    await dartFile.writeAsString('''// Generated file - contains base64 representation of the bird logo
const String logoBase64 = '$base64String';
''');
    print('Base64 logo file generated at lib/core/constants/logo_base64.dart.');
  });
}
