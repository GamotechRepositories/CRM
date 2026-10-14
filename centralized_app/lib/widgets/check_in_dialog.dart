import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../utils/attendance_helpers.dart';
import '../utils/geocode_helpers.dart';
import '../utils/ist_time.dart';

class CheckInDialog extends StatefulWidget {
  const CheckInDialog({super.key});

  @override
  State<CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<CheckInDialog> {
  DateTime _now = IstTime.now();
  Timer? _clockTimer;

  bool _loadingLocation = true;
  String? _locationError;
  double? _latitude;
  double? _longitude;
  String? _address;

  bool _submitting = false;
  String? _submitError;
  bool _success = false;
  String? _successTime;
  String? _successStatus;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = IstTime.now());
    });
    _acquireLocation();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _acquireLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permission denied. Please allow location in settings.';
            _loadingLocation = false;
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      final address = await GeocodeHelpers.resolveAddressOrCoords(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _address = address;
          _loadingLocation = false;
          _locationError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Unable to detect location. Ensure GPS is on and try again.';
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _handleCheckIn() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null || session.userId.isEmpty) return;

    if (_latitude == null || _longitude == null) {
      await _acquireLocation();
      if (_latitude == null || _longitude == null) {
        setState(() => _submitError = _locationError ?? 'Location required to check in.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final res = await api.checkIn(
        employeeId: session.userId,
        latitude: _latitude!,
        longitude: _longitude!,
        address: _address ?? GeocodeHelpers.formatCoords(_latitude!, _longitude!),
      );

      final attendance = res['attendance'] as Map<String, dynamic>? ?? res;
      final checkInVal = attendance['checkIn'];
      final statusVal = attendance['status']?.toString() ?? 'Present';

      final formattedTime = checkInVal != null
          ? AttendanceHelpers.formatTimeOnly(checkInVal)
          : _formatTimeOnly(_now);

      if (mounted) {
        setState(() {
          _success = true;
          _successTime = formattedTime;
          _successStatus = statusVal;
        });
      }

      // Close dialog after short celebration delay
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(true);
      }
    } catch (e) {
      final errStr = e.toString().replaceFirst('Exception: ', '');
      if (errStr.toLowerCase().contains('already checked in')) {
        if (mounted) {
          setState(() {
            _success = true;
            _successTime = _formatTimeOnly(_now);
            _successStatus = 'Already Checked In';
          });
        }
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(true);
        }
      } else {
        if (mounted) {
          setState(() {
            _submitError = errStr;
            _submitting = false;
          });
        }
      }
    }
  }

  static const _kDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _kMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static String _formatDate(DateTime d) {
    final weekday = _kDays[d.weekday - 1];
    final month = _kMonths[d.month - 1];
    return '$weekday, ${d.day} $month ${d.year}';
  }

  static String _formatClock(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    final second = d.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second $period';
  }

  static String _formatTimeOnly(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _greeting() {
    final hour = _now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final isLate = AttendanceHelpers.isLateCheckIn(_now);
    final dateLabel = _formatDate(_now);
    final timeLabel = _formatClock(_now);
    final firstName = session.userName.split(' ').first;

    return PopScope(
      canPop: _success,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        elevation: 12,
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Gradient Banner
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.wb_sunny_rounded,
                        color: Color(0xFFFDE047),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting()}, ${firstName.isEmpty ? 'Team Member' : firstName}! 👋',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Daily Check-In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: _success
                    ? _buildSuccessView()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Live Date & Clock Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TODAY',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateLabel,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'CURRENT TIME',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timeLabel,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Late Cutoff indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cutoff: 10:00 AM (Grace: ${AttendanceHelpers.lateAfterLabel})',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isLate ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLate ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isLate ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isLate ? 'Late Check-In' : 'On Time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isLate ? const Color(0xFFB45309) : const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Location Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _locationError != null
                                        ? const Color(0xFFFEF2F2)
                                        : _loadingLocation
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    size: 18,
                                    color: _locationError != null
                                        ? const Color(0xFFEF4444)
                                        : _loadingLocation
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'WORK LOCATION',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 4),
                                      if (_loadingLocation)
                                        const Row(
                                          children: [
                                            SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Detecting GPS location…',
                                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        )
                                      else if (_locationError != null) ...[
                                        Text(
                                          _locationError!,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
                                        ),
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: _acquireLocation,
                                          child: const Text(
                                            'Retry Location',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                      ] else if (_address != null) ...[
                                        Text(
                                          _address!,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '✓ GPS Verified (${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)})',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_submitError != null && _submitError!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _submitError!,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _handleCheckIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, size: 18),
                                        SizedBox(width: 6),
                                        Text(
                                          'Check In Now',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0), width: 3),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF059669),
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Checked In Successfully!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            'Time: $_successTime  •  Status: $_successStatus',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Have a wonderful workday!',
            style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
