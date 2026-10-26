#!/bin/bash
# Fixes for Linux on the ASUS Zenbook Pro 16X OLED (UX7602ZM).
# Written for Fedora Workstation 44; Debian/Ubuntu, Arch and openSUSE also work.
#
#   sudo bash install.sh           everything (DKMS module + userspace fixes)
#   sudo bash install.sh --no-dkms userspace fixes only (no kernel module)
#   sudo bash install.sh --softvol also install the WirePlumber software-volume
#                                  fallback (only if the hda_model fix fails)
#   sudo KVER=<version> bash install.sh   build the module for another installed kernel
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
DKMS_NAME=asus-ux7602
DKMS_VER=1.0
WITH_DKMS=1
WITH_SOFTVOL=0
for a in "$@"; do
    case $a in
        --no-dkms) WITH_DKMS=0 ;;
        --softvol) WITH_SOFTVOL=1 ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "unknown option $a"; exit 1 ;;
    esac
done

[ "$(id -u)" = 0 ] || { echo "run as root: sudo $0 $*"; exit 1; }

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!!  %s\033[0m\n' "$*"; }

board=$(cat /sys/class/dmi/id/board_name 2>/dev/null || true)
if [ "$board" != "UX7602ZM" ]; then
    warn "board is '$board', not UX7602ZM - some fixes are model specific."
    read -r -p "continue anyway? [y/N] " ans
    [ "${ans:-n}" = y ] || exit 1
fi

KVER=${KVER:-$(uname -r)}
if command -v dnf >/dev/null; then PM=dnf
elif command -v apt-get >/dev/null; then PM=apt
elif command -v pacman >/dev/null; then PM=pacman
elif command -v zypper >/dev/null; then PM=zypper
else PM=none; fi

install_pkgs() {
    case $PM in
        dnf) dnf install -y "$@" ;;
        apt) DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
        pacman) pacman -S --needed --noconfirm "$@" ;;
        zypper) zypper --non-interactive install "$@" ;;
        *) warn "unknown package manager, install manually: $*"; return 1 ;;
    esac
}

secure_boot_on() {
    command -v mokutil >/dev/null && mokutil --sb-state 2>/dev/null | grep -qi 'enabled'
}

say "Installing packages ($PM)"
case $PM in
    # cirrus-audio-firmware carries the CS35L41 tuning for 10431f62,
    # alsa-sof-firmware the DSP firmware the internal microphones need
    dnf) install_pkgs python3 v4l-utils alsa-utils libnotify mokutil cirrus-audio-firmware alsa-sof-firmware ;;
    apt) install_pkgs python3 v4l-utils alsa-utils libnotify-bin mokutil firmware-sof-signed ;;
    pacman) install_pkgs python v4l-utils alsa-utils libnotify sof-firmware ;;
    zypper) install_pkgs python3 v4l-utils alsa-utils libnotify-tools mokutil sof-firmware ;;
esac || warn "some packages could not be installed"

if [ "$WITH_DKMS" = 1 ]; then
    say "Building the asus_ux7602 kernel module (DKMS) for $KVER"
    case $PM in
        dnf) install_pkgs dkms gcc make "kernel-devel-$KVER" || true ;;
        apt) install_pkgs dkms build-essential "linux-headers-$KVER" || true ;;
        pacman)
            kpkg=$(pacman -Qoq "/usr/lib/modules/$KVER/vmlinuz" 2>/dev/null || echo linux)
            install_pkgs dkms base-devel "${kpkg}-headers" || true ;;
        zypper) install_pkgs dkms gcc make kernel-default-devel || true ;;
    esac
    if [ ! -e "/lib/modules/$KVER/build/Makefile" ]; then
        warn "kernel headers for the running kernel $KVER are not installed."
        [ "$PM" = dnf ] && echo "    The repositories only carry headers for the newest kernel:" \
            && echo "    sudo dnf upgrade --refresh && sudo reboot, then run sudo bash install.sh again."
        exit 1
    fi

    # With an RPM Fusion NVIDIA driver installed, akmods already has an
    # enrolled MOK key: sign with it too, so there is only one key to enroll.
    if [ -r /etc/pki/akmods/private/private_key.priv ] && [ -r /etc/pki/akmods/certs/public_key.der ]; then
        install -d /etc/dkms/framework.conf.d
        cat >/etc/dkms/framework.conf.d/zenbook-ux7602-akmods-key.conf <<'EOF'
mok_signing_key=/etc/pki/akmods/private/private_key.priv
mok_certificate=/etc/pki/akmods/certs/public_key.der
EOF
        echo "signing with the akmods key"
    fi

    if dkms status -m "$DKMS_NAME" -v "$DKMS_VER" 2>/dev/null | grep -q .; then
        dkms remove -m "$DKMS_NAME" -v "$DKMS_VER" --all || true
    fi
    rm -rf "/usr/src/$DKMS_NAME-$DKMS_VER"
    mkdir -p "/usr/src/$DKMS_NAME-$DKMS_VER"
    cp "$HERE"/kernel/dkms/{asus_ux7602.c,Makefile,dkms.conf} "/usr/src/$DKMS_NAME-$DKMS_VER/"
    dkms add -m "$DKMS_NAME" -v "$DKMS_VER"
    dkms build -m "$DKMS_NAME" -v "$DKMS_VER" -k "$KVER"
    dkms install -m "$DKMS_NAME" -v "$DKMS_VER" -k "$KVER"
    install -m 644 "$HERE/config/modprobe.d/asus-ux7602.conf" /etc/modprobe.d/asus-ux7602.conf

    if secure_boot_on; then
        cert=/var/lib/dkms/mok.pub
        [ -f /etc/dkms/framework.conf.d/zenbook-ux7602-akmods-key.conf ] && cert=/etc/pki/akmods/certs/public_key.der
        if mokutil --test-key "$cert" 2>/dev/null | grep -q 'already enrolled'; then
            echo "Secure Boot: the signing key $cert is already enrolled"
        else
            warn "Secure Boot is on and the module signing key is not enrolled yet."
            echo "    mokutil asks for a one-time password; after the reboot choose"
            echo "    'Enroll MOK' -> 'Continue' -> 'Yes' in the blue MOK manager and type it."
            read -r -p "enroll $cert now? [Y/n] " ans
            if [ "${ans:-y}" != n ]; then
                mokutil --import "$cert" || warn "mokutil --import failed"
            else
                echo "    later: sudo mokutil --import $cert"
            fi
        fi
    fi
    if modprobe asus_ux7602; then
        echo "module loaded"
    else
        warn "module not loaded yet - after enrolling the key it loads at the next boot"
    fi
fi

say "Speakers: route the bass pair to the volume-controlled DAC"
install -m 644 "$HERE/config/modprobe.d/asus-ux7602-audio.conf" /etc/modprobe.d/asus-ux7602-audio.conf

say "Installing tools and services"
install -m 755 "$HERE"/tools/{zb-touchpad,zb-kbd,zb-camera,zb-dial} /usr/local/sbin/
install -m 755 "$HERE/tools/zb-notify" /usr/local/bin/
install -m 644 "$HERE/config/udev/70-zenbook-ux7602.rules" /etc/udev/rules.d/
install -m 644 "$HERE"/config/systemd/{zb-touchpad-haptic,zb-kbd-restore,zb-resume,zb-dial}.service /etc/systemd/system/
install -d /etc/systemd/user
install -m 644 "$HERE/config/systemd/zb-notify.service" /etc/systemd/user/
command -v restorecon >/dev/null && restorecon -R /usr/local/sbin /usr/local/bin /etc/udev/rules.d \
    /etc/systemd/system /etc/systemd/user /etc/modprobe.d 2>/dev/null || true
systemctl daemon-reload
systemctl enable zb-resume.service
if [ "$WITH_DKMS" = 0 ]; then
    systemctl enable --now zb-dial.service
fi
systemctl --global enable zb-notify.service || true
udevadm control --reload || true
udevadm trigger --subsystem-match=hidraw --action=add || true
/usr/local/sbin/zb-touchpad restore || warn "touchpad haptics not applied (touchpad not found?)"

if command -v wireplumber >/dev/null; then
    say "PipeWire/WirePlumber rules"
    wpver=$(wireplumber --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+' | head -1 || echo 0.5)
    if [ "${wpver%%.*}" = 0 ] && [ "${wpver#*.}" -lt 5 ]; then
        warn "WirePlumber $wpver uses Lua config; the .conf rules need 0.5+, skipped"
    else
        install -d /etc/wireplumber/wireplumber.conf.d
        install -m 644 "$HERE/config/wireplumber/52-zenbook-ux7602-hide-ir-camera.conf" /etc/wireplumber/wireplumber.conf.d/
        if [ "$WITH_SOFTVOL" = 1 ]; then
            install -m 644 "$HERE/config/wireplumber/51-zenbook-ux7602-softvol.conf" /etc/wireplumber/wireplumber.conf.d/
        fi
    fi
fi

say "Done. Reboot now - the speaker fix and the module options apply at boot."
cat <<'EOF'
After the reboot check:
  speakers   volume slider changes the bass too   (cat /sys/module/snd_sof_intel_hda_generic/parameters/hda_model)
  touchpad   physical click works                 sudo zb-touchpad set 25|50|75|100
  keyboard   Fn+F7 cycles the backlight           sudo zb-kbd color 00aaff / sudo zb-kbd effect rainbow 2
  camera     Fn+F10 toggles it (F10 LED = off)    zb-camera status
  ASUS Dial  turn = volume, hold+turn = brightness, click = mute
             echo scroll | sudo tee /sys/devices/platform/asus_ux7602/dial_mode
If something does not work: sudo bash diag/zb-diag.sh --hotkeys
EOF
