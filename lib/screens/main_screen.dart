import 'dart:async';
import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';
// =========================================================================
// Main Screen for Passengers in Trippo
// Handles picking locations, requesting rides, drawing maps, and tracking drivers
// =========================================================================
import 'package:users/Assistants/assistant_methods.dart';
import 'package:users/Assistants/geofire_assistant.dart';
import 'package:users/global/global.dart';
import 'package:users/models/active_nearby_available_drivers.dart';
import 'package:users/screens/precise_pickup_location.dart';
import 'package:users/screens/profile_screen.dart';
import 'package:users/screens/search_pickup_screen.dart';
import 'package:users/screens/search_places_screen.dart';
import 'package:users/screens/trips_history_screen.dart';
import 'package:users/screens/rate_driver_screen.dart';
import 'package:users/widgets/info_design_ui.dart';
import 'package:users/widgets/pay_fare_amount_dialog.dart';
import 'package:users/widgets/progress_dialog.dart';
import 'package:users/screens/chat_screen.dart';
import 'package:users/Assistants/local_notification_service.dart';
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  LatLng? pickLocation;
  loc.Location location = loc.Location();
  String? _address;

  final Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController? newGoogleMapController;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(32.5742, 73.7765), // Gujrat, Punjab, Pakistan
    zoom: 14.4746,
  );

  GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

  double searchLocationContainerHeight = 220;
  double waitingResponseFromDriverContainerHeight = 0;
  double assignedDriverInfoContainerHeight = 0;

  Position? userCurrentPosition;
  var geoLocator = Geolocator();
  LocationPermission? _locationPermission;
  double bottomPaddingOfMap = 0;

  List<LatLng> pLineCoordinatesList = [];
  Set<Polyline> polyLineSet = {};
  Set<Marker> markerSet = {};
  Set<Circle> circleSet = {};

  bool openNavigationDrawer = true;
  bool activeNearbyDriverKeysLoaded = false;
  BitmapDescriptor? activeNearbyIcon;

  DatabaseReference? referenceRideRequest;
  String driverRideStatus = "Driver is Coming";
  StreamSubscription<DatabaseEvent>? tripRideRequestInfoStreamSubscription;
  StreamSubscription<DatabaseEvent>? chatSubscription;

  String userRideRequestStatus = "";
  bool requestPositionInfo = true;

  checkIfLocationPermissionAllowed() async {
    _locationPermission = await Geolocator.requestPermission();
    if (_locationPermission == LocationPermission.denied) {
      _locationPermission = await Geolocator.requestPermission();
    }
  }

  // Default location: Gujrat, Punjab, Pakistan
  static const double _gujratLat = 32.5742;
  static const double _gujratLng = 73.7765;

  locateUserPosition() async {
    Position cPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    // If emulator returns default US location (Google HQ area), override with Gujrat, Pakistan
    if (cPosition.latitude > 30.0 && cPosition.latitude < 35.0 &&
        cPosition.longitude > 70.0 && cPosition.longitude < 77.0) {
      // Already in Pakistan region, use real location
      userCurrentPosition = cPosition;
    } else {
      // Emulator default (likely US) — fallback to Gujrat, Pakistan
      userCurrentPosition = Position(
        latitude: _gujratLat,
        longitude: _gujratLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    LatLng latLngPosition = LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);
    CameraPosition cameraPosition = CameraPosition(target: latLngPosition, zoom: 15);
    newGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
    String humanReadableAddress = await AssistantMethods.searchAddressForGeographicCoordinates(userCurrentPosition!);
    setState(() { _address = humanReadableAddress; });
    initializeGeoFireListener();
  }

  initializeGeoFireListener() {
    DatabaseReference activeDriversRef = FirebaseDatabase.instance.ref().child("activeDrivers");
    activeDriversRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map driversMap = event.snapshot.value as Map;
        GeoFireAssistant.activeNearbyAvailableDriversList.clear();
        driversMap.forEach((key, value) {
          if (value != null && value is Map) {
            ActiveNearbyAvailableDrivers driver = ActiveNearbyAvailableDrivers();
            driver.driverId = key;
            driver.locationLatitude = double.tryParse(value["latitude"].toString()) ?? 0.0;
            driver.locationLongitude = double.tryParse(value["longitude"].toString()) ?? 0.0;
            GeoFireAssistant.activeNearbyAvailableDriversList.add(driver);
          }
        });
        displayActiveDriversOnUsersMap();
      }
    });
  }

  displayActiveDriversOnUsersMap() {
    setState(() {
      markerSet.clear();
      circleSet.clear();
      Set<Marker> driversMarkerSet = <Marker>{};
      for (ActiveNearbyAvailableDrivers eachDriver in GeoFireAssistant.activeNearbyAvailableDriversList) {
        LatLng eachDriverActivePosition = LatLng(eachDriver.locationLatitude!, eachDriver.locationLongitude!);
        Marker marker = Marker(
          markerId: MarkerId("driver${eachDriver.driverId}"),
          position: eachDriverActivePosition,
          icon: activeNearbyIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          rotation: 360,
        );
        driversMarkerSet.add(marker);
      }
      markerSet = driversMarkerSet;
    });
  }

  createActiveNearbyDriverIconMarker() {
    if (activeNearbyIcon == null) {
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(context, size: const Size(2, 2));
      BitmapDescriptor.asset(imageConfiguration, "images/pick.png").then((value) {
        activeNearbyIcon = value;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    checkIfLocationPermissionAllowed();
  }

  @override
  Widget build(BuildContext context) {
    bool darkTheme = MediaQuery.of(context).platformBrightness == Brightness.dark;
    createActiveNearbyDriverIconMarker();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            // Auto-cancel any active/waiting ride request when leaving the screen
            if (referenceRideRequest != null) {
              cancelRideRequest();
            }
          }
        },
        child: Scaffold(
          key: _scaffoldState,
          drawer: _buildDrawer(darkTheme),
        body: Stack(
          children: [
            // Google Map
            GoogleMap(
              padding: EdgeInsets.only(bottom: bottomPaddingOfMap),
              mapType: MapType.normal,
              myLocationEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              initialCameraPosition: _kGooglePlex,
              polylines: polyLineSet,
              markers: markerSet,
              circles: circleSet,
              onMapCreated: (GoogleMapController controller) {
                _controllerGoogleMap.complete(controller);
                newGoogleMapController = controller;
                setState(() { bottomPaddingOfMap = 240; });
                locateUserPosition();
              },
              onCameraMove: (CameraPosition? position) {
                if (pickLocation != position!.target) {
                  pickLocation = position.target;
                }
              },
              onCameraIdle: () { /* address update handled by precise pickup */ },
            ),

            // Menu/Back button
            Positioned(
              top: 50, left: 18,
              child: GestureDetector(
                onTap: () {
                  if (openNavigationDrawer) {
                    _scaffoldState.currentState!.openDrawer();
                  } else {
                    // Reset to default
                    setState(() {
                      openNavigationDrawer = true;
                      searchLocationContainerHeight = 220;
                      waitingResponseFromDriverContainerHeight = 0;
                      assignedDriverInfoContainerHeight = 0;
                      polyLineSet.clear();
                      markerSet.clear();
                      circleSet.clear();
                      pLineCoordinatesList.clear();
                      userDropOffLocation = null;
                    });
                    locateUserPosition();
                  }
                },
                child: CircleAvatar(
                  backgroundColor: darkTheme ? Colors.grey.shade800 : Colors.white,
                  radius: 22,
                  child: Icon(
                    openNavigationDrawer ? Icons.menu : Icons.close,
                    color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                  ),
                ),
              ),
            ),

            // Precise pickup button
            Positioned(
              top: 50, right: 18,
              child: GestureDetector(
                onTap: () async {
                  var responseFromPickup = await Navigator.push(context, MaterialPageRoute(builder: (c) => const PrecisePickupLocation()));
                  if (responseFromPickup == "obtainedPickUp") {
                    setState(() { _address = userPickUpLocation?.locationName; });
                  }
                },
                child: CircleAvatar(
                  backgroundColor: darkTheme ? Colors.grey.shade800 : Colors.white,
                  radius: 22,
                  child: Icon(Icons.my_location, color: darkTheme ? Colors.amber.shade400 : Colors.blue),
                ),
              ),
            ),

            // Search Location Container
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: AnimatedSize(
                curve: Curves.easeIn,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  height: searchLocationContainerHeight,
                  decoration: BoxDecoration(
                    color: darkTheme ? Colors.grey.shade900 : Colors.white,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 18, spreadRadius: 0.5, offset: Offset(0.7, 0.7))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: Column(
                      children: [
                        // Current location (tappable — user can type manually)
                        GestureDetector(
                          onTap: () async {
                            var result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const SearchPickupScreen(),
                              ),
                            );
                            if (result == "obtainedPickUp") {
                              setState(() {
                                _address = userPickUpLocation?.locationName;
                              });
                            }
                          },
                          child: Row(children: [
                            Icon(Icons.circle, color: Colors.green, size: 14),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: darkTheme ? Colors.grey.shade800 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: darkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("From", style: TextStyle(color: darkTheme ? Colors.grey.shade400 : Colors.grey, fontSize: 11)),
                                          const SizedBox(height: 2),
                                          Text(
                                            _address ?? "Getting your location...",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: darkTheme ? Colors.white : Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.edit_location_alt_outlined,
                                      size: 18,
                                      color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: darkTheme ? Colors.grey.shade700 : Colors.grey.shade300),
                        const SizedBox(height: 14),
                        // Destination search
                        GestureDetector(
                          onTap: () async {
                            var responseFromSearchScreen = await Navigator.push(context, MaterialPageRoute(builder: (c) => const SearchPlacesScreen()));
                            if (responseFromSearchScreen == "obtainedDropOff") {
                              setState(() { openNavigationDrawer = false; });
                              await drawPolyLineFromOriginToDestination(darkTheme);
                            }
                          },
                          child: Row(children: [
                            Icon(Icons.circle, color: Colors.red, size: 14),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: darkTheme ? Colors.grey.shade800 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  userDropOffLocation?.locationName ?? "Where do you want to go?",
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: darkTheme ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 14),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        // Request Ride Button
                        if (userDropOffLocation != null)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkTheme ? Colors.amber.shade400 : Colors.blue,
                              foregroundColor: darkTheme ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              minimumSize: const Size(double.infinity, 48),
                              elevation: 0,
                            ),
                            onPressed: () { saveRideRequestInformation(darkTheme); },
                            child: const Text("Request Ride", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Waiting for driver container
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: waitingResponseFromDriverContainerHeight,
                decoration: BoxDecoration(
                  color: darkTheme ? Colors.grey.shade900 : Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DefaultTextStyle(
                        style: TextStyle(fontSize: 22, color: darkTheme ? Colors.amber.shade400 : Colors.blue, fontWeight: FontWeight.bold),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            TypewriterAnimatedText("Waiting for Driver..."),
                            TypewriterAnimatedText("Please wait..."),
                            TypewriterAnimatedText("Finding nearby driver..."),
                          ],
                          isRepeatingAnimation: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () { cancelRideRequest(); setState(() { waitingResponseFromDriverContainerHeight = 0; searchLocationContainerHeight = 220; }); },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)]),
                          child: const Icon(Icons.close, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("Cancel Ride", style: TextStyle(color: darkTheme ? Colors.grey.shade400 : Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

            // Assigned Driver Info Container
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: assignedDriverInfoContainerHeight,
                decoration: BoxDecoration(
                  color: darkTheme ? Colors.grey.shade900 : Colors.white,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      Text(driverRideStatus, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkTheme ? Colors.amber.shade400 : Colors.blue)),
                      const SizedBox(height: 16),
                      Divider(color: darkTheme ? Colors.grey.shade700 : Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Row(children: [
                        CircleAvatar(radius: 24, backgroundColor: darkTheme ? Colors.amber.shade400 : Colors.blue, child: Icon(Icons.person, color: darkTheme ? Colors.black : Colors.white, size: 28)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(driverName.isNotEmpty ? driverName : "Driver Name", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkTheme ? Colors.white : Colors.black87)),
                            Text(driverCarDetails.isNotEmpty ? driverCarDetails : "Car Details", style: TextStyle(fontSize: 13, color: darkTheme ? Colors.grey.shade400 : Colors.grey)),
                          ]),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (referenceRideRequest?.key != null) {
                                  Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(rideRequestId: referenceRideRequest!.key!)));
                                }
                              },
                              icon: Icon(Icons.chat, color: darkTheme ? Colors.amber.shade400 : Colors.blue, size: 28),
                            ),
                          ],
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ========== Helper Methods ==========

  Future<void> drawPolyLineFromOriginToDestination(bool darkTheme) async {
    var originPosition = LatLng(userPickUpLocation!.locationLatitude!, userPickUpLocation!.locationLongitude!);
    var destinationPosition = LatLng(userDropOffLocation!.locationLatitude!, userDropOffLocation!.locationLongitude!);

    showDialog(context: context, builder: (c) => ProgressDialog(message: "Getting directions..."));

    var directionDetailsInfo = await AssistantMethods.obtainOriginToDestinationDirectionDetails(originPosition, destinationPosition);
    Navigator.pop(context);

    if (directionDetailsInfo == null) return;
    tripDirectionDetailsInfo = directionDetailsInfo;

    List<LatLng> decodedPolyLinePointsResultList = _decodeEncodedPolyline(directionDetailsInfo.encodedPoints!);
    pLineCoordinatesList.clear();

    if (decodedPolyLinePointsResultList.isNotEmpty) {
      pLineCoordinatesList.addAll(decodedPolyLinePointsResultList);
    }

    polyLineSet.clear();
    setState(() {
      Polyline polyline = Polyline(
        color: darkTheme ? Colors.amber.shade400 : Colors.blue,
        polylineId: const PolylineId("PolylineID"),
        jointType: JointType.round,
        points: pLineCoordinatesList,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        width: 5,
      );
      polyLineSet.add(polyline);
    });

    // Fit bounds
    LatLngBounds boundsLatLng;
    if (originPosition.latitude > destinationPosition.latitude && originPosition.longitude > destinationPosition.longitude) {
      boundsLatLng = LatLngBounds(southwest: destinationPosition, northeast: originPosition);
    } else if (originPosition.longitude > destinationPosition.longitude) {
      boundsLatLng = LatLngBounds(southwest: LatLng(originPosition.latitude, destinationPosition.longitude), northeast: LatLng(destinationPosition.latitude, originPosition.longitude));
    } else if (originPosition.latitude > destinationPosition.latitude) {
      boundsLatLng = LatLngBounds(southwest: LatLng(destinationPosition.latitude, originPosition.longitude), northeast: LatLng(originPosition.latitude, destinationPosition.longitude));
    } else {
      boundsLatLng = LatLngBounds(southwest: originPosition, northeast: destinationPosition);
    }
    newGoogleMapController!.animateCamera(CameraUpdate.newLatLngBounds(boundsLatLng, 65));

    // Add markers
    Marker originMarker = Marker(markerId: const MarkerId("originID"), infoWindow: InfoWindow(title: "Origin", snippet: _address ?? ""), position: originPosition, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));
    Marker destinationMarker = Marker(markerId: const MarkerId("destinationID"), infoWindow: InfoWindow(title: "Destination", snippet: userDropOffLocation!.locationName ?? ""), position: destinationPosition, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));

    setState(() {
      markerSet.add(originMarker);
      markerSet.add(destinationMarker);
    });

    // Add circles
    Circle originCircle = Circle(circleId: const CircleId("originID"), fillColor: Colors.green.withOpacity(0.3), center: originPosition, radius: 12, strokeWidth: 3, strokeColor: Colors.white);
    Circle destinationCircle = Circle(circleId: const CircleId("destinationID"), fillColor: Colors.red.withOpacity(0.3), center: destinationPosition, radius: 12, strokeWidth: 3, strokeColor: Colors.white);

    setState(() {
      circleSet.add(originCircle);
      circleSet.add(destinationCircle);
    });
  }

  void saveRideRequestInformation(bool darkTheme) {
    referenceRideRequest = FirebaseDatabase.instance.ref().child("All Ride Requests").push();
    var originLocation = userPickUpLocation;
    var destinationLocation = userDropOffLocation;

    Map originLocationMap = {"latitude": originLocation!.locationLatitude.toString(), "longitude": originLocation.locationLongitude.toString()};
    Map destinationLocationMap = {"latitude": destinationLocation!.locationLatitude.toString(), "longitude": destinationLocation.locationLongitude.toString()};

    Map userInformationMap = {
      "origin": originLocationMap,
      "destination": destinationLocationMap,
      "time": DateTime.now().toString(),
      "userName": userModelCurrentInfo?.name ?? "",
      "userPhone": userModelCurrentInfo?.phone ?? "",
      "originAddress": originLocation.locationName,
      "destinationAddress": destinationLocation.locationName,
      "driverId": "waiting",
      "status": "waiting",
    };

    referenceRideRequest!.set(userInformationMap);

    tripRideRequestInfoStreamSubscription = referenceRideRequest!.onValue.listen((eventSnap) {
      if (eventSnap.snapshot.value == null) return;
      var data = eventSnap.snapshot.value as Map;
      if (data["status"] != null) {
        userRideRequestStatus = data["status"].toString();
      }
      if (data["driverName"] != null) { driverName = data["driverName"].toString(); }
      if (data["driverPhone"] != null) { driverPhone = data["driverPhone"].toString(); }
      if (data["carDetails"] != null) { driverCarDetails = data["carDetails"].toString(); }

      if (userRideRequestStatus == "accepted") {
        setState(() {
          waitingResponseFromDriverContainerHeight = 0;
          assignedDriverInfoContainerHeight = 200;
          searchLocationContainerHeight = 0;
          driverRideStatus = "Driver is Coming";
        });
      }

      if (userRideRequestStatus == "arrived") {
        setState(() { driverRideStatus = "Driver has Arrived"; });
      }

      if (userRideRequestStatus == "ontrip") {
        setState(() { driverRideStatus = "On Trip"; });
      }

      if (userRideRequestStatus == "ended") {
        if (tripDirectionDetailsInfo != null) {
          double fareAmount = AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetailsInfo!);
          showDialog(context: context, builder: (c) => PayFareAmountDialog(fareAmount: fareAmount)).then((value) {
            if (value == "cashPayed") {
              if (data["driverId"] != null && data["driverId"] != "waiting") {
                Navigator.push(context, MaterialPageRoute(builder: (c) => RateDriverScreen(assignedDriverId: data["driverId"])));
              }
              referenceRideRequest!.onDisconnect();
              tripRideRequestInfoStreamSubscription?.cancel();
              chatSubscription?.cancel();
              setState(() {
                searchLocationContainerHeight = 220;
                waitingResponseFromDriverContainerHeight = 0;
                assignedDriverInfoContainerHeight = 0;
                openNavigationDrawer = true;
                polyLineSet.clear();
                markerSet.clear();
                circleSet.clear();
                pLineCoordinatesList.clear();
                userDropOffLocation = null;
              });
              locateUserPosition();
            }
          });
        }
      }
    });

    chatSubscription = referenceRideRequest!.child("chat").onChildAdded.listen((event) {
      if (isChatScreenOpen) return;
      var data = event.snapshot.value as Map?;
      if (data == null) return;
      
      String senderId = data["senderId"]?.toString() ?? "";
      String text = data["text"]?.toString() ?? "";
      
      // Avoid showing notification for our own messages
      if (senderId != firebaseAuth.currentUser?.uid && senderId.isNotEmpty) {
        // Prevent showing notifications for old messages during initial load
        int currentMillis = DateTime.now().millisecondsSinceEpoch;
        if (data["timestamp"] != null) {
          int msgTime = data["timestamp"] is int ? data["timestamp"] : 0;
          if (msgTime > 0 && (currentMillis - msgTime > 5000)) return;
        }
        LocalNotificationService.displayNotification("Driver", text);
      }
    });

    setState(() {
      searchLocationContainerHeight = 0;
      waitingResponseFromDriverContainerHeight = 200;
    });
    Fluttertoast.showToast(msg: "Ride request sent!");
  }

  void cancelRideRequest() {
    referenceRideRequest?.remove();
    tripRideRequestInfoStreamSubscription?.cancel();
    chatSubscription?.cancel();
    setState(() { userRideRequestStatus = ""; });
  }

  Widget _buildDrawer(bool darkTheme) {
    return Drawer(
      backgroundColor: darkTheme ? Colors.grey.shade900 : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: darkTheme ? [Colors.amber.shade400, Colors.amber.shade700] : [Colors.blue, Colors.blue.shade700],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(radius: 30, backgroundColor: Colors.white.withOpacity(0.3), child: Icon(Icons.person, size: 36, color: Colors.white)),
                const SizedBox(height: 10),
                Text(userModelCurrentInfo?.name ?? "User", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(userModelCurrentInfo?.email ?? "", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileScreen())); },
            child: InfoDesignUI(iconData: Icons.person, textInfo: "Profile"),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              AssistantMethods.readTripsKeysForOnlineUser();
              Future.delayed(const Duration(seconds: 1), () { AssistantMethods.readTripsHistoryInformation(); });
              Future.delayed(const Duration(seconds: 2), () { Navigator.push(context, MaterialPageRoute(builder: (c) => const TripsHistoryScreen())); });
            },
            child: InfoDesignUI(iconData: Icons.history, textInfo: "Trip History"),
          ),
          GestureDetector(
            onTap: () { Navigator.pop(context); },
            child: InfoDesignUI(iconData: Icons.info, textInfo: "About"),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              firebaseAuth.signOut();
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: InfoDesignUI(iconData: Icons.logout, textInfo: "Sign Out"),
          ),
        ],
      ),
    );
  }

  List<LatLng> _decodeEncodedPolyline(String encoded) {
    List<LatLng> polylineCoordinates = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index) - 63;
        index++;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index) - 63;
        index++;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polylineCoordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polylineCoordinates;
  }
}
