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

      final request = http.Request('POST', Uri.parse(_scriptUrl))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          "fileName": fileName,
          "content": base64File,
        })
        ..followRedirects = true;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("Upload Response Code: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          var responseData = jsonDecode(response.body);
          debugPrint("Upload Result: ${response.body}");
          return responseData;
        } catch (e) {
          // If decoding fails, it might be because the body is not JSON (e.g. an HTML error page)
          debugPrint("Error decoding response JSON: $e");
          debugPrint("Raw Response Body: ${response.body}");
          return {
            "status": "error",
            "message": "Invalid response format from server"
          };
        }
      } else {
        debugPrint("Upload failed. Status: ${response.statusCode}, Body: ${response.body}");
        return {
          "status": "error",
          "message": "Server error (${response.statusCode})"
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
