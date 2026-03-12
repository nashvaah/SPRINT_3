import 'package:cloud_firestore/cloud_firestore.dart';

class OrderHistoryModel {
  final String id;
  final String orderId; // Links to CaretakerBookingId or VolunteerRequestId
  final String orderType; // Type of order (e.g., 'Caregiver', 'Volunteer')
  final String? previousStatus; // The status before the change
  final String newStatus; // The new status
  final String updatedBy; // ID of the user who made the change
  final String updatedByName; // Name of the user who made the change
  final Timestamp updatedAt; // When the change occurred
  final String? notes; // Optional notes (e.g., rejection reasons)

  OrderHistoryModel({
    required this.id,
    required this.orderId,
    required this.orderType,
    this.previousStatus,
    required this.newStatus,
    required this.updatedBy,
    required this.updatedByName,
    required this.updatedAt,
    this.notes,
  });

  factory OrderHistoryModel.fromMap(Map<String, dynamic> data, String id) {
    return OrderHistoryModel(
      id: id,
      orderId: data['orderId'] ?? '',
      orderType: data['orderType'] ?? '',
      previousStatus: data['previousStatus'],
      newStatus: data['newStatus'] ?? '',
      updatedBy: data['updatedBy'] ?? '',
      updatedByName: data['updatedByName'] ?? 'Unknown User',
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'orderType': orderType,
      'previousStatus': previousStatus,
      'newStatus': newStatus,
      'updatedBy': updatedBy,
      'updatedByName': updatedByName,
      'updatedAt': updatedAt,
      'notes': notes,
    };
  }
}
