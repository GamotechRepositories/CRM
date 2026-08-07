#!/usr/bin/env bash
set -euo pipefail
URL="https://github.com/gradle/gradle-distributions/releases/download/v9.4.1/gradle-9.4.1-bin.zip"
HASH=$(python3 - <<'PY'
import hashlib
url="https://github.com/gradle/gradle-distributions/releases/download/v9.4.1/gradle-9.4.1-bin.zip"
n=int.from_bytes(hashlib.md5(url.encode()).digest(),"big")
a="0123456789abcdefghijklmnopqrstuvwxyz"
out=[]
while n:
    n,r=divmod(n,36); out.append(a[r])
print("".join(reversed(out)))
PY
)
DEST="${GRADLE_USER_HOME:-$HOME/.gradle}/wrapper/dists/gradle-9.4.1-bin/$HASH"
mkdir -p "$DEST"
ZIP="$DEST/gradle-9.4.1-bin.zip"
if [[ ! -f "$DEST/gradle-9.4.1-bin.zip.ok" ]]; then
  echo "Downloading Gradle 9.4.1 via curl..."
  curl -L --connect-timeout 30 --max-time 600 -o "$ZIP" "$URL"
  rm -rf "$DEST/gradle-9.4.1"
  (cd "$DEST" && unzip -qo gradle-9.4.1-bin.zip)
  touch "$DEST/gradle-9.4.1-bin.zip.ok"
  rm -f "$DEST"/*.lck "$DEST"/*.part
  echo "Gradle ready at $DEST"
else
  echo "Gradle already cached at $DEST"
fi
