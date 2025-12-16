#!/bin/bash

# Update package lists
sudo apt update

# Download Chrome Remote Desktop
wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb

# Install Chrome Remote Desktop and its dependencies
sudo apt install -y ./chrome-remote-desktop_current_amd64.deb

# Install a desktop environment (XFCE)
sudo apt install -y xfce4 xfce4-goodies

# Set XFCE as the default desktop environment for Chrome Remote Desktop
echo "exec /etc/X11/Xsession /usr/bin/xfce4-session" > ~/.chrome-remote-desktop-session

# Reload the desktop session to apply changes
sudo systemctl restart chrome-remote-desktop@$USER
