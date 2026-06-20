import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trip_model.dart';
import '../core/theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../core/utils/location_utils.dart';

class InteractiveGoogleMap extends StatefulWidget {
  final double currentLatitude;
  final double currentLongitude;
  final TripStatus tripStatus;
  final String etaMinutes;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double schoolLatitude;
  final double schoolLongitude;
  final String childName;

  const InteractiveGoogleMap({
    super.key,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.tripStatus,
    required this.etaMinutes,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.schoolLatitude,
    required this.schoolLongitude,
    required this.childName,
  });

  @override
  State<InteractiveGoogleMap> createState() => _InteractiveGoogleMapState();
}

class _InteractiveGoogleMapState extends State<InteractiveGoogleMap> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controllerCompleter = Completer<GoogleMapController>();

  @override
  void didUpdateWidget(covariant InteractiveGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLatitude != widget.currentLatitude ||
        oldWidget.currentLongitude != widget.currentLongitude) {
      _animateToPosition();
    }
  }

  void _animateToPosition() async {
    if (_mapController != null) {
      final cameraUpdate = CameraUpdate.newLatLng(
        LatLng(widget.currentLatitude, widget.currentLongitude),
      );
      await _mapController!.animateCamera(cameraUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? pLat = widget.pickupLatitude;
    final double? pLng = widget.pickupLongitude;

    // Calculate distance and ETA mathematically using LocationUtils
    double? distanceMeters;
    int? etaMinutes;
    if (pLat != null && pLng != null && widget.currentLatitude != 0.0) {
      distanceMeters = LocationUtils.calculateDistance(
        widget.currentLatitude,
        widget.currentLongitude,
        pLat,
        pLng,
      );
      etaMinutes = LocationUtils.calculateEtaMinutes(distanceMeters);
    }

    // Determine platform target
    final isDesktop = !kIsWeb && 
        (defaultTargetPlatform != TargetPlatform.android && 
         defaultTargetPlatform != TargetPlatform.iOS);

    if (isDesktop) {
      // High-fidelity fallback schema for Windows/Mac desktop testing
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: AppTheme.backgroundColor,
              child: CustomPaint(
                painter: _FallbackMapPainter(
                  schoolLat: widget.schoolLatitude,
                  schoolLng: widget.schoolLongitude,
                  pickupLat: pLat ?? widget.schoolLatitude,
                  pickupLng: pLng ?? widget.schoolLongitude,
                  busLat: widget.currentLatitude,
                  busLng: widget.currentLongitude,
                  busEta: widget.etaMinutes,
                  tripStatus: widget.tripStatus,
                  childName: widget.childName,
                ),
                child: Container(),
              ),
            ),
          ),
          _buildOverlayCard(distanceMeters, etaMinutes),
        ],
      );
    }

    // Interactive Google Map for Web & Mobile
    final LatLng driverLatLng = LatLng(widget.currentLatitude, widget.currentLongitude);
    final LatLng schoolLatLng = LatLng(widget.schoolLatitude, widget.schoolLongitude);
    final LatLng? pickupLatLng = (pLat != null && pLng != null) ? LatLng(pLat, pLng) : null;

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'School Bus (Driver)'),
      ),
      Marker(
        markerId: const MarkerId('school'),
        position: schoolLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'School'),
      ),
      if (pickupLatLng != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: '${widget.childName}\'s Pickup Point'),
        ),
    };

    // Connect markers with visual route lines
    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('route_path'),
        color: AppTheme.primaryLight,
        width: 5,
        points: [
          schoolLatLng,
          if (pickupLatLng != null) pickupLatLng,
          driverLatLng,
        ],
      ),
    };

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: driverLatLng,
              zoom: 14.5,
            ),
            markers: markers,
            polylines: polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal, // Standard map mode
            onMapCreated: (controller) {
              _mapController = controller;
              _controllerCompleter.complete(controller);
            },
          ),
        ),
        _buildOverlayCard(distanceMeters, etaMinutes),
      ],
    );
  }

  Widget _buildOverlayCard(double? distanceMeters, int? etaMinutes) {
    String distanceText = '-- km';
    if (distanceMeters != null) {
      if (distanceMeters < 1000.0) {
        distanceText = '${distanceMeters.toStringAsFixed(0)} m';
      } else {
        distanceText = '${(distanceMeters / 1000.0).toStringAsFixed(2)} km';
      }
    }

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: AppTheme.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Live Transit Status',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.tripStatus == TripStatus.active
                        ? (etaMinutes == 0 ? 'Van Arrived!' : 'Van arriving in $etaMinutes minutes')
                        : widget.tripStatus == TripStatus.completed
                            ? 'Trip Completed'
                            : 'Idle / Scheduled',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 32,
              width: 1,
              color: Colors.white10,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Distance',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  distanceText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.accentLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Canvas painter representation for platforms where Google Maps is not compiled (Windows simulator fallback)
class _FallbackMapPainter extends CustomPainter {
  final double schoolLat;
  final double schoolLng;
  final double pickupLat;
  final double pickupLng;
  final double busLat;
  final double busLng;
  final String busEta;
  final TripStatus tripStatus;
  final String childName;

  _FallbackMapPainter({
    required this.schoolLat,
    required this.schoolLng,
    required this.pickupLat,
    required this.pickupLng,
    required this.busLat,
    required this.busLng,
    required this.busEta,
    required this.tripStatus,
    required this.childName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.surfaceColor
      ..style = PaintingStyle.fill;
    
    // Background card container
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), 
        const Radius.circular(16),
      ), 
      paint,
    );

    // Map Grid Lines representation
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    final Offset schoolOffset = Offset(size.width * 0.2, size.height * 0.25);
    final Offset pickupOffset = Offset(size.width * 0.5, size.height * 0.55);
    final Offset homeOffset = Offset(size.width * 0.8, size.height * 0.75);

    // Render road paths (Bezier Curves)
    final routePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final Path path = Path();
    path.moveTo(schoolOffset.dx, schoolOffset.dy);
    path.quadraticBezierTo(
      size.width * 0.35, size.height * 0.35, 
      pickupOffset.dx, pickupOffset.dy,
    );
    path.quadraticBezierTo(
      size.width * 0.65, size.height * 0.65, 
      homeOffset.dx, homeOffset.dy,
    );
    canvas.drawPath(path, routePaint);

    final nodePaint = Paint()..style = PaintingStyle.fill;

    // School Marker
    nodePaint.color = AppTheme.primaryColor;
    canvas.drawCircle(schoolOffset, 14, nodePaint);
    nodePaint.color = Colors.white;
    canvas.drawCircle(schoolOffset, 5, nodePaint);
    _drawText(canvas, schoolOffset - const Offset(0, 32), 'Greenwood School', Colors.white, 10, FontWeight.bold);

    // Child Pickup Point Marker
    nodePaint.color = AppTheme.success;
    canvas.drawCircle(pickupOffset, 14, nodePaint);
    nodePaint.color = Colors.white;
    canvas.drawCircle(pickupOffset, 5, nodePaint);
    _drawText(canvas, pickupOffset + const Offset(-20, 20), '$childName Pickup', Colors.white, 10, FontWeight.bold);

    // Bus position mapping along progress
    if (busLat != 0.0) {
      double t = (busLat - schoolLat) / (40.760000 - schoolLat);
      if (t < 0) t = 0;
      if (t > 1) t = 1;

      final double busX = _calculateBezierPosition(schoolOffset.dx, size.width * 0.35, pickupOffset.dx, homeOffset.dx, t);
      final double busY = _calculateBezierPosition(schoolOffset.dy, size.height * 0.35, pickupOffset.dy, homeOffset.dy, t);
      final Offset busOffset = Offset(busX, busY);

      // Bus Glow ring
      final pulsePaint = Paint()
        ..color = AppTheme.warning.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(busOffset, 22, pulsePaint);

      nodePaint.color = AppTheme.warning;
      canvas.drawCircle(busOffset, 12, nodePaint);
      nodePaint.color = Colors.black;
      canvas.drawCircle(busOffset, 4, nodePaint);

      int etaMinutes = 0;
      if (busLat != 0.0) {
        final meters = Geolocator.distanceBetween(busLat, busLng, pickupLat, pickupLng);
        etaMinutes = LocationUtils.calculateEtaMinutes(meters);
      }

      // Driver Tag Box
      final tagRect = Rect.fromLTWH(busOffset.dx - 50, busOffset.dy - 35, 100, 18);
      nodePaint.color = AppTheme.cardColor;
      canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(4)), nodePaint);
      
      _drawText(
        canvas, 
        Offset(busOffset.dx - 45, busOffset.dy - 33), 
        etaMinutes == 0 ? 'Arrived' : '$etaMinutes min away', 
        AppTheme.textPrimary, 
        8, 
        FontWeight.bold,
      );
    } else {
      _drawText(
        canvas, 
        Offset(size.width * 0.5 - 110, size.height * 0.2), 
        'TRACKER IDLE • WAITING FOR ACTIVE TRIP', 
        AppTheme.textMuted, 
        10, 
        FontWeight.bold,
      );
    }
  }

  double _calculateBezierPosition(double p0, double p1, double p2, double p3, double t) {
    final double u = 1 - t;
    return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3;
  }

  void _drawText(Canvas canvas, Offset offset, String text, Color color, double fontSize, FontWeight weight) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
