Get the docker apt script
wget https://raw.githubusercontent.com/vaughnshaun/paperless-quickstart/refs/heads/main/docker-scripts/setup-docker-apt.sh
Make executable
chmod +x setup-docker-apt.sh
sudo ./setup-docker-apt.sh
cat /etc/apt/sources.list.d/docker.list

wget https://raw.githubusercontent.com/vaughnshaun/paperless-quickstart/refs/heads/main/docker-scripts/install-docker-packages.sh

chmod +x install-docker-packages.sh
sudo ./install-docker-packages.sh
