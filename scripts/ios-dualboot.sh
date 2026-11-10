#!/system/bin/sh
# Android + iOS (UniXNU) dual boot for the Redmi Note 9S family (miatoll), run on the phone as root.
#
# Android keeps the boot partition. The UniXNU boot.img (Mu-Silicium UEFI + iOS payload) goes on
# the recovery partition, so the stock bootloader chooses the OS:
#   power on              -> Android
#   Power + Volume Up     -> recovery -> UEFI -> UniXNU menu -> iOS
#
# usage: su -c sh ios-dualboot.sh install <boot.img> | restore | status
set -eu

DIR=${IOSDB_DIR:-/sdcard/ios-dualboot}
BACKUP=$DIR/recovery-stock.img
MARK=$DIR/installed.sha256

die() { echo "error: $*" >&2; exit 1; }
say() { echo "* $*"; }

find_part() {
  if [ -n "${IOSDB_PART:-}" ]; then echo "$IOSDB_PART"; return; fi
  for p in /dev/block/by-name/recovery /dev/block/bootdevice/by-name/recovery; do
    [ -e "$p" ] && { echo "$p"; return; }
  done
  die "recovery partition not found"
}

part_size() {
  if [ -n "${IOSDB_PART:-}" ]; then wc -c < "$1" | tr -d ' '; return; fi
  blockdev --getsize64 "$1" 2>/dev/null && return
  real=$(readlink -f "$1")
  echo $(( $(cat "/sys/class/block/${real##*/}/size") * 512 ))
}

file_size() { wc -c < "$1" | tr -d ' '; }
sha() { sha256sum | cut -d' ' -f1; }
# Hash of the first $2 bytes of $1: the partition is larger than the image it holds.
head_sha() { head -c "$2" "$1" | sha; }

preflight() {
  if [ -z "${IOSDB_PART:-}" ]; then
    [ "$(id -u)" = 0 ] || die "run as root: su -c sh $0 $*"
    dev=$(getprop ro.product.device 2>/dev/null || true)
    case "$dev" in
      curtana|joyeuse|excalibur|gram) ;;
      *) die "this script is for miatoll phones (curtana/joyeuse/excalibur/gram), found '$dev'" ;;
    esac
  fi
  mkdir -p "$DIR"
}

is_ours() {
  [ -f "$MARK" ] || return 1
  read -r want size < "$MARK"
  [ "$(head_sha "$PART" "$size")" = "$want" ]
}

cmd_install() {
  img=${1:-}
  [ -n "$img" ] && [ -f "$img" ] || die "usage: $0 install <boot.img>"
  [ "$(head -c 8 "$img")" = "ANDROID!" ] || die "$img is not an Android boot image"
  isize=$(file_size "$img"); psize=$(part_size "$PART")
  [ "$isize" -le "$psize" ] || die "image is $isize bytes, recovery partition only $psize"

  # Never replace the stock backup with a UniXNU image on a second install.
  if [ ! -f "$BACKUP" ]; then
    is_ours && die "recovery already holds UniXNU but $BACKUP is missing; restore it manually"
    say "backing up stock recovery to $BACKUP"
    dd if="$PART" of="$BACKUP" bs=4194304 2>/dev/null
    [ "$(file_size "$BACKUP")" = "$psize" ] || die "backup is incomplete"
    sha < "$BACKUP" > "$BACKUP.sha256"
  fi

  say "writing $img to $PART"
  want=$(sha < "$img")
  dd if="$img" of="$PART" bs=4194304 conv=notrunc 2>/dev/null
  sync
  [ "$(head_sha "$PART" "$isize")" = "$want" ] || die "verification failed; run: $0 restore"
  echo "$want $isize" > "$MARK"
  say "done. Power off, then hold Power + Volume Up to start iOS. Normal power on starts Android."
}

cmd_restore() {
  [ -f "$BACKUP" ] || die "no backup at $BACKUP"
  [ "$(sha < "$BACKUP")" = "$(cat "$BACKUP.sha256")" ] || die "backup checksum mismatch, not restoring"
  say "restoring stock recovery from $BACKUP"
  dd if="$BACKUP" of="$PART" bs=4194304 conv=notrunc 2>/dev/null
  sync
  [ "$(head_sha "$PART" "$(file_size "$BACKUP")")" = "$(cat "$BACKUP.sha256")" ] || die "verification failed"
  rm -f "$MARK"
  say "stock recovery restored"
}

cmd_status() {
  echo "recovery partition: $PART ($(part_size "$PART") bytes)"
  if is_ours; then echo "recovery holds: UniXNU (iOS)"; else echo "recovery holds: not UniXNU"; fi
  if [ -f "$BACKUP" ]; then echo "stock backup: $BACKUP"; else echo "stock backup: none"; fi
}

action=${1:-status}
[ $# -gt 0 ] && shift
preflight "$action"
PART=$(find_part)
case "$action" in
  install) cmd_install "$@" ;;
  restore) cmd_restore ;;
  status)  cmd_status ;;
  *) die "usage: $0 install <boot.img> | restore | status" ;;
esac
