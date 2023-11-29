import 'dart:async';

import 'package:esp32_ble/variables.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/snackbar.dart';
import '../utils/extra.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool isSwitchOn = false;
  List<int> readValue = [];

  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;

  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      prefs = await SharedPreferences.getInstance();
      if (state == BluetoothConnectionState.connected) {
        _services = []; // must rediscover services
        if (_services.isEmpty) {
          onDiscoverServicesPressed();
          setState(() {});
        }
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }
      setState(() {});
    });

    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      setState(() {});
    });

    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      setState(() {});
    });

    _isDisconnectingSubscription =
        widget.device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
      setState(() {});
    });

    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (isConnected && _rssi != null) {
        _rssi = await widget.device.readRssi();
      }
      setState(() {});
    });

    if (_services.isNotEmpty) {
      callDataReadStream();
    }
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectPressed() async {
    try {
      await widget.device.connectAndUpdateStream();
      Fluttertoast.showToast(msg: "Connect: Success");
      if (isConnected) {
        onDiscoverServicesPressed();
      }
    } catch (e) {
      if (e is FlutterBluePlusException &&
          e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        Fluttertoast.showToast(msg: prettyException("Connect Error:", e));
      }
    }
  }

  Future onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
      Fluttertoast.showToast(msg: "Cancel: Success");
    } catch (e) {
      Fluttertoast.showToast(msg: prettyException("Cancel Error:", e));
    }
  }

  Future onDisconnectPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream();
      Fluttertoast.showToast(msg: "Disconnect: Success");
    } catch (e) {
      Fluttertoast.showToast(msg: prettyException("Disconnect Error:", e));
    }
  }

  Future onDiscoverServicesPressed() async {
    setState(() {
      _isDiscoveringServices = true;
    });
    try {
      _services = await widget.device.discoverServices();
      BluetoothCharacteristic? c = getCharacteristic();
      if (c != null) readItAgainAndAgain(c);
      Fluttertoast.showToast(msg: "Discover Services: Success");
    } catch (e) {
      Fluttertoast.showToast(
          msg: prettyException("Discover Services Error:", e));
    }
    setState(() {
      _isDiscoveringServices = false;
    });
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223);
      Fluttertoast.showToast(
        msg: "Request Mtu: Success",
      );
    } catch (e) {
      Fluttertoast.showToast(msg: prettyException("Change Mtu Error:", e));
    }
  }

  // List<Widget> _buildServiceTiles(BuildContext context, BluetoothDevice d) {
  //   return _services
  //       .map(
  //         (s) => ServiceTile(
  //           service: s,
  //           characteristicTiles: s.characteristics
  //               .map((c) => _buildCharacteristicTile(c))
  //               .toList(),
  //         ),
  //       )
  //       .toList();
  // }

  // CharacteristicTile _buildCharacteristicTile(BluetoothCharacteristic c) {
  //   return CharacteristicTile(
  //     characteristic: c,
  //     descriptorTiles:
  //         c.descriptors.map((d) => DescriptorTile(descriptor: d)).toList(),
  //   );
  // }

  Widget buildSpinner(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('${widget.device.remoteId}'),
    );
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected
            ? const Icon(Icons.bluetooth_connected)
            : const Icon(Icons.bluetooth_disabled),
        Text(((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''),
            style: Theme.of(context).textTheme.bodySmall)
      ],
    );
  }

  Widget buildGetServices(BuildContext context) {
    return IndexedStack(
      index: (_isDiscoveringServices) ? 1 : 0,
      children: <Widget>[
        TextButton(
          onPressed: onDiscoverServicesPressed,
          child: const Text("Get Services"),
        ),
        const IconButton(
          icon: SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.grey),
            ),
          ),
          onPressed: null,
        )
      ],
    );
  }

  Widget buildMtuTile(BuildContext context) {
    return ListTile(
        title: const Text('MTU Size'),
        subtitle: Text('$_mtuSize bytes'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onRequestMtuPressed,
        ));
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(children: [
      if (_isConnecting || _isDisconnecting) buildSpinner(context),
      TextButton(
          onPressed: _isConnecting
              ? onCancelPressed
              : (isConnected ? onDisconnectPressed : onConnectPressed),
          child: Text(
            _isConnecting ? "CANCEL" : (isConnected ? "DISCONNECT" : "CONNECT"),
            style: Theme.of(context)
                .primaryTextTheme
                .labelLarge
                ?.copyWith(color: Colors.black45),
          ))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        actions: [buildConnectButton(context)],
      ),
      body: ListView(
        shrinkWrap: true,
        children: <Widget>[
          buildRemoteId(context),
          ListTile(
            leading: buildRssiTile(context),
            title:
                Text('Device is ${_connectionState.toString().split('.')[1]}.'),
            trailing: buildGetServices(context),
          ),
          buildMtuTile(context),
          const SizedBox(height: 50),
          Align(
            alignment: Alignment.center,
            child: Switch(
              value: isSwitchOn,
              onChanged: (val) async {
                if (isSwitchOn | !isSwitchOn) {
                  if (_services.isNotEmpty) {
                    BluetoothCharacteristic? c = getCharacteristic();

                    if (c != null) {
                      isSwitchOn = val;
                      setState(() {});

                      if (isSwitchOn) {
                        c.write([1, 0, 0, 0]);
                      } else {
                        c.write([0, 0, 0, 0]);
                      }
                    }
                  } else {
                    Fluttertoast.showToast(
                        msg: "Something is wrong, Please wait!");
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 50),
          Center(child: Text('Read value is: $readValue')),
          // ..._buildServiceTiles(context, widget.device),
        ],
      ),
    );
  }

  BluetoothCharacteristic? getCharacteristic() {
    String serviceuid = prefs.getString(Variables.serviceuuid) ?? '';
    String charuid = prefs.getString(Variables.charuuid) ?? '';

    if (serviceuid.isEmpty || charuid.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Either provide uuid from setting, otherwise exit fuck you 🖕',
      );
      return null;
    }

    var services = _services.map((e) => e).where((v) {
      return v.uuid.str.toUpperCase() == serviceuid.toUpperCase();
    }).toList();
    if (services.isEmpty) {
      Fluttertoast.showToast(msg: 'No services found maching your uuid');
      return null;
    }
    BluetoothService service = services.first;
    if (service.characteristics.isEmpty) {
      Fluttertoast.showToast(msg: 'No characteristic found maching your uuid');
      return null;
    }
    var chars = service.characteristics.map((e) => e).where((char) {
      return char.uuid.str.toUpperCase() == charuid.toUpperCase();
    }).toList();

    if (chars.isEmpty) {
      Fluttertoast.showToast(msg: 'No characteristic found matching your uuid');
      return null;
    }
    return chars.first;
  }

  readItAgainAndAgain(BluetoothCharacteristic c) {
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      readValue = await c.read();
      setState(() {});
    });
  }

  void callDataReadStream() {
    String serviceuuid = prefs.getString(Variables.serviceuuid) ?? '';
    String charuuid = prefs.getString(Variables.charuuid) ?? '';

    if (serviceuuid.isNotEmpty || charuuid.isNotEmpty) {
      var services = _services.map((e) => e).where((v) {
        return v.uuid.str.toUpperCase() == serviceuuid.toUpperCase();
      }).toList();

      if (services.isNotEmpty) {
        BluetoothService service = services.first;
        if (service.characteristics.isNotEmpty) {
          var chars = service.characteristics.map((e) => e).where((element) {
            if (element.properties.notify || element.properties.indicate) {
              return true;
            } else {
              return false;
            }
          }).toList();
        }
      }
    }
  }

// BluetoothService service = services.first;
// if (service.characteristics.isEmpty) {
//   Fluttertoast.showToast(msg: 'No characteristic found maching your uuid');
//   return null;
// }
// var chars = service.characteristics.map((e) => e).where((char) {
//   return char.uuid.str.toUpperCase() == charuuid.toUpperCase();
// }).toList();
}