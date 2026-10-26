#!/bin/bash
# Collect everything needed to debug Linux on the ASUS Zenbook UX7602ZM.
# Read-only, except for the optional --hotkeys capture which only listens.
#
#   sudo ./zb-diag.sh             -> /tmp/zb-diag-<date>.tar.gz
#   sudo ./zb-diag.sh --hotkeys   also records Fn keys for 30 seconds
#   sudo ./zb-diag.sh --acpidump  also dumps the ACPI tables
set -u

[ "$(id -u)" = 0 ] || { echo "run as root: sudo $0 $*"; exit 1; }

OUT=/tmp/zb-diag-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"
HOTKEYS=0 ACPIDUMP=0
for a in "$@"; do
    case $a in
        --hotkeys) HOTKEYS=1 ;;
        --acpidump) ACPIDUMP=1 ;;
    esac
done

run() {  # run <file> <command...>
    local f=$1; shift
    { echo "\$ $*"; "$@" 2>&1; echo; } >>"$OUT/$f"
}
have() { command -v "$1" >/dev/null 2>&1; }

echo "collecting into $OUT ..."

# system
run system.txt uname -a
run system.txt cat /etc/os-release
run system.txt cat /proc/cmdline
for k in sys_vendor product_name product_version board_name bios_version bios_date; do
    run system.txt cat /sys/class/dmi/id/$k
done
run system.txt cat /sys/kernel/security/lockdown
have mokutil && run system.txt mokutil --sb-state
run system.txt cat /sys/power/mem_sleep
dmesg >"$OUT/dmesg.txt" 2>&1
have journalctl && journalctl -b -p warning --no-pager >"$OUT/journal-warnings.txt" 2>&1
run modules.txt lsmod
have lspci && run pci.txt lspci -nnk
have lsusb && { run usb.txt lsusb; run usb.txt lsusb -t; run usb.txt lsusb -v -d 0b05:8854; run usb.txt lsusb -v -d 13d3:5280; }

# HID devices, drivers and report descriptors
for d in /sys/bus/hid/devices/*; do
    id=$(basename "$d")
    {
        echo "== $id"
        echo "driver: $(basename "$(readlink -f "$d/driver")" 2>/dev/null)"
        echo "path:   $(readlink -f "$d")"
        echo "hidraw: $(ls "$d/hidraw" 2>/dev/null)"
        if [ -r "$d/report_descriptor" ]; then
            od -An -tx1 -v "$d/report_descriptor"
        fi
        echo
    } >>"$OUT/hid.txt"
done
run input.txt cat /proc/bus/input/devices
have libinput && run input.txt libinput list-devices

# audio
run audio.txt cat /proc/asound/cards
for c in /proc/asound/card*/codec#*; do [ -e "$c" ] && run audio-codecs.txt cat "$c"; done
for h in /sys/class/sound/hwC*D*; do
    [ -d "$h" ] || continue
    for f in vendor_name chip_name modelname init_pin_configs driver_pin_configs user_pin_configs; do
        [ -r "$h/$f" ] && run audio.txt cat "$h/$f"
    done
done
for p in /sys/module/snd_sof_intel_hda_generic/parameters/hda_model \
         /sys/module/snd_sof_intel_hda_common/parameters/hda_model \
         /sys/module/snd_hda_intel/parameters/model \
         /sys/module/snd_intel_dspcfg/parameters/dsp_driver; do
    [ -r "$p" ] && run audio.txt cat "$p"
done
run audio.txt sh -c 'ls -la /lib/firmware/cirrus/ | grep -i 10431f62'
run audio.txt sh -c 'ls /lib/firmware/intel/sof* /lib/firmware/intel/sof-ipc4* -d 2>/dev/null'
grep -i -E 'cs35l41|sof|snd_hda|hda.?codec|alc285|skl_hda' "$OUT/dmesg.txt" >"$OUT/audio-dmesg.txt"
have aplay && run audio.txt aplay -l
have amixer && for card in $(awk '/^ *[0-9]+ \[/{print $1}' /proc/asound/cards); do run audio-mixer.txt amixer -c "$card" contents; done
if have wpctl; then
    u=$(loginctl list-users --no-legend 2>/dev/null | awk 'NR==1{print $2}')
    [ -n "$u" ] && run audio.txt sudo -u "$u" XDG_RUNTIME_DIR="/run/user/$(id -u "$u")" wpctl status
fi

# camera
have v4l2-ctl && {
    run camera.txt v4l2-ctl --list-devices
    for v in /dev/video*; do
        run camera.txt v4l2-ctl -d "$v" --info --list-ctrls
    done
}

# ASUS WMI and our module
for f in /sys/devices/platform/asus-nb-wmi/*; do
    [ -f "$f" ] && [ -r "$f" ] && echo "$(basename "$f"): $(timeout 2 cat "$f" 2>&1 | head -c 200)"
done >"$OUT/asus-wmi.txt"
run asus-wmi.txt cat /sys/firmware/acpi/platform_profile_choices
run asus-wmi.txt cat /sys/firmware/acpi/platform_profile
run asus-wmi.txt sh -c 'grep -H . /sys/class/power_supply/BAT*/charge_control_* 2>&1'
run asus-wmi.txt sh -c 'ls /sys/class/leds/'
if [ -d /sys/kernel/debug/asus-nb-wmi ]; then
    for id in 0x00050021 0x00060078 0x00060079 0x00040017 0x00100023 0x00110019 0x00120057; do
        { echo "$id" >/sys/kernel/debug/asus-nb-wmi/dev_id && cat /sys/kernel/debug/asus-nb-wmi/dsts; } >>"$OUT/asus-wmi.txt" 2>&1
    done
fi
run module.txt sh -c 'lsmod | grep -E "asus|hid"'
run module.txt sh -c 'grep -H . /sys/devices/platform/asus_ux7602/* 2>&1'
run module.txt sh -c 'dkms status 2>&1'

# display / GPU / power
run display.txt sh -c 'for b in /sys/class/backlight/*; do echo $b: type=$(cat $b/type) max=$(cat $b/max_brightness) cur=$(cat $b/brightness); done'
run display.txt sh -c 'grep -H . /sys/module/i915/parameters/enable_psr /sys/module/i915/parameters/enable_dpcd_backlight /sys/module/xe/parameters/enable_psr 2>&1'
run display.txt sh -c 'cat /sys/kernel/debug/dri/*/i915_edp_psr_status 2>&1 | head -40'
have nvidia-smi && run display.txt nvidia-smi -L
run display.txt sh -c 'cat /proc/driver/nvidia/version 2>&1'
have powerprofilesctl && run display.txt powerprofilesctl
run pinctrl.txt sh -c 'cat /sys/kernel/debug/pinctrl/*/pins 2>&1 | head -400'

if [ "$ACPIDUMP" = 1 ] && have acpidump; then
    acpidump >"$OUT/acpi.dat" 2>&1
fi

if [ "$HOTKEYS" = 1 ]; then
    echo
    echo ">>> For 30 seconds press: Fn+F1 ... Fn+F12, Fn+Esc, Fn+F10 twice,"
    echo ">>> rotate and press the ASUS Dial, tap and click the touchpad."
    python3 -I - "$OUT/hotkeys.txt" <<'PY'
import glob, os, select, struct, sys, time
out = open(sys.argv[1], "w")
names = {}
fds = {}
for ev in glob.glob("/dev/input/event*"):
    try:
        fd = os.open(ev, os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        continue
    base = os.path.basename(ev)
    try:
        names[fd] = open(f"/sys/class/input/{base}/device/name").read().strip()
    except OSError:
        names[fd] = base
    fds[fd] = "evdev"
for dev in glob.glob("/sys/bus/hid/devices/0003:0B05:8854.*") + glob.glob("/sys/bus/hid/devices/0018:0B05:0220.*"):
    for node in glob.glob(dev + "/hidraw/hidraw*"):
        try:
            fd = os.open("/dev/" + os.path.basename(node), os.O_RDONLY | os.O_NONBLOCK)
        except OSError:
            continue
        names[fd] = "hidraw " + os.path.basename(dev) + " " + os.path.realpath(dev).split("/")[-2]
        fds[fd] = "hidraw"
end = time.time() + 30
while time.time() < end:
    r, _, _ = select.select(list(fds), [], [], 0.5)
    for fd in r:
        try:
            data = os.read(fd, 4096)
        except OSError:
            continue
        stamp = time.strftime("%H:%M:%S")
        if fds[fd] == "hidraw":
            print(stamp, names[fd], data.hex(" "), file=out, flush=True)
            continue
        for i in range(0, len(data) - 23, 24):
            _, _, t, c, v = struct.unpack_from("llHHi", data, i)
            if t in (1, 2, 5):  # EV_KEY, EV_REL, EV_SW
                print(stamp, names[fd], f"type={t} code={c} value={v}", file=out, flush=True)
PY
    echo "hotkey capture saved"
fi

tar -C /tmp -czf "$OUT.tar.gz" "$(basename "$OUT")"
echo
echo "done: $OUT.tar.gz"
