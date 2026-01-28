import 'package:firebase_database/firebase_database.dart';
import 'package:users/global/global.dart';
import 'package:users/models/user_model.dart';

class AssistantMethods {
   static void readCurrentOnLineUserInfo() async {
     currentUser = firebaseAuth.currentUser;
     DatabaseReference userRef = FirebaseDatabase.instance
     .ref()
     .child("users")
     .child(currentUser!.uid);

     userRef.once().then((snap) {
       if(snap.snapshot.value != null){
         userModelCurrentInfo=UserModel.fromSnapshot(snap.snapshot);
       }
     });
   }
}