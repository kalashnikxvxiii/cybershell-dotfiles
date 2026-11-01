#!/bin/sh
# hud-snapshot -- one sample of what the HUD shows. Read-only.
head -1 /proc/stat
awk '/^MemTotal:/{t=$2}/^MemAvailable:/{a=$2}END{print "MEM",t-a,t}' /proc/meminfo
echo "DISK $(df -B1 --output=used,size / | tail -1)"
i=$(awk '$2=="00000000"{print $1;exit}' /proc/net/route)
echo "NET ${i:-none} $(awk -v k="$i:" '$1==k{print $2,$10}' /proc/net/dev)"
echo "GPU $(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ,)"
