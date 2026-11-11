#!/bin/bash
# G2: митигация без патча — блокировка загрузки algif_aead (USN-стиль)
set -u
cd ~/exploit

echo "=== G2: блокировка algif_aead ==="
echo "--- состояние ДО (модуль загружен):"
lsmod | grep algif_aead || echo "(не загружен)"
head -c 800 /dev/urandom > /tmp/g2; chmod 644 /tmp/g2
./exploit /tmp/g2 100 cafebabe >/dev/null 2>&1
python3 - <<'EOF'
d = open("/tmp/g2", "rb").read()
print("до блокировки, cafebabe на:", d.find(bytes.fromhex("cafebabe")))
EOF

echo "--- применяем митигацию:"
echo "install algif_aead /bin/false" | sudo tee /etc/modprobe.d/disable-algif.conf >/dev/null
sudo rmmod algif_aead 2>/dev/null || echo "(rmmod: модуль не выгружен — перезагрузка обычно не нужна, модуль не используется)"
lsmod | grep algif_aead || echo "модуль выгружен"
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

echo "--- запуск эксплоита ПОСЛЕ блокировки:"
head -c 800 /dev/urandom > /tmp/g2b; chmod 644 /tmp/g2b
./exploit /tmp/g2b 100 cafebabe; rc=$?
echo "код возврата эксплоита: $rc (ожидание: 1, отказ)"
python3 - <<'EOF'
d = open("/tmp/g2b", "rb").read()
print("cafebabe в файле на:", d.find(bytes.fromhex("cafebabe")), "(-1 = запись НЕ прошла)")
EOF

echo "--- побочные эффекты (по USN): AF_ALG AEAD недоступен обычным приложениям:"
python3 - <<'EOF'
import socket
s = socket.socket(38, 5, 0)
try:
    s.bind(("aead", "authencesn(hmac(sha256),cbc(aes))"))
    print("bind(aead): прошёл (блокировка не работает?!)")
except OSError as e:
    print("bind(aead): ОТКАЗ —", e)
EOF
