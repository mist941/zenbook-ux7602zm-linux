# Linux fixes for ASUS Zenbook Pro 16X OLED (UX7602ZM)

| Problem | Cause | Fix |
|---|---|---|
| Volume doesn't affect bass speakers | Bass pin 0x17 is routed to DAC 0x06, which has no volume control | `hda_model=1043:1caf` (modprobe option) |
| Touchpad doesn't click | Haptic touchpad; Linux never sets its click intensity (HID report 0x09) | `zb-touchpad` |
| Camera dark, Fn+F10 does nothing | Camera privacy line is WMI device 0x00060078; nothing toggles it on Linux | `asus_ux7602` module |
| No keyboard backlight | Keyboard 0b05:8854 isn't supported by `hid-asus` | `asus_ux7602` module, `zb-kbd` |
| ASUS Dial ignored | Kernel creates no input device for it | `asus_ux7602` module |

Requires kernel ≥ 6.7 and linux-firmware ≥ 2024-01. Tested target: Fedora 44.

## Install

```bash
sudo bash install.sh        # add --no-dkms for userspace fixes only
sudo reboot
```

With Secure Boot on, enroll the DKMS MOK key when prompted.

## Diagnostics

```bash
sudo bash diag/zb-diag.sh --hotkeys
```

## Kernel patches

`kernel/patches/` (against Linux 7.3, untested on hardware, unsigned):

1. ALSA: hda/realtek: fix speaker volume on UX7602ZM
2. platform/x86: asus-wmi: toggle the webcam privacy line on UX7602ZM
3. HID: multitouch: set haptic intensity of firmware-driven haptic touchpads
4. platform/x86: asus-wmi: fix use-after-free of kbd_led on removal

Don't unload `asus_nb_wmi` on 7.x kernels without patch 4.

## Credits

[taminomara/zenbook-ux7602-linux](https://github.com/taminomara/zenbook-ux7602-linux), [Novaryu/zenauracore](https://github.com/Novaryu/zenauracore)
