import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/order_history_model.dart';
import '../models/caretaker_booking_model.dart';
import '../models/volunteer_request_model.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _isLoading = true;
  String? _orderType;
  dynamic _orderData; 
  List<OrderHistoryModel> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    try {
      // Find what type of order it is by checking both collections
      var caretakerDoc = await FirebaseFirestore.instance.collection('caretaker_bookings').doc(widget.orderId).get();
      if (caretakerDoc.exists) {
        _orderType = 'Caretaker';
        _orderData = CaretakerBookingModel.fromMap(caretakerDoc.data()!, caretakerDoc.id);
      } else {
        var volunteerDoc = await FirebaseFirestore.instance.collection('volunteer_requests').doc(widget.orderId).get();
        if (volunteerDoc.exists) {
          _orderType = 'Volunteer';
          _orderData = VolunteerRequestModel.fromMap(volunteerDoc.data()!, volunteerDoc.id);
        } else {
           setState(() {
              _error = 'Order not found or has been deleted.';
              _isLoading = false;
           });
           return;
        }
      }

      // Fetch history log
      var historyQuery = await FirebaseFirestore.instance
          .collection('order_history')
          .where('orderId', isEqualTo: widget.orderId)
          .orderBy('updatedAt', descending: true)
          .get();

      _history = historyQuery.docs.map((d) => OrderHistoryModel.fromMap(d.data(), d.id)).toList();

      setState(() {
         _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
         setState(() {
            _error = "Failed to load order tracking: $e";
            _isLoading = false;
         });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Order Tracking")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Order Tracking")),
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
      );
    }

    // Determine current status color
    Color statusColor = Colors.grey;
    String currentStatus = '';
    String serviceType = '';
    String dateLabel = '';
    
    if (_orderType == 'Caretaker') {
       final req = _orderData as CaretakerBookingModel;
       currentStatus = req.status;
       serviceType = "${req.serviceType} (${req.durationType})";
       dateLabel = DateFormat('MMM d, h:mm a').format(req.requestTime.toDate());
    } else {
       final req = _orderData as VolunteerRequestModel;
       currentStatus = req.status;
       serviceType = req.serviceType;
       dateLabel = DateFormat('MMM d, h:mm a').format(req.requestTime.toDate());
    }

    if (currentStatus == 'Pending') statusColor = Colors.orange;
    if (currentStatus == 'Accepted' || currentStatus == 'Confirmed') statusColor = Colors.green;
    if (currentStatus == 'On the Way') statusColor = Colors.teal;
    if (currentStatus == 'Completed') statusColor = Colors.blue;
    if (currentStatus == 'Rejected' || currentStatus == 'Cancelled') statusColor = Colors.red;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("$_orderType Tracking", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _orderType == 'Caretaker' ? Colors.indigo : Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Status Box
            Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(16),
                 boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                 ]
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text("Order # ${widget.orderId.substring(0, 8)}...", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                   const SizedBox(height: 8),
                   Text(serviceType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                   const SizedBox(height: 4),
                   Text(dateLabel, style: const TextStyle(color: Colors.grey)),
                   const Divider(height: 30),
                   Row(
                     children: [
                       const Text("Current Status:", style: TextStyle(fontSize: 16)),
                       const Spacer(),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: statusColor.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(20),
                         ),
                         child: Text(
                           currentStatus.toUpperCase(), 
                           style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)
                         ),
                       )
                     ],
                   )
                 ],
               ),
            ),
            
            const SizedBox(height: 24),
            const Text("Tracking History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            const SizedBox(height: 16),
            
            if (_history.isEmpty)
              const Center(child: Text("No history logs available yet.", style: TextStyle(color: Colors.grey)))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final log = _history[index];
                  final isLast = index == _history.length - 1;
                  
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline Line
                        SizedBox(
                          width: 40,
                          child: Column(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == 0 ? statusColor : Colors.grey.shade400,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                              if (!isLast)
                                Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
                            ],
                          ),
                        ),
                        // Content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.newStatus, 
                                  style: TextStyle(
                                    fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                    color: index == 0 ? Colors.black87 : Colors.grey.shade700
                                  )
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('MMM d, yyyy • h:mm a').format(log.updatedAt.toDate()),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "By: ${log.updatedByName}",
                                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic)
                                ),
                                if (log.notes != null && log.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300)
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(log.notes!, style: const TextStyle(fontSize: 13, color: Colors.black87))
                                        )
                                      ],
                                    ),
                                  )
                                ]
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
          ],
        ),
      ),
    );
  }
}
