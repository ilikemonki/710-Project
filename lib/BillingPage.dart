import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gas_710/BillingPassengersPage.dart';
import 'package:gas_710/NavigationDrawer.dart';
import 'package:gas_710/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BillingPage extends StatefulWidget {
  @override
  _BillingPageState createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  List<String> recipentsPhoneNumber = []; // List of phone numbers to text
  DateTime tripDateTime;
  final databaseReference = signedIn
      ? Firestore.instance.collection('userData').document(firebaseUser.email)
      : null;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      drawer: NavigationDrawer(), // provides nav drawer
      appBar: new AppBar(
        title: new Text("Billing Page"),
        backgroundColor: Colors.purple,
      ),
      body: signedIn
        ? StreamBuilder(
          //Get trips from firebase
          stream: databaseReference
            .collection('trips')
            .orderBy('date', descending: true)
            .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return Center(
                  child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.amber)));
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Expanded(child: _listView(snapshot)),
                ],
              ),
            );
          })
      : _signedOut(context)
    );
  }

  _listView(AsyncSnapshot<QuerySnapshot> snapshot) {
    var dates = [];
    for (int i = 0; i < snapshot.data.documents.length; i++) {
      DateTime myDateTime = snapshot.data.documents[i]['date'].toDate();
      dates.add(DateFormat.yMMMMd().format(myDateTime).toString() +
          " " +
          DateFormat("h:mm a").format(myDateTime).toString());
    }
    return ListView.builder(
        itemCount: snapshot.data.documents.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 5,
            child: ListTile(
              contentPadding: EdgeInsets.all(8.0),
              title: Text(
                snapshot.data.documents[index]['location'].toString(),
                style: TextStyle(fontSize: 18.0),
              ),
              subtitle: Text(
                "Passengers: " +
                    snapshot.data.documents[index]['passengers'].length
                        .toString() +
                    "\nDater: " +
                    dates[index],
                style: TextStyle(fontSize: 12.0),
              ),
              onTap: () {
                // Get passenger names
                List<dynamic> passengerList =
                    snapshot.data.documents[index]['passengers'];
                // Get price owed from passengers
                HashMap priceOwedPassengerList =
                    new HashMap<String, dynamic>.from(
                        snapshot.data.documents[index]['passengersOwed']);
                //Remove the text 'Delete' in their name
                for (int i = 0; i < passengerList.length; i++) {
                  if (passengerList[i].toString().contains('(Deleted')) {
                    passengerList[i] = passengerList[i]
                        .toString()
                        .substring(0, passengerList[i].toString().length - 9);
                  }
                }
                String tripLocation =
                    snapshot.data.documents[index]['location'].toString();
                String driver = snapshot.data.documents[index]['driverName'];
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => BillingPassengersPage(
                              passengerList: passengerList,
                              priceOwedPassengerList: priceOwedPassengerList,
                              tripLocation: tripLocation,
                              driver: driver
                            )));
              },
            ),
          );
        });
  }

  Widget _signedOut(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'That can\'t be right..?\nSign in to see your bills!',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 24.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
