#!/bin/bash
# Boot a kernel tree in QEMU and exercise the fixes against emulated hardware:
#   1. asus_ux7602.ko with uhid copies of the N-KEY keyboard and the ASUS Dial,
#      plus a fake ATK WMI device (fake-atkd.asl) for the camera GPIO: with its
#      own LED, and as listener of asus-wmi with asus-nb-wmi probing late/early
#   2. asus-nb-wmi from the tree (needs patch 0002) - WMI event 0x85
#   3. hid-multitouch from the tree (needs patch 0003) - haptic intensity
#
#   KDIR=/path/to/linux ./run-qemu-tests.sh
# The tree must be built (bzImage + modules) with CONFIG_UHID, CONFIG_HIDRAW,
# CONFIG_ACPI_WMI, CONFIG_LEDS_BRIGHTNESS_HW_CHANGED and ASUS_WMI, ASUS_NB_WMI,
# HID_MULTITOUCH as modules. Needs qemu-system-x86_64, busybox (static), iasl, gcc.
set -euo pipefail

KDIR=${KDIR:?set KDIR to a built kernel tree}
HERE=$(cd "$(dirname "$0")" && pwd)
KIT=$(cd "$HERE/../.." && pwd)
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
KVER=$(make -s -C "$KDIR" kernelrelease)
R=$W/root
mkdir -p $R/{bin,dev,proc,sys,tmp} $R/lib/modules/$KVER/extra

cp -r "$KIT/kernel/dkms" "$W/dkms"
make -s -C "$KDIR" M="$W/dkms" modules
cp "$W/dkms/asus_ux7602.ko" $R/lib/modules/$KVER/extra/
for m in drivers/platform/x86/asus-wmi.ko drivers/platform/x86/asus-nb-wmi.ko drivers/hid/hid-multitouch.ko; do
    cp "$KDIR/$m" $R/lib/modules/$KVER/extra/
    for dep in $(modinfo -F depends "$KDIR/$m" | tr ',' ' '); do
        f=$(find "$KDIR" -name "$dep.ko" -o -name "${dep//-/_}.ko" | head -1)
        [ -n "$f" ] && cp "$f" $R/lib/modules/$KVER/extra/
    done
done
depmod -b $R "$KVER" 2>/dev/null

for t in uhid-test evwatch uhid-touchpad; do
    gcc -O2 -static -o $R/bin/$t "$HERE/$t.c"
done
cp "$(command -v busybox)" $R/bin/busybox
iasl -p $W/fake-atkd "$HERE/fake-atkd.asl" >/dev/null

cat >$R/init <<'EOF'
#!/bin/busybox sh
/bin/busybox --install -s /bin
mount -t proc proc /proc; mount -t sysfs sys /sys; mount -t devtmpfs dev /dev
mount -t debugfs none /sys/kernel/debug

echo "=== 1a. asus_ux7602 with its own LED (kernels before 7.0)"
modprobe asus-wmi
insmod "$(find /lib/modules -name asus_ux7602.ko)" kbd_own_led=1 && /bin/uhid-test own
rmmod asus_ux7602

echo "=== 1b. asus_ux7602 as asus-wmi listener, asus-nb-wmi probing after the keyboard"
modprobe asus_ux7602 && { /bin/uhid-test listener & sleep 0.5; modprobe asus-nb-wmi; wait; }
rmmod asus_ux7602

echo "=== 1c. asus_ux7602 as asus-wmi listener, asus-nb-wmi already loaded"
modprobe asus_ux7602 && /bin/uhid-test listener
rmmod asus_ux7602

echo "=== 2. asus-nb-wmi camera toggle (patch 0002)"
D=/sys/kernel/debug/asus-nb-wmi
dsts() { echo 0x00060078 > $D/dev_id; cat $D/dsts; }
fn_f10() { echo 0x54534554 > $D/method_id; echo 0x85 > $D/dev_id; cat $D/call >/dev/null; }
if modprobe asus-nb-wmi; then
    before=$(dsts)
    evwatch "Asus WMI hotkeys" 1500 state > /tmp/ev &
    sleep 0.3; fn_f10; sleep 1.6
    echo "before: $before / after: $(dsts)"; cat /tmp/ev
    rmmod asus-nb-wmi
fi

echo "=== 3. hid-multitouch haptic intensity (patch 0003)"
modprobe hid-multitouch && /bin/uhid-touchpad
dmesg | grep -E 'BUG:|WARNING:|Oops|Call Trace' || echo "no kernel warnings"
poweroff -f
EOF
chmod +x $R/init
(cd $R && find . | cpio -o -H newc 2>/dev/null | gzip -1 >$W/initramfs.gz)

kvm=; [ -w /dev/kvm ] && kvm=-enable-kvm
timeout 180 qemu-system-x86_64 $kvm -m 512M -nographic -no-reboot \
    -acpitable file=$W/fake-atkd.aml \
    -kernel "$KDIR/arch/x86/boot/bzImage" -initrd $W/initramfs.gz \
    -append "console=ttyS0 quiet panic=-1" \
    -smbios "type=1,manufacturer=ASUSTeK COMPUTER INC.,product=Zenbook UX7602ZM_UX7602ZM" \
    -smbios "type=2,manufacturer=ASUSTeK COMPUTER INC.,product=UX7602ZM" \
    2>&1 | tr -d '\r' | grep -v -E '^$|SeaBIOS|iPXE|Booting from|Press Ctrl'
