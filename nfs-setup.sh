#!/bin/bash

# Function to install NFS Server
install_nfs_server() {
    echo "Installing NFS Server..."
    sudo apt update && sudo apt install -y nfs-kernel-server
    sudo systemctl enable nfs-kernel-server
    echo "NFS Server Installed Successfully!"
}

# Function to configure NFS Server
configure_nfs_server() {
    echo "Creating NFS shared directory..."
    sudo mkdir -p /mnt/nfs_share
    sudo chown -R nobody:nogroup /mnt/nfs_share
    sudo chmod 777 /mnt/nfs_share

    echo "Configuring /etc/exports file..."
    echo "/mnt/nfs_share *(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports

    echo "Applying NFS export changes..."
    sudo exportfs -a
    sudo systemctl restart nfs-kernel-server
    echo "NFS Server Configured Successfully!"
}

# Function to install NFS Client
install_nfs_client() {
    echo "Installing NFS Client..."
    sudo apt update && sudo apt install -y nfs-common
    echo "NFS Client Installed Successfully!"
}

# Function to configure NFS Client
configure_nfs_client() {
    echo "Enter NFS Server IP Address:"
    read SERVER_IP
    sudo mkdir -p /mnt/nfs_client
    sudo mount $SERVER_IP:/mnt/nfs_share /mnt/nfs_client
    echo "$SERVER_IP:/mnt/nfs_share /mnt/nfs_client nfs defaults 0 0" | sudo tee -a /etc/fstab
    echo "NFS Client Configured Successfully!"
}

# Function to start/stop/restart NFS service
manage_nfs_service() {
    echo "Choose an option:"
    echo "1) Start NFS Server"
    echo "2) Restart NFS Server"
    echo "3) Stop NFS Server"
    read choice
    case $choice in
        1) sudo systemctl start nfs-kernel-server ;;
        2) sudo systemctl restart nfs-kernel-server ;;
        3) sudo systemctl stop nfs-kernel-server ;;
        *) echo "Invalid option";;
    esac
}

# Function to test file sharing
test_file_sharing() {
    echo "Enter the client machine (type 'server' or 'client'):"
    read MACHINE
    if [ "$MACHINE" == "server" ]; then
        echo "Creating test file on Server..."
        echo "Hello from NFS Server!" | sudo tee /mnt/nfs_share/server_test.txt
    elif [ "$MACHINE" == "client" ]; then
        echo "Creating test file on Client..."
        echo "Hello from NFS Client!" | sudo tee /mnt/nfs_client/client_test.txt
    else
        echo "Invalid option!"
    fi
}

# Function to configure firewall
configure_firewall() {
    echo "Configuring firewall for NFS..."
    sudo ufw allow from 192.168.1.0/24 to any port 2049
    sudo ufw enable
    echo "Firewall configured successfully!"
}

# Function to share a file from the server to client
share_file_from_server() {
    echo "Choose a file to share from the server:"
    echo "1) server_test.txt"
    echo "2) another_test_file.txt"
    read file_choice

    if [ "$file_choice" -eq 1 ]; then
        FILE_NAME="server_test.txt"
    elif [ "$file_choice" -eq 2 ]; then
        FILE_NAME="another_test_file.txt"
    else
        echo "Invalid choice!"
        return
    fi

    if [ -f "/mnt/nfs_share/$FILE_NAME" ]; then
        echo "Copying $FILE_NAME to client..."
        sudo cp "/mnt/nfs_share/$FILE_NAME" /mnt/nfs_client/
        echo "$FILE_NAME copied to client successfully!"
    else
        echo "$FILE_NAME does not exist on the server!"
    fi
}

# Function to share files from client to server
share_file_from_client() {
    echo "Choose a file to share from the client:"
    echo "1) client_test.txt"
    echo "2) another_client_file.txt"
    echo "Enter the number corresponding to the file you want to share:"
    read choice
    case $choice in
        1) echo "Copying client_test.txt to server..." 
           sudo cp /mnt/nfs_client/client_test.txt /mnt/nfs_share/ ;;
        2) echo "Copying another_client_file.txt to server..." 
           sudo cp /mnt/nfs_client/another_client_file.txt /mnt/nfs_share/ ;;
        *) echo "Invalid choice, no file copied." ;;
    esac
}
# Function to view shared files
view_shared_files() {
    echo "Are you on the 'server' or 'client' machine?"
    read MACHINE
    if [ "$MACHINE" == "server" ]; then
        echo "Listing shared files on the Server (/mnt/nfs_share):"
        ls -l /mnt/nfs_share
    elif [ "$MACHINE" == "client" ]; then
        echo "Listing shared files on the Client (/mnt/nfs_client):"
        ls -l /mnt/nfs_client
    else
        echo "Invalid input! Please type 'server' or 'client'."
    fi
}

# Menu for user selection
while true; do
    clear
    echo "==============================="
    echo "      NFS SERVER MANAGER       "
    echo "==============================="
    echo "1) Install NFS Server"
    echo "2) Configure NFS Server"
    echo "3) Install NFS Client"
    echo "4) Configure NFS Client"
    echo "5) Manage NFS Services (Start/Stop/Restart)"
    echo "6) Test File Sharing"
    echo "7) Configure Firewall"
    echo "8) Share File from Server to Client"
    echo "9) Share File from Client to Server"
    echo "10) View Shared Files"
    echo "11) Exit"
    echo "==============================="
    echo "Enter your choice:"
    read option

    case $option in
        1) install_nfs_server ;;
        2) configure_nfs_server ;;
        3) install_nfs_client ;;
        4) configure_nfs_client ;;
        5) manage_nfs_service ;;
        6) test_file_sharing ;;
        7) configure_firewall ;;
        8) share_file_from_server ;;
        9) share_file_from_client ;;
        10) view_shared_files ;;
        11) echo "Exiting..."; exit ;;
        *) echo "Invalid option! Please enter a valid choice." ;;
    esac

    echo "Press Enter to continue..."
    read
done
