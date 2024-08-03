#!/bin/bash

# Update and install dependencies
sudo apt update
sudo apt upgrade -y
sudo apt install git python3 python3-venv python3-dev libssl-dev libffi-dev build-essential mysql-server -y

# Secure MySQL installation
sudo mysql_secure_installation

# Set up MySQL database and user
sudo mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE honeypot_data;
USE honeypot_data;
CREATE TABLE attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ip_address VARCHAR(255) NOT NULL,
    attempt_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    port INT NOT NULL
);
GRANT ALL PRIVILEGES ON honeypot_data.* TO 'honeypot_user'@'localhost' IDENTIFIED BY 'your_password'; 
FLUSH PRIVILEGES;
EXIT;
MYSQL_SCRIPT

# Clone and set up Cowrie
cd /opt
sudo git clone https://github.com/cowrie/cowrie
cd cowrie
sudo python3 -m venv cowrie-env
source cowrie-env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install mysql-connector-python

# Configure Cowrie
cp etc/cowrie.cfg.dist etc/cowrie.cfg
sed -i 's/^#listen_port = 2222/listen_port = 22/' etc/cowrie.cfg

# Add MySQL logging configuration
cat <<EOT >> etc/cowrie.cfg
[output_mysql]
host = localhost
database = honeypot_data
username = honeypot_user
password = your_password
port = 3306
class = cowrie.output.mysql.MySQLLogger
EOT

# Create custom output plugin
cat <<'EOF' > /opt/cowrie/cowrie/output/mysql.py
import mysql.connector
from cowrie.core.output import Output
from cowrie.core.config import CowrieConfig

class MySQLLogger(Output):
    def start(self):
        self.conn = mysql.connector.connect(
            host=CowrieConfig.get('output_mysql', 'host'),
            database=CowrieConfig.get('output_mysql', 'database'),
            user=CowrieConfig.get('output_mysql', 'username'),
            password=CowrieConfig.get('output_mysql', 'password')
        )
        self.cursor = self.conn.cursor()

    def stop(self):
        self.cursor.close()
        self.conn.close()

    def write(self, entry):
        if entry["eventid"] == "cowrie.session.connect":
            ip_address = entry["src_ip"]
            attempt_time = entry["timestamp"]
            port = entry["dst_port"]

            sql = "INSERT INTO attempts (ip_address, attempt_time, port) VALUES (%s, %s, %s)"
            val = (ip_address, attempt_time, port)
            self.cursor.execute(sql, val)
            self.conn.commit()
EOF

# Create systemd service
sudo tee /etc/systemd/system/cowrie.service > /dev/null <<EOF
[Unit]
Description=Cowrie SSH Honeypot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cowrie
ExecStart=/opt/cowrie/cowrie-env/bin/cowrie start
ExecStop=/opt/cowrie/cowrie-env/bin/cowrie stop
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Cowrie
sudo systemctl daemon-reload
sudo systemctl start cowrie
sudo systemctl enable cowrie

# Set up log rotation (optional)
sudo tee /etc/logrotate.d/cowrie > /dev/null <<EOF
/opt/cowrie/log/cowrie.json {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
    sharedscripts
    postrotate
        /bin/systemctl reload cowrie > /dev/null 2>/dev/null || true
    endscript
}
EOF

echo "Cowrie SSH Honeypot installation complete with MySQL logging."
