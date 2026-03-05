import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/services/auth_provider.dart';

class NotificationBadgeWidget extends StatelessWidget {
  final Widget child;

  const NotificationBadgeWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user == null) return child;

    // Determine target IDs for queries like Staff Broadcasts vs Individual
    List<String> targetIds = user.role.name == 'hospitalStaff' 
        ? [user.id, 'staff_broadcast'] 
        : [user.id];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', whereIn: targetIds)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return child;

        // Optionally filter by role if it was a broadcast
        int unreadCount = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final targetRole = data['targetRole'];
          return targetRole == null || targetRole == user.role.name;
        }).length;

        if (unreadCount == 0) return child;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
