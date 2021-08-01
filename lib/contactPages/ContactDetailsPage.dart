import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:gas_710/contactPages/ContactListPage.dart';
import 'package:gas_710/contactPages/UpdateContactsPage.dart';
import 'package:gas_710/contactPages/AddressTileWidget.dart';
import 'package:gas_710/contactPages/ItemsTileWidget.dart';
import 'package:intl/intl.dart';

class ContactDetailsPage extends StatelessWidget {
  ContactDetailsPage(this._contact);
  final Contact _contact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_contact.displayName ?? ""),
        backgroundColor: Colors.purple,
        actions: <Widget>[
          //make sure to return to contacts page after delete
          IconButton(
            tooltip: 'Delete contact',
            icon: Icon(Icons.delete),
            onPressed: () {
              ContactsService.deleteContact(_contact);
              Navigator.push(context, MaterialPageRoute(builder: (context) => ContactListPage()));
            }
          ),
          IconButton(
            tooltip: 'Update contact',
            icon: Icon(Icons.update),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UpdateContactsPage(
                  contact: _contact,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            ListTile(
              title: Text("Name"),
              trailing: Text(_contact.givenName ?? ""),
            ),
            ListTile(
              title: Text("Middle name"),
              trailing: Text(_contact.middleName ?? ""),
            ),
            ListTile(
              title: Text("Family name"),
              trailing: Text(_contact.familyName ?? ""),
            ),
            ListTile(
              title: Text("Prefix"),
              trailing: Text(_contact.prefix ?? ""),
            ),
            ListTile(
              title: Text("Suffix"),
              trailing: Text(_contact.suffix ?? ""),
            ),
            ListTile(
              title: Text("Birthday"),
              trailing: Text(_contact.birthday != null
                  ? DateFormat('dd-MM-yyyy').format(_contact.birthday)
                  : ""),
            ),
            ListTile(
              title: Text("Company"),
              trailing: Text(_contact.company ?? ""),
            ),
            ListTile(
              title: Text("Job"),
              trailing: Text(_contact.jobTitle ?? ""),
            ),
            ListTile(
              title: Text("Account Type"),
              trailing: Text((_contact.androidAccountType != null)
                  ? _contact.androidAccountType.toString()
                  : ""),
            ),
            AddressesTile(_contact.postalAddresses),
            ItemsTile("Phones", _contact.phones),
            ItemsTile("Emails", _contact.emails)
          ],
        ),
      ),
    );
  }
}