#!/bin/sh
# Exercises scripts/ios-dualboot.sh against file-backed fake partitions.
set -eu
SCRIPT=$(cd "$(dirname "$0")/.." && pwd)/scripts/ios-dualboot.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export IOSDB_DIR="$T/store" IOSDB_PART="$T/recovery"
fail() { echo "FAIL: $*"; exit 1; }
run() { sh "$SCRIPT" "$@"; }

# Fake getprop: crDroid's unified build reports ro.product.device=miatoll.
mkdir "$T/bin"
# shellcheck disable=SC2016
printf '#!/bin/sh\ncase "$1" in ro.product.device) echo "${FAKE_DEVICE:-miatoll}" ;; esac\n' > "$T/bin/getprop"
chmod +x "$T/bin/getprop"
PATH="$T/bin:$PATH"
FAKE_DEVICE=lavender sh "$SCRIPT" status >/dev/null 2>&1 && fail "accepted a non miatoll phone"

# Stock recovery: 8 MiB of recognisable data.
{ printf 'ANDROID!'; head -c 8388600 /dev/urandom; } > "$IOSDB_PART"
cp "$IOSDB_PART" "$T/stock"
{ printf 'ANDROID!'; head -c 3000000 /dev/urandom; } > "$T/ios.img"

head -c 100 /dev/urandom > "$T/bad.img"
run install "$T/bad.img" 2>/dev/null && fail "accepted a non boot image"
{ printf 'ANDROID!'; head -c 9000000 /dev/urandom; } > "$T/big.img"
run install "$T/big.img" 2>/dev/null && fail "accepted an oversized image"
cmp -s "$IOSDB_PART" "$T/stock" || fail "rejected install changed the partition"

run install "$T/ios.img" >/dev/null
cmp -s "$IOSDB_DIR/recovery-stock.img" "$T/stock" || fail "backup differs from stock"
cmp -s -n 3000008 "$IOSDB_PART" "$T/ios.img" || fail "image not written"
run status | grep -q "UniXNU (iOS)" || fail "status does not report UniXNU"

# Reinstall must keep the original stock backup.
run install "$T/ios.img" >/dev/null
cmp -s "$IOSDB_DIR/recovery-stock.img" "$T/stock" || fail "reinstall overwrote the backup"

run restore >/dev/null
cmp -s "$IOSDB_PART" "$T/stock" || fail "restore did not bring back stock"
run status | grep -q "not UniXNU" || fail "status after restore"

# A corrupted backup is never written back.
run install "$T/ios.img" >/dev/null
printf 'x' | dd of="$IOSDB_DIR/recovery-stock.img" bs=1 seek=100 conv=notrunc 2>/dev/null
run restore 2>/dev/null && fail "restored a corrupted backup"
echo "all tests passed"
