#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use: sudo bash script.sh)"
  exit 1
fi

# Function to install NFS Server
install_nfs_server() {
  echo "Installing NFS Server..."
  apt update && apt install -y nfs-kernel-server
  systemctl enable nfs-kernel-server
  echo "NFS Server Installed Successfully!"
}

# Function to configure NFS Server
configure_nfs_server() {
  echo "Creating NFS shared directory..."
  mkdir -p /mnt/nfs_share
  chown -R nobody:nogroup /mnt/nfs_share
  chmod 777 /mnt/nfs_share

  echo "Configuring /etc/exports..."
  if ! grep -q "/mnt/nfs_share" /etc/exports; then
    echo "/mnt/nfs_share 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  fi

  exportfs -ra
  systemctl restart nfs-kernel-server
  echo "NFS Server Configured Successfully!"
}

# Function to install NFS Client
install_nfs_client() {
  echo "Installing NFS Client..."
  apt update && apt install -y nfs-common
  echo "NFS Client Installed Successfully!"
}

# Validate IP format
valid_ip() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

# Function to configure NFS Client
configure_nfs_client() {
  read -p "Enter NFS Server IP Address: " SERVER_IP

  if ! valid_ip "$SERVER_IP"; then
    echo "Invalid IP address format."
    return
  fi

  mkdir -p /mnt/nfs_client

  if mount "$SERVER_IP:/mnt/nfs_share" /mnt/nfs_client; then
    if ! grep -q "$SERVER_IP:/mnt/nfs_share" /etc/fstab; then
      echo "$SERVER_IP:/mnt/nfs_share /mnt/nfs_client nfs defaults 0 0" >> /etc/fstab
    fi
    echo "NFS share mounted successfully."
  else
    echo "Failed to mount. Please check the server IP or network connection."
  fi
}

# Manage NFS service
manage_nfs_service() {
  echo "1) Start NFS Server"
  echo "2) Restart NFS Server"
  echo "3) Stop NFS Server"
  read -p "Choose an option: " choice
  case $choice in
    1) systemctl start nfs-kernel-server ;;
    2) systemctl restart nfs-kernel-server ;;
    3) systemctl stop nfs-kernel-server ;;
    *) echo "Invalid option" ;;
  esac
}

# Test file sharing
test_file_sharing() {
  read -p "Enter machine type (server/client): " MACHINE
  if [ "$MACHINE" == "server" ]; then
    echo "Hello from NFS Server!" > /mnt/nfs_share/server_test.txt
    echo "server_test.txt created on server!"
  elif [ "$MACHINE" == "client" ]; then
    echo "Hello from NFS Client!" > /mnt/nfs_client/client_test.txt
    echo "client_test.txt created on client!"
  else
    echo "Invalid input!"
  fi
}

# Configure firewall
configure_firewall() {
  echo "Configuring firewall..."
  ufw allow from 192.168.1.0/24 to any port 2049
  ufw --force enable
  echo "Firewall configured."
}

# Share custom file from server to client
share_file_from_server() {
  read -p "Enter the custom file name to share (e.g., note.txt): " FILE_NAME
  read -p "Enter content for the file: " FILE_CONTENT

  echo "$FILE_CONTENT" > "/mnt/nfs_share/$FILE_NAME"

  if [ -f "/mnt/nfs_client/$FILE_NAME" ]; then
    echo "$FILE_NAME shared successfully to client!"
  else
    echo "File not visible in client mount. Please check mount."
  fi
}

# Share custom file from client to server
share_file_from_client() {
  read -p "Enter the custom file name to share (e.g., update.txt): " FILE_NAME
  read -p "Enter content for the file: " FILE_CONTENT

  echo "$FILE_CONTENT" > "/mnt/nfs_client/$FILE_NAME"

  if [ -f "/mnt/nfs_share/$FILE_NAME" ]; then
    echo "$FILE_NAME shared successfully to server!"
  else
    echo "File not visible in server mount. Please check mount."
  fi
}

# View shared files and access selected one
view_shared_files() {
  read -p "Are you on 'server' or 'client'? " MACHINE

  if [ "$MACHINE" == "server" ]; then
    DIR="/mnt/nfs_share"
  elif [ "$MACHINE" == "client" ]; then
    DIR="/mnt/nfs_client"
  else
    echo "Invalid input."
    return
  fi

  echo "Files in $DIR:"
  mapfile -t FILES < <(ls "$DIR")
  
  if [ ${#FILES[@]} -eq 0 ]; then
    echo "No files found."
    return
  fi

  for i in "${!FILES[@]}"; do
    printf "%d) %s\n" $((i+1)) "${FILES[$i]}"
  done

  read -p "Enter the number of the file you want to view: " FILE_NUM

  if [[ "$FILE_NUM" -gt 0 && "$FILE_NUM" -le ${#FILES[@]} ]]; then
    FILE_SELECTED="${FILES[$((FILE_NUM-1))]}"
    echo "------- Content of $FILE_SELECTED -------"
    cat "$DIR/$FILE_SELECTED"
    echo "----------------------------------------"
  else
    echo "Invalid selection!"
  fi
}
delete_shared_file_server_only() {
  echo "Delete Shared File [Server Only]"

  DIR="/mnt/nfs_share"

  if [ ! -d "$DIR" ]; then
    echo "Shared directory does not exist!"
    return
  fi

  echo "Files in $DIR:"
  mapfile -t FILES < <(ls "$DIR")

  if [ ${#FILES[@]} -eq 0 ]; then
    echo "No files to delete."
    return
  fi

  for i in "${!FILES[@]}"; do
    printf "%d) %s\n" $((i+1)) "${FILES[$i]}"
  done

  read -p "Enter the number of the file you want to delete: " FILE_NUM

  if [[ "$FILE_NUM" -gt 0 && "$FILE_NUM" -le ${#FILES[@]} ]]; then
    FILE_SELECTED="${FILES[$((FILE_NUM-1))]}"
    read -p "Are you sure you want to delete '$FILE_SELECTED'? (y/n): " confirm
    if [ "$confirm" == "y" ]; then
      rm "$DIR/$FILE_SELECTED"
      echo "'$FILE_SELECTED' has been deleted from the server."
    else
      echo "Deletion cancelled."
    fi
  else
    echo "Invalid selection!"
  fi
}
# Main menu loop
while true; do
  clear
  echo "==============================="
  echo "      NFS SERVER MANAGER       "
  echo "==============================="
  echo "1) Install NFS Server"
  echo "2) Configure NFS Server"
  echo "3) Install NFS Client"
  echo "4) Configure NFS Client"
  echo "5) Manage NFS Services"
  echo "6) Test File Sharing"
  echo "7) Configure Firewall"
  echo "8) Share Custom File from Server to Client"
  echo "9) Share Custom File from Client to Server"
  echo "10) View Shared Files"
  echo "11) Delete a Shared File (Server Only)"
  echo "12) Exit"
  echo "==============================="
  read -p "Enter your choice: " option

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
    11) delete_shared_file_server_only ;;
    12) echo "Exiting..."; exit ;;
    *) echo "Invalid choice." ;;
  esac

  read -p "Press Enter to continue..."
done
