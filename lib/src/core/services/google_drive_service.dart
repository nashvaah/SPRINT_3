import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';

class GoogleDriveService {
  // 🔹 REPLACE THIS URL with your newly deployed Google Apps Script Web App URL
  static const String _scriptUrl =
      "https://script.google.com/macros/s/AKfycbz1CNBda6hoW9b-T2LC7uphtCiZxyMBjiU3Up1MR1MhW9zpDrQqsAoGf8Ub40upDxMpEQ/exec";

  /// Uploads a file to Google Drive via Google Apps Script
  static Future<Map<String, dynamic>?> uploadFile(File file, {String? fileName}) async {
    try {
      var bytes = await file.readAsBytes();
      String name = fileName ?? file.path.split('/').last;
      return await uploadBytes(bytes, fileName: name);
    } catch (e) {
      debugPrint("Upload Exception: \$e");
      return null;
    }
  }

  /// Uploads raw bytes to Google Drive via Google Apps Script
  static Future<Map<String, dynamic>?> uploadBytes(Uint8List bytes, {required String fileName}) async {
    try {
      String base64File = base64Encode(bytes);
      final client = http.Client();

      debugPrint("Attempting upload to Google Drive: $fileName");

      var response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "fileName": fileName,
          "content": base64File,
        }),
      );

      debugPrint("Upload Initial Response Code: ${response.statusCode}");

      // 🔹 Manually handle redirects if necessary (common with Google Apps Script on mobile)
      if (response.statusCode == 302 || response.statusCode == 301) {
        String? redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          debugPrint("Following redirect to: $redirectUrl");
          response = await http.get(Uri.parse(redirectUrl));
          debugPrint("Redirect Response Code: ${response.statusCode}");
        }
      }

      if (response.statusCode == 200) {
        try {
          // Check if response is actually JSON
          if (response.body.trim().startsWith('{') || response.body.trim().startsWith('[')) {
            var responseData = jsonDecode(response.body);
            debugPrint("Upload Success Result: ${response.body}");
            return responseData;
          } else {
            // It might be the URL directly or an error message in plain text
            if (response.body.contains("http")) {
               return {
                 "status": "success",
                 "url": response.body.trim()
               };
            }
            throw Exception("Response is not valid JSON: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}");
          }
        } catch (e) {
          debugPrint("Error decoding response: $e");
          return {
            "status": "error",
            "message": "Invalid response format from server. Body: ${response.body.substring(0, response.body.length > 50 ? 50 : response.body.length)}"
          };
        }
      } else {
        debugPrint("Upload failed. Status: ${response.statusCode}, Body: ${response.body}");
        return {
          "status": "error",
          "message": "Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 50 ? 50 : response.body.length)}"
        };
      }

    } catch (e) {
      debugPrint("Upload Exception: $e");
      return {
        "status": "error",
        "message": e.toString()
      };
    }
  }

  /// Reads a file from Google Drive via Google Apps Script (returns Base64 string)
  static Future<String?> getFileBase64(String fileId) async {
    try {
      var url = Uri.parse("\$_scriptUrl?fileId=\$fileId");
      var response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 302) {
        debugPrint("File read successfully");
        return response.body; // The response body is the base64 string
      } else {
        debugPrint("Get file failed with status: \${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Get file Exception: \$e");
      return null;
    }
  }

  /// Helper to get bytes directly from fileId
  static Future<Uint8List?> getFileBytes(String fileId) async {
    String? base64String = await getFileBase64(fileId);
    if (base64String != null && base64String.isNotEmpty) {
      return base64Decode(base64String);
    }
    return null;
  }
}
