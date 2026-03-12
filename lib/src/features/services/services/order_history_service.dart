import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_history_model.dart';

class OrderHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> logStatusChange({
    required String orderId,
    required String orderType,
    String? previousStatus,
    required String newStatus,
    required String updatedBy,
    required String updatedByName,
    String? notes,
  }) async {
    try {
      final docRef = _firestore.collection('order_history').doc();
      final historyModel = OrderHistoryModel(
        id: docRef.id,
        orderId: orderId,
        orderType: orderType,
        previousStatus: previousStatus,
        newStatus: newStatus,
        updatedBy: updatedBy,
        updatedByName: updatedByName,
        updatedAt: Timestamp.now(),
        notes: notes,
      );

      await docRef.set(historyModel.toMap());
    } catch (e) {
      if (kDebugMode) {
        print("Error logging order history: $e");
      }
    }
  }
}
