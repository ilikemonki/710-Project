import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class AddPassengersPage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<AddPassengersPage> {
  List<Contact> _contacts = new List<Contact>();
  List<CustomContact> _uiCustomContacts = List<CustomContact>();
  List<CustomContact> _allContacts = List<CustomContact>();
  List<Contact> returnContacts = new List<Contact>();
  bool _isLoading = false;
  bool _isSelectedContactsView = false;

  //Add Passenger screen variables
  String floatingButtonLabel = 'Add Passengers';
  Color floatingButtonColor = Colors.amber;
  IconData icon = Icons.add;
  //Confirm Passenger screen variables
  String floatingButtonLabel2 = 'Confirm Passengers';
  Color floatingButtonColor2 = Colors.green;
  IconData icon2 = Icons.send;
  //Temp variables
  String tFloatingButtonLabel;
  Color tFloatingButtonColor;
  IconData tIcon;

  Permission _contactPermission = Permission.contacts;
  PermissionStatus _contactPermissionStatus = PermissionStatus.undetermined;

  @override
  void initState() {
    super.initState();
    _listenForPermissionStatus();
    requestPermission(Permission.contacts)
    .then((PermissionStatus status){
      if(status == PermissionStatus.granted) {
        refreshContacts();
      }
    });
    //Initialize button on screen
    tFloatingButtonLabel = floatingButtonLabel;
    tFloatingButtonColor = floatingButtonColor;
    tIcon = icon;
  }

  void _listenForPermissionStatus() async {
    final status = await _contactPermission.status;
    setState(() => _contactPermissionStatus = status);
  }

  Future<PermissionStatus> requestPermission(Permission permission) async {
    final status = await permission.request();
    setState((){
      _contactPermissionStatus = status;
    });
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: new Scaffold(
        appBar: new AppBar(
          title: new Text('Passengers'),
          backgroundColor: Colors.purple,
        ),
        body: _contactPermissionStatus == PermissionStatus.granted ? !_isLoading
            ? Container(
                child: ListView.builder(
                  itemCount: _uiCustomContacts?.length,
                  itemBuilder: (BuildContext context, int index) {
                    CustomContact _contact = _uiCustomContacts[index];
                    var _phonesList = _contact.contact.phones.toList();

                    return _buildListTile(_contact, _phonesList);
                  },
                ),
              )
            : Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              )
            : Center(child: Text('Enable contacts permission to continue')),
        floatingActionButton: new FloatingActionButton.extended(
          backgroundColor: tFloatingButtonColor,
          onPressed: _onSubmit,
          icon: Icon(tIcon),
          label: Text(tFloatingButtonLabel),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
      )
    );
  }

  //when tapping button
  void _onSubmit() {
    setState(() {
      if (!_isSelectedContactsView) {
        //Add passengers button
        //Transition to Confirm Screen
        _uiCustomContacts =
            _allContacts.where((contact) => contact.isChecked == true).toList();
        _isSelectedContactsView = true;
        _restateFloatingButton(
          floatingButtonLabel2,
          icon2,
          floatingButtonColor2,
        );
      } else {
        //Confirm passengers button
        //Send data back to navigation page
        for (CustomContact n in _uiCustomContacts) {
          returnContacts.add(n.contact);
        }
        Navigator.pop(context, returnContacts);
      }
    });
  }

  //Build contacts
  ListTile _buildListTile(CustomContact c, List<Item> list) {
    return ListTile(
      leading: (c.contact.avatar != null && c.contact.avatar.length > 0)
          ? CircleAvatar(backgroundImage: MemoryImage(c.contact.avatar))
          : CircleAvatar(
              backgroundColor: Colors.purple,
              child: Text(
                c.contact.initials(),
                style: TextStyle(color: Colors.white),
              ),
            ),
      title: Text(c.contact.displayName ?? ""),
      subtitle: list.length >= 1 && list[0]?.value != null
          ? Text(list[0].value)
          : Text(''),
      trailing: Checkbox(
          activeColor: Colors.amber,
          value: c.isChecked,
          onChanged: (bool value) {
            setState(() {
              c.isChecked = value;
            });
          }),
    );
  }

  //Change floating Button
  void _restateFloatingButton(String label, IconData icon, Color color) {
    tFloatingButtonLabel = label;
    tIcon = icon;
    tFloatingButtonColor = color;
  }

  refreshContacts() async {
    setState(() {
      _isLoading = true;
    });
    var contacts = await ContactsService.getContacts();
    _populateContacts(contacts);
  }

  void _populateContacts(Iterable<Contact> contacts) {
    _contacts = contacts.where((item) => item.displayName != null).toList();
    _contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    _allContacts =
        _contacts.map((contact) => CustomContact(contact: contact)).toList();
    setState(() {
      _uiCustomContacts = _allContacts;
      _isLoading = false;
    });
  }

  //Override back button
  Future<bool> _onBackPressed() async {
    //Revert back to first screen
    if (_isSelectedContactsView) {
      setState(() {
        _uiCustomContacts = _allContacts;
        _isSelectedContactsView = false;
        _restateFloatingButton(
          floatingButtonLabel,
          icon,
          floatingButtonColor,
        );
      });
      return false;
    } else {
      return true;
    }
  }
}

class CustomContact {
  final Contact contact;
  bool isChecked;

  CustomContact({
    this.contact,
    this.isChecked = false,
  });
}
