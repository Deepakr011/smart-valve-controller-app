import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final MqttServerClient client;
  final String subscribeTopic;
  final String publishTopic;
  final Function(String) onMessageReceived;
  String _lastPayload = ''; // Store the last received payload

  // Add a StreamController to handle data streaming
  final StreamController<String> _mqttStreamController =
      StreamController.broadcast();

  // Getter for the stream
  Stream<String> get mqttStream => _mqttStreamController.stream;

  MqttService(this.client, this.subscribeTopic, this.publishTopic,
      this.onMessageReceived);

  Future<void> connect() async {
    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      print('MQTT NoConnectionException: $e');
      client.disconnect();
    } catch (e) {
      print('MQTT Connection Exception: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Connected to the broker');

      client.subscribe(subscribeTopic, MqttQos.atLeastOnce);

      client.updates!
          .listen((List<MqttReceivedMessage<MqttMessage?>>? updates) {
        final MqttPublishMessage recMess =
            updates![0].payload as MqttPublishMessage;
        final String payload =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        _lastPayload = payload; // Update the last payload

        try {
          final Map<String, dynamic> data = json.decode(payload);
          final String? status = data['status']; // Handle null safety

          if (status != null) {
            onMessageReceived(status);
            // Add the payload to the stream for real-time updates
            _mqttStreamController.add(payload);
          } else {
            print('Warning: Status is null in the received payload');
          }
        } catch (e) {
          print('Error decoding JSON: $e');
        }
      });
    } else {
      print('Failed to connect to the broker');
      client.disconnect();
    }
  }

  String getPayload() {
    return _lastPayload; // Simply return the latest received payload
  }

  void publish(String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    // Publish the message using the publishTopic
    client.publishMessage(publishTopic, MqttQos.atLeastOnce, builder.payload!);
    print('Published message: $message');
  }

  void disconnect() {
    client.disconnect();
    _mqttStreamController.close(); // Close the stream when disconnecting
  }
}
