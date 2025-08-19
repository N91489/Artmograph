# Server Setup Script 

## Overview

This setup script automates the complete installation and configuration of the Artmograph server.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/N91489/Artmograph.git
cd Artmograph

# Make the script executable
chmod +x setup.sh

# Run the setup
sudo ./setup.sh

# If NVIDIA GPU was detected, reboot after installation
sudo reboot

# Access the web interface
# Open browser and navigate to: http://your-server-ip
```

## 📦 What Gets Installed

### Core Components
- **Apache2 Web Server** - Serves the web dashboard and API
- **Mosquitto MQTT Broker** - Receives sensor data from ESP32 devices
- **Ollama with LLaMA 3.2** - Generates artistic prompts from weather data
- **Stable Diffusion WebUI** - Creates images from AI-generated prompts
- **Python MQTT Listener** - Orchestrates the entire pipeline
- **Sensor Data API** - Provides real-time data to web interface
- **NVIDIA Drivers & CUDA** - GPU acceleration (if NVIDIA GPU detected)

### System Dependencies
- Apache2 with proxy modules
- Python 3 with pip and venv
- Git, curl, wget, jq, bc
- Build essentials
- OpenGL libraries
- Network utilities

## System Architecture

DIAGRAM

## 📁 Directory Structure

After installation, the following directories are created:

```
~/
├── generated_img/           # Stores all generated artwork
│   └── latest_image.png    # Most recent generated image
├── stable-diffusion/        # Stable Diffusion installation
│   └── stable-diffusion-webui/
├── artmograph_logs/         # All system logs
│   ├── mqtt_listener.log
│   ├── image_generator.log
│   ├── stable_diffusion.log
│   ├── sensor_api.log
│   └── latest_sensor_data.json
├── mqtt_listener.py         # MQTT listener script
├── image_generator.sh       # Image generation script
└── sensor_data_api.py       # API server for sensor data

/var/www/artmograph/         # Web interface files
├── index.html              # Main dashboard
└── images/                 # Symlink to generated images
```

## 🔧 Services Configuration

All services are configured to start automatically on boot:

| Service | Port | Auto-Start | Description |
|---------|------|------------|-------------|
| Apache2 | 80 | ✅ | Web dashboard and proxy |
| Mosquitto | 1883 | ✅ | MQTT message broker |
| Ollama | 11434 | ✅ | LLaMA model server |
| Stable Diffusion | 7860 | ✅ | Image generation API |
| Sensor Data API | 8081 | ✅ | JSON API for sensor data |
| MQTT Listener | - | ✅ | Python orchestration script |

## 🌐 Web Interface

### Accessing the Dashboard
- **URL**: `http://your-server-ip`
- **Local**: `http://localhost`

### Features
- Real-time sensor data display (Temperature, Humidity, Pressure)
- Live generated artwork display
- Auto-refresh every 30 seconds
- Manual refresh buttons
- Connection status indicator
- Responsive design for mobile/desktop

### API Endpoints
- **Sensor Data**: `http://your-server-ip/api/sensor-data`
- **Latest Image**: `http://your-server-ip/images/latest_image.png`

## Service Management

### Check Service Status
```bash
# View all service statuses
sudo systemctl status apache2
sudo systemctl status mosquitto
sudo systemctl status ollama
sudo systemctl status stable-diffusion-webui
sudo systemctl status sensor-data-api
sudo systemctl status artmograph-mqtt

# Check if services are enabled for auto-start
systemctl is-enabled apache2
systemctl is-enabled mosquitto
systemctl is-enabled ollama
systemctl is-enabled stable-diffusion-webui
systemctl is-enabled sensor-data-api
systemctl is-enabled artmograph-mqtt
```

### View Logs
```bash
# Real-time MQTT listener logs
sudo journalctl -u artmograph-mqtt -f

# Apache web server logs
sudo tail -f /var/log/apache2/artmograph_access.log
sudo tail -f /var/log/apache2/artmograph_error.log

# View specific log files
tail -f ~/artmograph_logs/mqtt_listener.log
tail -f ~/artmograph_logs/image_generator.log
tail -f ~/artmograph_logs/stable_diffusion.log
tail -f ~/artmograph_logs/sensor_api.log
```

### Restart Services
```bash
sudo systemctl restart apache2
sudo systemctl restart mosquitto
sudo systemctl restart ollama
sudo systemctl restart stable-diffusion-webui
sudo systemctl restart sensor-data-api
sudo systemctl restart artmograph-mqtt
```

### Stop/Start Services
```bash
# Stop a service
sudo systemctl stop artmograph-mqtt

# Start a service
sudo systemctl start artmograph-mqtt

# Disable auto-start
sudo systemctl disable artmograph-mqtt

# Enable auto-start
sudo systemctl enable artmograph-mqtt
```

## Testing

### Test Web Interface
```bash
# Open in browser
firefox http://localhost &
# Or from remote machine
firefox http://your-server-ip &

# Test API endpoint
curl http://localhost/api/sensor-data | jq
```

### Manual Image Generation
```bash
# Generate test image with sample weather data
~/image_generator.sh 22 65 1013
# Arguments: temperature(°C) humidity(%) pressure(hPa)
```

### Test MQTT Publishing
```bash
# Send test data to MQTT broker
mosquitto_pub -h localhost -t 'esp32/sensor_data' \
  -m '{"temperature":22,"humidity":65,"pressure":1013}'
  
# Watch the web dashboard update automatically!
```

### Test MQTT Subscription
```bash
# Monitor MQTT messages
mosquitto_sub -h localhost -t 'esp32/sensor_data' -v
```

### Verify All Endpoints
```bash
# Check Apache web server
curl -I http://localhost

# Check Sensor Data API
curl http://localhost:8081/api/sensor-data

# Check Stable Diffusion API
curl http://localhost:7860/sdapi/v1/options

# Check Ollama API
curl http://localhost:11434/api/tags
```

## Security Configuration

### Secure Web Access (Optional)
To add basic authentication to the web interface:

```bash
# Create password file
sudo htpasswd -c /etc/apache2/.htpasswd admin

# Edit Apache config
sudo nano /etc/apache2/sites-available/artmograph.conf

# Add to <Directory /var/www/artmograph>:
AuthType Basic
AuthName "Artmograph Dashboard"
AuthUserFile /etc/apache2/.htpasswd
Require valid-user

# Restart Apache
sudo systemctl restart apache2
```

### MQTT Broker Security (Optional)
To add authentication to MQTT:

1. Create password file:
```bash
sudo mosquitto_passwd -c /etc/mosquitto/passwd username
```

2. Edit `/etc/mosquitto/conf.d/artmograph.conf`:
```conf
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd
```

3. Restart Mosquitto:
```bash
sudo systemctl restart mosquitto
```

## Troubleshooting

### Web Interface Not Loading
```bash
# Check Apache status
sudo systemctl status apache2

# Check Apache error logs
sudo tail -f /var/log/apache2/artmograph_error.log

# Verify Apache configuration
sudo apache2ctl configtest

# Check if port 80 is listening
sudo netstat -tlnp | grep :80

# Restart Apache
sudo systemctl restart apache2
```

### Sensor Data Not Updating
```bash
# Check Sensor Data API
sudo systemctl status sensor-data-api
curl http://localhost:8081/api/sensor-data

# Check latest sensor data file
cat ~/artmograph_logs/latest_sensor_data.json | jq

# Restart API service
sudo systemctl restart sensor-data-api
```

### NVIDIA GPU Not Detected
```bash
# Check if GPU is present
lspci | grep -i nvidia

# Verify driver installation
nvidia-smi
```

### Service Won't Start
```bash
# Check service logs
sudo journalctl -u service_name -n 50

# Check system resources
df -h          # Disk space
free -h        # Memory
htop           # CPU usage
```

### MQTT Connection Issues
```bash
# Test MQTT broker
mosquitto_pub -h localhost -t test -m "test" -d

# Check if port is open
sudo netstat -tlnp | grep 1883
```

### Stable Diffusion Issues
```bash
# Check if WebUI is running
curl http://localhost:7860

# View Stable Diffusion logs
tail -f ~/artmograph_logs/stable_diffusion.log

# Manually start WebUI
cd ~/stable-diffusion/stable-diffusion-webui
./webui.sh --listen --port 7860 --api
```

### Ollama Issues
```bash
# Check Ollama status
ollama list

# Re-pull model
ollama pull llama3.2:latest

# Test Ollama
ollama run llama3.2:latest "Hello"
```

## System Requirements

### Minimum Requirements
- **OS**: Debian 11+ or Ubuntu 20.04+
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 20GB free space
- **CPU**: 4+ cores recommended
- **Network**: Stable internet for initial setup

### Recommended Requirements
- **GPU**: NVIDIA GPU with 6GB+ VRAM
- **RAM**: 16GB or more
- **Storage**: 50GB+ for models and generated images
- **CPU**: 8+ cores for better performance

## Updating Components

### Update Ollama
```bash
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull llama3.2:latest
```

### Update Stable Diffusion
```bash
cd ~/stable-diffusion/stable-diffusion-webui
git pull
./webui.sh --update
```

### Update System Packages
```bash
sudo apt update && sudo apt upgrade -y
```

## ESP32 Configuration

Configure your ESP32 to send data to the MQTT broker:

```cpp
// MQTT Configuration
const char* mqtt_server = "YOUR_SERVER_IP";
const int mqtt_port = 1883;
const char* mqtt_topic = "esp32/sensor_data";

// JSON payload format
{
  "temperature": 22.5,
  "humidity": 65.0,
  "pressure": 1013.25
}
```

## Customization

### Modify Image Generation Prompts
Edit `~/image_generator.sh` to customize the prompt generation logic.

### Adjust Image Settings
Modify the Stable Diffusion parameters in `~/image_generator.sh`:
```bash
payload=$(jq -n \
    --arg prompt "$generated_prompt" \
    '{
        prompt: $prompt,
        steps: 30,           # Increase for better quality
        width: 512,          # Image width
        height: 512,         # Image height
        cfg_scale: 7.5,      # Creativity vs prompt adherence
        sampler_name: "Euler a"
    }')
```

### Change MQTT Topics
Edit `~/mqtt_listener.py` to modify MQTT configuration:
```python
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_TOPIC = "esp32/sensor_data"  # Change this
```

## 📝 Logs Location

All logs are stored in multiple locations:

### Application Logs
- `~/artmograph_logs/mqtt_listener.log` - MQTT listener activity
- `~/artmograph_logs/image_generator.log` - Image generation process
- `~/artmograph_logs/stable_diffusion.log` - Stable Diffusion WebUI output
- `~/artmograph_logs/sensor_api.log` - Sensor Data API logs
- `~/artmograph_logs/mqtt_service.log` - Systemd service logs
- `~/artmograph_logs/latest_sensor_data.json` - Latest sensor readings

### Apache Logs
- `/var/log/apache2/artmograph_access.log` - Web access logs
- `/var/log/apache2/artmograph_error.log` - Web error logs

### System Service Logs
- Use `journalctl -u service-name` to view systemd logs

## Support

For issues or questions:
1. Check the logs in `~/artmograph_logs/`
2. Verify all services are running with `systemctl status`
3. Open an issue on [GitHub](https://github.com/N91489/Artmograph)

---

**Note**: After running the setup script, all services will start automatically on every system boot. No manual intervention required!
