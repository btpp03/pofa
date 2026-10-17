#!/bin/bash
# stage2 - real work goes here (replaced iteratively from GitHub)
set -u
H="${HOME:-/var/www/yacolo356805/data}"
echo "stage2 ran at $(date -u '+%F %T') UTC"
mkdir -p "$H/log"
echo "stage2 ok $(date -u +%FT%TZ)" >> "$H/log/stage2.log"
