import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/google_drive_service.dart';

class SharedMedicalDocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getMedicalDocuments(String elderlyId) {
    return _firestore
        .collection('medical_documents')
        .doc(elderlyId)
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  Future<void> uploadMedicalDocument({
    required String elderlyId,
    required String fileName,
    required Uint8List fileBytes,
    required String fileType,
    required String uploadedById,
    required String uploadedByName,
    required String uploadedByRole,
  }) async {
    try {
      // Use GoogleDriveService to upload the file bytes
      final response = await GoogleDriveService.uploadBytes(
        fileBytes,
        fileName: fileName,
      );

      if (response == null || response['status'] != 'success') {
        throw Exception(response?['message'] ?? "Failed to upload file to Google Drive");
      }

      final String fileUrl = response['url'] as String;

      final docRef = _firestore
          .collection('medical_documents')
          .doc(elderlyId)
          .collection('documents')
          .doc();

      await docRef.set({
        'fileName': fileName,
        'fileUrl': fileUrl,
        'uploadedById': uploadedById,
        'uploadedByName': uploadedByName,
        'uploadedByRole': uploadedByRole,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error uploading shared document: $e");
      rethrow;
    }
  }
}
