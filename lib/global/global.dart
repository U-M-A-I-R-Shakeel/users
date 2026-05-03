import 'package:firebase_auth/firebase_auth.dart';
import '../models/direction_details_info.dart';
import '../models/directions.dart';
import '../models/trips_history_model.dart';
import '../models/user_model.dart';

final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
User? currentUser;

UserModel? userModelCurrentInfo;

DirectionDetailsInfo? userPickUpLocation;
DirectionDetailsInfo? userDropOffLocation;

String cloudMessagingServerToken = "";

String userDropOffAddress = "";

List<String> tripsKeysList = [];
List<TripsHistoryModel> tripsHistoryList = [];

String chosenDriverId = "";
String driverCarDetails = "";
String driverName = "";
String driverPhone = "";
double driverRatings = 0;

Directions? tripDirectionDetailsInfo;
