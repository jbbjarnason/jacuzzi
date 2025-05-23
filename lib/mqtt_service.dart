import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_server_setup.dart' if (dart.library.js_interop) 'mqtt_browser_setup.dart' as mqttsetup;
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';

class MQTTService {
  late MqttClient client;
  final Map<String, Function(String)> _messageHandlers = {};

  MQTTService();

  Future<bool> connect(String server, int port, String clientId, {String? username, String? password}) async {
    client = mqttsetup.setup(server, clientId, port);

    if (!kIsWeb) {
      (client as MqttServerClient).secure = true;
      (client as MqttServerClient).securityContext = SecurityContext.defaultContext;
    }

    client.autoReconnect = true;
    
    // Additional client configuration...
    try {
      // Your existing connection logic here
      // It's often required to set the protocol to MQTT 3.1.1 for SSL connections
      client.setProtocolV311();
      final connMess = MqttConnectMessage()
          .authenticateAs(username, password)
          .withClientIdentifier(client.clientIdentifier)
          .startClean() // Non persistent session for testing
          .withWillTopic('willtopic') // If you wish to set a will message
          .withWillMessage('My Will message')
          .withWillQos(MqttQos.atLeastOnce);
      client.connectionMessage = connMess;

      await client.connect();
      _setupMessageListener();
    } catch (e) {
      print('MQTT Client Exception: $e');
      client.disconnect();
      return false;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      print("MQTT Client Connected");
      return true;
    } else {
      print('ERROR MQTT Client Connection failed - disconnecting, status is ${client!.connectionStatus}');
      return false;
    }
  }

  void subscribe(String topic, Function(String) messageHandler) {
    client.subscribe(topic, MqttQos.atLeastOnce);
    _messageHandlers[topic] = messageHandler;
  }

  void unsubscribe() {
    for (var topic in _messageHandlers.keys) {
      client.unsubscribe(topic);
    }
    _messageHandlers.clear();
  }

  void _setupMessageListener() {
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messageList) {
      for (var messageData in messageList) {
        final MqttPublishMessage recMess = messageData.payload as MqttPublishMessage;
        final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final String topic = messageData.topic;

        // Iterate through all handlers to find a match for the current topic
        // This approach does not handle MQTT wildcards.
        // If exact match is found, call the handler
        Function(String)? callback = _messageHandlers[topic];
        if (callback != null) {
          callback(message);
        }
      }
    });
  }

  // Publish to a topic
  void publish(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
  }

  void publishDouble(String topic, double number) {
    final builder = MqttClientPayloadBuilder();
    builder.addDouble(number);
    client.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
  }

  void disconnect() {
    client.disconnect();
  }
}
