#!/bin/bash
# Remove everything install.sh put on the system.
set -u
[ "$(id -u)" = 0 ] || { echo "run as root: sudo $0"; exit 1; }

systemctl disable --now zb-dial.service zb-resume.service 2>/dev/null
systemctl --global disable zb-notify.service 2>/dev/null
rm -f /etc/systemd/system/{zb-touchpad-haptic,zb-kbd-restore,zb-resume,zb-dial}.service \
      /etc/systemd/user/zb-notify.service \
      /etc/udev/rules.d/70-zenbook-ux7602.rules \
      /etc/modprobe.d/asus-ux7602.conf /etc/modprobe.d/asus-ux7602-audio.conf \
      /etc/wireplumber/wireplumber.conf.d/5{1,2}-zenbook-ux7602-*.conf \
      /usr/local/sbin/{zb-touchpad,zb-kbd,zb-camera,zb-dial} /usr/local/bin/zb-notify
systemctl daemon-reload
udevadm control --reload

# not "modprobe -r": it would also unload the asus-nb-wmi softdep, which oopses
# on 7.x kernels without kernel/patches/0004
rmmod asus_ux7602 2>/dev/null
if command -v dkms >/dev/null; then
    dkms remove -m asus-ux7602 -v 1.0 --all 2>/dev/null
fi
rm -rf /usr/src/asus-ux7602-1.0 /var/lib/zenbook-ux7602
echo "removed; reboot to return the audio driver to its default quirk"
