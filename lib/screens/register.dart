import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:location_sharing_app/screens/login.dart';
import 'package:quickalert/quickalert.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  bool showPassword = true;
  void toggleShowPassword() {
    setState(() {
      showPassword = !showPassword;
    });
  }

  void register() {
    if (!formKey.currentState!.validate()) {
      return;
    }
    Alert(
      context: context,
      type: AlertType.info,
      title: "Register Account?",
      buttons: [
        DialogButton(
          child: Text(
            "Cancel",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          onPressed: () => Navigator.pop(context),
          color: Colors.grey,
        ),
        DialogButton(
          child: Text(
            "Register",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          onPressed: () {
            RegisterUser();
            print('Button Pressed');
          },
          color: Colors.blue.shade700,
        )
      ],
    ).show();
  }

  void RegisterUser() async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: 'Registering',
      text: 'Please wait...',
    );
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: email.text, password: password.text);
      String user_id = userCredential.user!.uid;
      await FirebaseFirestore.instance.collection('user_accounts').doc(user_id).set({
        'userID': user_id,
        'firstname': firstName.text,
        'lastname': lastName.text,
        'email': email.text,
        'isFriend': false,
        'timestamp': FieldValue.serverTimestamp(),
        'friends': []
      });
      firstName.clear();
      lastName.clear();
      email.clear();
      password.clear();
      confirmPassword.clear();

      Navigator.of(context).pop();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => LoginScreen()));
    } on FirebaseAuthException catch (exception) {
      Navigator.of(context).pop();
      if (exception.code == 'email-already-in-use') {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Registration Failed',
          text: 'This email is already in use.',
        );
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Registration Failed',
          text: 'An unexpected error occurred. Please try again.',
        );
      }
      firstName.clear();
      lastName.clear();
      email.clear();
      password.clear();
      confirmPassword.clear();
      print('Error registering user: $exception');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.fromLTRB(0, 5, 0, 8),
          child: Row(
            children: [
              Image.asset(
                'images/location_logo.png',
                width: 40,
                height: 40,
              ),
              SizedBox(width: 8.0),
            ],
          ),
        ),
        backgroundColor: Color.fromARGB(255, 29, 89, 255),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(28.5),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                  },
                  controller: firstName,
                  decoration: InputDecoration(
                      labelText: 'First name', border: OutlineInputBorder()),
                ),
                const SizedBox(
                  height: 18.5,
                ),
                TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                  },
                  controller: lastName,
                  decoration: InputDecoration(
                      labelText: 'Last name', border: OutlineInputBorder()),
                ),
                const SizedBox(
                  height: 18.5,
                ),
                TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    if (!EmailValidator.validate(value)) {
                      return 'Please enter a valid email';
                    }
                  },
                  controller: email,
                  decoration: InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(
                  height: 18.5,
                ),
                TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters long';
                    }
                  },
                  obscureText: showPassword,
                  controller: password,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                        onPressed: toggleShowPassword,
                        icon: Icon(showPassword
                            ? Icons.visibility
                            : Icons.visibility_off)),
                  ),
                ),
                const SizedBox(
                  height: 18.5,
                ),
                TextFormField(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (password.text != value) {
                      return 'Passwords do not match';
                    }
                  },
                  obscureText: showPassword,
                  controller: confirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                        onPressed: toggleShowPassword,
                        icon: Icon(showPassword
                            ? Icons.visibility
                            : Icons.visibility_off)),
                  ),
                ),
                const SizedBox(
                  height: 18.5,
                ),
                //REGISTER BUTTON
                ElevatedButton(
                  onPressed: register,
                  child: Text(
                    'Register',
                    style: GoogleFonts.poppins(
                        textStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.white)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 29, 89, 255),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.all(15),
                    fixedSize: Size(180, 60),
                  ),
                ),
                SizedBox(
                  height: 18.5,
                ),

                //LOGIN BUTTON
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  child: Text(
                    'Login',
                    style: GoogleFonts.poppins(
                        textStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.blue)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.blue, width: 2),
                    ),
                    padding: EdgeInsets.all(15),
                    fixedSize: Size(180, 60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
