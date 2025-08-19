#!/bin/bash

# Exit on any error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status "Starting Artmograph server setup..."

# Update system
print_status "Updating Debian system packages..."
sudo apt update && sudo apt upgrade -y

# Install basic dependencies
print_status "Installing basic dependencies..."
sudo apt install -y \
    wget \
    git \
    curl \
    python3 \
    python3-pip \
    python3-venv \
    libgl1 \
    libglib2.0-0 \
    jq \
    mosquitto \
    mosquitto-clients \
    netcat-openbsd \
    build-essential \
    software-properties-common \
    pciutils \
    lshw \
    apache2 \
    bc

# Check if NVIDIA GPU is present
print_status "Checking for NVIDIA GPU..."
if lspci | grep -i nvidia > /dev/null; then
    print_status "NVIDIA GPU detected. Installing drivers..."
    
    # Add NVIDIA repository and install drivers
    sudo apt install -y linux-headers-$(uname -r)
    
    # Install NVIDIA drivers and CUDA toolkit properly
    # First, remove any existing NVIDIA installations
    sudo apt remove --purge '^nvidia-.*' -y 2>/dev/null || true
    sudo apt remove --purge '^libnvidia-.*' -y 2>/dev/null || true
    sudo apt remove --purge '^cuda-.*' -y 2>/dev/null || true
    
    # Add the official NVIDIA repository
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')
    wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb
    sudo dpkg -i /tmp/cuda-keyring.deb 2>/dev/null || true
    sudo apt update
    
    # Install NVIDIA driver and CUDA
    sudo apt install -y nvidia-driver-535 nvidia-utils-535 || \
    sudo apt install -y nvidia-driver-530 nvidia-utils-530 || \
    sudo apt install -y nvidia-driver-525 nvidia-utils-525 || \
    print_warning "Could not install specific NVIDIA driver version, trying generic..."
    
    sudo apt install -y nvidia-cuda-toolkit
    
    print_warning "NVIDIA drivers installed. A reboot will be required after setup completes."
    NEEDS_REBOOT=true
else
    print_warning "No NVIDIA GPU detected. Stable Diffusion will run in CPU mode (slower)."
fi

# Install Ollama
print_status "Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
print_status "Starting Ollama service..."
sudo systemctl enable ollama 2>/dev/null || true
sudo systemctl start ollama 2>/dev/null || true

# Wait for Ollama to be ready
sleep 5

# Pull LLaMA 3.2 model
print_status "Downloading LLaMA 3.2 model (this may take a while)..."
ollama pull llama3.2:latest || ollama pull llama3.2

# Create necessary directories
print_status "Creating project directories..."
mkdir -p ~/generated_img
mkdir -p ~/stable-diffusion
mkdir -p ~/artmograph_logs

# Install Python dependencies for MQTT
print_status "Installing Python MQTT client..."
pip3 install --user paho-mqtt

# Download and set up Stable Diffusion WebUI
print_status "Setting up Stable Diffusion WebUI..."
cd ~/stable-diffusion

if [ ! -d "stable-diffusion-webui" ]; then
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
fi

cd stable-diffusion-webui

# Create a Python virtual environment for Stable Diffusion
print_status "Setting up Python environment for Stable Diffusion..."
python3 -m venv venv
source venv/bin/activate

# Install torch with CPU support if no GPU, otherwise with CUDA
if lspci | grep -i nvidia > /dev/null; then
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
else
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
fi

deactivate

# Create MQTT Listener Python script
print_status "Creating MQTT listener script..."
cat <<'EOL' > ~/mqtt_listener.py
#!/usr/bin/env python3
import paho.mqtt.client as mqtt
import json
import subprocess
import os
from datetime import datetime

MQTT_BROKER = "localhost"  # Use localhost instead of 0.0.0.0
MQTT_PORT = 1883
MQTT_TOPIC = "esp32/sensor_data"
LOG_FILE = os.path.expanduser("~/artmograph_logs/mqtt_listener.log")

def log_message(message):
    """Log messages to file and console"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"[{timestamp}] {message}"
    print(log_entry)
    
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, 'a') as f:
        f.write(log_entry + '\n')

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        log_message("Connected to MQTT broker successfully")
        client.subscribe(MQTT_TOPIC)
        log_message(f"Subscribed to topic: {MQTT_TOPIC}")
    else:
        log_message(f"Failed to connect to MQTT broker. Return code: {rc}")

def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode())
        temperature = data.get('temperature', 0)
        humidity = data.get('humidity', 0)
        pressure = data.get('pressure', 0)
        
        log_message(f"Received data: Temperature: {temperature}°C, Humidity: {humidity}%, Pressure: {pressure} hPa")
        
        # Run image generator script
        script_path = os.path.expanduser("~/image_generator.sh")
        result = subprocess.run(
            ["/bin/bash", script_path, str(temperature), str(humidity), str(pressure)],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            log_message("Image generation completed successfully")
        else:
            log_message(f"Image generation failed: {result.stderr}")
            
    except json.JSONDecodeError as e:
        log_message(f"Failed to parse JSON: {e}")
    except Exception as e:
        log_message(f"Error processing message: {e}")

def on_disconnect(client, userdata, rc):
    if rc != 0:
        log_message(f"Unexpected disconnection from MQTT broker. Return code: {rc}")

# Create MQTT client
client = mqtt.Client(client_id="artmograph_listener")
client.on_connect = on_connect
client.on_message = on_message
client.on_disconnect = on_disconnect

try:
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    log_message(f"Starting MQTT listener on {MQTT_BROKER}:{MQTT_PORT}")
    client.loop_forever()
except Exception as e:
    log_message(f"Failed to start MQTT listener: {e}")
    exit(1)
EOL

chmod +x ~/mqtt_listener.py

# Configure and start Apache2 web server
print_status "Configuring Apache2 web server..."

# Create web directory
sudo mkdir -p /var/www/artmograph
sudo chown -R $USER:www-data /var/www/artmograph

# Create the webpage
print_status "Creating web interface..."
cat <<'EOL' | sudo tee /var/www/artmograph/index.html > /dev/null
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Atmospheric Art</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
            color: #333;
        }
        header {
            background-color: #2c3e50;
            color: white;
            padding: 1rem;
            text-align: center;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }
        .data-display {
            display: flex;
            justify-content: space-around;
            flex-wrap: wrap;
            margin-bottom: 2rem;
            background-color: white;
            border-radius: 8px;
            padding: 1rem;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        .data-point {
            text-align: center;
            padding: 1rem;
            margin: 0.5rem;
            border-radius: 8px;
            background-color: #ecf0f1;
            min-width: 120px;
        }
        .data-value {
            font-size: 2rem;
            font-weight: bold;
            color: #2980b9;
        }
        .data-label {
            font-size: 0.9rem;
            color: #7f8c8d;
        }
        .art-container {
            display: flex;
            justify-content: center;
            margin-bottom: 2rem;
        }
        #artImage {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            box-shadow: 0 4px 10px rgba(0,0,0,0.2);
        }
        .controls {
            background-color: white;
            border-radius: 8px;
            padding: 1rem;
            margin-top: 2rem;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        button {
            background-color: #3498db;
            color: white;
            border: none;
            padding: 0.5rem 1rem;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 0.5rem;
            transition: background-color 0.3s;
        }
        button:hover {
            background-color: #2980b9;
        }
        .status {
            text-align: center;
            padding: 0.5rem;
            margin: 1rem 0;
            border-radius: 4px;
            font-size: 0.9rem;
        }
        .status.connected {
            background-color: #d4edda;
            color: #155724;
        }
        .status.disconnected {
            background-color: #f8d7da;
            color: #721c24;
        }
        footer {
            text-align: center;
            padding: 1rem;
            background-color: #2c3e50;
            color: white;
        }
    </style>
</head>
<body>
    <header>
        <h1>ArtmoGraph</h1>
        <p>Generative art created from real-time atmospheric data</p>
    </header>
    
    <div class="container">
        <div class="status" id="status">Loading sensor data...</div>
        
        <div class="data-display">
            <div class="data-point">
                <div class="data-value" id="temperature">--</div>
                <div class="data-label">Temperature (°C)</div>
            </div>
            <div class="data-point">
                <div class="data-value" id="humidity">--</div>
                <div class="data-label">Humidity (%)</div>
            </div>
            <div class="data-point">
                <div class="data-value" id="pressure">--</div>
                <div class="data-label">Pressure (hPa)</div>
            </div>
        </div>
        
        <div class="art-container">
            <img id="artImage" src="/images/latest_image.png" alt="Generated Art" onerror="this.src='/images/placeholder.png'">
        </div>
        
        <div class="controls">
            <button onclick="refreshData()">Refresh Data</button>
            <button onclick="refreshImage()">Refresh Image</button>
            <p style="margin-top: 1rem; color: #7f8c8d;">Auto-refresh every 30 seconds</p>
        </div>
    </div>
    
    <footer>
        <p>&copy; 2025 ArtmoGraph - Real-time Weather Art Generation</p>
    </footer>
    
    <script>
        async function fetchSensorData() {
            try {
                const response = await fetch('/api/sensor-data');
                const data = await response.json();
                
                document.getElementById('temperature').textContent = data.temperature.toFixed(1);
                document.getElementById('humidity').textContent = data.humidity.toFixed(0);
                document.getElementById('pressure').textContent = data.pressure.toFixed(0);
                
                document.getElementById('status').textContent = 'Connected - Last update: ' + new Date().toLocaleTimeString();
                document.getElementById('status').className = 'status connected';
            } catch (error) {
                console.error('Error fetching sensor data:', error);
                document.getElementById('status').textContent = 'Connection error - Retrying...';
                document.getElementById('status').className = 'status disconnected';
            }
        }
        
        function refreshImage() {
            const img = document.getElementById('artImage');
            img.src = '/images/latest_image.png?' + new Date().getTime();
        }
        
        function refreshData() {
            fetchSensorData();
            refreshImage();
        }
        
        // Initial load
        fetchSensorData();
        
        // Auto-refresh every 30 seconds
        setInterval(() => {
            fetchSensorData();
            refreshImage();
        }, 30000);
    </script>
</body>
</html>
EOL

# Create placeholder image
print_status "Creating placeholder image..."
sudo mkdir -p /var/www/artmograph/images
cat <<'EOL' | sudo tee /var/www/artmograph/images/placeholder.svg > /dev/null
<svg width="512" height="512" xmlns="http://www.w3.org/2000/svg">
    <rect width="512" height="512" fill="#ecf0f1"/>
    <text x="50%" y="50%" font-family="Arial" font-size="24" fill="#95a5a6" text-anchor="middle" dy=".3em">Waiting for first image...</text>
</svg>
EOL

# Create symbolic link for generated images
sudo ln -sf $HOME/generated_img /var/www/artmograph/images

# Create API endpoint for sensor data
print_status "Creating sensor data API endpoint..."
cat <<'EOL' > ~/sensor_data_api.py
#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
from datetime import datetime

SENSOR_DATA_FILE = os.path.expanduser("~/artmograph_logs/latest_sensor_data.json")

class SensorDataHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/sensor-data':
            try:
                with open(SENSOR_DATA_FILE, 'r') as f:
                    data = json.load(f)
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(data).encode())
            except FileNotFoundError:
                # Return default values if no data yet
                default_data = {
                    "temperature": 0,
                    "humidity": 0,
                    "pressure": 0,
                    "timestamp": datetime.now().isoformat()
                }
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(default_data).encode())
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress console output
        pass

if __name__ == '__main__':
    server = HTTPServer(('localhost', 8081), SensorDataHandler)
    print("Sensor Data API running on port 8081")
    server.serve_forever()
EOL

chmod +x ~/sensor_data_api.py

# Update MQTT listener to save sensor data
print_status "Updating MQTT listener to save sensor data..."
cat <<'EOL' > ~/mqtt_listener.py
#!/usr/bin/env python3
import paho.mqtt.client as mqtt
import json
import subprocess
import os
from datetime import datetime

MQTT_BROKER = "localhost"
MQTT_PORT = 1883
MQTT_TOPIC = "esp32/sensor_data"
LOG_FILE = os.path.expanduser("~/artmograph_logs/mqtt_listener.log")
SENSOR_DATA_FILE = os.path.expanduser("~/artmograph_logs/latest_sensor_data.json")

def log_message(message):
    """Log messages to file and console"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"[{timestamp}] {message}"
    print(log_entry)
    
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, 'a') as f:
        f.write(log_entry + '\n')

def save_sensor_data(data):
    """Save latest sensor data for web API"""
    try:
        data['timestamp'] = datetime.now().isoformat()
        os.makedirs(os.path.dirname(SENSOR_DATA_FILE), exist_ok=True)
        with open(SENSOR_DATA_FILE, 'w') as f:
            json.dump(data, f)
    except Exception as e:
        log_message(f"Error saving sensor data: {e}")

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        log_message("Connected to MQTT broker successfully")
        client.subscribe(MQTT_TOPIC)
        log_message(f"Subscribed to topic: {MQTT_TOPIC}")
    else:
        log_message(f"Failed to connect to MQTT broker. Return code: {rc}")

def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode())
        temperature = data.get('temperature', 0)
        humidity = data.get('humidity', 0)
        pressure = data.get('pressure', 0)
        
        log_message(f"Received data: Temperature: {temperature}°C, Humidity: {humidity}%, Pressure: {pressure} hPa")
        
        # Save sensor data for web API
        save_sensor_data(data)
        
        # Run image generator script
        script_path = os.path.expanduser("~/image_generator.sh")
        result = subprocess.run(
            ["/bin/bash", script_path, str(temperature), str(humidity), str(pressure)],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            log_message("Image generation completed successfully")
        else:
            log_message(f"Image generation failed: {result.stderr}")
            
    except json.JSONDecodeError as e:
        log_message(f"Failed to parse JSON: {e}")
    except Exception as e:
        log_message(f"Error processing message: {e}")

def on_disconnect(client, userdata, rc):
    if rc != 0:
        log_message(f"Unexpected disconnection from MQTT broker. Return code: {rc}")

# Create MQTT client
client = mqtt.Client(client_id="artmograph_listener")
client.on_connect = on_connect
client.on_message = on_message
client.on_disconnect = on_disconnect

try:
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    log_message(f"Starting MQTT listener on {MQTT_BROKER}:{MQTT_PORT}")
    client.loop_forever()
except Exception as e:
    log_message(f"Failed to start MQTT listener: {e}")
    exit(1)
EOL

chmod +x ~/mqtt_listener.py

# Configure Apache2 virtual host
print_status "Configuring Apache2 virtual host..."
sudo tee /etc/apache2/sites-available/artmograph.conf > /dev/null <<EOL
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/artmograph
    
    <Directory /var/www/artmograph>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Proxy API requests to Python API server
    ProxyPass /api/sensor-data http://localhost:8081/api/sensor-data
    ProxyPassReverse /api/sensor-data http://localhost:8081/api/sensor-data
    
    # Serve generated images
    Alias /images/latest_image.png $HOME/generated_img/latest_image.png
    <Directory $HOME/generated_img>
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/artmograph_error.log
    CustomLog \${APACHE_LOG_DIR}/artmograph_access.log combined
</VirtualHost>
EOL

# Enable Apache2 modules and site
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod rewrite
sudo a2dissite 000-default
sudo a2ensite artmograph
sudo systemctl reload apache2

# Create systemd service for sensor data API
print_status "Creating systemd service for sensor data API..."
sudo tee /etc/systemd/system/sensor-data-api.service > /dev/null <<EOL
[Unit]
Description=Artmograph Sensor Data API
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/python3 $HOME/sensor_data_api.py
Restart=always
RestartSec=10
StandardOutput=append:$HOME/artmograph_logs/sensor_api.log
StandardError=append:$HOME/artmograph_logs/sensor_api.log

[Install]
WantedBy=multi-user.target
EOL

# Create image generator script
print_status "Creating image generator script..."
cat <<'EOL' > ~/image_generator.sh
#!/bin/bash

# Ensure the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <temperature> <humidity> <pressure>"
    exit 1
fi

temperature=$1
humidity=$2
pressure=$3

# Expand home directory
image_folder="$HOME/generated_img"
log_file="$HOME/artmograph_logs/image_generator.log"

# Create directories if they don't exist
mkdir -p "$image_folder"
mkdir -p "$(dirname "$log_file")"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$log_file"
}

log_message "Starting image generation with T:${temperature}°C, H:${humidity}%, P:${pressure}hPa"

# Construct the prompt for LLaMA
prompt="Based on these weather conditions: temperature ${temperature}°C, humidity ${humidity}%, pressure ${pressure}hPa. Create an artistic image prompt that captures the mood and atmosphere of this weather. Focus on abstract landscapes, colors, textures, and atmospheric elements. Be creative and artistic. Provide only the image generation prompt, no explanations."

# Run LLaMA to generate the detailed prompt
log_message "Generating artistic prompt with LLaMA..."
generated_prompt=$(timeout 30 ollama run llama3.2:latest "$prompt" 2>/dev/null)

# Check if LLaMA returned a valid prompt
if [[ -z "$generated_prompt" ]]; then
    log_message "LLaMA failed to generate a prompt. Using fallback prompt."
    # Fallback prompt based on weather conditions
    if (( $(echo "$temperature < 10" | bc -l) )); then
        mood="cold, crystalline"
    elif (( $(echo "$temperature > 25" | bc -l) )); then
        mood="warm, vibrant"
    else
        mood="mild, serene"
    fi
    
    if (( $(echo "$humidity > 70" | bc -l) )); then
        atmosphere="misty, ethereal"
    else
        atmosphere="clear, crisp"
    fi
    
    generated_prompt="Abstract atmospheric landscape, ${mood} mood, ${atmosphere} atmosphere, artistic interpretation of weather"
fi

log_message "Generated prompt: $generated_prompt"

# Check if Stable Diffusion WebUI is running
if ! nc -z 127.0.0.1 7860 2>/dev/null; then
    log_message "Stable Diffusion WebUI is not running. Starting it..."
    cd "$HOME/stable-diffusion/stable-diffusion-webui"
    
    # Start WebUI in background with API enabled
    nohup bash -c './webui.sh --listen --port 7860 --api --xformers --no-half' > "$HOME/artmograph_logs/stable_diffusion.log" 2>&1 &
    
    # Wait for WebUI to initialize
    for i in {1..60}; do
        if nc -z 127.0.0.1 7860 2>/dev/null; then
            log_message "Stable Diffusion WebUI started successfully"
            break
        fi
        sleep 2
    done
    
    if ! nc -z 127.0.0.1 7860 2>/dev/null; then
        log_message "Failed to start Stable Diffusion WebUI"
        exit 1
    fi
fi

# Generate timestamp for unique filename
timestamp=$(date +%Y%m%d_%H%M%S)
image_filename="weather_art_${timestamp}.png"

# Prepare the payload for the API request
payload=$(jq -n \
    --arg prompt "$generated_prompt" \
    '{
        prompt: $prompt,
        negative_prompt: "human, person, people, face, portrait, text, watermark, signature",
        steps: 30,
        width: 512,
        height: 512,
        batch_size: 1,
        seed: -1,
        cfg_scale: 7.5,
        sampler_name: "Euler a"
    }')

# Send request to Stable Diffusion API
log_message "Sending request to Stable Diffusion API..."
response=$(curl -s -X POST http://127.0.0.1:7860/sdapi/v1/txt2img \
    -H "Content-Type: application/json" \
    -d "$payload" \
    --max-time 120)

# Extract and save the image
image_data=$(echo "$response" | jq -r '.images[0]' 2>/dev/null)

if [[ -n "$image_data" ]] && [[ "$image_data" != "null" ]]; then
    echo "$image_data" | base64 -d > "$image_folder/$image_filename"
    
    # Also save as latest_image.png for easy access
    cp "$image_folder/$image_filename" "$image_folder/latest_image.png"
    
    log_message "Image generated and saved as $image_folder/$image_filename"
    echo "$image_folder/$image_filename"
else
    log_message "Failed to generate image. Response: $response"
    exit 1
fi
EOL

chmod +x ~/image_generator.sh

# Create systemd service for MQTT listener
print_status "Creating systemd service for MQTT listener..."
sudo tee /etc/systemd/system/artmograph-mqtt.service > /dev/null <<EOL
[Unit]
Description=Artmograph MQTT Listener
After=network.target mosquitto.service stable-diffusion-webui.service ollama.service
Wants=mosquitto.service stable-diffusion-webui.service ollama.service

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/python3 $HOME/mqtt_listener.py
Restart=always
RestartSec=30
StartLimitBurst=5
StartLimitIntervalSec=100
StandardOutput=append:$HOME/artmograph_logs/mqtt_service.log
StandardError=append:$HOME/artmograph_logs/mqtt_service.log

[Install]
WantedBy=multi-user.target
EOL

# Create systemd service for Stable Diffusion WebUI (auto-start enabled)
print_status "Creating systemd service for Stable Diffusion WebUI..."
sudo tee /etc/systemd/system/stable-diffusion-webui.service > /dev/null <<EOL
[Unit]
Description=Stable Diffusion WebUI
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/stable-diffusion/stable-diffusion-webui
ExecStart=/bin/bash -c 'source venv/bin/activate && python launch.py --listen --port 7860 --api --xformers --no-half'
Restart=always
RestartSec=10
StandardOutput=append:$HOME/artmograph_logs/stable_diffusion_service.log
StandardError=append:$HOME/artmograph_logs/stable_diffusion_service.log

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable ALL services for auto-start
print_status "Enabling all services for auto-start on boot..."
sudo systemctl daemon-reload

# Enable and start Apache2 web server
sudo systemctl enable apache2.service
sudo systemctl restart apache2.service

# Enable and start Mosquitto MQTT broker
sudo systemctl enable mosquitto.service
sudo systemctl start mosquitto.service

# Enable and start Ollama service
sudo systemctl enable ollama.service
sudo systemctl start ollama.service

# Enable and start Stable Diffusion WebUI service
sudo systemctl enable stable-diffusion-webui.service
sudo systemctl start stable-diffusion-webui.service

# Enable and start Sensor Data API service
sudo systemctl enable sensor-data-api.service
sudo systemctl start sensor-data-api.service

# Enable and start MQTT listener service
sudo systemctl enable artmograph-mqtt.service
sudo systemctl start artmograph-mqtt.service

# Final setup summary
print_status "==========================================="
print_status "Artmograph Server Setup Complete!"
print_status "==========================================="
echo ""
echo "Services installed and enabled for auto-start:"
echo "  ✓ Apache2 Web Server (Port 80) - AUTO-START ENABLED"
echo "  ✓ Mosquitto MQTT Broker (Port 1883) - AUTO-START ENABLED"
echo "  ✓ Ollama with LLaMA 3.2 - AUTO-START ENABLED"
echo "  ✓ Stable Diffusion WebUI (Port 7860) - AUTO-START ENABLED"
echo "  ✓ Sensor Data API (Port 8081) - AUTO-START ENABLED"
echo "  ✓ MQTT Listener Service - AUTO-START ENABLED"
echo ""
echo "ALL SERVICES WILL START AUTOMATICALLY ON BOOT!"
echo ""
echo "Web Interface:"
echo "  • URL: http://$(hostname -I | awk '{print $1}')"
echo "  • Local: http://localhost"
echo ""
echo "Directories created:"
echo "  • ~/generated_img - Generated images storage"
echo "  • ~/stable-diffusion - Stable Diffusion installation"
echo "  • ~/artmograph_logs - Log files"
echo "  • /var/www/artmograph - Web interface files"
echo ""
echo "Key files:"
echo "  • ~/mqtt_listener.py - MQTT listener script"
echo "  • ~/image_generator.sh - Image generation script"
echo "  • ~/sensor_data_api.py - Sensor data API server"
echo "  • /var/www/artmograph/index.html - Web interface"
echo ""
echo "Service management commands:"
echo "  • sudo systemctl status apache2               - Check web server"
echo "  • sudo systemctl status artmograph-mqtt       - Check MQTT listener"
echo "  • sudo systemctl status stable-diffusion-webui - Check Stable Diffusion"
echo "  • sudo systemctl status sensor-data-api       - Check Sensor API"
echo "  • sudo systemctl status mosquitto             - Check MQTT broker"
echo "  • sudo systemctl status ollama                - Check Ollama"
echo "  • sudo journalctl -u artmograph-mqtt -f       - View MQTT listener logs"
echo ""
echo "Manual testing:"
echo "  • ~/image_generator.sh 22 65 1013  - Generate test image"
echo "  • mosquitto_pub -h localhost -t 'esp32/sensor_data' -m '{\"temperature\":22,\"humidity\":65,\"pressure\":1013}'"
echo "  • curl http://localhost/api/sensor-data  - Test sensor API"
echo ""
echo "Current service status:"
sudo systemctl is-active --quiet apache2 && echo "  ✓ Apache2 is running" || echo "  ✗ Apache2 is not running"
sudo systemctl is-active --quiet mosquitto && echo "  ✓ Mosquitto is running" || echo "  ✗ Mosquitto is not running"
sudo systemctl is-active --quiet ollama && echo "  ✓ Ollama is running" || echo "  ✗ Ollama is not running"
sudo systemctl is-active --quiet stable-diffusion-webui && echo "  ✓ Stable Diffusion is running" || echo "  ✗ Stable Diffusion is not running"
sudo systemctl is-active --quiet sensor-data-api && echo "  ✓ Sensor Data API is running" || echo "  ✗ Sensor Data API is not running"
sudo systemctl is-active --quiet artmograph-mqtt && echo "  ✓ MQTT Listener is running" || echo "  ✗ MQTT Listener is not running"
echo ""

if [ "$NEEDS_REBOOT" = true ]; then
    print_warning "IMPORTANT: Please reboot the system to apply NVIDIA driver changes!"
    echo "Run: sudo reboot"
fi

print_status "Setup script execution completed!"
