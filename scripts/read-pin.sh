#!/usr/bin/env bash
# Extracts the pinned contrails==X.Y.Z version from requirements.txt. Shared by
# check-template.yml and tag-pin.yml so the pin format only needs updating in
# one place if it ever changes shape.
set -euo pipefail

PIN=$(grep -oE '^contrails==[0-9][0-9.]*' requirements.txt | head -1 | cut -d= -f3)
if [ -z "$PIN" ]; then
  echo "No contrails pin found in requirements.txt. Has the file changed shape?" >&2
  exit 1
fi
echo "$PIN"
