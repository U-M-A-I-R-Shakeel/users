import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:users/screens/forget_password_screen.dart';
import 'package:users/screens/pending_approval_screen.dart';

import '../global/global.dart';
import 'role_selection_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final emailTextEditingController = TextEditingController();
  final passwordTextEditingController = TextEditingController();

  bool _passwordVisible = false;
  // declare a global key
  final _formKey = GlobalKey<FormState>();


  void _submit() async {
    // validate all the form fields
    if (_formKey.currentState!.validate()) {
      await firebaseAuth.signInWithEmailAndPassword(
          email: emailTextEditingController.text.trim(),
          password: passwordTextEditingController.text.trim()
      ).then((auth) async {
        currentUser = auth.user;

        // Check user approval status
        DatabaseReference userRef = FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(currentUser!.uid);
        DatabaseEvent event = await userRef.once();

        if (event.snapshot.value != null) {
          Map userData = event.snapshot.value as Map;
          String status = userData["status"]?.toString() ?? "approved";

          if (status == "approved") {
            await Fluttertoast.showToast(msg: "Successfully Logged In");
            Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (c) => const RoleSelectionScreen()), (route) => false);
          } else if (status == "pending") {
            await Fluttertoast.showToast(msg: "Your account is pending admin approval.");
            Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (c) => const PendingApprovalScreen()), (route) => false);
          } else if (status == "rejected") {
            await Fluttertoast.showToast(msg: "Your account has been rejected by admin.");
            firebaseAuth.signOut();
          }
        } else {
          // User data not found in database, allow access (legacy user)
          await Fluttertoast.showToast(msg: "Successfully Logged In");
          Navigator.pushAndRemoveUntil(
              context, MaterialPageRoute(builder: (c) => const RoleSelectionScreen()), (route) => false);
        }
      }).catchError((errorMessage) {
        Fluttertoast.showToast(msg: "Error occured : \n $errorMessage");
      });
    }
    else{
      Fluttertoast.showToast(msg: "Not all field are valid");
    }
  }

  @override
  Widget build(BuildContext context) {

    bool darkTheme = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return GestureDetector(
      onTap: (){
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(0),
            children: [
              Image.asset(darkTheme ? "images/city_dark.png": "images/city.png"),
  
              SizedBox(height: 20),
  
              Center(
                child: Text(
                  "Login",
                  style: TextStyle(
                    color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
  
  
  
              Padding(
                  padding: const EdgeInsets.fromLTRB(15, 20, 15, 50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
  
                              TextFormField(
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(100)
                                ],
                                decoration: InputDecoration(
                                  hintText: "Email",
                                  hintStyle: TextStyle(
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: darkTheme ? Colors.black45 : Colors.grey.shade300,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(40),
                                      borderSide: BorderSide(
                                        width: 0,
                                        style: BorderStyle.none,
                                      )
                                  ),
                                  prefixIcon: Icon(Icons.person,color: darkTheme ? Colors.amber.shade400 : Colors.grey),
                                ),
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                validator: (text){
                                  if(text ==null || text.isEmpty) {
                                    return "Email cannot be empty ";
                                  }
                                  if(EmailValidator.validate(text) == true){
                                    return null;
                                  }
                                  if(text.length < 2){
                                    return "Please enter a valid email";
                                  }
                                  if(text.length > 99){
                                    return "Email cannot be more than 100";
                                  }
                                },
                                onChanged: (text) => setState(() {
                                  emailTextEditingController.text =text;
                                }),
                              ),
  
  
                              SizedBox(height: 20,),
                              TextFormField(
                                obscureText: !_passwordVisible,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(100)
                                ],
                                decoration: InputDecoration(
                                    hintText: "Password",
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: darkTheme ? Colors.black45 : Colors.grey.shade300,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(40),
                                        borderSide: BorderSide(
                                          width: 0,
                                          style: BorderStyle.none,
                                        )
                                    ),
                                    prefixIcon: Icon(Icons.person,color: darkTheme ? Colors.amber.shade400 : Colors.grey),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                        color: darkTheme ? Colors.amber.shade400 : Colors.grey,
                                      ),
                                      onPressed: () {
                                        //update the state i.e toggle the state of passwordVisible variable
                                        setState(() {
                                          _passwordVisible = !_passwordVisible;
                                        });
                                      },
                                    )
                                ),
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                validator: (text){
                                  if(text ==null || text.isEmpty) {
                                    return "Password cannot be empty ";
                                  }
  
                                  if(text.length < 6){
                                    return "Please enter a valid email";
                                  }
                                  if(text.length > 49) {
                                    return "Password cannot be more than 50";
                                  }
                                  return null;
                                },
                                onChanged: (text) => setState(() {
                                  passwordTextEditingController.text =text;
                                }),
                              ),
  
                              SizedBox(height: 20,),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                  foregroundColor: darkTheme ? Colors.black : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  minimumSize: Size(double.infinity, 50),
                                ),
                                onPressed: () {
                                  _submit();
                                },
                                child: Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              SizedBox(height: 20,),
  
                              GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                        context, MaterialPageRoute(builder: (c) => ForgetPasswordScreen()));
                                  },
                                  child: Text(
                                    "Forget Password?",
                                    style: TextStyle(
                                      color: darkTheme ? Colors.amber.shade400: Colors.blue,
                                    ),
                                  )
                              ),
  
                              SizedBox(height: 15,),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Does not have an account?",
                                    style: TextStyle(
                                      color:Colors.grey,
                                      fontSize: 15,
                                    ),
                                  ),
  
                                  SizedBox(width: 5,),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RegisterScreen(),
                                        ),
                                      );
                                    },
  
                                    child: Text(
                                      "Register",
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                                      ),
                                    ),
                                  )
                                ],
                              )
  
  
                            ],
                          )
                      ),
                    ],
                  )
              )
            ],
          ),
        ),
      ),
    );
  }
}
