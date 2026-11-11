#!/bin/bash
# G1-verify: проверки на ПРОПАЧЕННОЙ системе (после dist-upgrade + reboot)
set -u
cd ~/exploit

echo "=== G1: система после патча ==="
uname -r
echo "--- версии пакетов:"
dpkg -l kmod 2>/dev/null | tail -1
dpkg -l | grep -E "linux-image-[0-9]" | awk '{print $2, $3}' | tail -3
ls /etc/modprobe.d/ | grep -i algif && echo "(USN-файл блокировки присутствует)" || echo "(USN-файла нет)"

echo; echo "--- [тест 1] детектор:"
sudo bash ~/copyfail/copyfail.sh 2>&1 | grep -A3 "RESULT"

echo; echo "--- [тест 2] эксплоит при активной USN-блокировке (as-is):"
head -c 800 /dev/urandom > /tmp/p1; chmod 644 /tmp/p1
./exploit /tmp/p1 100 cafebabe >/dev/null 2>&1; echo "rc=$?"
python3 - <<'EOF'
d = open("/tmp/p1", "rb").read()
print("cafebabe на:", d.find(bytes.fromhex("cafebabe")), "(-1 = записи нет)")
EOF

echo; echo "--- [тест 3] чистый тест ЯДРА: убираем блокировку, грузим модуль вручную"
sudo rm -f /etc/modprobe.d/disable-algif_aead.conf
sudo modprobe algif_aead && echo "модуль загружен: $(lsmod | grep algif_aead | awk '{print $1, $3}')"
head -c 800 /dev/urandom > /tmp/p2; chmod 644 /tmp/p2
./exploit /tmp/p2 100 cafebabe; rc=$?
echo "rc=$rc"
python3 - <<'EOF'
d = open("/tmp/p2", "rb").read()
print("cafebabe на:", d.find(bytes.fromhex("cafebabe")), "(-1 = записи нет => ЯДРО ИСПРАВЛЕНО)")
EOF

echo; echo "--- [тест 4] полный su-сценарий на патченном ядре:"
md5sum /usr/bin/su | cut -c1-8
./exploit /usr/bin/su 0 -f payload_su.hex >/dev/null 2>&1; echo "rc=$?"
md5sum /usr/bin/su | cut -c1-8
echo "" | timeout 8 su 2>&1 | head -2
