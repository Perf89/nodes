#!/bin/bash

# Авторское меню от Perfnode

clear
echo -e "\n============================="
echo "      by Perfnode         "
echo -e "=============================\n"

INSTALL_DIR="$HOME/aztec-rpc"
JWT_SECRET="$INSTALL_DIR/jwt.hex"
GETH_PORT=8545
LIGHTHOUSE_PORT=5052

show_menu() {
  echo "========== Меню =========="
  echo "1. Установить и запустить RPC-ноду"
  echo "2. Установить и запустить Beacon-ноду"
  echo "3. Остановить все"
  echo "4. Перезапустить все"
  echo "5. Показать RPC-адрес"
  echo "6. Проверить логи"
  echo "7. Выйти"
  echo "==========================="
}

install_geth() {
  echo "[+] Установка Geth..."
  sudo apt update && sudo apt install -y curl wget unzip tar openssl

  if ! command -v geth >/dev/null; then
    curl -L -O https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-latest.tar.gz || { echo "Ошибка скачивания Geth"; exit 1; }
    tar -xvzf geth-linux-amd64-latest.tar.gz
    cd geth-linux-*/ && sudo cp geth /usr/local/bin/
    cd ~ && rm -rf geth-linux-*
  fi

  mkdir -p "$INSTALL_DIR"
  if [ ! -f "$JWT_SECRET" ]; then
    echo "$(openssl rand -hex 32)" > "$JWT_SECRET"
  fi

  echo "[+] Запуск Geth..."
  nohup geth --sepolia \
    --http --http.addr 0.0.0.0 --http.port $GETH_PORT \
    --http.api "eth,net,web3" \
    --authrpc.addr 0.0.0.0 --authrpc.port 8551 \
    --authrpc.vhosts="*" --authrpc.jwtsecret "$JWT_SECRET" \
    > "$INSTALL_DIR/geth.log" 2>&1 &
}

install_lighthouse() {
  echo "[+] Установка Lighthouse..."

  if ! command -v lighthouse >/dev/null; then
    curl -s https://raw.githubusercontent.com/sigp/lighthouse/master/ci/install.sh | bash || { echo "Ошибка установки Lighthouse"; exit 1; }
  fi

  echo "[+] Запуск Beacon-ноды..."
  nohup lighthouse bn \
    --network sepolia \
    --execution-endpoint http://127.0.0.1:8551 \
    --execution-jwt "$JWT_SECRET" \
    --http --http-address 0.0.0.0 --http-port $LIGHTHOUSE_PORT \
    > "$INSTALL_DIR/lighthouse.log" 2>&1 &
}

stop_all() {
  pkill geth
  pkill lighthouse
  echo "Все процессы остановлены."
}

restart_all() {
  stop_all
  sleep 2
  install_geth
  install_lighthouse
  echo "Все перезапущено."
}

show_rpc() {
  IPV4=$(curl -s ipv4.icanhazip.com)
  IPV6=$(curl -s ipv6.icanhazip.com)
  echo "RPC IPv4: http://$IPV4:$GETH_PORT"
  echo "RPC IPv6: http://[$IPV6]:$GETH_PORT"
  echo "BEACON RPC IPv4: http://$IPV4:$LIGHTHOUSE_PORT"
  echo "BEACON RPC IPv6: http://[$IPV6]:$LIGHTHOUSE_PORT"
}

show_logs() {
  echo "--- Последние логи Geth ---"
  tail -n 20 "$INSTALL_DIR/geth.log"
  echo -e "\n--- Последние логи Lighthouse ---"
  tail -n 20 "$INSTALL_DIR/lighthouse.log"
}

while true; do
  show_menu
  read -rp "Выберите опцию: " option
  case $option in
    1)
      install_geth
      sleep 3
      echo -e "\n[✓] Geth установлен и запущен."
      ps aux | grep geth | grep -v grep
      ;;
    2)
      install_lighthouse
      sleep 3
      echo -e "\n[✓] Lighthouse установлен и запущен."
      ps aux | grep lighthouse | grep -v grep
      ;;
    3)
      stop_all
      ;;
    4)
      restart_all
      ;;
    5)
      show_rpc
      ;;
    6)
      show_logs
      ;;
    7)
      echo "Выход..."
      exit 0
      ;;
    *)
      echo "Неверный ввод. Попробуйте снова."
      ;;
  esac
  echo -e "\nНажмите Enter для продолжения..."
  read
done

