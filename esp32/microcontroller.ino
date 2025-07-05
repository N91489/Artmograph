#include <WiFi.h>
#include <DHT.h>
#include <HX711.h>
#include <PubSubClient.h>

#define BUILT_IN_LED 2
#define DHT_PIN 33
#define HX_DATA_PIN 27
#define HX_CLK_PIN 13

#define WIFI_SSID "your_wifi_name"
#define WIFI_PASSWORD "your_wifi_password"
#define MQTT_SERVER "aws_public_ip"
#define MQTT_PORT 1883
#define MQTT_TOPIC "sensor/data"
#define MQTT_CLIENT_ID "ESP32Sensor"

// Initializing Sensors
DHT temp_humd_sensor(DHT_PIN, DHT22);
HX711 pressure_sensor;
WiFiClient espClient;
PubSubClient client(espClient);

// HX711 Calibration Parameters - ADJUST THESE VALUES
const float KNOWN_WEIGHT = 1000.0; // A known weight in grams for calibration
const long ZERO_OFFSET = -94500; // Tare value when no weight is applied
const float SCALE_FACTOR = 420.0; // Calibration factor to convert to actual pressure

// Status tracking
unsigned long lastMqttReconnectAttempt = 0;
unsigned long lastMeasurement = 0;
const unsigned long MEASUREMENT_INTERVAL = 30000; // 30 seconds

// Calibration mode
bool calibrationMode = false;

void led_blink(int times = 1) {
    for (int i = 0; i < times; i++) {
        digitalWrite(BUILT_IN_LED, HIGH);
        delay(100);
        digitalWrite(BUILT_IN_LED, LOW);
        if (i < times - 1) delay(100);
    }
}

void setup_wifi() {
    Serial.println("Connecting to WiFi");
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    unsigned long startAttempt = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < 20000) {
        digitalWrite(BUILT_IN_LED, !digitalRead(BUILT_IN_LED));
        delay(250);
        Serial.print(".");
    }
    digitalWrite(BUILT_IN_LED, LOW);
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println();
        Serial.println("Connected to WiFi");
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
        led_blink(3);
    } else {
        Serial.println();
        Serial.println("Failed to connect to WiFi");
        led_blink(5);
    }
}

boolean reconnect_mqtt() {
    Serial.print("Attempting MQTT connection...");
    if (client.connect(MQTT_CLIENT_ID)) {
        Serial.println("connected");
        led_blink(2);
        return true;
    } else {
        Serial.print("failed, rc=");
        Serial.print(client.state());
        Serial.println(" retrying later");
        return false;
    }
}

void calibrate_hx711() {
    Serial.println("\n\n=== HX711 Calibration ===");
    Serial.println("Remove all weight from the load cell and press any key...");
    while (!Serial.available());
        Serial.read();
        Serial.println("Taring...");
        pressure_sensor.tare(10); // Average 10 readings
        long zero_reading = pressure_sensor.get_offset();
        Serial.print("Zero offset: ");
        Serial.println(zero_reading);
        Serial.println("Place a known weight on the load cell and enter the weight in grams:"); 
    while (!Serial.available());
        String input = Serial.readStringUntil('\n');
        float known_weight = input.toFloat();
        Serial.println("Reading...");
        float reading = pressure_sensor.get_value(10); // Average 10 readings
        float scale = reading / known_weight;
        Serial.print("Scale factor: ");
        Serial.println(scale);
        Serial.println("\nUpdate your code with these calibration values:");
        Serial.print("const long ZERO_OFFSET = ");
        Serial.print(zero_reading);
        Serial.println(";");
        Serial.print("const float SCALE_FACTOR = ");
        Serial.print(scale);
        Serial.println(";");
        Serial.println("\nCalibration complete! Reset your device to continue.");
    while(1); // Stop execution
}

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n\n--- ESP32 Sensor Project ---");
    // Setup LED
    pinMode(BUILT_IN_LED, OUTPUT);
    digitalWrite(BUILT_IN_LED, LOW);
    // Initialize DHT sensor
    temp_humd_sensor.begin();
    Serial.println("DHT sensor initialized");
    // Initialize pressure sensor
    pressure_sensor.begin(HX_DATA_PIN, HX_CLK_PIN);
    // Check if calibration mode is requested
    Serial.println("Send 'c' within 5 seconds to enter calibration mode...");
    unsigned long startTime = millis();
    while (millis() - startTime < 5000) {
        if (Serial.available() && Serial.read() == 'c') {
            calibrationMode = true;
            break;
        }
        delay(100);
    }
    if (calibrationMode) {
        calibrate_hx711();
    } else {
        // Normal operation
        pressure_sensor.set_scale(SCALE_FACTOR);
        pressure_sensor.set_offset(ZERO_OFFSET);
        Serial.println("Pressure sensor initialized with calibration values");
        // Setup WiFi
        setup_wifi();
        // Setup MQTT
        client.setServer(MQTT_SERVER, MQTT_PORT);
        client.setKeepAlive(120);
        client.setSocketTimeout(10);
        Serial.println("Setup complete, starting measurements...");
    }
}

void loop() {
    // Skip loop if in calibration mode
    if (calibrationMode) return;
    // Handle WiFi reconnection
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi disconnected");
        setup_wifi();
    }
    // Handle MQTT reconnection
    if (!client.connected()) {
        unsigned long now = millis();
        if (now - lastMqttReconnectAttempt > 5000) {
                lastMqttReconnectAttempt = now;
            if (reconnect_mqtt()) {
                lastMqttReconnectAttempt = 0;
            }
        }
    } else {
        client.loop();
    }
    // Send measurements at regular intervals
    unsigned long currentMillis = millis();
    if (currentMillis - lastMeasurement >= MEASUREMENT_INTERVAL) {
        lastMeasurement = currentMillis;
        // Read temperature and humidity
        float temp = temp_humd_sensor.readTemperature();
        float humidity = temp_humd_sensor.readHumidity();
        // Check if readings are valid
        if (isnan(temp) || isnan(humidity)) {
            Serial.println("Failed to read from DHT sensor!");
        } else {
            // Read pressure
            if (pressure_sensor.is_ready()) {
                // Get weight in grams from the calibrated scale
                float weight = pressure_sensor.get_units(10); // Average 10 readings for stability
                // Convert weight to pressure if needed
                // For example, if your sensor measures weight and you need pressure:
                // Assuming area in cm² and converting to kPa (weight in g * 9.81 / area in cm² / 100)
                float area = 10.0; // Example area in cm²
                float pressure = weight * 9.81 / (area * 100); // Convert to kPa
                Serial.print("Temperature: ");
                Serial.print(temp);
                Serial.print("°C, Humidity: ");
                Serial.print(humidity);
                Serial.print("%, Weight: ");
                Serial.print(weight);
                Serial.print("g, Pressure: ");
                Serial.print(pressure);
                Serial.println(" kPa");
                // Format MQTT message - use weight or pressure based on your needs
                char payload[50];
                // If your image generator expects pressure:
                snprintf(payload, sizeof(payload), "%.2f,%.2f,%.2f", temp, humidity, pressure);
                // If your image generator expects weight:
                // snprintf(payload, sizeof(payload), "%.2f,%.2f,%.2f", temp, humidity, weight);
                // Publish to MQTT
                if (client.connected()) {
                    led_blink(1);
                    if (client.publish(MQTT_TOPIC, payload)) {
                        Serial.println("Data sent successfully");
                    } else {
                        Serial.println("Failed to send data");
                    }
                } else {
                    Serial.println("MQTT not connected, data not sent");
                }
            } else {
                Serial.println("Pressure sensor not ready!");
            }
        }
    }
    // Keep loop running without blocking
    delay(100);
}
