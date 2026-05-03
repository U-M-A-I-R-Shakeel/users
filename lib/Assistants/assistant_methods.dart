import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:users/Assistants/request_assistant.dart';
import 'package:users/global/global.dart';
import 'package:users/global/map_key.dart';
import 'package:users/models/direction_details_info.dart';
import 'package:users/models/directions.dart';
import 'package:users/models/trips_history_model.dart';
import 'package:users/models/user_model.dart';

class AssistantMethods {
  static void readCurrentOnLineUserInfo() async {
    currentUser = firebaseAuth.currentUser;
    DatabaseReference userRef = FirebaseDatabase.instance
        .ref()
        .child("users")
        .child(currentUser!.uid);

    userRef.once().then((snap) {
      if (snap.snapshot.value != null) {
        userModelCurrentInfo = UserModel.fromSnapshot(snap.snapshot);
      }
    });
  }

  static Future<String> searchAddressForGeographicCoordinates(
      Position position) async {
    String apiUrl =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$mapKey";
    String humanReadableAddress = "";

    var requestResponse = await RequestAssistant.receiveRequest(apiUrl);

    if (requestResponse != "Error Occurred. Failed. No Response.") {
      humanReadableAddress = requestResponse["results"][0]["formatted_address"];

      DirectionDetailsInfo userPickUpAddress = DirectionDetailsInfo();
      userPickUpAddress.locationLatitude = position.latitude;
      userPickUpAddress.locationLongitude = position.longitude;
      userPickUpAddress.locationName = humanReadableAddress;

      userPickUpLocation = userPickUpAddress;
    }

    return humanReadableAddress;
  }

  static Future<Directions?> obtainOriginToDestinationDirectionDetails(
      LatLng originPosition, LatLng destinationPosition) async {
    String urlOriginToDestinationDirectionDetails =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${originPosition.latitude},${originPosition.longitude}&destination=${destinationPosition.latitude},${destinationPosition.longitude}&key=$mapKey";

    var responseDirectionApi = await RequestAssistant.receiveRequest(
        urlOriginToDestinationDirectionDetails);

    if (responseDirectionApi == "Error Occurred. Failed. No Response.") {
      return null;
    }

    Directions directionDetailsInfo = Directions();
    directionDetailsInfo.encodedPoints =
        responseDirectionApi["routes"][0]["overview_polyline"]["points"];

    directionDetailsInfo.distanceText =
        responseDirectionApi["routes"][0]["legs"][0]["distance"]["text"];
    directionDetailsInfo.distanceValue =
        responseDirectionApi["routes"][0]["legs"][0]["distance"]["value"];

    directionDetailsInfo.durationText =
        responseDirectionApi["routes"][0]["legs"][0]["duration"]["text"];
    directionDetailsInfo.durationValue =
        responseDirectionApi["routes"][0]["legs"][0]["duration"]["value"];

    return directionDetailsInfo;
  }

  static double calculateFareAmountFromOriginToDestination(
      Directions directionDetailsInfo) {
    // per km = 25 PKR, per minute = 10 PKR, base fare = 50 PKR
    double timeTraveledFareAmountPerMinute =
        (directionDetailsInfo.durationValue! / 60) * 10;
    double distanceTraveledFareAmountPerKilometer =
        (directionDetailsInfo.distanceValue! / 1000) * 25;
    double totalFareAmount = timeTraveledFareAmountPerMinute +
        distanceTraveledFareAmountPerKilometer +
        50; // base fare

    return double.parse(totalFareAmount.toStringAsFixed(1));
  }

  static void readTripsKeysForOnlineUser() {
    DatabaseReference tripsRef = FirebaseDatabase.instance
        .ref()
        .child("All Ride Requests");

    tripsRef
        .orderByChild("userName")
        .equalTo(userModelCurrentInfo?.name)
        .once()
        .then((snap) {
      if (snap.snapshot.value != null) {
        Map tripsMap = snap.snapshot.value as Map;
        int totalTrips = tripsMap.length;
        List<String> tripKeysList = [];

        tripsMap.forEach((key, value) {
          tripKeysList.add(key);
        });

        // store in global
        tripsKeysList = tripKeysList;
      }
    });
  }

  static void readTripsHistoryInformation() {
    tripsHistoryList.clear();

    for (String eachKey in tripsKeysList) {
      DatabaseReference tripsRef = FirebaseDatabase.instance
          .ref()
          .child("All Ride Requests")
          .child(eachKey);

      tripsRef.once().then((snap) {
        if (snap.snapshot.value != null) {
          var eachTripHistory =
              TripsHistoryModel.fromSnapshot(snap.snapshot);
          if ((snap.snapshot.value as dynamic)["status"] == "ended") {
            tripsHistoryList.add(eachTripHistory);
          }
        }
      });
    }
  }
}