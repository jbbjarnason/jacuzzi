import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mqtt_service.dart'; // Adjust this import based on your project structure
import 'package:thermostat/thermostat.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({Key? key, required this.currentRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text('Menu'),
          ),
          _createDrawerItem(
            context: context,
            text: 'Dashboard',
            routeName: '/dashboard',
            isSelected: currentRoute == '/dashboard',
          ),
          _createDrawerItem(
            context: context,
            text: 'Configuration',
            routeName: '/configuration',
            isSelected: currentRoute == '/configuration',
          ),
          // Add more items here
        ],
      ),
    );
  }

  Widget _createDrawerItem(
      {required BuildContext context,
      required String text,
      required String routeName,
      required bool isSelected}) {
    return ListTile(
      title:
          Text(text, style: TextStyle(color: isSelected ? Colors.blue : null)),
      selected: isSelected,
      onTap: () {
        final MQTTService mqttService =
            Provider.of<MQTTService>(context, listen: false);
        mqttService.unsubscribe();
        Navigator.pop(context); // Close the drawer
        if (ModalRoute.of(context)?.settings.name != routeName) {
          Navigator.pushReplacementNamed(context, routeName);
        }
      },
    );
  }
}

class BaseView extends StatelessWidget {
  final Widget body;
  final String title;
  final String currentRoute;

  const BaseView(
      {Key? key,
      required this.body,
      required this.title,
      required this.currentRoute})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: AppDrawer(currentRoute: currentRoute),
      body: body,
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  MQTTService get mqttService =>
      Provider.of<MQTTService>(context, listen: false);
  double mixerCurrentTemp = 0;
  double mixerTargetTemp = 0;
  double tubCurrentTemp = 0;
  double tubTargetTemp = 0;
  bool tubOn = false;
  bool mixerOn = false;

  @override
  void initState() {
    super.initState();
    _subscribeToTopics();
  }

  @override
  void dispose() {
    // mqttService.unsubscribe();
    super.dispose();
  }

  void _subscribeToTopics() {
    mqttService.subscribe(
        "tempservo/climate/mixer_pid/current_temperature/state", (payload) {
      setState(() => mixerCurrentTemp = double.parse(payload));
    });
    mqttService.subscribe(
        "tempservo/climate/mixer_pid/target_temperature/state", (payload) {
      setState(() => mixerTargetTemp = double.parse(payload));
    });
    mqttService
        .subscribe("tempservo/climate/tub_thermostat/current_temperature/state",
            (payload) {
      setState(() => tubCurrentTemp = double.parse(payload));
    });
    mqttService.subscribe(
        "tempservo/climate/tub_thermostat/target_temperature/state", (payload) {
      setState(() => tubTargetTemp = double.parse(payload));
    });
    mqttService.subscribe("tempservo/climate/tub_thermostat/mode/state",
        (payload) {
      setState(() => tubOn = payload.toUpperCase() != "OFF");
    });
    mqttService.subscribe("tempservo/climate/mixer_pid/mode/state", (payload) {
      setState(() => mixerOn = payload.toUpperCase() != "OFF");
    });
  }

  String buttonLabel() {
    return tubOn ? 'Turn Off Tub' : 'Turn On Tub';
  }

  void changeTargetTemp(double newTemp) {
    mqttService.publish(
        "tempservo/climate/tub_thermostat/target_temperature/command",
        newTemp.toString());
  }

  static String celsiusNumFormatting(double val) {
    return "${val.toStringAsFixed(1)} °C";
  }

  @override
  Widget build(BuildContext context) {
    return BaseView(
      title: 'Dashboard',
      currentRoute: '/dashboard',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Tub Thermostat'),
            Thermostat(
              maxVal: 46, // todo fetch from mqtt
              minVal: 32, // todo fetch from mqtt
              curVal: tubCurrentTemp,
              setPoint: tubTargetTemp,
              formatCurVal: celsiusNumFormatting,
              formatSetPoint: celsiusNumFormatting,
              setPointMode: SetPointMode.displayAndEdit,
              onChanged: changeTargetTemp,
              turnOn: tubOn,
            ),
            const Text('Mixer Thermostat'),
            Thermostat(
              maxVal: 46, // todo fetch from mqtt
              minVal: 32, // todo fetch from mqtt
              curVal: mixerCurrentTemp,
              setPoint: mixerTargetTemp,
              formatCurVal: celsiusNumFormatting,
              formatSetPoint: celsiusNumFormatting,
              setPointMode: SetPointMode.displayOnly,
              turnOn: mixerOn,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (tubOn) {
                  mqttService.publish(
                      "tempservo/climate/tub_thermostat/mode/command", "OFF");
                } else {
                  mqttService.publish(
                      "tempservo/climate/tub_thermostat/mode/command", "HEAT");
                }
              },
              child: Text(buttonLabel()),
            ),
          ],
        ),
      ),
    );
  }
}

class ConfigurationView extends StatefulWidget {
  const ConfigurationView({Key? key}) : super(key: key);

  @override
  State<ConfigurationView> createState() => _ConfigurationViewState();
}

class _ConfigurationViewState extends State<ConfigurationView> {
  MQTTService get mqttService =>
      Provider.of<MQTTService>(context, listen: false);
  double flowRate = 0; // Initial value for flow rate
  double mixerTempOffset = 0; // Initial value for mixer temperature offset

  @override
  void initState() {
    super.initState();

    mqttService.subscribe("tempservo/number/flow_rate/state", (payload) {
      setState(() {
        flowRate = double.tryParse(payload) ?? 0;
      });
    });

    mqttService.subscribe("tempservo/number/mixer_temperature_offset/state",
        (payload) {
      setState(() {
        mixerTempOffset = double.tryParse(payload) ?? 0;
      });
    });
  }

  @override
  void dispose() {
    // mqttService.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseView(
      title: 'Configuration',
      currentRoute: '/configuration',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Slider for Flow Rate
            Text('Flow Rate: ${flowRate.toInt()}%'),
            Slider(
              min: 0,
              max: 100,
              divisions: 100,
              value: flowRate,
              label: '${flowRate.toInt()}%',
              onChanged: (value) {
                print(value);
                setState(() {
                  flowRate = value;
                });
                mqttService.publish(
                    "tempservo/number/flow_rate/command", value.toString());
              },
            ),
            // Slider for Mixer Temperature Offset
            Text('Mixer Temp Offset: ${mixerTempOffset.toStringAsFixed(1)}˚C'),
            Slider(
              min: 0,
              max: 10,
              divisions: 20, // (max - min) / step = (10 - 0) / 0.5
              value: mixerTempOffset,
              label: '${mixerTempOffset.toStringAsFixed(1)}˚C',
              onChanged: (value) {
                print(value);
                setState(() {
                  mixerTempOffset = value;
                });
                mqttService.publish(
                    "tempservo/number/mixer_temperature_offset/command",
                    value.toString());
              },
            ),
          ],
        ),
      ),
    );
  }
}
