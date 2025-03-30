import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:pwa_install/pwa_install.dart'; // Add this import
import 'mqtt_service.dart'; // Import the MQTT service
import 'dashboard.dart'; // Import the DashboardView

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Add this

  // Add PWA install setup
  PWAInstall().setup(installCallback: () {
    debugPrint('APP INSTALLED!');
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget { // Changed to StatefulWidget
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver { // Added WidgetsBindingObserver
  late MQTTService mqttService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Added observer
    mqttService = MQTTService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Removed observer
    mqttService.disconnect(); // Disconnect MQTT service
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { // Handle app lifecycle changes
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _reconnectMQTT();
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      mqttService.disconnect();
    }
  }

  Future<void> _reconnectMQTT() async {
    final prefs = await SharedPreferences.getInstance();
    final mqttUrl = prefs.getString('mqttUrl') ?? '';
    final mqttPort = int.parse(prefs.getString('mqttPort') ?? '8883');
    final mqttUsername = prefs.getString('mqttUsername') ?? '';
    final mqttPassword = prefs.getString('mqttPassword') ?? '';

    if (mqttUrl.isNotEmpty) {
      await mqttService.connect(
        mqttUrl,
        mqttPort,
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
        username: mqttUsername,
        password: mqttPassword,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Provider<MQTTService>(
      create: (context) => mqttService,
      child: MaterialApp(
        title: 'Tub control',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const MyHomePage(title: 'Login'),
          '/dashboard': (context) => const DashboardView(),
          '/configuration': (context) => const ConfigurationView(),
          '/history': (context) => const TemperatureHistoryWidget(),
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

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

    final mqttService = Provider.of<MQTTService>(context, listen: false);

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
      print("Failed to connect to MQTT broker");
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          if (PWAInstall().installPromptEnabled)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => PWAInstall().promptInstall_(),
              tooltip: 'Install App',
            ),
        ],
      ),
      body: Center(
        child: Column(
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
                  return 'Port number must be between 1 and 65535';
                }
                return null;
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
      ),
    );
  }
}
