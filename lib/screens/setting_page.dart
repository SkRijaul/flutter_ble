import 'package:esp32_ble/variables.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  TextEditingController serviceuuid = TextEditingController();
  TextEditingController charuuid = TextEditingController();

  @override
  void initState() {
    super.initState();
    getPreviousUUids();
  }

  getPreviousUUids() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String service = prefs.getString(Variables.serviceuuid) ?? '';
    String char = prefs.getString(Variables.charuuid) ?? '';
    serviceuuid = TextEditingController(text: service);
    charuuid = TextEditingController(text: char);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: serviceuuid,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                label: Text('Service uuid'),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: charuuid,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                label: Text('Characteristic uuid'),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setString(Variables.serviceuuid, serviceuuid.text);
                prefs.setString(Variables.charuuid, charuuid.text);
                Fluttertoast.showToast(msg: 'UUID SAVED');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
