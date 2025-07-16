#!/bin/bash

set -e

echo "🔄 Обновляем пакеты и устанавливаем зависимости..."
sudo apt update
sudo apt purge pulseaudio pulseaudio-utils pulseaudio-module*
sudo rm -rf ~/.config/pulse /etc/pulse /var/lib/pulse
sudo apt install -y git wireguard firefox pulseaudio python3 python3-pip
systemctl --user mask pulseaudio.socket
systemctl --user mask pulseaudio.service
echo "autospawn = no" > ~/.config/pulse/client.conf
pulseaudio --kill
rm -rf ~/.config/pulse ~/.pulse /run/user/1000/pulse
pulseaudio --start --log-level=info

cd /home/orangepi/orange/linphone_web_interface
pip3 install -r requirements.txt
echo "🧩 Создаём профиль Firefox..."
DISPLAY=:0 firefox --no-remote --CreateProfile orangepi

echo "📥 Клонируем репозиторий и переносим файлы..."
git clone https://github.com/kirillsilent/orange.git
cd orange
sudo mv linphone_web_interface /home/orangepi/
sudo mv gpio.sh run.sh config.json /home/orangepi/
sudo mv start.service web.service /etc/systemd/system/

echo "📂 Создаём desktop-файл для автозапуска Firefox в режиме киоска..."
mkdir -p ~/.config/autostart
cat <<EOF > ~/.config/autostart/sip-main.desktop
[Desktop Entry]
Type=Application
Exec=firefox -P orangepi --kiosk https://localhost:8080 --noerrdialogs --autoplay-policy=no-user-gesture-required
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=SIP Interface Main
EOF

echo "🔐 Назначаем права и активируем systemd-сервисы..."
cd /home/orangepi/
sudo chmod +x gpio.sh run.sh
sudo chmod 777 linphone_web_interface/
sudo systemctl enable start.service
sudo systemctl enable web.service
sudo systemctl start start.service
sudo systemctl start web.service

echo "🔊 Настраиваем PulseAudio с нужными устройствами..."

# Шаг 1: создаём скрипт, который выбирает нужные устройства
mkdir -p ~/.config/pulse

cat <<EOF > ~/.config/pulse/default-devices.sh
#!/bin/bash
sleep 5
pactl set-default-sink alsa_output.platform-rk809-sound.stereo-fallback
pactl set-default-source alsa_input.usb-GeneralPlus_USB_Audio_Device-00.mono-fallback
EOF

sudo chmod +x ~/.config/pulse/default-devices.sh

# Шаг 2: создаём systemd-сервис для выполнения скрипта после запуска PulseAudio
mkdir -p ~/.config/systemd/user

cat <<EOF > ~/.config/systemd/user/set-pulseaudio-defaults.service
[Unit]
Description=Set PulseAudio default devices
After=network.target

[Service]
ExecStart=/home/orangepi/.config/pulse/default-devices.sh
Restart=on-failure

[Install]
WantedBy=default.target
EOF

# Шаг 3: активируем пользовательский systemd-сервис
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable --now set-pulseaudio-defaults.service

sudo mkdir -p /etc/ssl/localcerts
cd /etc/ssl/localcerts

sudo openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout localhost.key \
  -out localhost.crt \
  -subj "/C=KZ/ST=Kazakhstan/L=Local/O=Localhost/CN=localhost"

systemctl --user unmask pulseaudio.socket
systemctl --user unmask pulseaudio.service
systemctl --user enable pulseaudio.socket
systemctl --user enable pulseaudio.service
systemctl --user restart pulseaudio.socket
systemctl --user restart pulseaudio.service

(crontab -l 2>/dev/null; echo "@reboot wg-quick up wg0") | sudo crontab -
echo "✅ Установка завершена успешно!"
