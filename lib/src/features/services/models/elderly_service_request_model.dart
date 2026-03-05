import 'package:cloud_firestore/cloud_firestore.dart';

class ElderlyServiceRequestModel {
  final String requestId;
  final String elderlyId;
  final String requestType;
  final String requestDescription;
  final String requestStatus; // 'pending', 'approved', 'in_progress', 'completed', 'cancelled'
  final String priorityLevel; // 'low', 'medium', 'high', 'emergency'
  final String? locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  ElderlyServiceRequestModel({
    required this.requestId,
    required this.elderlyId,
    required this.requestType,
    required this.requestDescription,
    this.requestStatus = 'pending',
    this.priorityLevel = 'low',
    this.locationAddress,
    this.locationLatitude,
    this.locationLongitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ElderlyServiceRequestModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ElderlyServiceRequestModel(
      requestId: documentId,
      elderlyId: data['elderly_id'] ?? '',
      requestType: data['request_type'] ?? '',
      requestDescription: data['request_description'] ?? '',
      requestStatus: data['request_status'] ?? 'pending',
      priorityLevel: data['priority_level'] ?? 'low',
      locationAddress: data['location_address'],
      locationLatitude: (data['location_latitude'] as num?)?.toDouble(),
      locationLongitude: (data['location_longitude'] as num?)?.toDouble(),
      createdAt: data['created_at'] ?? Timestamp.now(),
      updatedAt: data['updated_at'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'elderly_id': elderlyId,
      'request_type': requestType,
      'request_description': requestDescription,
      'request_status': requestStatus,
      'priority_level': priorityLevel,
      'location_address': locationAddress,
      'location_latitude': locationLatitude,
      'location_longitude': locationLongitude,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  ElderlyServiceRequestModel copyWith({
    String? requestId,
    String? elderlyId,
    String? requestType,
    String? requestDescription,
    String? requestStatus,
    String? priorityLevel,
    String? locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return ElderlyServiceRequestModel(
      requestId: requestId ?? this.requestId,
      elderlyId: elderlyId ?? this.elderlyId,
      requestType: requestType ?? this.requestType,
      requestDescription: requestDescription ?? this.requestDescription,
      requestStatus: requestStatus ?? this.requestStatus,
      priorityLevel: priorityLevel ?? this.priorityLevel,
      locationAddress: locationAddress ?? this.locationAddress,
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
