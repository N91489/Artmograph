#include <WiFi.h>
#include <PubSubClient.h>
#include <Adafruit_Sensor.h>
#include <DHT.h>
#include <Adafruit_BMP280.h>

// WiFi and MQTT Configuration
const char* ssid = "your_wifi_ssid";
const char* password = "your_wifi_password";
const char* mqtt_server = "your_ec2_public_ip";
const int mqtt_port = 1883;
const char* mqtt_topic = "esp32/sensor_data";

WiFiClient espClient;
PubSubClient client(espClient);

// Sensor Configuration
#define DHTPIN 4       // GPIO where DHT22 is connected
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);
Adafruit_BMP280 bmp;

void setup() {
    Serial.begin(115200);
    
    // Connect to WiFi
    WiFi.begin(ssid, password);
    Serial.print("Connecting to WiFi...");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nWiFi connected");

    // Connect to MQTT Broker
    client.setServer(mqtt_server, mqtt_port);
    Serial.print("Connecting to MQTT broker...");
    while (!client.connected()) {
        if (client.connect("ESP32Client")) {
            Serial.println("\nConnected to MQTT broker");
        } else {
            Serial.print(".");
            delay(500);
        }
    }

    // Initialize Sensors
    dht.begin();
    if (!bmp.begin(0x76)) {
        Serial.println("Could not find a valid BMP280 sensor, check wiring!");
        while (1);
    }
}

void loop() {
    float temperature = dht.readTemperature();
    float humidity = dht.readHumidity();
    float pressure = bmp.readPressure() / 100.0F; // Convert to hPa

    if (isnan(temperature) || isnan(humidity) || isnan(pressure)) {
        Serial.println("Failed to read from sensors!");
        return;
    }

    // Publish sensor data to MQTT
    char payload[100];
    snprintf(payload, sizeof(payload), "{\"temperature\":%.2f, \"humidity\":%.2f, \"pressure\":%.2f}", temperature, humidity, pressure);
    client.publish(mqtt_topic, payload);
    Serial.println("Published data to MQTT");

    delay(300000); // Send data every 5 minute
}
