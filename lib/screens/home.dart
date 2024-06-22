import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_sharing_app/screens/friends_list.dart';
import 'package:location_sharing_app/screens/login.dart';
import 'package:location_sharing_app/screens/profile.dart';
import 'package:location_sharing_app/screens/shared_locations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final String userEmail;

  const HomePage({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final initialPosition = LatLng(16.0286389, 120.7454167);
  LatLng? selectedPosition;
  String? selectedLocationName;
  String? sharedFriendID;
  Set<String> sharedFriendIDs = Set<String>();
  late GoogleMapController mapController;
  Position? _currentLocation;
  Set<Marker> markers = {
    Marker(
      markerId: MarkerId("1"),
      position: initialPosition,
    ),
  };
  bool isShareContainerVisible = false;
  List<Map<String, String>> friendsList = [];

  List<LatLng> polylineCoordinates = [];
  Set<Polyline> polylines = {};

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    loadFriendsFromFirestore();
    _trackLocation();
  }

  void _getCurrentLocation() async {
    try {
      Position position = await _determinePosition();
      setState(() {
        _currentLocation = position;
      });
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  void _trackLocation() {
    Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (_currentLocation == null ||
          (position.latitude != _currentLocation!.latitude &&
              position.longitude != _currentLocation!.longitude)) {
        setState(() {
          _currentLocation = position;
          polylineCoordinates
              .add(LatLng(position.latitude, position.longitude));
          markers = Set.from([
            Marker(
              markerId: MarkerId("currentLocation"),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: InfoWindow(title: "You are here"),
            ),
          ]);
          polylines = Set.from([
            Polyline(
              polylineId: PolylineId("route"),
              color: Colors.blue,
              points: List.from(polylineCoordinates),
              width: 5,
            ),
          ]);
          mapController.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        });
      }
    });
  }

  void loadFriendsFromFirestore() async {
    try {
      print('Loading friends for user: ${widget.userEmail}');
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('user_accounts')
          .doc(widget.userEmail)
          .get();
      print('User document: ${documentSnapshot.data()}');

      if (documentSnapshot.exists) {
        List<String> friendsIds =
            List<String>.from(documentSnapshot.get('friends') ?? []);
        print('Friends IDs: $friendsIds');

        List<Map<String, String>> tempFriends = [];

        for (String friendID in friendsIds) {
          print('Loading friend: $friendID');
          DocumentSnapshot friendSnapshot = await FirebaseFirestore.instance
              .collection('user_accounts')
              .doc(friendID)
              .get();

          if (friendSnapshot.exists) {
            String firstname = friendSnapshot.get('firstname') ?? '';
            String lastname = friendSnapshot.get('lastname') ?? '';
            print('Friend details: $firstname $lastname');

            tempFriends.add({
              'name': '$firstname $lastname',
              'userID': friendID,
            });
          } else {
            print('Friend document not found for userID: $friendID');
          }
        }

        setState(() {
          friendsList = tempFriends;
          print('Friends list updated: $friendsList');
        });
      } else {
        print('User document not found for email: ${widget.userEmail}');
      }
    } catch (e) {
      print('Failed to load friend list: $e');
    }
  }

  void updateFriendsList() {
    loadFriendsFromFirestore();
  }

  void _shareLocationWithFriend(String userID) async {
    if (_currentLocation == null) {
      print('Current location is not available.');
      return;
    }

    LatLng currentLatLng =
        LatLng(_currentLocation!.latitude, _currentLocation!.longitude);

    List<Placemark> placemarks = await placemarkFromCoordinates(
        currentLatLng.latitude, currentLatLng.longitude);
    String address =
        placemarks.isNotEmpty ? placemarks.first.name ?? '' : 'Unknown address';

    try {
      DocumentSnapshot friendSnapshot = await FirebaseFirestore.instance
          .collection('user_accounts')
          .doc(userID)
          .get();

      if (!friendSnapshot.exists) {
        print('Friend details not found for userID: $userID');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend details not found.')),
        );
        return;
      }

      String? firstname = friendSnapshot.get('firstname') as String?;
      String? lastname = friendSnapshot.get('lastname') as String?;

      if (firstname == null || lastname == null) {
        print(
            'Friend document does not contain required fields: firstname or lastname');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend details are incomplete.')),
        );
        return;
      }

      String sharedByID = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot currentUserSnapshot = await FirebaseFirestore.instance
          .collection('user_accounts')
          .doc(sharedByID)
          .get();
      String? sharedByName = currentUserSnapshot.get('firstname') as String?;

      if (sharedByName == null) {
        sharedByName = 'Unknown';
      }

      CollectionReference sharedLocations =
          FirebaseFirestore.instance.collection('shared_locations');

      sharedLocations.add({
        'address': address,
        'isSharing': true,
        'latitude': currentLatLng.latitude.toString(),
        'longitude': currentLatLng.longitude.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'userID': userID,
        'firstname': firstname,
        'lastname': lastname,
        'sharedBy': sharedByName,
      }).then((value) {
        setState(() {
          sharedFriendIDs.add(userID);
        });
        print('Location shared successfully with $firstname $lastname');
        print('Attempting to retrieve friend details for userID: $userID');
        print('Friend document retrieved: ${friendSnapshot.data()}');

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location shared successfully')));
      }).catchError((error) {
        print('Failed to share location: $error');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to share location')));
      });
    } catch (e) {
      print('Error retrieving friend details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to retrieve friend details.')),
      );
    }
  }

  void _toggleShareContainer() {
    setState(() {
      isShareContainerVisible = !isShareContainerVisible;
    });
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
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SharedLocationsLogScreen()),
              );
            },
            icon: Icon(
              Icons.person_pin_circle_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FriendsListScreen(
                      currentUserEmail: widget.userEmail,
                      updateFriendsList: updateFriendsList,
                    ),
                  ));
            },
            icon: Icon(
              Icons.people_rounded,
              color: Color.fromARGB(255, 255, 255, 255),
              size: 25,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.account_circle,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(userEmail: widget.userEmail),
                ),
              );
            },
          ),
        ],
        backgroundColor: Color.fromARGB(255, 29, 89, 255),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              initialCameraPosition:
                  CameraPosition(target: initialPosition, zoom: 15),
              markers: markers,
              polylines: polylines,
              onMapCreated: (controller) {
                mapController = controller;
              },
            ),
          ],
        ),
      ),
    );
  }
}
