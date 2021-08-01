import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gas_710/NavigationDrawer.dart';
import 'package:gas_710/auth.dart';
import 'package:gas_710/AccountPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PaymentServices {paypal, gpay, cashapp, venmo, zelle}
PaymentServices prefService = PaymentServices.paypal;

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {  
  String _name, _email, _number;
  double _mpg;

  Future editProfile(String editName, String editEmail, String editNumber, double editMPG) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('profileName', editName);
    prefs.setString('profileEmail', editEmail);
    prefs.setString('profileNumber', editNumber);
    prefs.setDouble('profileMPG', editMPG);

    setState(() {
      _name = prefs.getString('profileName');
      _email = prefs.getString('profileEmail');
      _number = prefs.getString('profileNumber');
      _mpg = prefs.getDouble('profileMPG');
    });
  }

  Future getProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = (prefs.getString('profileName') ?? "No Name Set");
      _email = (prefs.getString('profileEmail') ?? "No Email Set");
      _number = (prefs.getString('profileNumber') ?? "No Number Set");
      _mpg = (prefs.getDouble('profileMPG') ?? 0.0);
    });
  }

  @override
  void initState() { 
    super.initState();
    getProfile();
  }

  final textControllerName = TextEditingController();
  final textControllerEmail = TextEditingController();
  final textControllerNumber = TextEditingController();
  final textControllerMPG = TextEditingController();


  @override
  void dispose() {
    textControllerName.dispose();
    textControllerEmail.dispose();
    textControllerNumber.dispose();
    textControllerMPG.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      drawer: NavigationDrawer(), // provides nav drawer
      appBar: new AppBar(
        title: new Text("Settings Page"),
        backgroundColor: Colors.purple,
      ),
      resizeToAvoidBottomPadding: false,
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Preferred Payment Services',
                style: TextStyle(
                  fontSize: 24
                )
              ),
            ),
          ),
          ListTile(
            title: const Text('PayPal'),
            leading: Radio(
              value: PaymentServices.paypal,
              groupValue: prefService,
              onChanged: (PaymentServices value) {
                setState(() {
                  prefService = value;
                });
              },
              activeColor: Colors.amber,
            )
          ),
          ListTile(
            title: const Text('Google Pay'),
            leading: Radio(
              value: PaymentServices.gpay,
              groupValue: prefService,
              onChanged: (PaymentServices value) {
                setState(() {
                  prefService = value;
                });
              },
              activeColor: Colors.amber,
            )
          ),
          ListTile(
            title: const Text('Cash App'),
            leading: Radio(
              value: PaymentServices.cashapp,
              groupValue: prefService,
              onChanged: (PaymentServices value) {
                setState(() {
                  prefService = value;
                });
              },
              activeColor: Colors.amber,
            )
          ),
          ListTile(
            title: const Text('Venmo'),
            leading: Radio(
              value: PaymentServices.venmo,
              groupValue: prefService,
              onChanged: (PaymentServices value) {
                setState(() {
                  prefService = value;
                });
              },
              activeColor: Colors.amber,
            )
          ),
          ListTile(
            title: const Text('Zelle'),
            leading: Radio(
              value: PaymentServices.zelle,
              groupValue: prefService,
              onChanged: (PaymentServices value) {
                setState(() {
                  prefService = value;
                });
              },
              activeColor: Colors.amber,
            )
          ),
          Divider(),
          SizedBox(
            width: double.infinity,
            height: 10.0,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 24
                )
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 10.0,
          ),
          Center(child: _signInButton()), // log in with Google Button
          SizedBox(
            width: double.infinity,
            height: 10.0,
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0.0),
            child: Row(
              children: <Widget>[ 
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Contact Profile',
                    style: TextStyle(
                      fontSize: 24
                    )
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit
                  ),
                  color: Colors.grey,
                  onPressed: () {
                    _showEditDialog();
                  },
                  tooltip: 'Edit Profile',
                ),
              ]
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 240.0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.person),
                    title: Text('Name'),
                    trailing: Text(_name ?? "No Name Set"),
                  ),
                  ListTile(
                    leading: Icon(Icons.email),
                    title: Text('Email' ?? "No Email Set"),
                    trailing: Text(_email ?? "No Email Set"),
                  ),
                  ListTile(
                    leading: Icon(Icons.phone),
                    title: Text('Phone' ?? "No Number Set"),
                    trailing: Text(_number ?? "No Number Set"),
                  ),
                  ListTile(
                    leading: Icon(Icons.directions_car),
                    title: Text('Miles per Gallon'),
                    trailing: Text('$_mpg' ?? "No MPG Set"),
                  ),
                ],
              )
            ),
          )
        ],
      ),
    );
  }

  Widget _signInButton() {
    return RaisedButton(
      color: (MediaQuery.of(context).platformBrightness == Brightness.dark) ? Colors.grey[700] : Colors.white,
      splashColor: Colors.grey,
      onPressed: () {
        signInWithGoogle().whenComplete(() {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) {
                return AccountPage();
              },
            ),
          );
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image(image: AssetImage("assets/google_logo.png"), height: 35.0), // asset image
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                'Sign in with Google',
                style: TextStyle(
                  fontSize: 20,
                  color: (MediaQuery.of(context).platformBrightness == Brightness.dark) ? Colors.white : Colors.black,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showEditDialog() {
    String editName, editEmail, editNumber;
    double editMPG;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              height: 327.0,
              child: ListView(
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Edit Profile",
                      style: TextStyle(
                        fontSize: 24.0,
                      ))
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      controller: textControllerName,
                      decoration: InputDecoration(
                        icon: Icon(Icons.person),
                        border: InputBorder.none,
                        hintText: 'Enter full name'
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      controller: textControllerEmail,
                      decoration: InputDecoration(
                        icon: Icon(Icons.email),
                        border: InputBorder.none,
                        hintText: 'Enter email'
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      controller: textControllerNumber,
                      decoration: InputDecoration(
                        icon: Icon(Icons.phone),
                        border: InputBorder.none,
                        hintText: 'Enter phone number'
                      ),
                      keyboardType: TextInputType.numberWithOptions(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                    child: TextFormField(
                      controller: textControllerMPG,
                      decoration: InputDecoration(
                        icon: Icon(Icons.directions_car),
                        border: InputBorder.none,
                        hintText: 'Enter MPG'
                      ),
                      keyboardType: TextInputType.numberWithOptions(),
                    ),
                  ),
                  ButtonBar(
                    children: <Widget>[
                      FlatButton(
                        child: Text('Cancel'),
                        onPressed: () {
                          textControllerName.clear();
                          textControllerEmail.clear();
                          textControllerNumber.clear();
                          textControllerMPG.clear();
                          Navigator.pop(context);
                        },
                      ),
                      RaisedButton(
                        child: Text('Confirm'),
                        color: Colors.amber,
                        onPressed: () {
                          editName = textControllerName.text;
                          editEmail = textControllerEmail.text;
                          editNumber = textControllerNumber.text;
                          editMPG = double.parse(textControllerMPG.text);
                          print('Saving Profile - $editName $editEmail $editNumber $editMPG');
                          editProfile(editName, editEmail, editNumber, editMPG);
                          textControllerName.clear();
                          textControllerEmail.clear();
                          textControllerNumber.clear();
                          textControllerMPG.clear();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          )
        );
      }
    );
  }
}