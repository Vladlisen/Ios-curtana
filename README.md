# Ios-curtana: Android + iOS dual boot on the Redmi Note 9S

Android and the [UniXNU](https://github.com/qdizax-w/UniXNU-miatoll) iOS port on one phone,
switched with the hardware buttons. No PC is needed after the one-time setup.

| You do | Phone starts |
| --- | --- |
| Normal power on / reboot | Android (unchanged, `boot` partition) |
| Power off, then hold **Power + Volume Up** | `recovery` partition → Mu-Silicium UEFI → UniXNU menu → iOS |

Android, its data and the `boot` partition are never touched. Only `recovery` is replaced, and
the stock recovery is backed up first and can be restored from the phone.

> [!WARNING]
> The iOS port (iPadOS 17.7.11 via UniXNU) **does not boot to a usable system yet**. Its own
> status is "builds, not yet booted": no touch, storage, Wi-Fi, cellular or GPU acceleration.
> This dual boot is how you will test new builds without a PC. It does not make iOS work today.

## One-time requirements

- Unlocked bootloader. Mi Unlock is the only step that needs a PC, and only once.
- Root through Magisk, and a terminal app such as Termux.
- A miatoll phone: curtana (Redmi Note 9S, the tested target), joyeuse, excalibur or gram.
- Custom recovery (TWRP/OrangeFox) is replaced. Use `restore` before flashing ROM zips.

## Build the image

1. In this repository: **Settings → Secrets → Actions**, add `UNIXNU_UNIQUE_CHIP_ID`
   (8 hex digits, your phone's platform seed, see UniXNU-miatoll).
2. **Actions → dualboot → Run workflow**.
3. Download the `ios-dualboot` artifact on the phone and unzip it to `/sdcard/Download/`.
   Then delete the workflow run, because the image is tied to your phone.

## Install (on the phone)

```sh
su -c sh /sdcard/Download/ios-dualboot.sh install /sdcard/Download/ios-boot.img
```

The script checks the phone model, that the file is a boot image and fits in `recovery`. It
backs up the stock recovery to `/sdcard/ios-dualboot/recovery-stock.img` (only the first time),
writes the image and verifies it by checksum.

Copy `/sdcard/ios-dualboot/` somewhere safe as well. A factory reset wipes `/sdcard`.

## Switch

- **To iOS:** power off, hold Power + Volume Up until the screen lights up.
- **To Android:** hold Power about 10 seconds to force a restart, then let it boot normally.

Use the buttons rather than `adb reboot recovery` or *Reboot → Recovery*. Android may then write
a "boot recovery" request that keeps sending every restart back to iOS until it is cleared.

## Update or remove

```sh
su -c sh /sdcard/Download/ios-dualboot.sh install /sdcard/Download/ios-boot.img   # newer build
su -c sh /sdcard/Download/ios-dualboot.sh restore                                  # stock recovery back
su -c sh /sdcard/Download/ios-dualboot.sh status
```

## Development

`make test` runs the installer against file-backed fake partitions. CI runs it with shellcheck.
