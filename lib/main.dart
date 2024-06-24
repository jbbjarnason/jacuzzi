import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'mqtt_service.dart'; // Import the MQTT service
import 'dashboard.dart'; // Import the DashboardView

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create the instance of MQTTService
    final mqttService = MQTTService();

    // Use Provider to supply the MQTTService instance to the widget tree
    return Provider<MQTTService>(
      create: (context) => mqttService,
      child: MaterialApp(
        title: 'Tub control',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: '/',
        // Define the routes
        routes: {
          '/': (context) => const MyHomePage(title: 'Login'),
          '/dashboard': (context) => const DashboardView(),
          '/configuration': (context) => const ConfigurationView(),
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final _mqttUrlController = TextEditingController();
  final _mqttPortController =
      TextEditingController(text: '8883'); // Default port
  final _mqttUsernameController = TextEditingController();
  final _mqttPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Add a key for the form

  @override
  void initState() {
    super.initState();
    _prefs.then((prefs) => {
          _mqttUrlController.text = prefs.getString('mqttUrl') ?? '',
          _mqttPortController.text = prefs.getString('mqttPort') ?? '8883',
          _mqttUsernameController.text = prefs.getString('mqttUsername') ?? '',
          _mqttPasswordController.text = prefs.getString('mqttPassword') ?? '',
        });
  }

  Future<void> _connectAndNavigate() async {
    final SharedPreferences prefs = await _prefs;
    prefs.setString('mqttUrl', _mqttUrlController.text);
    prefs.setString('mqttPort', _mqttPortController.text);
    prefs.setString('mqttUsername', _mqttUsernameController.text);
    prefs.setString('mqttPassword', _mqttPasswordController.text);

    // Initialize your MQTT service here with the server details
    final mqttService = Provider.of<MQTTService>(context, listen: false);

    // Attempt to connect
    final isConnected = await mqttService.connect(
      _mqttUrlController.text,
      int.parse(_mqttPortController.text),
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}', // Ensuring a unique client ID
      username: _mqttUsernameController.text,
      password: _mqttPasswordController.text,
    );

    if (isConnected) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // Handle connection failure (e.g., show an alert dialog)
      print("Failed to connect to MQTT broker");
    }
  }
  // void _submitForm() {
  //   setState(() {
  //     // This call to setState tells the Flutter framework that something has
  //     // changed in this State, which causes it to rerun the build method below
  //     // so that the display can reflect the updated values. If we changed
  //     // _counter without calling setState(), then the build method would not be
  //     // called again, and so nothing would appear to happen.
  //     // _counter++;
  //   });
  //   print("MQTT Port: ${_mqttPortController.text}");
  // }

  @override
  void dispose() {
    _mqttUrlController.dispose();
    _mqttPortController.dispose();
    _mqttUsernameController.dispose();
    _mqttPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextFormField(
              controller: _mqttUrlController,
              decoration: const InputDecoration(labelText: 'MQTT URL/IP'),
            ),
            TextFormField(
              controller: _mqttPortController,
              decoration: const InputDecoration(labelText: 'MQTT Port'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a port number';
                }
                final num? portNum = num.tryParse(value);
                if (portNum == null) {
                  return 'Please enter a valid number';
                }
                if (portNum < 1 || portNum > 65535) {
                  // Adjust min and max values as needed
                  return 'Port number must be between 1 and 65535';
                }
                return null; // Return null if the input is valid
              },
            ),
            TextFormField(
              controller: _mqttUsernameController,
              decoration: const InputDecoration(labelText: 'MQTT Username'),
            ),
            TextFormField(
              controller: _mqttPasswordController,
              decoration: const InputDecoration(labelText: 'MQTT Password'),
              obscureText: true,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _connectAndNavigate,
        tooltip: 'Connect to the configured MQTT broker',
        child: const Text('Connect'),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
