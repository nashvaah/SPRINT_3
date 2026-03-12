import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medical_record.dart';
import '../../../core/services/google_drive_service.dart';

class MedicalRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<MedicalRecord>> getMedicalRecords(String elderlyId) {
    return _firestore
        .collection('medical_records')
        .where('elderlyId', isEqualTo: elderlyId)
        .snapshots()
        .map((snapshot) {
          final records = snapshot.docs
              .map((doc) => MedicalRecord.fromMap(doc.data(), doc.id))
              .where((record) => record.isActive)
              .toList();

          records.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
          return records;
        });
  }

  Future<void> addMedicalRecord({
    required String elderlyId,
    required String title,
    required String description,
    required String doctorId,
    required String doctorName,
    required String department,
    required DateTime recordDate,
    required String uploadedByRole,
    required Uint8List fileBytes,
    required String fileName,
    required int fileSize,
    required String fileType,
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

      MedicalRecord record = MedicalRecord(
        id: '',
        title: title,
        description: description,
        department: department,
        doctorId: doctorId,
        doctorName: doctorName,
        recordDate: recordDate,
        uploadDate: DateTime.now(),
        fileSize: fileSize,
        fileType: fileType,
        fileUrl: fileUrl,
        uploadedByRole: uploadedByRole,
        elderlyId: elderlyId,
        isActive: true,
      );

      await _firestore
          .collection('medical_records')
          .add(record.toMap())
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      // Provide clean error without standard stack trace prefixes
      final errorStr = e.toString();
      if (errorStr.contains('TimeoutException')) {
        throw Exception(
          "Network timeout. Please check your connection and try again.",
        );
      }
      throw Exception(errorStr.replaceAll('Exception: ', ''));
    }
  }

  Future<void> updateMedicalRecord(
    String recordId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('medical_records').doc(recordId).update(data);
  }

  Future<void> softDeleteMedicalRecord(String recordId) async {
    await updateMedicalRecord(recordId, {'isActive': false});
  }
}
