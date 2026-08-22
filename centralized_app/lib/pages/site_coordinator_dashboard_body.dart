import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import '../utils/attendance_helpers.dart';
import '../utils/geocode_helpers.dart';
import '../utils/ist_time.dart';
import '../widgets/travel_route_map.dart';

/// Travel dashboard for site coordinators (mirrors web `SiteCoordinatorDashboardView.jsx`).
class SiteCoordinatorDashboardBody extends StatefulWidget {
  const SiteCoordinatorDashboardBody({
    super.key,
    this.shrinkWrap = false,
  });

  final bool shrinkWrap;

  @override
  State<SiteCoordinatorDashboardBody> createState() => _SiteCoordinatorDashboardBodyState();
}

class _SiteCoordinatorDashboardBodyState extends State<SiteCoordinatorDashboardBody> {
  DateTime _date = DateTime.now();
  Map<String, dynamic>? _timelineData;
  List<Map<String, dynamic>> _visits = [];
  bool _loading = true;
  String? _error;
  String? _success;
  String? _busyKey;
  String? _journeyBusy;
  bool _allocating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _dateKey => AttendanceHelpers.todayKey(_date);

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null || session.userId.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final from = '${_dateKey}T00:00:00';
      final to = '${_dateKey}T23:59:59';
      final results = await Future.wait([
        api.fetchTravelTimeline(employeeId: session.userId, date: _dateKey),
        api.fetchSiteVisits(assignedTo: session.userId, from: from, to: to),
      ]);
      if (!mounted) return;
      setState(() {
        _timelineData = Map<String, dynamic>.from(results[0] as Map);
        _visits = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _timelineData = null;
        _visits = [];
        _loading = false;
      });
    }
  }

  Future<({double lat, double lon, String address})?> _requireLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied');
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final address = await GeocodeHelpers.resolveAddressOrCoords(pos.latitude, pos.longitude);
      return (lat: pos.latitude, lon: pos.longitude, address: address);
    } catch (_) {
      setState(() => _error = 'Unable to get location. Enable GPS and try again.');
      return null;
    }
  }

  Future<void> _startOrEndJourney(String action) async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) return;
    final loc = await _requireLocation();
    if (loc == null) return;

    setState(() {
      _journeyBusy = action;
      _error = null;
      _success = null;
    });

    try {
      if (action == 'start') {
        await api.startTravelJourney(
          employeeId: session.userId,
          date: _dateKey,
          latitude: loc.lat,
          longitude: loc.lon,
          address: loc.address,
        );
        _success = 'Journey started. Check in at sites to track distance.';
      } else {
        await api.endTravelJourney(
          employeeId: session.userId,
          date: _dateKey,
          latitude: loc.lat,
          longitude: loc.lon,
          address: loc.address,
        );
        _success = 'Journey ended. You can allocate travel expense.';
      }
      await _load();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _journeyBusy = null);
    }
  }

  Future<void> _visitAction(String visitId, String action) async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) return;
    final loc = await _requireLocation();
    if (loc == null) return;

    final key = '$visitId:$action';
    setState(() {
      _busyKey = key;
      _error = null;
      _success = null;
    });

    try {
      if (action == 'check-in') {
        await api.checkInSiteVisit(
          visitId: visitId,
          employeeId: session.userId,
          latitude: loc.lat,
          longitude: loc.lon,
          address: loc.address,
        );
        _success = 'Checked in at site.';
      } else {
        await api.checkOutSiteVisit(
          visitId: visitId,
          employeeId: session.userId,
          latitude: loc.lat,
          longitude: loc.lon,
          address: loc.address,
        );
        _success = 'Checked out from site.';
      }
      await _load();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _allocateExpense() async {
    final session = context.read<AuthSession>();
    final api = session.api;
    if (api == null) return;
    if (_timelineData?['journeyStarted'] != true) {
      setState(() => _error = 'Start your journey first before allocating travel expense.');
      return;
    }

    final km = _timelineData?['totalDistanceKm'] ?? 0;
    final expense = _timelineData?['estimatedExpense'] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Allocate travel expense', style: TextStyle(fontSize: 14)),
        content: Text(
          'Allocate for $_dateKey?\n\nDistance: $km km\nEstimated: ${_scFormatInr(expense)}',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Allocate')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _allocating = true;
      _error = null;
      _success = null;
    });

    try {
      final res = await api.allocateTravelExpense(employeeId: session.userId, date: _dateKey);
      if (!mounted) return;
      setState(() {
        _success = 'Travel expense allocated: ${_scFormatInr(res['amount'])} for ${res['totalDistanceKm']} km.';
      });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _allocating = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = _timelineData?['journey'];
    final journeyMap = journey is Map ? Map<String, dynamic>.from(journey) : null;
    final journeyStarted = _timelineData?['journeyStarted'] == true && journeyMap?['startedAt'] != null;
    final journeyActive = journeyStarted && journeyMap?['status'] == 'active';
    final journeyEnded = journeyStarted && journeyMap?['status'] == 'ended';
    final timeline = _timelineData?['timeline'] is List
        ? (_timelineData!['timeline'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
      final totalKm = _timelineData?['totalDistanceKm'] ?? 0;
      final estimatedExpense = _timelineData?['estimatedExpense'] ?? 0;
      final ratePerKm = _timelineData?['ratePerKm'] ?? 12;
      final routeUrl = _timelineData?['routeUrl']?.toString();

      final children = <Widget>[
        const Text(
          'Start your journey, then check in at each site. Route distance is calculated after the journey starts.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _pickDate,
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(_dateKey, style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, size: 18)),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _Banner(text: _error!, color: const Color(0xFFFEF2F2), textColor: const Color(0xFFB91C1C)),
        ],
        if (_success != null) ...[
          const SizedBox(height: 8),
          _Banner(text: _success!, color: const Color(0xFFECFDF5), textColor: const Color(0xFF047857)),
        ],
        const SizedBox(height: 8),
        _JourneyPanel(
          loading: _loading,
          journeyStarted: journeyStarted,
          journeyActive: journeyActive,
          journeyEnded: journeyEnded,
          startedAt: journeyMap?['startedAt'],
          startAddress: journeyMap?['startAddress']?.toString(),
          endedAt: journeyMap?['endedAt'],
          journeyBusy: _journeyBusy,
          onStart: () => _startOrEndJourney('start'),
          onEnd: () => _startOrEndJourney('end'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _StatCard(title: 'Distance travelled', value: '$totalKm km', subtitle: 'Calculated route distance', icon: Icons.map_outlined),
            _StatCard(title: 'Estimated expense', value: _scFormatInr(estimatedExpense), subtitle: '₹$ratePerKm / km rate', icon: Icons.attach_money),
          ],
        ),
        const SizedBox(height: 8),
        _Panel(
          title: 'Travel expense allocation',
          subtitle: 'Claim travel reimbursement for completed journey',
          action: _allocating
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : FilledButton(
                  onPressed: _loading || !journeyStarted ? null : _allocateExpense,
                  child: const Text('Allocate expense', style: TextStyle(fontSize: 11)),
                ),
          child: Text(
            journeyEnded
                ? 'Journey completed. You can allocate your travel expense.'
                : journeyStarted
                    ? 'End your journey to finalize travel expense.'
                    : 'Start journey to compute distance.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 8),
        _Panel(
          title: 'Route map',
          subtitle: 'Interactive map and driving directions',
          action: (routeUrl != null && routeUrl.isNotEmpty)
              ? InkWell(
                  onTap: () => TravelRouteMap.openDirections(context, routeUrl: routeUrl, points: timeline),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Open Maps ', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                      Icon(Icons.open_in_new, size: 12, color: Color(0xFF2563EB)),
                    ],
                  ),
                )
              : null,
          child: SizedBox(
            height: 220,
            child: TravelRouteMap(
              points: timeline,
              routeUrl: journeyStarted ? routeUrl : null,
              height: 220,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Panel(
          title: 'Travel timeline',
          subtitle: journeyStarted ? 'Journey start → check-ins' : 'Start journey to begin timeline',
          child: _loading
              ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : !journeyStarted
                  ? const Text('No active journey. Tap Start journey above.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                  : timeline.isEmpty
                      ? const Text('Journey started. Check in at a visit to add stops.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                      : Column(
                          children: timeline.asMap().entries.map((entry) {
                            final point = entry.value;
                            final idx = entry.key;
                            return _TimelineTile(point: point, index: idx, isLast: idx == timeline.length - 1);
                          }).toList(),
                        ),
        ),
        const SizedBox(height: 8),
        _Panel(
          title: "Today's assigned visits",
          subtitle: journeyStarted ? 'Check in on arrival · check out when leaving' : 'Start journey to track distance',
          child: _loading
              ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : _visits.isEmpty
                  ? const Text('No site visits assigned for this date.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                  : Column(
                      children: _visits.map((visit) {
                        return _VisitTile(
                          visit: visit,
                          busyKey: _busyKey,
                          journeyStarted: journeyStarted,
                          onCheckIn: () => _visitAction('${visit['_id']}', 'check-in'),
                          onCheckOut: () => _visitAction('${visit['_id']}', 'check-out'),
                        );
                      }).toList(),
                    ),
        ),
      ];

      if (widget.shrinkWrap) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      }

      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
          children: children,
        ),
      );
    }
  }

String _scFormatInr(dynamic amount) {
  final v = num.tryParse('$amount') ?? 0;
  final s = v.round().toString();
  if (s.length <= 3) return '₹ $s';
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  return '₹ $rest,$last3';
}

String _scFormatTime(dynamic value) => IstTime.formatTimeShort(value);

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.textColor});
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 11, color: textColor)),
    );
  }
}

class _JourneyPanel extends StatelessWidget {
  const _JourneyPanel({
    required this.loading,
    required this.journeyStarted,
    required this.journeyActive,
    required this.journeyEnded,
    required this.startedAt,
    required this.startAddress,
    required this.endedAt,
    required this.journeyBusy,
    required this.onStart,
    required this.onEnd,
  });

  final bool loading;
  final bool journeyStarted;
  final bool journeyActive;
  final bool journeyEnded;
  final dynamic startedAt;
  final String? startAddress;
  final dynamic endedAt;
  final String? journeyBusy;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's journey", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (!loading && !journeyStarted)
            const Text('Journey not started. Tap Start journey to track distance.', style: TextStyle(fontSize: 10, color: Color(0xFFB45309))),
          if (journeyActive)
            Text(
              'Active since ${_scFormatTime(startedAt)}${startAddress != null && startAddress!.isNotEmpty ? ' · $startAddress' : ''}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF047857)),
            ),
          if (journeyEnded)
            Text(
              'Ended at ${_scFormatTime(endedAt)}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (!journeyStarted || journeyEnded)
                FilledButton(
                  onPressed: loading || journeyBusy != null || journeyActive ? null : onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: Text(journeyBusy == 'start' ? 'Starting…' : journeyEnded ? 'Restart journey' : 'Start journey'),
                ),
              if (journeyActive)
                FilledButton(
                  onPressed: loading || journeyBusy != null ? null : onEnd,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: Text(journeyBusy == 'end' ? 'Ending…' : 'End journey'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.subtitle, this.icon});
  final String title;
  final String value;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - 28) / 2;
    return SizedBox(
      width: w,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: const Color(0xFF64748B)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child, this.action});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(padding: const EdgeInsets.all(10), child: child),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatefulWidget {
  const _TimelineTile({required this.point, required this.index, required this.isLast});
  final Map<String, dynamic> point;
  final int index;
  final bool isLast;

  @override
  State<_TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<_TimelineTile> {
  String? _placeName;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _resolvePlace();
  }

  @override
  void didUpdateWidget(covariant _TimelineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point != widget.point) _resolvePlace();
  }

  Future<void> _resolvePlace() async {
    final point = widget.point;
    final raw = '${point['address'] ?? ''}'.trim();
    final lat = num.tryParse('${point['latitude'] ?? point['lat']}')?.toDouble();
    final lon = num.tryParse('${point['longitude'] ?? point['lng'] ?? point['lon']}')?.toDouble();

    if (raw.isNotEmpty && !GeocodeHelpers.isCoordOnlyAddress(raw)) {
      setState(() {
        _placeName = raw;
        _resolving = false;
      });
      return;
    }

    setState(() => _resolving = true);
    final resolved = await GeocodeHelpers.resolveDisplayAddress(
      address: raw.isEmpty ? null : raw,
      latitude: lat,
      longitude: lon,
    );
    if (!mounted) return;
    setState(() {
      _placeName = resolved.isNotEmpty ? resolved : (raw.isNotEmpty ? raw : null);
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final type = point['type']?.toString() ?? '';
    final isStart = type == 'journey_start';
    final isEnd = type == 'journey_end';
    final property = point['property'];
    final propTitle = property is Map ? (property['title'] ?? '').toString() : '';
    final label = isStart
        ? 'Journey start'
        : isEnd
            ? 'Journey end'
            : propTitle.isNotEmpty
                ? propTitle
                : (point['visitorName'] ?? 'Site visit').toString();
    final segmentKm = point['segmentKm'] ?? 0;
    final place = _placeName;
    final city = '${point['city'] ?? ''}'.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isStart || isEnd ? const Color(0xFF334155) : const Color(0xFFE0E7FF),
                child: Text(
                  isStart ? 'S' : isEnd ? 'E' : '${widget.index}',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isStart || isEnd ? Colors.white : const Color(0xFF4338CA)),
                ),
              ),
              if (!widget.isLast) Container(width: 2, height: 24, color: const Color(0xFFE0E7FF)),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    if (!isStart)
                      Text('+$segmentKm km', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                  ],
                ),
                Text(
                  '${_scFormatTime(point['checkInAt'])}${city.isNotEmpty ? ' · $city' : ''}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
                if (_resolving && (place == null || place.isEmpty))
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('Resolving place…', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  )
                else if (place != null && place.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            place,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({
    required this.visit,
    required this.busyKey,
    required this.journeyStarted,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final Map<String, dynamic> visit;
  final String? busyKey;
  final bool journeyStarted;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    final id = '${visit['_id']}';
    final property = visit['property'];
    final title = property is Map
        ? (property['title'] ?? visit['visitorName'] ?? 'Visit').toString()
        : (visit['visitorName'] ?? 'Visit').toString();
    final checkedIn = visit['checkInAt'] != null;
    final checkedOut = visit['checkOutAt'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text(
            '${_scFormatTime(visit['scheduledAt'])} · ${visit['status'] ?? '—'}${visit['city'] != null ? ' · ${visit['city']}' : ''}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
          ),
          if ('${visit['address'] ?? visit['meetingPoint'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${visit['address'] ?? visit['meetingPoint']}', style: const TextStyle(fontSize: 10, color: Color(0xFF475569)), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!checkedIn)
                FilledButton(
                  onPressed: busyKey != null ? null : onCheckIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 10),
                  ),
                  child: Text(busyKey == '$id:check-in' ? '…' : 'Check in'),
                )
              else if (!checkedOut)
                FilledButton(
                  onPressed: busyKey != null ? null : onCheckOut,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 10),
                  ),
                  child: Text(busyKey == '$id:check-out' ? '…' : 'Check out'),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Done', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
                ),
              if (checkedIn && journeyStarted && visit['travelFromPreviousKm'] != null) ...[
                const SizedBox(width: 8),
                Text('+${visit['travelFromPreviousKm']} km', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
