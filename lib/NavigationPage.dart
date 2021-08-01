import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:gas_710/AddPassengersPage.dart';
import 'package:gas_710/NavigationDrawer.dart';
import 'package:gas_710/widgets/PassengerWidget.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:async';
import 'package:geocoder/geocoder.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:gas_710/auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

double CAMERA_ZOOM = 13;
double CAMERA_TILT = 0;
double CAMERA_BEARING = 0;
LatLng SOURCE_LOCATION = LatLng(33.783022, -118.112858); // CSULB :)
const googlePlacesAPIKey = "Google-Places-API-Key";

GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: googlePlacesAPIKey);

class NavigationPage extends StatefulWidget {
  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage>
    with WidgetsBindingObserver {
  Completer<GoogleMapController> _controller = Completer();
  TextEditingController _textController = new TextEditingController();

  // this set will hold my markers
  Set<Marker> _markers = {};

  // this will hold the generated polylines
  Set<Polyline> _polylines = {};

  // this will hold each polyline coordinate as Lat and Lng pairs
  List<LatLng> polylineCoordinates = [];

  // this is the key object - the PolylinePoints
  // which generates every polyline between start and finish
  PolylinePoints polylinePoints = PolylinePoints();

  String googleAPIKey = "Google-Maps-API-Key";

  // for my custom icons
  BitmapDescriptor sourceIcon;
  BitmapDescriptor destinationIcon;

  // search address
  String searchAddr;

  // number of passengers
  int passengers = 0;

  List<Contact> contacts = new List<Contact>();
  bool _locationSearched = false;
  bool _milesGot = false;
  bool calculationMade = false;
  bool _userProfileSet = false;

  // distance
  double miles = 0.0;

  double latitude = 0.0;
  double longitude = 0.0;

  double fuelEfficiency = 0.0;
  double cost = 0.0;
  double costPerPassenger = 0.0;
  double gas = 0.0;
  String state = "";

  final databaseReference = Firestore.instance;

  final noPhoneError = "NO PHONE NUMBER PROVIDED";
  final noEmailError = "NO EMAIL PROVIDED";

  bool userDriving = true;
  Contact _driver = Contact();

  String _theme;
  String _darkMapStyle;
  String _lightMapStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getTheme();
    rootBundle.loadString('assets/dark_map_theme.json').then((string) {
      _darkMapStyle = string;
    });
    rootBundle.loadString('assets/light_map_theme.json').then((string) {
      _lightMapStyle = string;
    });
    setSourceAndDestinationIcons();
    getStateLocation();
    _getInitLocation();
    setGas();
    getUserProfile();
    getFuelEfficiency();
  }

  Future setTheme(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('theme', value);
    setState(() {
      _theme = prefs.getString('theme');
    });
  }

  @override
  void didChangePlatformBrightness() {
    final Brightness brightness =
        WidgetsBinding.instance.window.platformBrightness;
    //inform listeners and rebuild widget tree
    print('THEME CHANGED');
    if (brightness == Brightness.dark) {
      setTheme('Dark');
      Route route = MaterialPageRoute(builder: (context) => NavigationPage());
      Navigator.pushReplacement(context, route);
    } else if (brightness == Brightness.light) {
      setTheme('Light');
      Route route = MaterialPageRoute(builder: (context) => NavigationPage());
      Navigator.pushReplacement(context, route);
    } else {
      setTheme('Light');
      Route route = MaterialPageRoute(builder: (context) => NavigationPage());
      Navigator.pushReplacement(context, route);
    }
  }

  void getTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _theme = (prefs.getString('theme') ??
          (MediaQuery.of(context).platformBrightness == Brightness.dark
              ? 'Dark'
              : 'Light'));
    });
    print('Theme $_theme');
  }

  void getUserProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print(prefs.getString('profileName'));
    if (prefs.getString('profileName') == "No Name Set") {
      Fluttertoast.showToast(
        msg: 'Update Contact Profile in Settings!',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIos: 1,
        fontSize: 16.0,
      );
    } else {
      _userProfileSet = true;
    }
    setState(() {
      _driver.displayName = (prefs.getString('profileName') ?? "No Name Set");
      _driver.emails = [
        Item(
            label: 'work',
            value: (prefs.getString('profileEmail') ?? "No Email Set"))
      ];
      _driver.phones = [
        Item(
            label: 'mobile',
            value: (prefs.getString('profileNunber') ?? "No Number Set"))
      ];
    });
  }

  void setSourceAndDestinationIcons() async {
    sourceIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), 'assets/driving_pin.png');
    destinationIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), 'assets/location_pin.png');
  }

  void getStateLocation() async {
    var currentLocation = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    var currentState = await _getState(currentLocation);
    state = currentState.toString(); // sets state to current state
  }

  void _onMapCreated(GoogleMapController controller) {
    if (_theme == 'Dark') {
      controller.setMapStyle(_darkMapStyle);
    } else if (_theme == 'Light') {
      controller.setMapStyle(_lightMapStyle);
    } else {
      controller.setMapStyle(_lightMapStyle);
    }
    _controller.complete(controller);
  }

  void _getLocation() async {
    var currentLocation = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    print(
        'got current location as ${currentLocation.latitude}, ${currentLocation.longitude}');
    var currentAddress = await _getAddress(currentLocation);
    await _moveToPosition(currentLocation);

    setState(() {
      final marker = Marker(
        markerId: MarkerId("curr_loc"),
        position: LatLng(currentLocation.latitude, currentLocation.longitude),
        infoWindow: InfoWindow(title: currentAddress),
        icon: sourceIcon,
      );
      _markers.add(marker);
    });
  }

  _getInitLocation() async {
    var currentLocation = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    await _moveToPosition(currentLocation);
  }

  PanelController _pc = new PanelController();

  @override
  Widget build(BuildContext context) {
    CameraPosition initialLocation = CameraPosition(
        zoom: CAMERA_ZOOM,
        bearing: CAMERA_BEARING,
        tilt: CAMERA_TILT,
        target: SOURCE_LOCATION);

    BorderRadiusGeometry radius = BorderRadius.only(
      topLeft: Radius.circular(24.0),
      topRight: Radius.circular(24.0),
    );

    return new Scaffold(
      drawer: NavigationDrawer(), // provides nav drawer
      appBar: new AppBar(
        title: new Text("Navigation Page"),
        backgroundColor: Colors.purple,
      ),
      body: SlidingUpPanel(
        controller: _pc,
        color: _theme == 'Dark'
            ? Color.fromRGBO(18, 18, 18, 1.0)
            : Color.fromRGBO(255, 255, 255, 1.0),
        borderRadius: radius,
        minHeight: 70,
        backdropTapClosesPanel: true,
        backdropEnabled: true,
        backdropOpacity: 0.3,
        parallaxEnabled: true,
        panel: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Expanded(
                child: Container(
                  alignment: Alignment.topLeft,
                  child: Padding(
                      padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 8.0, 0, 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  'Add Passengers',
                                  style: TextStyle(
                                    fontSize: 23.0,
                                  ),
                                ),
                                Spacer(),
                                Container(
                                  decoration: BoxDecoration(
                                    color: _theme == 'Dark'
                                        ? Colors.amber
                                        : Colors.purple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.location_on),
                                    onPressed: () {
                                      if (_pc.isAttached) {
                                        if (_pc.isPanelOpen) {
                                          _pc.close();
                                          _getLocation();
                                        } else {
                                          _getLocation();
                                        }
                                      }
                                    },
                                    tooltip: "Get Your Current Location",
                                    iconSize: 36,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(
                                  width: 10.0,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                      color: _theme == 'Dark'
                                          ? Colors.amber
                                          : Colors.purple,
                                      shape: BoxShape.circle),
                                  child: IconButton(
                                    icon: Icon(Icons.group_add),
                                    onPressed: () {
                                      if (_pc.isAttached) {
                                        if (_pc.isPanelClosed) {
                                          _pc.open();
                                          _getPassengers(context);
                                        } else {
                                          _getPassengers(context);
                                        }
                                      }
                                    },
                                    tooltip: "Add Passengers to a Trip",
                                    iconSize: 36,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: _theme == 'Dark'
                                  ? Colors.grey[900]
                                  : Colors.grey[100],
                              ),
                              child: passengers > 0
                                ? ListView.builder(
                                  itemCount: contacts.length,
                                  itemBuilder: (context, index) {
                                    return PassengerWidget( 
                                      passenger: contacts[index],
                                      index: index,
                                      onLongPress: () {
                                        final Contact passenger = contacts[index];
                                        setState(() {
                                          _driver = passenger;
                                          userDriving = false;
                                        });
                                        Scaffold.of(context)
                                          .showSnackBar(SnackBar(
                                            content: Text(
                                              '${passenger.displayName} has been assigned as driver'
                                            )
                                          )
                                        );
                                      },
                                      onDismissed: (_) {
                                        final Contact passenger = contacts[index];
                                        setState(() {
                                          if (_driver == passenger) {
                                            userDriving = true;
                                            getUserProfile();
                                            Scaffold.of(context)
                                              .showSnackBar(SnackBar(
                                                content: Text(
                                                  "You are the driver"
                                                )
                                              )
                                            );
                                          }
                                          contacts.removeAt(index);
                                          passengers--;
                                          setCostPP();
                                        });
                                        Scaffold.of(context).
                                          showSnackBar(
                                            SnackBar(content:
                                              Text(
                                                "${passenger.displayName} removed"
                                              )
                                            )
                                          );
                                      },
                                    );
                                  },
                                  scrollDirection: Axis.vertical,
                                )
                                : Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Try adding some contacts!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18.0,
                                        color: Colors.grey[400]
                                      ),
                                    ),
                                )
                              ),
                            ),
                        ],
                      )),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Number of Passengers: $passengers',
                              style: TextStyle(
                                  fontSize: 20.0, color: Colors.grey[700]),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Total Miles: $miles',
                              style: TextStyle(
                                  fontSize: 20.0, color: Colors.grey[700]),
                            ),
                          ),
                          Divider(
                            thickness: 0.8,
                          ),
                          Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                child: Text(
                                  (passengers == 0 || miles == 0)
                                      ? 'Cost Per Passenger: 0.0'
                                      : 'Cost Per Passenger: $costPerPassenger',
                                  style: TextStyle(
                                      fontSize: 20.0,
                                      color: Colors.grey[700],
                                      decoration:
                                          (passengers == 0 || miles == 0)
                                              ? null
                                              : TextDecoration.underline),
                                ),
                                onTap: () {
                                  if (passengers != 0 || miles != 0) {
                                    Fluttertoast.showToast(
                                        msg:
                                            '(${gas.toStringAsFixed(2)} GAS x $miles MILES) / ($fuelEfficiency MPG x $passengers PASSENGERS) ');
                                  }
                                },
                              )),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Total Cost: $cost',
                              style: TextStyle(
                                fontSize: 20.0,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ]),
                  ),
                ),
              ),
              Row(children: <Widget>[
                Checkbox(
                  value: userDriving,
                  activeColor: Colors.amber,
                  onChanged: (bool newValue) {
                    setState(() {
                      userDriving = newValue;
                      if (newValue) {
                        getUserProfile();
                      }
                    });
                  },
                ),
                Text('I am the driver!'),
                Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: RaisedButton(
                      color: ((passengers > 0) &&
                              (_locationSearched) &&
                              (_userProfileSet))
                          ? Colors.amber
                          : Colors.grey[400],
                      child: Text(
                        "Confirm Passengers",
                      ),
                      onPressed: confirmPassengerButtonPress,
                      onLongPress: () {
                        print(_driver.displayName);
                      },
                    ),
                  ),
                ),
              ])
            ],
          ),
        ),
        body: Stack(children: <Widget>[
          GoogleMap(
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            tiltGesturesEnabled: false,
            compassEnabled: false,
            markers: _markers,
            polylines: _polylines,
            mapType: MapType.normal,
            onMapCreated: _onMapCreated,
            initialCameraPosition: initialLocation,
            onLongPress: (LatLng destination) {
              longPressAndNavigate(destination);
            },
          ),
          Positioned(
            top: 30.0,
            right: 15.0,
            left: 15.0,
            child: Container(
              height: 50.0,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: _theme == 'Dark'
                    ? Color.fromRGBO(18, 18, 18, 1.0)
                    : Colors.white,
              ),
              child: TextField(
                readOnly: false,
                controller: _textController,
                // When user taps search bar, autocomplete comes up
                onTap: () async {
                  Prediction p = await PlacesAutocomplete.show(
                    context: context,
                    mode: Mode.overlay,
                    apiKey: googlePlacesAPIKey,
                  );
                  //if user picks an address, send it to the search bar
                  if (p != null) {
                    displayPrediction(p);
                    searchAddr = p.description;
                    _textController.value = TextEditingValue(
                      text: searchAddr,
                      selection: TextSelection.fromPosition(
                        TextPosition(offset: searchAddr.length),
                      ),
                    );
                    searchandNavigate();
                  }
                  //closes keyboard
                  FocusScope.of(context).requestFocus(new FocusNode());
                },
                //When user presses 'ok' on keyboard.
                onSubmitted: (String value) async {
                  searchandNavigate();
                },
                decoration: InputDecoration(
                  hintText: 'Enter Address..',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(left: 15.0, top: 15.0),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    iconSize: 30.0,
                    onPressed: searchandNavigate,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    searchAddr = val;
                  });
                },
              ),
            ),
          )
        ]),
      ),
    );
  }

  Future<void> animateTo(double lat, double long) async {
    final c = await _controller.future;
    final p = CameraPosition(target: LatLng(lat, long), zoom: 15.0);
    c.animateCamera(CameraUpdate.newCameraPosition(p));
  }

  longPressAndNavigate(LatLng destination) {
    _markers.clear(); // clears any previous search queries
    _polylines.clear();
    polylineCoordinates.clear();
    Geolocator().placemarkFromCoordinates(destination.latitude, destination.longitude).then((result) async {
      Placemark placemark = result[0];
      animateTo(placemark.position.latitude,
          placemark.position.longitude); // takes us to the location
      var currentLocation = await Geolocator().getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best); // pings YOUR location
      double distanceInMeter = await Geolocator().distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          placemark.position.latitude,
          placemark.position.longitude);
      miles = convertMetersToMiles(distanceInMeter);
      if(miles > 0) {
        setCost();
        setCostPP();
      }
      _locationSearched = true;
      _milesGot = true;
      latitude = placemark.position.latitude;
      longitude = placemark.position.longitude;
      searchAddr = '${placemark.subThoroughfare} ${placemark.thoroughfare} ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.postalCode}';
      print(
          "Distance to $searchAddr is $distanceInMeter meters from your location");
      setMapPins(currentLocation.latitude, currentLocation.longitude,
          placemark.position.latitude, placemark.position.longitude);
      setPolylines(currentLocation.latitude, currentLocation.longitude,
          placemark.position.latitude, placemark.position.longitude);
    });
  }

  searchandNavigate() {
    _markers.clear(); // clears any previous search queries
    _polylines.clear();
    polylineCoordinates.clear();
    Geolocator().placemarkFromAddress(searchAddr).then((result) async {
      // result is your destination that searched from searchAddr
      animateTo(result[0].position.latitude,
          result[0].position.longitude); // takes us to the location
      var currentLocation = await Geolocator().getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best); // pings YOUR location
      double distanceInMeter = await Geolocator().distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          result[0].position.latitude,
          result[0].position.longitude);
      miles = convertMetersToMiles(distanceInMeter);
      if (miles > 0) {
        setCost();
        setCostPP();
      }
      _locationSearched = true;
      _milesGot = true;
      latitude = result[0].position.latitude;
      longitude = result[0].position.longitude;
      print(
          "Distance to $searchAddr is $distanceInMeter meters from your location");
      setMapPins(currentLocation.latitude, currentLocation.longitude,
          result[0].position.latitude, result[0].position.longitude);
      setPolylines(currentLocation.latitude, currentLocation.longitude,
          result[0].position.latitude, result[0].position.longitude);
    });
  }

  Future<String> _getAddress(Position pos) async {
    List<Placemark> placemarks = await Geolocator()
        .placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (placemarks != null && placemarks.isNotEmpty) {
      final Placemark pos = placemarks[0];
      print(pos.thoroughfare + ', ' + pos.locality);
      return pos.thoroughfare + ', ' + pos.locality;
    }
    return "";
  }

  Future<String> _getState(Position pos) async {
    List<Placemark> placemarks = await Geolocator()
        .placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (placemarks != null && placemarks.isNotEmpty) {
      final Placemark pos = placemarks[0];
      print(pos.administrativeArea);
      return pos.administrativeArea;
    }
    return "";
  }

  Future<void> _moveToPosition(Position pos) async {
    if (_controller == null) return;
    print('moving to position ${pos.latitude}, ${pos.longitude}');
    animateTo(pos.latitude, pos.longitude);
  }

  void setMapPins(double sourceLat, double sourceLong, double destLat,
      double destLong) async {
    double distanceInMeter = await Geolocator()
        .distanceBetween(sourceLat, sourceLong, destLat, destLong);
    setState(() {
      // source pin
      _markers.add(Marker(
          markerId: MarkerId('sourcePin'),
          position: LatLng(sourceLat, sourceLong),
          icon: sourceIcon));
      // destination pin
      _markers.add(Marker(
          markerId: MarkerId('destPin'),
          position: LatLng(destLat, destLong),
          icon: destinationIcon,
          infoWindow: InfoWindow(
            title: "$distanceInMeter meters away",
          )));
    });
  }

  setPolylines(double sourceLat, double sourceLong, double destLat,
      double destLong) async {
    List<PointLatLng> result = await polylinePoints?.getRouteBetweenCoordinates(
        googleAPIKey, sourceLat, sourceLong, destLat, destLong);
    if (result.isNotEmpty) {
      // loop through all PointLatLng points and convert them
      // to a list of LatLng, required by the Polyline
      result.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    setState(() {
      // create a Polyline instance
      // with an id, an RGB color and the list of LatLng pairs
      Polyline polyline = Polyline(
          polylineId: PolylineId("poly"),
          color: Color.fromARGB(255, 40, 122, 198),
          points: polylineCoordinates);

      // add the constructed polyline as a set of points
      // to the polyline set, which will eventually
      // end up showing up on the map
      _polylines.add(polyline);
    });
  }

  double convertMetersToMiles(double m) {
    return double.parse((m * 0.00062137).toStringAsFixed(2));
  }

  //prints the autocomplete address
  //Can be scraped later if of no use
  Future<Null> displayPrediction(Prediction p) async {
    if (p != null) {
      PlacesDetailsResponse detail =
          await _places.getDetailsByPlaceId(p.placeId);

      var placeId = p.placeId;
      double lat = detail.result.geometry.location.lat;
      double lng = detail.result.geometry.location.lng;

      var address = await Geocoder.local.findAddressesFromQuery(p.description);

      print(lat.toString() + ", " + lng.toString() + ", " + p.description);
    }
  }

  void dispose() {
    _textController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  //Return passengers data and set it to contacts variable
  _getPassengers(BuildContext context) async {
    List<Contact> passengerResult = new List<Contact>();

    passengerResult = await Navigator.push(context,
        new MaterialPageRoute(builder: (context) => AddPassengersPage()));
    setState(() {
      if (passengerResult != null) {
        contacts = passengerResult;
        passengers = passengerResult.length;
        if (miles > 0) {
          setCost();
          setCostPP();
        }
      }
    });
  }

  void _showConfirmDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.directions, size: 60.0),
                    title: Text(
                      'Your Trip',
                      style: TextStyle(
                        fontSize: 30.0,
                      ),
                    ),
                    subtitle: Text(
                      '$miles miles to $searchAddr',
                      style: TextStyle(
                        fontSize: 15.0,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 35.0,
                    child: ListView.separated(
                      separatorBuilder: (context, index) => SizedBox(
                        width: 5.0,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: contacts.length,
                      itemBuilder: (BuildContext context, int index) => Chip(
                          avatar: (contacts[index].avatar != null &&
                                  contacts[index].avatar.length > 0)
                              ? CircleAvatar(
                                  backgroundImage:
                                      MemoryImage(contacts[index].avatar))
                              : CircleAvatar(
                                  child: Text(contacts[index].initials(),
                                      style: TextStyle(
                                        color: Colors.white,
                                      )),
                                  backgroundColor: Colors.purple,
                                ),
                          label: Text(contacts[index].displayName,
                              style: TextStyle(color: Colors.black)),
                          backgroundColor: (_driver == contacts[index])
                              ? Colors.amber
                              : Colors.grey[300]),
                    ),
                  ),
                  ButtonBar(
                    children: <Widget>[
                      FlatButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text('Go Back'),
                      ),
                      RaisedButton(
                          onPressed: () {
                            if (signedIn) {
                              addTrip();
                              addContact();
                              if (_pc.isAttached) {
                                if (_pc.isPanelOpen) {
                                  _pc.close();
                                }
                              }
                              Navigator.pop(context);
                              openMap(searchAddr);
                              searchAddr = null;
                            } else {
                              showAlertDialog(context);
                            }
                          },
                          child: Text('Start Trip'),
                          color: Colors.amber),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
  }

  showAlertDialog(BuildContext context) {
    AlertDialog alert = AlertDialog(
      title: Text('Warning'),
      content: Text(
          'Your Trips Will Not Be Saved Unless You Are Signed In. \n\nPlease Check Settings.'),
      actions: <Widget>[
        FlatButton(
          child: Text('Open GoogleMaps'),
          onPressed: () {
            if (_pc.isAttached) {
              if (_pc.isPanelOpen) {
                _pc.close();
              }
            }
            Navigator.pop(context);
            openMap(searchAddr);
            searchAddr = null;
          },
        ),
      ],
    );

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        });
  }

  //when Confirm Passengers button gets pressed
  confirmPassengerButtonPress() {
    print(_userProfileSet);
    if (contacts.length > 0 &&
        _milesGot &&
        _locationSearched &&
        _userProfileSet) {
      _showConfirmDialog();
    } else {
      if (contacts.length <= 0 && !_milesGot && !_locationSearched) {
        Fluttertoast.showToast(
          msg: 'No passengers or destination set',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIos: 1,
          fontSize: 16.0,
        );
      } else if (contacts.length <= 0) {
        Fluttertoast.showToast(
          msg: 'No passengers selected',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIos: 1,
          fontSize: 16.0,
        );
      } else if (!_milesGot || !_locationSearched) {
        Fluttertoast.showToast(
          msg: 'Destination not set',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIos: 1,
          fontSize: 16.0,
        );
      } else if (!_userProfileSet) {
        Fluttertoast.showToast(
          msg: 'Update Contact Profile in Settings',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIos: 1,
          fontSize: 16.0,
        );
      }
    }
  }

  setGas() async {
    // TODO: change collection to 'costPerState' when updated in Firebase
    // TODO: change so that it actually gets the location instead of pulling California's gas
    var query = Firestore.instance
        .collection('costPerSate')
        .where('location', isEqualTo: 'California')
        .getDocuments();
    query.then((value) =>
        gas = double.parse(value.documents[0]['ppg'].toString().substring(1)));
  }

  setCost() {
    setState(() {
      print('Gas: $gas Miles: $miles FuelEfficiency $fuelEfficiency');
      double tempCost = ((miles * gas) / fuelEfficiency);
      cost = double.parse(tempCost.toStringAsFixed(2));
      print('Cost: $cost');
      calculationMade = true;
    });
  }

  setCostPP() {
    String temp = (cost / passengers).toStringAsFixed(2);
    setState(() {
      costPerPassenger = double.parse(temp);
    });
  }

  static Future<void> openMap(String location) async {
    String googleUrl =
        'https://www.google.com/maps/search/?api=1&query=$location';
    if (await canLaunch(googleUrl)) {
      await launch(googleUrl);
    } else {
      throw 'Could not open the map.';
    }
  }

  void addTrip() async {
    // this is different from addPassengers() bc this one stores all passengers in one
    var userReference =
        databaseReference.collection('userData').document(firebaseUser.email);
    print('addTrip: selected.length = ${contacts.length}');
    var passengers = [];
    //This is to set the price for passenger payment in firebase.
    HashMap passengersOwed = new HashMap<String, dynamic>();
    for (int i = 0; i < contacts.length; i++) {
      passengers.add(contacts[i].displayName);
      passengersOwed.putIfAbsent(
          contacts[i].displayName, () => costPerPassenger);
    }
    String driverName, driverEmail, driverPhone;
    driverName = _driver.displayName;
    if (_driver.emails.isEmpty) {
      driverEmail = noEmailError;
    } else {
      driverEmail = _driver.emails.first.value.toString();
    }
    if (_driver.phones.isEmpty) {
      driverPhone = noPhoneError;
    } else {
      driverPhone = _driver.phones.first.value.toString();
    }
    print('addTrip: Sending $passengers to Firebase');
    await userReference.collection("trips").add({
      'passengers': passengers,
      'passengersOwed': passengersOwed,
      'miles': miles,
      'location': searchAddr,
      'date': DateTime.now(),
      'price': cost,
      'pricePerPassenger': costPerPassenger,
      'route': GeoPoint(latitude, longitude),
      'driverName': driverName,
      'driverEmail': driverEmail,
      'driverPhone': driverPhone,
    });
  }

  void addContact() async {
    // we add per individual
    var userReference =
        databaseReference.collection('userData').document(firebaseUser.email);
    var test = await userReference
        .collection('userData')
        .document(firebaseUser.email)
        .collection('contacts')
        .getDocuments();
    if (test.documents.length == 0) {
      // no record of collection
      userReference.collection('contacts').document('init').setData({
        'displayName': 'init',
        'emailAddress': 'int',
        'phoneNumber': 'int',
        'avatar': 'init',
        'bill': 0.0,
      });
    }
    for (int i = 0; i < contacts.length; i++) {
      var query = await userReference
          .collection('contacts')
          .where('displayName', isEqualTo: contacts[i].displayName)
          .getDocuments();
      if (query.documents.length == 0) {
        String emails, phoneNumbers = '';
        if (contacts[i].emails.isNotEmpty) {
          emails = contacts[i].emails.first.value.toString();
        } else {
          emails = noEmailError;
        }
        if (contacts[i].phones.isNotEmpty) {
          phoneNumbers = contacts[i].phones.first.value.toString();
        } else {
          phoneNumbers = noPhoneError;
        }

        var avatar;
        if (contacts[i].avatar != null && contacts[i].avatar.length > 0) {
          avatar = String.fromCharCodes(contacts[i].avatar);
        } else {
          avatar = 'none';
        }
        if (_driver.phones.first.value.toString() ==
            contacts[i].phones.first.value.toString()) {
          print(
              'addContacts: Sending DRIVER ${contacts[i].displayName} - $emails - $phoneNumbers');
          await userReference.collection("contacts").add({
            'displayName': contacts[i].displayName,
            'emailAddress': emails,
            'phoneNumber': phoneNumbers,
            'avatar': avatar,
            'bill': (costPerPassenger * -1)
          });
        } else {
          print(
              'addContacts: Sending passenger ${contacts[i].displayName} - $emails - $phoneNumbers');
          await userReference.collection("contacts").add({
            'displayName': contacts[i].displayName,
            'emailAddress': emails,
            'phoneNumber': phoneNumbers,
            'avatar': avatar,
            'bill': costPerPassenger
          });
        }
      } else if (query.documents.length == 1) {
        // contact exists within Firebase
        var docId = query.documents[0].documentID;
        var updatedBill;
        if (userDriving) {
          updatedBill = query.documents[0]['bill'] + costPerPassenger;
        } else if (_driver.phones.first.value.toString() ==
            query.documents[0]['phoneNumber']) {
          updatedBill = query.documents[0]['bill'] - cost;
        }
        await userReference
            .collection('contacts')
            .document(docId)
            .updateData({'bill': updatedBill});
      }
    }
    userReference.collection('contacts').document('init').delete();
  }

  Future getFuelEfficiency() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      this.fuelEfficiency = (prefs.getDouble('profileMPG') ?? 0.0);
    });
  }
}
