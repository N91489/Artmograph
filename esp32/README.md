### Setup for ESP32 with DHT22 + HX711 (Pressure) Sensor

This project runs on an ESP32, reading:

- Temperature & Humidity from a DHT22 sensor
- Pressure (via load cell + HX711 amplifier)

It then publishes these readings to an MQTT broker (like one hosted on AWS) at regular intervals.

It also features:

- Calibration mode for the HX711 (find zero offset & scale factor)
- LED indicators for WiFi/MQTT status.

### How it works

1.  DHT22: Measures temperature (°C) and humidity (%RH).

2.  HX711 + Load Cell: Measures force (interpreted as weight).
    With a known area, it calculates pressure (kPa):
    `pressure = weight (g) * 9.81 / (area cm² * 100)`

3.      Sends data every 30 seconds to MQTT topic:
    `sensor/data`

Payload format:

```
"temperature,humidity,pressure"
e.g. "28.75,56.42,3.28"
```

4. LED blinks:

- Rapid: connecting to WiFi
- 3x: WiFi connected
- 2x: MQTT connected
- 1x: data published

### Hardware Setup

### Software Setup

1. Install Arduino IDE
   Download from https://www.arduino.cc/en/software.

2. Install ESP32 Core
   In Arduino IDE:

   - Go to: File > Preferences > Additional Boards Manager URLs
   - Add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`

   - Then: Tools > Board > Boards Manager → search ESP32 → install

3. Install Libraries
   Use Sketch > Include Library > Manage Libraries to install:

- DHT sensor library (by Adafruit)
- Adafruit Unified Sensor
- HX711 (by Bogdan Necula or similar)
- PubSubClient (by Nick O’Leary for MQTT)

4. Cofigure the Settings

- Edit these lines in your code:

```
#define WIFI_SSID "your_wifi_name"
#define WIFI_PASSWORD "your_wifi_password"
#define MQTT_SERVER "your_aws_ip"
#define MQTT_PORT 1883
```

5. Upload the Code

- Select board: Tools > Board > ESP32 Dev Module
- Select port: Tools > Port
- Click Upload.

6. Calibrating the HX711

**Calibration finds:**

- ZERO_OFFSET: reading with no load
- SCALE_FACTOR: to convert raw values to grams

**To Calibrate**

i. Open Serial Monitor @ 115200 baud.
ii. When prompted: `Send 'c' within 5 seconds to enter calibration mode...`
Enter c in the text field and enter

iii. Copy printed values into your code:

```
const long ZERO_OFFSET = ...;
const float SCALE_FACTOR = ...;
```

Re-upload and you’re done.

7. Run it!

- Watch your Serial Monitor print:`Temperature: 28.7°C, Humidity: 54%, Pressure: 3.2 kPa`
- Data publishes every 30 seconds to your MQTT topic.
