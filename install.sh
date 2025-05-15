#!/bin/bash

RPC_PORT=8545
BEACON_PORT=5052

clear
echo -e "\e[1;34m==============================\e[0m"
echo -e "\e[1;36m     Ethereum Sepolia Node     \e[0m"
echo -e "\e[1;32m         by Perfnode          \e[0m"
echo -e "\e[1;34m==============================\e[0m"

function install_node() {
  echo -e "\n\e[1;33mУстановка зависимостей...\e[0m"
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y curl git build-essential ufw unzip wget jq

  echo -e "\n\e[1;33mУстановка Docker и Docker Compose...\e[0m"
  curl -fsSL https://get.docker.com | bash
  sudo systemctl enable docker
  sudo systemctl start docker

  DOCKER_COMPOSE_VERSION="2.24.2"
  sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose

  echo -e "\n\e[1;33mНастройка ноды...\e[0m"
  mkdir -p ~/eth-rpc && cd ~/eth-rpc

  cat > docker-compose.yml <<EOF
version: "3.9"
services:
  geth:
    image: ethereum/client-go:stable
    volumes:
      - ./geth-data:/root/.ethereum
    command: >
      --sepolia
      --http
      --http.addr 0.0.0.0
      --http.port ${RPC_PORT}
      --http.api eth,net,web3
      --http.corsdomain "*"
      --ws
      --ws.addr 0.0.0.0
      --ws.port 8546
      --ws.api eth,net,web3
      --syncmode snap
      --gcmode archive
    ports:
      - "${RPC_PORT}:${RPC_PORT}"
      - "8546:8546"
      - "30303:30303"
    restart: unless-stopped
EOF

  docker compose up -d
  echo -e "\n\e[1;32mНода установлена и запущена!\e[0m"
}

function install_beacon() {
  echo -e "\n\e[1;33mУстановка Beacon Chain (Lighthouse)...\e[0m"
  mkdir -p ~/beacon && cd ~/beacon

  cat > docker-compose.yml <<EOF
version: "3.9"
services:
  lighthouse:
    image: sigp/lighthouse:latest
    command: >
      lighthouse bn
      --network sepolia
      --checkpoint-sync-url https://sepolia.checkpoint-sync.ethpandaops.io
      --http
      --http-address 0.0.0.0
      --http-port ${BEACON_PORT}
    volumes:
      - ./lighthouse-data:/root/.lighthouse
    ports:
      - "${BEACON_PORT}:${BEACON_PORT}"
    restart: unless-stopped
EOF

  docker compose up -d
  echo -e "\n\e[1;32mBeacon нода установлена и запущена!\e[0m"
}

function show_menu() {
  echo -e "\n\e[1;34m========== Меню ==========\e[0m"
  echo -e "\e[1;36m1.\e[0m Установить и запустить RPC-ноду"
  echo -e "\e[1;36m2.\e[0m Установить и запустить Beacon-ноду"
  echo -e "\e[1;36m3.\e[0m Остановить все"
  echo -e "\e[1;36m4.\e[0m Перезапустить все"
  echo -e "\e[1;36m5.\e[0m Показать RPC-адрес"
  echo -e "\e[1;36m6.\e[0m Выйти"
  echo -e "\e[1;34m===========================\e[0m"
}

function stop_node() {
  cd ~/eth-rpc && docker compose stop
  cd ~/beacon && docker compose stop
  echo -e "\e[1;33mНоды остановлены\e[0m"
}

function restart_node() {
  cd ~/eth-rpc && docker compose restart
  cd ~/beacon && docker compose restart
  echo -e "\e[1;33mНоды перезапущены\e[0m"
}

function show_rpc() {
  IP=$(curl -s ifconfig.me)
  echo -e "\n\e[1;32mRPC адрес: http://${IP}:${RPC_PORT}\e[0m"
  echo -e "\e[1;32mBEACON RPC: http://${IP}:${BEACON_PORT}\e[0m"
}

while true; do
  show_menu
  read -rp $'\nВыберите пункт (1-6): ' choice

  case "$choice" in
    1) install_node ;;
    2) install_beacon ;;
    3) stop_node ;;
    4) restart_node ;;
    5) show_rpc ;;
    6) echo -e "\e[1;34mВыход...\e[0m"; exit 0 ;;
    *) echo -e "\e[1;31mНеверный ввод. Попробуйте снова.\e[0m" ;;
  esac
done
