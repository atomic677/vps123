FROM --platform=linux/amd64 ubuntu:25.04

ENV DEBIAN_FRONTEND=noninteractive

# Update and install base packages
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    novnc \
    websockify \
    sudo \
    xterm \
    init \
    systemd \
    snapd \
    vim \
    net-tools \
    curl \
    wget \
    git \
    tzdata \
    openssl

# Install X11 related packages
RUN apt update -y && apt install -y \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps

# Install software-properties-common
RUN apt install software-properties-common -y

# Install Firefox (Ubuntu 25.04 uses Firefox from Ubuntu repos directly or snap)
# For 25.04, Firefox might be available directly without PPA
RUN apt update -y && apt install -y firefox || \
    (snap install firefox && ln -s /snap/bin/firefox /usr/local/bin/firefox)

# Install icon theme
RUN apt update -y && apt install -y xubuntu-icon-theme || \
    apt install -y adwaita-icon-theme

# Create Xauthority file
RUN touch /root/.Xauthority

# Expose VNC and noVNC ports
EXPOSE 5901
EXPOSE 6080

# Start VNC server and websockify
CMD bash -c "vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && \
    openssl req -new -subj '/C=JP' -x509 -days 365 -nodes -out self.pem -keyout self.pem && \
    websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && \
    tail -f /dev/null"
