import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient setup(String serverAddress, String uniqueID, int port) {
  serverAddress = serverAddress.startsWith('ws') ? serverAddress : 'wss://$serverAddress';
  if (serverAddress.contains('hivemq') && !serverAddress.endsWith('/mqtt')) {
    print('Adding /mqtt to server address');
    serverAddress = '$serverAddress/mqtt';
  }
  return MqttBrowserClient.withPort(serverAddress, uniqueID, port);
}
