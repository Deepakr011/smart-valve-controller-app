import paho.mqtt.client as mqtt
import time
import json







MQTT_BROKER = "mqtt.eclipseprojects.io"
MQTT_CLIENT_ID = "deepak_"
MQTT_TOPIC_SUB = "bushan/sub"
MQTT_TOPIC_PUB = "bushan/pub"

# Device-specific variables
DEVICE_ID = "bushan_device"

current_mode = "rest"

# Sample data to publish
data = {
    "status": "online",
    "number_of_valve": 30,
    "open_valve": [2, 3, 7],
    "set period": ["2:30", "3:10", "2:10"],
    "Current Time": "1:00",
    "device_id": DEVICE_ID,
    "mode": current_mode
}

# Create MQTT client instance
client = mqtt.Client(client_id=MQTT_CLIENT_ID, userdata={"device_id": DEVICE_ID})

# Define callback for connection
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT broker")
        client.subscribe(MQTT_TOPIC_SUB)
    else:
        print(f"Failed to connect, return code {rc}")

# Define callback for disconnection
def on_disconnect(client, userdata, rc):
    print("Disconnected from MQTT broker")

# Define callback for incoming messages
def on_message(client, userdata, msg):
    global current_mode
    received_message = json.loads(msg.payload.decode())

    # Ignore own messages
    if received_message.get("device_id") != userdata["device_id"]:
        print(f"Received message from topic {msg.topic}: {received_message}")

        # Handle mode change
        if 'mode' in received_message:
            new_mode = received_message['mode']
            if new_mode in ['automatic', 'manual', 'Rest Mode']:
                current_mode = new_mode
                print(f"Switching to {current_mode}")

        # Handle manual mode valve control
        if current_mode == "manual" and 'valve' in received_message and 'status' in received_message:
            valve = received_message['valve']
            status = received_message['status']
            if status == 'on' and valve not in data["open_valve"]:
                data["open_valve"].append(valve)
            elif status == 'off' and valve in data["open_valve"]:
                data["open_valve"].remove(valve)
            print(f"Manual operation: Valve {valve} turned {status}")

# Assign callbacks
client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.on_message = on_message

# Connect to the broker
client.connect(MQTT_BROKER, 1883, 60)
client.loop_start()

try:
    while True:
        # Update data mode and timestamp
        data["mode"] = current_mode
        data["timestamp"] = time.time()

        if current_mode == "Rest Mode":
            data["open_valve"] = []

        # Publish the data
        client.publish(MQTT_TOPIC_PUB, json.dumps(data))
        print(f"Published data: {data}")

        time.sleep(1)

except KeyboardInterrupt:
    print("Terminating the connection...")
    client.disconnect()
    client.loop_stop()
