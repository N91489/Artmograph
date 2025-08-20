# ArtmoGraph
**Transform live environmental data into stunning AI-generated art**

## Overview
ArtmoGraph is an IoT & AI-powered system that creates generative artwork from real-time atmospheric conditions. Using ESP32 sensors to capture temperature, humidity, and pressure data, it generates creative prompts through LLaMA and produces unique digital art via Stable Diffusion - all viewable in your browser.

*Developed as a major project for BCA Semester 6, Department of Computer Science, CHRIST (Deemed to be University)*

## Features
- Real-time environmental monitoring (temperature, humidity, pressure)
- AI prompt generation using LLaMA 3.2B
- Automatic artwork creation with Stable Diffusion
- Web-based display accessible from any device
- AWS cloud infrastructure with GPU support
- Fully automated pipeline from sensor to artwork

## System Architecture
![ArtmoGraph Architecture Diagram](images/architecture-diagram.png)

## Tech Stack
| Component | Technology |
|-----------|------------|
| Hardware | ESP32, DHT22, Hx710B |
| IoT | MQTT (Mosquitto) |
| AI Models | LLaMA 3.2B, Stable Diffusion |
| Cloud | AWS EC2 G4 (GPU instance) |
| Backend | Python, Bash |
| Frontend | Apache2, HTML |
| IaC | Terraform |

## Quick Setup
### Prerequisites
- ESP32 with DHT22 and BMP280 sensors
- AWS account with GPU instance access
- Arduino IDE for ESP32 programming
- Terraform installed locally

### Installation Steps
#### 1 Infrastructure Setup
```bash
cd infrastructure/
terraform init
terraform apply
# detailed info at infrastructure/README.md
```
This provisions the AWS EC2 GPU instance with required security groups.

#### 2 Server Configuration
SSH into your EC2 instance and:
```bash
git clone https://github.com/N91489/Artmograph.git
cd Artmograph/server-setup/
chmod +x setup.sh
./setup.sh
# detailed info at server-setup/README.md
```

#### 3 ESP32 Setup
1. Wire ESP32 to sensors (see `esp32/README.md` for pinout)
2. Open `esp32/sensor_publish.ino` in Arduino IDE
3. Update WiFi credentials and MQTT broker IP
4. Flash to ESP32

detailed info at esp32/README.md

#### 4 View Your Art
Open your EC2 public IP in a browser to see live-generated artwork!

## Sample Generated Artwork

![Sample Art 1](images/sample-art-1.png)
![Sample Art 2](images/sample-art-2.png)
![Sample Art 3](images/sample-art-3.png)

## Project Structure
```
artmograph/
├── esp32/            # Arduino sketch & sensor code
├── infrastructure/   # Terraform AWS deployment
├── server-setup/     # Server configuration & AI pipeline
├── images/           # Documentation images & samples
│   ├── architecture-diagram.png
│   ├── sample-art-1.png
│   ├── sample-art-2.png
│   └── sample-art-3.png
└── README.md         # You are here
```

## Documentation
For detailed setup instructions, refer to:
- [`esp32/README.md`](https://github.com/N91489/Artmograph/blob/main/esp32/README.md) - Hardware wiring & firmware
- [`infrastructure/README.md`](https://github.com/N91489/Artmograph/tree/main/infrastructure) - AWS infrastructure details
- [`server-setup/README.md`](https://github.com/N91489/Artmograph/tree/main/server-setup) - Server & AI pipeline setup

## Future Enhancements
- Additional sensors (air quality, UV index)
- User-selectable art styles
- Artwork history storage 
- Mobile app for live viewing and settings
- Predictive art based on weather forecasts

## Notes
### Hardware Variations
- **Pressure Sensor**: Hx710B was used instead of the originally planned BMP280 due to unavailability
- **Display**: Originally designed to display artwork on an e-ink display inside a photo frame for a physical art installation, but due to unavailability of components, the project uses web-based display instead

## License
Apache License 2.0 - See [LICENSE](https://github.com/N91489/Artmograph/blob/main/LICENSE) for details

---
