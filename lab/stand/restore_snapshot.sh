#!/bin/bash
# restore_snapshot.sh — откат лабораторной ВМ на снимок vuln-verified.
# Дисциплина: каждый опыт начинается с чистого уязвимого состояния.
# Использование: ./restore_snapshot.sh <имя-ВМ> [<алиас-ssh>]
set -eu
VM="${1:?укажите имя ВМ, например cf-ubuntu}"
HOST="${2:-cf-lab}"

VBOXMANAGE="VBoxManage"   # при необходимости укажите полный путь

echo "[1/4] выключение ВМ"
"$VBOXMANAGE" controlvm "$VM" poweroff 2>/dev/null || true
sleep 8

echo "[2/4] откат на снимок vuln-verified"
"$VBOXMANAGE" snapshot "$VM" restore vuln-verified

echo "[3/4] старт"
"$VBOXMANAGE" startvm "$VM" --type headless

echo "[4/4] ожидание SSH"
for i in $(seq 1 30); do
  sleep 6
  if ssh -o BatchMode=yes -o ConnectTimeout=4 "$HOST" true 2>/dev/null; then
    echo "      готово (${i}x6 c)"
    exit 0
  fi
done
echo "ОШИБКА: SSH не поднялся" >&2
exit 1
