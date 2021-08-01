import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gas_710/BillContactPage.dart';
import 'package:gas_710/WebViewPage.dart';
import 'package:gas_710/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gas_710/SettingsPage.dart';
import 'package:flutter_sms/flutter_sms_platform.dart';

class BillingPassengersPage extends StatefulWidget {
  final passengerList,
      priceOwedPassengerList,
      tripLocation,
      driver; // required keys from BillingPassengersPage.dart
  const BillingPassengersPage(
      {Key key,
      @required this.passengerList,
      @required this.priceOwedPassengerList,
      @required this.tripLocation,
      @required this.driver
      }) : super(key: key);

  @override
  _BillingPassengersPageState createState() => _BillingPassengersPageState();
}

class _BillingPassengersPageState extends State<BillingPassengersPage> {
  String defaultTextMessage =
      "this is a reminder of what you owe for our recent trips! Cost: \$"; // Default text message
  List<String> recipentsPhoneNumber = []; // List of phone numbers to text
  final databaseReference = signedIn
      ? Firestore.instance.collection('userData').document(firebaseUser.email)
      : null;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(
          widget.tripLocation ?? 'Billing Page',
          maxLines: 3,
        ),
        backgroundColor: Colors.purple,
      ),
      body: signedIn
        ? StreamBuilder(
          stream: databaseReference
            .collection('contacts')
            .where('displayName', whereIn: widget.passengerList)
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
    return ListView.builder(
        itemCount: snapshot.data.documents.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 5,
            child: ListTile(
                contentPadding: EdgeInsets.all(8.0),
                leading: (snapshot.data.documents[index]['avatar'].toString() !=
                            'none' &&
                        (Uint8List.fromList(snapshot.data
                                    .documents[index]['avatar'].codeUnits) !=
                                null &&
                            Uint8List.fromList(snapshot.data
                                        .documents[index]['avatar'].codeUnits)
                                    .length >
                                0))
                    ? CircleAvatar(
                        backgroundImage: MemoryImage(Uint8List.fromList(snapshot
                            .data.documents[index]['avatar'].codeUnits)),
                        maxRadius: 30,
                      )
                    : CircleAvatar(
                        child: Text(
                          snapshot.data.documents[index]['displayName'][0],
                          style: TextStyle(color: Colors.white, fontSize: 36.0),
                        ),
                        backgroundColor: Colors.purple,
                        maxRadius: 30,
                      ),
                title: Text(
                  snapshot.data.documents[index]['displayName'],
                  style: TextStyle(fontSize: 24.0),
                ),
                subtitle: Text(
                  (widget.passengerList.contains(widget.driver) ? "-\$" : "\$") + 
                      widget.priceOwedPassengerList[
                              snapshot.data.documents[index]['displayName']]
                          .toString(),
                  style: TextStyle(fontSize: 18.0),
                ),
                trailing: Wrap(
                  spacing: 10, // space between two icons
                  children: <Widget>[
                    widget.passengerList.contains(widget.driver)
                        ? _payButton(context)
                        : _requestButton(context),
                    _textButton(
                        context,
                        snapshot.data.documents[index]['displayName'],
                        snapshot.data.documents[index]['phoneNumber'],
                        widget.priceOwedPassengerList[
                            snapshot.data.documents[index]['displayName']]),
                  ],
                ),
                onTap: () {
                  String contactName =
                      snapshot.data.documents[index]['displayName'];
                  String dollars;
                  if(widget.passengerList.contains(widget.driver)) {
                    dollars = "-" + widget.priceOwedPassengerList[
                          snapshot.data.documents[index]['displayName']]
                      .toString(); 
                  } else {
                    dollars = widget.priceOwedPassengerList[
                          snapshot.data.documents[index]['displayName']]
                      .toString(); 
                  }
                  var avatar;
                  if (snapshot.data.documents[index]['avatar'] != 'none') {
                    avatar = Uint8List.fromList(
                        snapshot.data.documents[index]['avatar'].codeUnits);
                  } else {
                    avatar = 'none';
                  }
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BillContactPage(
                              name: contactName,
                              money: double.parse(dollars),
                              avatar: avatar)));
                },
                onLongPress: () {
                  String contactName =
                      snapshot.data.documents[index]['displayName'].toString();
                  bool youOwe;
                  String dollars;
                  if (widget.priceOwedPassengerList[
                          snapshot.data.documents[index]['displayName']] >
                      0) {
                    youOwe = false;
                    dollars = widget.priceOwedPassengerList[
                            snapshot.data.documents[index]['displayName']]
                        .toString();
                  } else {
                    youOwe = true;
                    dollars = (-1 *
                            widget.priceOwedPassengerList[
                                snapshot.data.documents[index]['displayName']])
                        .toStringAsFixed(2);
                  }
                  Fluttertoast.showToast(
                    msg: youOwe
                        ? 'You owe $contactName \$$dollars'
                        : '$contactName owes you \$$dollars',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIos: 1,
                    fontSize: 16.0,
                  );
                }),
          );
        });
  }

  Widget _requestButton(BuildContext context) {
    return RaisedButton(
      child: Text('Request'),
      shape: StadiumBorder(),
      color: Colors.amber,
      onPressed: () {
        if (prefService == PaymentServices.gpay) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "Google Pay",
                    selectedUrl: "https://pay.google.com",
                  )));
        } else if (prefService == PaymentServices.paypal) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "PayPal",
                    selectedUrl: "https://www.paypal.com/us/home",
                  )));
        } else if (prefService == PaymentServices.cashapp) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "CashApp",
                    selectedUrl: "https://cash.app/",
                  )));
        } else if (prefService == PaymentServices.venmo) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "Venmo",
                    selectedUrl: "https://venmo.com/",
                  )));
        } else if (prefService == PaymentServices.zelle) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "Zelle",
                    selectedUrl: "https://www.zellepay.com/",
                  )));
        }
      },
    );
  }

  Widget _payButton(BuildContext context) {
    return RaisedButton(
      child: Text('Pay'),
      shape: StadiumBorder(),
      color: Colors.amber,
      onPressed: () {
        if (prefService == PaymentServices.gpay) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "Google Pay",
                    selectedUrl: "https://pay.google.com",
                  )));
        } else if (prefService == PaymentServices.paypal) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "PayPal",
                    selectedUrl: "https://www.paypal.com/us/home",
                  )));
        } else if (prefService == PaymentServices.cashapp) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "CashApp",
                    selectedUrl: "https://cash.app/",
                  )));
        } else if (prefService == PaymentServices.venmo) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "Venmo",
                    selectedUrl: "https://venmo.com/",
                  )));
        } else if (prefService == PaymentServices.zelle) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (BuildContext context) => WebViewPage(
                    title: "Zelle",
                    selectedUrl: "https://www.zellepay.com/",
                  )));
        }
      },
    );
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

  Widget _textButton(BuildContext context, String personName,
      String phoneNumber, double bill) {
    return IconButton(
      icon: Icon(Icons.textsms),
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) =>
              _buildTextingDialog(context, personName, phoneNumber, bill),
        );
      },
    );
  }

  Widget _buildTextingDialog(BuildContext context, String personName,
      String phoneNumber, double bill) {
    return new AlertDialog(
      title: new Text("Text $personName"),
      content: new Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text("Pressing \'Okay\' will send you to your default SMS app. \n"),
          Text("Phone Number: $phoneNumber \n"),
          Text("Message: \"Hey $personName, $defaultTextMessage $bill\""),
        ],
      ),
      actions: <Widget>[
        new FlatButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel',
            style: TextStyle(
              color: MediaQuery.of(context).platformBrightness ==
                Brightness.light
                  ? Colors.black
                  : Colors.white
            )
          )
        ),
        new RaisedButton(
          onPressed: () {
            Navigator.of(context).pop();
            //Add their phone in the list
            recipentsPhoneNumber.add(phoneNumber);
            // Open message app
            _sendSMS(
                "Hey $personName," + defaultTextMessage + bill.toString(), recipentsPhoneNumber);
            recipentsPhoneNumber.clear();
          },
          child: Text('Okay'),
          color: Colors.amber,
        ),
      ],
    );
  }

  void _sendSMS(String message, List<String> recipents) async {
    String _result = await FlutterSmsPlatform.instance
        .sendSMS(message: message, recipients: recipents)
        .catchError((onError) {
      print(onError);
    });
    print(_result);
  }
}
