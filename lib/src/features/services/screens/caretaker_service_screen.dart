import 'package:flutter/material.dart';
import 'package:carenow/l10n/app_localizations.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/services/auth_provider.dart';
import '../models/caretaker_booking_model.dart';
import 'package:intl/intl.dart';
import '../../../core/services/notification_service.dart';
import '../services/order_history_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class CaretakerServiceScreen extends StatefulWidget {
  const CaretakerServiceScreen({super.key});

  @override
  State<CaretakerServiceScreen> createState() => _CaretakerServiceScreenState();
}

class _CaretakerServiceScreenState extends State<CaretakerServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedService = 'Daily care';
  late final List<String> _serviceTypes;
  
  String _selectedDuration = 'Hourly';
  late final List<String> _durationTypes;
  
  final TextEditingController _contactController = TextEditingController();
  String? _locationUrl;
  Position? _currentPosition;
  bool _isLocationLoading = true;
  String _locationStatus = "Fetching live GPS location...";
  bool _permissionDenied = false;

  bool _isLoading = false;
  Stream<QuerySnapshot>? _bookingsStream;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
      _permissionDenied = false;
      _locationStatus = "Fetching live GPS location...";
    });

    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = "Location services are disabled.";
          _isLocationLoading = false;
          _permissionDenied = true;
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = "Location permission denied.";
            _isLocationLoading = false;
            _permissionDenied = true;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = "Location permissions are permanently denied.";
          _isLocationLoading = false;
          _permissionDenied = true;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        _locationUrl = "https://www.google.com/maps?q=${position.latitude},${position.longitude}";
        _isLocationLoading = false;
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _locationStatus = "Error fetching location: $e";
        _isLocationLoading = false;
        _permissionDenied = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _serviceTypes = [l10n.dailyCare, 'Medical assistance', 'Home support', 'Emergency help']; 
    if (_selectedService == 'Daily care' || _selectedService == 'ദിവസേന പരിചരണം') {
      _selectedService = l10n.dailyCare;
    }
    _durationTypes = [l10n.hourly, l10n.daily, l10n.monthly];
    
    if (_selectedDuration == 'Hourly') _selectedDuration = l10n.hourly;
    if (_selectedDuration == 'Daily') _selectedDuration = l10n.daily;
    if (_selectedDuration == 'Monthly') _selectedDuration = l10n.monthly;

    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user != null && _contactController.text.isEmpty && user.contactNumber != null) {
      _contactController.text = user.contactNumber!;
    }
    if (user != null && user.id != _lastUserId) {
      _lastUserId = user.id;
      _bookingsStream = FirebaseFirestore.instance
          .collection('caretaker_bookings')
          .where('userId', isEqualTo: user.id)
          .snapshots();
    }
  }

  Future<void> _bookCaretaker() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    if (_locationUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.locationRequired)));
      return;
    }

    String address = "Coordinates: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}";
    if (_currentPosition != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          address = [place.street, place.subLocality, place.locality, place.administrativeArea, place.postalCode]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
        }
      } catch (e) {
        debugPrint("Geocoding failed: $e");
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmRequest, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.reviewRequest),
              const SizedBox(height: 16),
              Text(l10n.taskLabel, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
              Text("$_selectedService ($_selectedDuration)"),
              const SizedBox(height: 8),
              Text(l10n.deliveryLocation, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
              Text(address),
              const SizedBox(height: 8),
              Text(l10n.contactLabel, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
              Text(_contactController.text),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.editAction, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(l10n.confirmRequest),
          ),
        ],
        actionsOverflowButtonSpacing: 8,
        scrollable: true,
      )
    );

    if (confirmed != true) return;

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.userNotFound)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('caretaker_bookings').doc();
      final booking = CaretakerBookingModel(
        id: docRef.id,
        userId: user.id,
        uniqueId: user.uniqueId ?? '', 
        userName: user.name,
        serviceType: _selectedService,
        durationType: _selectedDuration,
        status: 'Pending',
        requestTime: Timestamp.now(),
        location: _locationUrl,
        contactDetails: _contactController.text.trim(),
      );

      await docRef.set(booking.toMap());

      await OrderHistoryService.logStatusChange(
        orderId: docRef.id,
        orderType: 'Caretaker',
        newStatus: 'Pending',
        updatedBy: user.id,
        updatedByName: user.name,
      );

      try {
        final caregiversSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'caregiver').get();
        final caregiverIds = caregiversSnapshot.docs.map((doc) => doc.id).toList();
        if (caregiverIds.isNotEmpty) {
           await NotificationService().logNotificationToDb(
             title: l10n.caretakerService,
             message: "${user.name} ${l10n.requestAssistance}: $_selectedService.",
             notificationType: "new_request",
             targetUserIds: caregiverIds,
             orderId: docRef.id,
           );
        }
      } catch (e) {
        debugPrint("Error notifying caregivers: $e");
      }

      _contactController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.bookingRequestedSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePermission(CaretakerBookingModel booking, bool isAllowed) async {
    try {
      if (!isAllowed) {
        // Handle Deny
        await FirebaseFirestore.instance.collection('caretaker_bookings').doc(booking.id).update({
          'permissionStatus': 'Denied',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access denied. Account will not be linked.")));
        }
        return;
      }

      // Handle Allow -> Auto Linking
      if (booking.assignedCaretakerId == null || booking.userId.isEmpty) return;

      // Check current limit first
      final linksSnapshot = await FirebaseFirestore.instance
          .collection('linked_users')
          .doc(booking.assignedCaretakerId)
          .collection('elderlies')
          .get();

      if (linksSnapshot.docs.length >= 5) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caregiver has reached maximum linked accounts (5/5).")));
         }
         return;
      }

      // 1. Update Booking Status
      await FirebaseFirestore.instance.collection('caretaker_bookings').doc(booking.id).update({
        'permissionStatus': 'Approved',
      });

      // 2. Add to linked_users collection
      await FirebaseFirestore.instance
          .collection('linked_users')
          .doc(booking.assignedCaretakerId)
          .collection('elderlies')
          .doc(booking.userId)
          .set({
        'elderlyId': booking.userId,
        'linkedAt': FieldValue.serverTimestamp(),
        'linkedBy': 'auto',
      });

      // Also add to auth provider's linkedElderlyIds to maintain compatibility
      final caregiverDoc = await FirebaseFirestore.instance.collection('users').doc(booking.assignedCaretakerId).get();
      if (caregiverDoc.exists) {
        final links = List<String>.from((caregiverDoc.data() as Map<String, dynamic>)['linkedElderlyIds'] ?? []);
        if (!links.contains(booking.userId)) {
          links.add(booking.userId);
          await FirebaseFirestore.instance.collection('users').doc(booking.assignedCaretakerId).update({
            'linkedElderlyIds': links
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Allowed! Accounts successfully linked.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error processing request: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.caretakerService)),
      body: SingleChildScrollView(
        child: Column(
          children: [
          // Booking Form
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.withOpacity(0.05),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.bookProfessionalCaretaker, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedService,
                    items: _serviceTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 16)))).toList(),
                    onChanged: (val) => setState(() => _selectedService = val!),
                    decoration: InputDecoration(border: const OutlineInputBorder(), labelText: l10n.serviceType),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDuration,
                    items: _durationTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 16)))).toList(),
                    onChanged: (val) => setState(() => _selectedDuration = val!),
                    decoration: InputDecoration(border: const OutlineInputBorder(), labelText: l10n.duration),
                  ),

                  const SizedBox(height: 12),
                  // Location Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _permissionDenied ? Colors.red : Colors.indigo.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.currentLocation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                        const SizedBox(height: 4),
                        if (_isLocationLoading)
                           Row(
                            children: [
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(l10n.capturingGps, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                              ),
                            ],
                          )

                        else if (_locationUrl != null)
                          Text(_locationUrl!, style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)
                        else
                          Text(_locationStatus, style: const TextStyle(fontSize: 12, color: Colors.red)),
                        const SizedBox(height: 4),
                        Text(l10n.locationAutoCapture, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        if (_permissionDenied)
                          TextButton.icon(
                            onPressed: _getCurrentLocation, 
                            icon: const Icon(Icons.refresh, size: 16, color: Colors.indigo), 
                            label: Text(l10n.retryAccess, style: const TextStyle(fontSize: 12, color: Colors.indigo))
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(), 
                      labelText: l10n.contactNumber,
                      hintText: l10n.contactNumberHint,
                      prefixIcon: const Icon(Icons.phone)
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Contact number is mandatory";
                      if (!RegExp(r'^\d{10}$').hasMatch(val)) return "Please enter a valid 10-digit number";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_permissionDenied && _locationUrl == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(l10n.enableLocationToContinue, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _locationUrl == null) ? null : _bookCaretaker,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : Text(l10n.bookCaretaker),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          if (_currentPosition != null)
            _NearbyCaretakersPanel(currentPosition: _currentPosition!),

          StreamBuilder<QuerySnapshot>(
            stream: _bookingsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                   return const Center(child: Padding(
                     padding: EdgeInsets.all(20),
                     child: Text("Preparing your bookings...", style: TextStyle(color: Colors.grey)),
                   ));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = (snapshot.data?.docs ?? []).toList();
                docs.sort((a, b) {
                  final tA = (a.data() as Map<String, dynamic>)['requestTime'] as Timestamp;
                  final tB = (b.data() as Map<String, dynamic>)['requestTime'] as Timestamp;
                  return tB.compareTo(tA);
                });
                
                return ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.medical_services, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(_isLoading ? l10n.processingBooking : l10n.noBookingsYet, 
                                style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final booking = CaretakerBookingModel.fromMap(data, doc.id);
                      
                      Color statusColor = Colors.orange;
                      if (booking.status == 'Confirmed') statusColor = Colors.green;
                      if (booking.status == 'Completed') statusColor = Colors.blue;
                      if (booking.status == 'Cancelled' || booking.status == 'Rejected') statusColor = Colors.red;

                      final localizedStatus = booking.status == 'Confirmed' ? l10n.confirmed : booking.status;

                      return Card(
                        key: ValueKey(doc.id),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text("${booking.serviceType} (${booking.durationType})", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                subtitleWidget(booking, l10n), // we will define a separate piece here
                               Text("${l10n.statusLabel} $localizedStatus", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                               if (booking.status == 'Confirmed' && booking.assignedCaretakerName != null) ...[
                                 const SizedBox(height: 4),
                                 Text("${l10n.caretakerLabel} ${booking.assignedCaretakerName}"),
                                 Text("${l10n.contactLabel} ${(booking.assignedCaretakerContact != null && booking.assignedCaretakerContact != 'Not provided' && booking.assignedCaretakerContact!.isNotEmpty) ? booking.assignedCaretakerContact! : l10n.notSpecified}"),
                               ],
                               if (booking.status == 'Rejected') ...[
                                 const SizedBox(height: 4),
                                 Container(
                                   padding: const EdgeInsets.all(8),
                                   decoration: BoxDecoration(
                                     color: Colors.red.shade50,
                                     borderRadius: BorderRadius.circular(8),
                                     border: Border.all(color: Colors.red.shade200),
                                   ),
                                   child: Row(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       const Icon(Icons.info_outline, color: Colors.red, size: 16),
                                       const SizedBox(width: 6),
                                       Expanded(
                                         child: Text(
                                           "${l10n.reasonLabelDetailed} ${booking.rejectionReason?.isNotEmpty == true ? booking.rejectionReason : l10n.notSpecified}",
                                           style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                                           overflow: TextOverflow.ellipsis,
                                           maxLines: 2,
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                               ]
                            ],
                          ),
                          trailing: Text(
                            DateFormat('MMM d, h:mm a').format(booking.requestTime.toDate()),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget subtitleWidget(CaretakerBookingModel booking, AppLocalizations l10n) {
    if (booking.status == 'Completed' && booking.permissionStatus == 'Pending') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade400),
          borderRadius: BorderRadius.circular(8)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.allowHealthAccess, 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 14)
            ),
            const SizedBox(height: 4),
            Text(
              l10n.healthAccessDesc,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _handlePermission(booking, false),
                  child: Text(l10n.denyAction, style: const TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () => _handlePermission(booking, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: Text(l10n.allowAction),
                )
              ],
            )
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _NearbyCaretakersPanel extends StatelessWidget {
  final Position currentPosition;
  const _NearbyCaretakersPanel({required this.currentPosition});

  double _calculateDistance(double lat1, double lon1, dynamic lat2, dynamic lon2) {
    if (lat2 == null || lon2 == null) return 0.0;
    double dLat2 = (lat2 is num) ? lat2.toDouble() : double.tryParse(lat2.toString()) ?? 0.0;
    double dLon2 = (lon2 is num) ? lon2.toDouble() : double.tryParse(lon2.toString()) ?? 0.0;
    return Geolocator.distanceBetween(lat1, lon1, dLat2, dLon2) / 1000.0; // km
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'caregiver')
        .where('isAvailable', isEqualTo: true)
        .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final caregivers = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        
        // Filter by distance
        final nearby = caregivers.where((c) {
          if (c['latitude'] == null || c['longitude'] == null) return false;
          final dist = _calculateDistance(currentPosition.latitude, currentPosition.longitude, c['latitude'], c['longitude']);
          return dist <= 15.0; // Within 15km radius
        }).toList();

        if (nearby.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.noVolunteersNearby, style: const TextStyle(color: Colors.red, fontSize: 13, fontStyle: FontStyle.italic)),
          );
        }

        // Sort by nearest
        nearby.sort((a, b) {
          final dA = _calculateDistance(currentPosition.latitude, currentPosition.longitude, a['latitude'], a['longitude']);
          final dB = _calculateDistance(currentPosition.latitude, currentPosition.longitude, b['latitude'], b['longitude']);
          return dA.compareTo(dB);
        });

        final l10n = AppLocalizations.of(context)!;
        return Container(
          height: 220,
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.availableNearbyCaregivers, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: nearby.length,
                  itemBuilder: (context, index) {
                    final dist = _calculateDistance(currentPosition.latitude, currentPosition.longitude, nearby[index]['latitude'], nearby[index]['longitude']);
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Container(
                        decoration: BoxDecoration(
                          border: const Border(left: BorderSide(color: Colors.green, width: 4)),
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(12),
                        width: 150,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const CircleAvatar(radius: 20, backgroundColor: Colors.indigo, child: Icon(Icons.person, size: 24, color: Colors.white)),
                            const SizedBox(height: 8),
                            Flexible(
                              child: Text(
                                "${l10n.nameLabel} ${(nearby[index]['name']?.toString().isNotEmpty == true) ? nearby[index]['name'] : (nearby[index]['fullName']?.toString().isNotEmpty == true ? nearby[index]['fullName'] : (nearby[index]['userName']?.toString().isNotEmpty == true ? nearby[index]['userName'] : 'Caregiver'))}", 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.kmAway(dist.toStringAsFixed(1)), 
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(l10n.availableStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
