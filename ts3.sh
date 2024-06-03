#!/bin/bash

echo "=================================================="
echo "   ÖNEM: Bu script Teamspeak sunucusunu kurar,    "
echo "  başlatır, durdurur ve siler. Kullanıcı bilgileri "
echo "          ve şifreyi kurulumdan sonra             "
echo "            ekranda göreceksiniz.                 "
echo "=================================================="
echo

# Define some variables
TEAMSPEAK_VERSION_URL="https://teamspeak.com/versions/server" # URL to check for the latest version
INSTALL_DIR="/opt/teamspeak"
DATA_DIR="/opt/teamspeak/data"
TS_USER="teamspeak"
TS_SERVICE="/etc/systemd/system/teamspeak.service"

# Function to download and install Teamspeak
install_teamspeak() {
    echo "Fetching latest Teamspeak version..."
    LATEST_VERSION=$(curl -s $TEAMSPEAK_VERSION_URL | grep -oP 'teamspeak-server-linux_amd64-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "Latest version is $LATEST_VERSION"

    DOWNLOAD_URL="https://files.teamspeak-services.com/releases/server/$LATEST_VERSION/teamspeak-server-linux_amd64-$LATEST_VERSION.tar.bz2"
    
    echo "Downloading Teamspeak server..."
    curl -O $DOWNLOAD_URL
    
    echo "Extracting Teamspeak server..."
    tar xvf teamspeak-server-linux_amd64-$LATEST_VERSION.tar.bz2
    mv teamspeak-server-linux_amd64-$LATEST_VERSION $INSTALL_DIR
    
    echo "Setting up permissions..."
    useradd -r -s /bin/false $TS_USER
    chown -R $TS_USER:$TS_USER $INSTALL_DIR
    mkdir -p $DATA_DIR
    chown -R $TS_USER:$TS_USER $DATA_DIR

    echo "Creating systemd service..."
    cat <<EOF > $TS_SERVICE
[Unit]
Description=TeamSpeak 3 Server
After=network.target

[Service]
WorkingDirectory=$INSTALL_DIR
User=$TS_USER
Group=$TS_USER
Type=forking
ExecStart=$INSTALL_DIR/ts3server_startscript.sh start inifile=$DATA_DIR/ts3server.ini
ExecStop=$INSTALL_DIR/ts3server_startscript.sh stop
PIDFile=$INSTALL_DIR/ts3server.pid
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

    echo "Enabling and starting Teamspeak server..."
    systemctl enable teamspeak
    systemctl start teamspeak

    sleep 5  # Give the server time to start

    # Fetch the serveradmin password from the log
    SERVERADMIN_PASSWORD=$(grep -oP 'token=[a-zA-Z0-9]+' $INSTALL_DIR/logs/ts3server_*.log | head -1 | cut -d'=' -f2)
    
    # Get server IP address
    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo "Teamspeak server installation completed!"
    echo "---------------------------------------"
    echo "Server IP: $SERVER_IP"
    echo "Server Admin Username: serveradmin"
    echo "Server Admin Password: $SERVERADMIN_PASSWORD"
    echo "---------------------------------------"
}

# Function to start Teamspeak server
start_teamspeak() {
    echo "Starting Teamspeak server..."
    systemctl start teamspeak
}

# Function to stop Teamspeak server
stop_teamspeak() {
    echo "Stopping Teamspeak server..."
    systemctl stop teamspeak
}

# Function to uninstall Teamspeak server
uninstall_teamspeak() {
    echo "Stopping and disabling Teamspeak server..."
    systemctl stop teamspeak
    systemctl disable teamspeak
    
    echo "Removing Teamspeak server files..."
    rm -rf $INSTALL_DIR
    rm -rf $DATA_DIR
    userdel -r $TS_USER
    rm $TS_SERVICE
    
    echo "Teamspeak server has been uninstalled!"
}

# Script usage information
usage() {
    echo "Usage: $0 {install|start|stop|uninstall}"
    exit 1
}

# Main script logic
if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    install)
        install_teamspeak
        ;;
    start)
        start_teamspeak
        ;;
    stop)
        stop_teamspeak
        ;;
    uninstall)
        uninstall_teamspeak
        ;;
    *)
        usage
        ;;
esac
