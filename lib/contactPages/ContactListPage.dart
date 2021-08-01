import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:gas_710/contactPages/AddContactPage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:gas_710/NavigationDrawer.dart';
import 'package:gas_710/contactPages/ContactDetailsPage.dart';

class ContactListPage extends StatefulWidget {
  @override
  _ContactListPageState createState() => _ContactListPageState();
}

class _ContactListPageState extends State<ContactListPage> {
  Permission _contactPermission = Permission.contacts;
  PermissionStatus _contactPermissionStatus = PermissionStatus.undetermined;
  List<Contact> _contacts;
  var selected = [];
  var selectedContacts = new List<String>();

  @override
  initState() {
    super.initState();
    _listenForPermissionStatus();
    refreshContacts();
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

  refreshContacts() async {
    _contactPermissionStatus = await requestPermission(_contactPermission);
    if (_contactPermissionStatus == PermissionStatus.granted) {
      // Load without thumbnails initially.
      var contacts =
          (await ContactsService.getContacts(withThumbnails: false)).toList();
      setState(() {
        _contacts = contacts;
      });

      // Lazy load thumbnails after rendering initial contacts.
      for (final contact in contacts) {
        ContactsService.getAvatar(contact).then((avatar) {
          if (avatar == null) return; // Don't redraw if no change.
          setState(() => contact.avatar = avatar);
        });
      }
    } else {
      _handleInvalidPermissions(_contactPermissionStatus);
    }
  }

  updateContact() async {
    Contact ninja = _contacts
        .toList()
        .firstWhere((contact) => contact.familyName.startsWith("Ninja"));
    ninja.avatar = null;
    await ContactsService.updateContact(ninja);

    refreshContacts();
  }

  void _handleInvalidPermissions(PermissionStatus permissionStatus) {
    if (permissionStatus == PermissionStatus.denied) {
      throw new PlatformException(
          code: "PERMISSION_DENIED",
          message: "Access to location data denied",
          details: null);
    } else if (permissionStatus == PermissionStatus.denied) {
      throw new PlatformException(
          code: "PERMISSION_DISABLED",
          message: "Location data is not available on device",
          details: null);
    }
  }

  // -----------------------Main Contacts Page------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(), // provides the nav drawer
      appBar: new AppBar(
        title: new Text("Contacts Page"),
        backgroundColor: Colors.purple,
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        backgroundColor: Colors.amber,
        tooltip: 'Add new contact',
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AddContactPage())).then((_){
            refreshContacts();
          });
        },
      ),
      body: SafeArea(
        child: _contacts != null
            ? ListView.builder(
                itemCount: _contacts?.length ?? 0,
                itemBuilder: (BuildContext context, int index) {
                  Contact c = _contacts?.elementAt(index);
                  return ListTile(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (BuildContext context) =>
                              ContactDetailsPage(c)));
                    },
                    leading: (c.avatar != null && c.avatar.length > 0)
                        ? CircleAvatar(backgroundImage: MemoryImage(c.avatar))
                        : CircleAvatar(child: 
                        Text(
                          c.initials(),
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.purple),
                    title: Text(c.displayName ?? ""),
                  );
                },
              )
            : Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber)
                ),
              ),
      ),
    );
  }
}