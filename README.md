# Artmograph
⸻

ArtmoGraph

IoT & AI-powered system that transforms live environmental data into stunning generative art.

ArtmoGraph combines sensor-driven IoT, AI language models, and generative image technology to visualize real-time atmospheric conditions as digital artwork.
It demonstrates how climate data can inspire creativity, making environmental awareness both interactive and beautiful.

Developed as a major project for BCA Semester 6 under the Department of Computer Science, CHRIST (Deemed to be University).

⸻

Features

✅ Real-time data collection with ESP32 + DHT22 (temperature & humidity) + BMP280 (pressure)
✅ Creative prompt generation using LLaMA 3.2B on an AWS GPU instance
✅ AI image creation via Stable Diffusion (AUTOMATIC1111)
✅ Web server display through Apache, accessible from any device
✅ Automated pipeline from sensor input to browser output

⸻

How it Works

    A[ESP32 + Sensors<br/>(DHT22, BMP280)] -->|MQTT| B[AWS EC2<br/>Data Processor]
    B --> C[LLaMA 3.2B<br/>Prompt Generator]
    C --> D[Stable Diffusion<br/>(AUTOMATIC1111)]
    D --> E[Apache Web Server]
    E --> F[Browser<br/>Live Art Display]

	1.	ESP32 with sensors captures live temperature, humidity, and pressure.
	2.	Sends data over MQTT to an AWS EC2 instance.
	3.	Bash & Python scripts process data into descriptive prompts.
	4.	LLaMA 3.2B refines these into rich artistic prompts.
	5.	Stable Diffusion generates beautiful, context-driven images.
	6.	Apache server hosts the latest artwork, viewable on any browser.

⸻

Tech Stack

Layer	Tools / Frameworks
Hardware	ESP32, DHT22, BMP280
IoT Comm	MQTT (Mosquitto)
AI	LLaMA 3.2B (via Ollama), Stable Diffusion
Scripts	Python 3, Bash
Infra	Terraform on AWS EC2 G4 (GPU)
Web	Apache2, HTML


⸻

Project Structure

artmograph/
├── esp32/           # Arduino sketch for ESP32 + sensors
├── terraform/       # Terraform scripts for AWS infra
├── server/          # MQTT listener & AI automation scripts
├── web/             # HTML for Apache-hosted display
├── requirements.txt # Python packages
├── LICENSE
└── README.md


⸻

Quick Start

Hardware Setup
	1.	Wire the ESP32 to DHT22 & BMP280 sensors.
	2.	Flash the ESP32 with esp32/sensor_publish.ino using Arduino IDE.
	3.	Update WiFi + MQTT broker IP in the code.

Deploy AWS EC2
	1.	Navigate to terraform/:

terraform init
terraform apply


	2.	This provisions a GPU EC2 instance with security groups for MQTT & HTTP.

Set up Server
	1.	SSH into your EC2 instance.
	2.	Clone this repo and install requirements:

pip install -r requirements.txt


	3.	Start your pipeline:

python3 server/mqtt_listener.py



View Your Art
	•	Open your EC2 public IP in a browser.
	•	See real-time evolving artwork based on your environment!

⸻

Example Outputs

Data	Generated Prompt	Artwork
47°C, 66% humidity	“A breathtaking Greek beach under a golden sun…”	
27°C, 56% humidity	“A serene village nestled in lush misty hills…”	


⸻

Future Enhancements
	•	Additional sensors (air quality, UV index, wind speed)
	•	User controls for style & themes
	•	Cloud storage of generated artwork history (S3)
	•	Mobile app for live viewing & downloads
	•	Predictive AI to generate art based on forecasts

⸻

📜 License

This project is licensed under the Apache License 2.0. See LICENSE for details.

⸻

📂 Folder READMEs

For details on individual components, see:
	•	esp32/README.md – Wiring & flashing instructions
	•	terraform/README.md – AWS infra setup
	•	server/README.md – Python + Bash AI pipeline
	•	web/README.md – HTML display served by Apache
