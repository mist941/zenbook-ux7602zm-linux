// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Platform helper for the ASUS Zenbook Pro 16X OLED (UX7602ZM).
 *
 *  - N-KEY keyboard (USB 0b05:8854): backlight levels 0-3 through
 *    "asus::kbd_backlight", keyboard colour/effects, Fn+F7, backlight off
 *    during system sleep.
 *  - Webcam privacy: Fn+F10 toggles WMI device 0x00060078. On this model it
 *    is GPIO 0x090E000F ("CLED" in the DSDT), which both lights the F10 LED
 *    and drives the camera's privacy input (0 = blocked, 1 = available).
 *    On Windows the ASUS service flips it; on Linux nothing did, so the
 *    camera stayed in whatever state the firmware left it.
 *  - ASUS Dial (I2C HID 0b05:0220): the kernel creates no input device for
 *    its "System Multi-Axis" collection, so map it here.
 *
 * Since 7.0 asus-wmi owns "asus::kbd_backlight" and hands level changes
 * (sysfs, its own Fn+F7 WMI event) to listeners such as this driver; it even
 * registers that LED by itself on the first Fn+F7 event. Older kernels get
 * the LED from this driver.
 *
 * Runtime controls live in /sys/devices/platform/asus_ux7602/.
 */

#include <linux/device.h>
#include <linux/dmi.h>
#include <linux/hid.h>
#if __has_include(<linux/hex.h>)
#include <linux/hex.h>
#endif
#include <linux/input.h>
#include <linux/jiffies.h>
#include <linux/kernel.h>
#include <linux/leds.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/platform_data/x86/asus-wmi.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/sysfs.h>
#include <linux/version.h>
#include <linux/workqueue.h>

#define DRV_NAME		"asus_ux7602"

#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 0, 0)
#define UX_ASUS_LISTENER	1
#else
#define UX_ASUS_LISTENER	0
#endif

#define USB_VENDOR_ID_ASUSTEK	0x0b05
#define PID_NKEY_KEYBOARD	0x8854
#define PID_ASUS_DIAL		0x0220

#define KBD_REPORT_ID		0x5a
#define AURA_REPORT_ID		0x5c
#define KBD_REPORT_SIZE		64
#define KBD_MAX_BRIGHTNESS	3

#define CODE_KBD_UP		0xc4
#define CODE_KBD_DOWN		0xc5
#define CODE_KBD_TOGGLE		0xc7
#define CODE_CAMERA		0x85

#define DEVID_CAMERA_GPIO	0x00060078
#define DEVID_CAMERA		0x00060013

#define DIAL_REPORT_ID		0x01

enum ux_kind { UX_KBD = 1, UX_DIAL = 2 };

enum dial_mode {
	DIAL_VOLUME,
	DIAL_BRIGHTNESS,
	DIAL_SCROLL,
	DIAL_ZOOM,
	DIAL_MEDIA,
	DIAL_RAW,
	DIAL_MODE_COUNT
};

static const char * const dial_mode_names[DIAL_MODE_COUNT] = {
	[DIAL_VOLUME]		= "volume",
	[DIAL_BRIGHTNESS]	= "brightness",
	[DIAL_SCROLL]		= "scroll",
	[DIAL_ZOOM]		= "zoom",
	[DIAL_MEDIA]		= "media",
	[DIAL_RAW]		= "raw",
};

static int kbd_brightness = 2;
module_param(kbd_brightness, int, 0444);
MODULE_PARM_DESC(kbd_brightness, "Keyboard backlight level set at probe, 0-3 (-1 = leave as is, default 2)");

static char *kbd_color;
module_param(kbd_color, charp, 0444);
MODULE_PARM_DESC(kbd_color, "Keyboard colour set at probe as RRGGBB (default: leave as is)");

static bool kbd_own_led = !UX_ASUS_LISTENER;
module_param(kbd_own_led, bool, 0444);
MODULE_PARM_DESC(kbd_own_led, "Register asus::kbd_backlight here instead of going through asus-wmi (always on before 7.0)");

static int camera_boot_state = 1;
module_param(camera_boot_state, int, 0444);
MODULE_PARM_DESC(camera_boot_state, "Webcam state at load: 1 = available (default), 0 = blocked, -1 = leave as is");

static bool camera_control = true;
module_param(camera_control, bool, 0444);
MODULE_PARM_DESC(camera_control, "Toggle the webcam privacy line on Fn+F10 (default true)");

static char *dial_mode = "volume";
module_param(dial_mode, charp, 0444);
MODULE_PARM_DESC(dial_mode, "Dial mode: volume, brightness, scroll, zoom, media, raw (default volume)");

static char *dial_pressed_mode = "brightness";
module_param(dial_pressed_mode, charp, 0444);
MODULE_PARM_DESC(dial_pressed_mode, "Mode used while the dial is held down (default brightness)");

static bool dial_press_cycles;
module_param(dial_press_cycles, bool, 0444);
MODULE_PARM_DESC(dial_press_cycles, "A short press cycles volume/brightness/scroll instead of its click action");

static int dial_step = 1;
module_param(dial_step, int, 0444);
MODULE_PARM_DESC(dial_step, "Raw dial units per step (default 1, one detent)");

static bool log_hotkeys;
module_param(log_hotkeys, bool, 0644);
MODULE_PARM_DESC(log_hotkeys, "Log every N-KEY vendor hotkey code to the kernel log");

struct ux_kbd {
	struct hid_device *hdev;
	struct mutex io_lock;
	struct work_struct key_work;
	struct work_struct resume_work;
	int pending_code;
	u8 level;
	u8 rgb[3];
	bool rgb_valid;
	bool own_led;

	/* own LED: kernels before 7.0 or kbd_own_led=1 */
	struct led_classdev led;
	bool led_registered;

#if UX_ASUS_LISTENER
	struct asus_hid_listener listener;
	struct work_struct level_work;
	struct delayed_work fallback_work;
	struct delayed_work sync_work;
	unsigned long press_time;
	unsigned long last_listener_call;
	int pressed_code;
	int fallback_code;
	int wanted_level;
	int sync_target;
	int sync_tries;
	bool listening;
#endif
};

struct ux_dial {
	struct hid_device *hdev;
	struct input_dev *keys;
	struct input_dev *wheel;
	int accum;
	bool pressed;
	bool rotated;
};

static struct {
	struct mutex lock;
	struct platform_device *pdev;
	struct input_dev *cam_input;
	struct ux_kbd *kbd;
	bool camera_supported;
	int mode;
	int pressed_mode;
} ux;

/* Keyboard ------------------------------------------------------------------ */

static int kbd_send(struct hid_device *hdev, const u8 *data, size_t len)
{
	u8 *buf;
	int ret;

	buf = kzalloc(KBD_REPORT_SIZE, GFP_KERNEL);
	if (!buf)
		return -ENOMEM;
	memcpy(buf, data, min_t(size_t, len, KBD_REPORT_SIZE));

	ret = hid_hw_raw_request(hdev, buf[0], buf, KBD_REPORT_SIZE,
				 HID_FEATURE_REPORT, HID_REQ_SET_REPORT);
	kfree(buf);
	return ret < 0 ? ret : 0;
}

static int kbd_handshake(struct hid_device *hdev)
{
	static const u8 init[] = { KBD_REPORT_ID, 'A', 'S', 'U', 'S', ' ', 'T',
				   'e', 'c', 'h', '.', 'I', 'n', 'c', '.', 0 };

	return kbd_send(hdev, init, sizeof(init));
}

static int kbd_send_level(struct ux_kbd *kbd, u8 level)
{
	const u8 cmd[] = { KBD_REPORT_ID, 0xba, 0xc5, 0xc4, level };
	int ret;

	mutex_lock(&kbd->io_lock);
	ret = kbd_send(kbd->hdev, cmd, sizeof(cmd));
	mutex_unlock(&kbd->io_lock);
	return ret;
}

/* send a level and remember it as the one to restore after resume */
static int kbd_set_level(struct ux_kbd *kbd, u8 level)
{
	int ret = kbd_send_level(kbd, level);

	if (!ret)
		kbd->level = level;
	return ret;
}

/* effect: 0 static, 1 breathing, 2 colour cycle, 3 rainbow, 5 raindrop, 0x0a strobe */
static int kbd_set_effect(struct ux_kbd *kbd, u8 effect, const u8 rgb[3], u8 speed)
{
	u8 cmd[8] = { AURA_REPORT_ID, 0xa0, 0, effect, rgb[0], rgb[1], rgb[2], speed };
	int ret;

	mutex_lock(&kbd->io_lock);
	ret = kbd_send(kbd->hdev, cmd, sizeof(cmd));
	if (!ret) {
		/* the second message applies the effect */
		cmd[1] = 0xa5;
		ret = kbd_send(kbd->hdev, cmd, sizeof(cmd));
	}
	mutex_unlock(&kbd->io_lock);
	return ret;
}

static int kbd_led_set(struct led_classdev *cdev, enum led_brightness value)
{
	struct ux_kbd *kbd = container_of(cdev, struct ux_kbd, led);

	/* keep the backlight as it is when the module goes away */
	if (cdev->flags & LED_UNREGISTERING)
		return 0;
	return kbd_set_level(kbd, min_t(int, value, KBD_MAX_BRIGHTNESS));
}

static enum led_brightness kbd_led_get(struct led_classdev *cdev)
{
	return container_of(cdev, struct ux_kbd, led)->level;
}

static void kbd_own_led_step(struct ux_kbd *kbd, int code)
{
	int level = kbd->level;

	switch (code) {
	case CODE_KBD_TOGGLE:
		level = level >= KBD_MAX_BRIGHTNESS ? 0 : level + 1;
		break;
	case CODE_KBD_UP:
		level = min(level + 1, KBD_MAX_BRIGHTNESS);
		break;
	case CODE_KBD_DOWN:
		level = max(level - 1, 0);
		break;
	}

	/*
	 * Set the level explicitly even if the firmware already stepped it on
	 * its own: the result is then the same whatever the firmware did.
	 */
	if (kbd_set_level(kbd, level) || !kbd->led_registered)
		return;
	kbd->led.brightness = level;
#if IS_ENABLED(CONFIG_LEDS_BRIGHTNESS_HW_CHANGED)
	led_classdev_notify_brightness_hw_changed(&kbd->led, level);
#endif
}

#if UX_ASUS_LISTENER
/* called by asus-wmi with a spinlock held */
static void kbd_listener_set(struct asus_hid_listener *listener, int brightness)
{
	struct ux_kbd *kbd = container_of(listener, struct ux_kbd, listener);
	int target = READ_ONCE(kbd->sync_target);

	WRITE_ONCE(kbd->last_listener_call, jiffies);
	if (target >= 0) {
		/* an intermediate step of kbd_sync_work() */
		if (brightness != target)
			return;
		WRITE_ONCE(kbd->sync_target, -1);
	}
	WRITE_ONCE(kbd->wanted_level, brightness);
	schedule_work(&kbd->level_work);
}

static void kbd_level_work(struct work_struct *work)
{
	struct ux_kbd *kbd = container_of(work, struct ux_kbd, level_work);

	kbd_set_level(kbd, clamp(READ_ONCE(kbd->wanted_level), 0, KBD_MAX_BRIGHTNESS));
}

/*
 * The EC normally reports Fn+F7 to asus-wmi too (WMI 0xc7, right after the
 * key is released) and asus-wmi steps the level. Step it from here only if
 * that did not happen since the key went down.
 */
static void kbd_fallback_work(struct work_struct *work)
{
	struct ux_kbd *kbd = container_of(to_delayed_work(work), struct ux_kbd, fallback_work);

	if (time_after_eq(READ_ONCE(kbd->last_listener_call), kbd->press_time))
		return;

	switch (READ_ONCE(kbd->fallback_code)) {
	case CODE_KBD_UP:
		asus_hid_event(ASUS_EV_BRTUP);
		break;
	case CODE_KBD_DOWN:
		asus_hid_event(ASUS_EV_BRTDOWN);
		break;
	default:
		asus_hid_event(ASUS_EV_BRTTOGGLE);
		break;
	}
}

/*
 * asus-wmi cannot read this backlight, so its level starts out unknown. Walk
 * it to ours with relative steps once it has registered its LED.
 */
static void kbd_sync_work(struct work_struct *work)
{
	struct ux_kbd *kbd = container_of(to_delayed_work(work), struct ux_kbd, sync_work);
	int i;

	WRITE_ONCE(kbd->sync_target, kbd->level);
	if (asus_hid_event(ASUS_EV_BRTDOWN)) {
		/* asus-nb-wmi not probed yet, or its LED not registered yet */
		WRITE_ONCE(kbd->sync_target, -1);
		if (++kbd->sync_tries < 50)
			schedule_delayed_work(&kbd->sync_work, msecs_to_jiffies(200));
		return;
	}
	for (i = 0; i < KBD_MAX_BRIGHTNESS; i++)
		asus_hid_event(ASUS_EV_BRTDOWN);
	for (i = 0; i < kbd->level; i++)
		asus_hid_event(ASUS_EV_BRTUP);
}
#endif

static void kbd_restore(struct ux_kbd *kbd)
{
	kbd_handshake(kbd->hdev);
	if (kbd->rgb_valid)
		kbd_set_effect(kbd, 0, kbd->rgb, 0);
	kbd_send_level(kbd, kbd->level);
}

static void kbd_resume_work(struct work_struct *work)
{
	kbd_restore(container_of(work, struct ux_kbd, resume_work));
}

static void camera_toggle(void);

static void kbd_key_work(struct work_struct *work)
{
	struct ux_kbd *kbd = container_of(work, struct ux_kbd, key_work);
	int code = READ_ONCE(kbd->pending_code);

	if (code == CODE_CAMERA)
		camera_toggle();
	else
		kbd_own_led_step(kbd, code);
}

static bool kbd_is_vendor_iface(struct hid_device *hdev)
{
	struct hid_report *rep;

	list_for_each_entry(rep, &hdev->report_enum[HID_INPUT_REPORT].report_list, list)
		if (rep->id == KBD_REPORT_ID &&
		    (rep->application & HID_USAGE_PAGE) == HID_UP_ASUSVENDOR)
			return true;
	return false;
}

static int parse_rgb(const char *s, u8 rgb[3])
{
	u8 tmp[3];

	if (!s || strlen(s) != 6 || hex2bin(tmp, s, 3))
		return -EINVAL;
	memcpy(rgb, tmp, 3);
	return 0;
}

static int kbd_probe_vendor(struct hid_device *hdev)
{
	struct ux_kbd *kbd;
	int ret;

	kbd = devm_kzalloc(&hdev->dev, sizeof(*kbd), GFP_KERNEL);
	if (!kbd)
		return -ENOMEM;

	kbd->hdev = hdev;
	kbd->own_led = kbd_own_led || !UX_ASUS_LISTENER;
	mutex_init(&kbd->io_lock);
	INIT_WORK(&kbd->key_work, kbd_key_work);
	INIT_WORK(&kbd->resume_work, kbd_resume_work);
#if UX_ASUS_LISTENER
	INIT_WORK(&kbd->level_work, kbd_level_work);
	INIT_DELAYED_WORK(&kbd->fallback_work, kbd_fallback_work);
	INIT_DELAYED_WORK(&kbd->sync_work, kbd_sync_work);
	kbd->sync_target = -1;
#endif

	ret = kbd_handshake(hdev);
	if (ret)
		hid_warn(hdev, "N-KEY handshake failed: %d\n", ret);

	if (kbd_brightness >= 0)
		kbd_set_level(kbd, min(kbd_brightness, KBD_MAX_BRIGHTNESS));

	if (kbd_color) {
		if (!parse_rgb(kbd_color, kbd->rgb) &&
		    !kbd_set_effect(kbd, 0, kbd->rgb, 0))
			kbd->rgb_valid = true;
		else
			hid_warn(hdev, "invalid kbd_color '%s'\n", kbd_color);
	}

	hid_set_drvdata(hdev, kbd);

	if (kbd->own_led) {
		kbd->led.name = "asus::kbd_backlight";
		kbd->led.max_brightness = KBD_MAX_BRIGHTNESS;
		kbd->led.brightness = kbd->level;
		kbd->led.brightness_set_blocking = kbd_led_set;
		kbd->led.brightness_get = kbd_led_get;
		kbd->led.flags = LED_BRIGHT_HW_CHANGED;
		ret = led_classdev_register(&hdev->dev, &kbd->led);
		if (ret)
			hid_warn(hdev, "cannot register keyboard backlight LED: %d\n", ret);
		else
			kbd->led_registered = true;
	}
#if UX_ASUS_LISTENER
	else {
		kbd->listener.brightness_set = kbd_listener_set;
		ret = asus_hid_register_listener(&kbd->listener);
		if (ret) {
			hid_warn(hdev, "cannot register with asus-wmi: %d\n", ret);
		} else {
			kbd->listening = true;
			schedule_delayed_work(&kbd->sync_work, 0);
		}
	}
#endif

	mutex_lock(&ux.lock);
	ux.kbd = kbd;
	mutex_unlock(&ux.lock);
	return 0;
}

static void kbd_remove_vendor(struct ux_kbd *kbd)
{
	mutex_lock(&ux.lock);
	if (ux.kbd == kbd)
		ux.kbd = NULL;
	mutex_unlock(&ux.lock);

	/* unregister while the device can still take the final LED request */
	if (kbd->led_registered)
		led_classdev_unregister(&kbd->led);
#if UX_ASUS_LISTENER
	cancel_delayed_work_sync(&kbd->sync_work);
	cancel_delayed_work_sync(&kbd->fallback_work);
	if (kbd->listening)
		asus_hid_unregister_listener(&kbd->listener);
	cancel_work_sync(&kbd->level_work);
#endif
	cancel_work_sync(&kbd->key_work);
	cancel_work_sync(&kbd->resume_work);
}

static int kbd_raw_event(struct hid_device *hdev, struct hid_report *report,
			 u8 *data, int size)
{
	struct ux_kbd *kbd = hid_get_drvdata(hdev);
	int code;

	if (!kbd || report->id != KBD_REPORT_ID || size < 2)
		return 0;

	code = data[1];
	if (log_hotkeys && code)
		hid_info(hdev, "hotkey %*ph\n", min(size, 8), data);

	switch (code) {
	case 0:
#if UX_ASUS_LISTENER
		/* key released: give asus-wmi time to report it before stepping */
		if (kbd->pressed_code) {
			WRITE_ONCE(kbd->fallback_code, kbd->pressed_code);
			kbd->pressed_code = 0;
			schedule_delayed_work(&kbd->fallback_work, msecs_to_jiffies(300));
		}
#endif
		return 0;
	case CODE_KBD_TOGGLE:
	case CODE_KBD_UP:
	case CODE_KBD_DOWN:
#if UX_ASUS_LISTENER
		if (!kbd->own_led) {
			kbd->press_time = jiffies;
			kbd->pressed_code = code;
			return 0;
		}
#endif
		break;
	case CODE_CAMERA:
		if (!ux.camera_supported || !camera_control)
			return 0;
		break;
	default:
		return 0;
	}

	WRITE_ONCE(kbd->pending_code, code);
	schedule_work(&kbd->key_work);
	return 0;
}

/* Webcam privacy ------------------------------------------------------------ */

static int camera_get_blocked(void)
{
	u32 val;
	int ret;

	ret = asus_wmi_evaluate_method(ASUS_WMI_METHODID_DSTS, DEVID_CAMERA_GPIO, 0, &val);
	if (ret)
		return ret;
	if (!(val & ASUS_WMI_DSTS_PRESENCE_BIT))
		return -ENODEV;
	return !(val & 1);
}

static void camera_report(int blocked)
{
	struct input_dev *in = ux.cam_input;
#ifdef KEY_CAMERA_ACCESS_ENABLE
	unsigned int key = blocked ? KEY_CAMERA_ACCESS_DISABLE : KEY_CAMERA_ACCESS_ENABLE;
#endif

	if (!in)
		return;
	input_report_switch(in, SW_CAMERA_LENS_COVER, blocked);
#ifdef KEY_CAMERA_ACCESS_ENABLE
	input_report_key(in, key, 1);
	input_sync(in);
	input_report_key(in, key, 0);
#endif
	input_sync(in);
}

/* caller holds ux.lock */
static int camera_set_blocked(bool blocked)
{
	u32 ret;
	int err;

	err = asus_wmi_evaluate_method(ASUS_WMI_METHODID_DEVS, DEVID_CAMERA_GPIO,
				       blocked ? 0 : 1, &ret);
	if (err)
		return err;

	camera_report(blocked);
	sysfs_notify(&ux.pdev->dev.kobj, NULL, "camera_blocked");
	return 0;
}

static void camera_toggle(void)
{
	int blocked;

	mutex_lock(&ux.lock);
	blocked = camera_get_blocked();
	if (blocked >= 0)
		camera_set_blocked(!blocked);
	mutex_unlock(&ux.lock);
}

static bool camera_detect(void)
{
	u32 val;

	if (!dmi_match(DMI_BOARD_NAME, "UX7602ZM"))
		return false;
	/* models with the dedicated camera switch device don't need this */
	if (!asus_wmi_evaluate_method(ASUS_WMI_METHODID_DSTS, DEVID_CAMERA, 0, &val) &&
	    (val & ASUS_WMI_DSTS_PRESENCE_BIT))
		return false;
	return camera_get_blocked() >= 0;
}

static int camera_input_init(struct device *parent)
{
	struct input_dev *in;
	int ret;

	in = input_allocate_device();
	if (!in)
		return -ENOMEM;

	in->name = "ASUS Camera Privacy Switch";
	in->phys = DRV_NAME "/input0";
	in->id.bustype = BUS_HOST;
	in->dev.parent = parent;
	input_set_capability(in, EV_SW, SW_CAMERA_LENS_COVER);
#ifdef KEY_CAMERA_ACCESS_ENABLE
	input_set_capability(in, EV_KEY, KEY_CAMERA_ACCESS_ENABLE);
	input_set_capability(in, EV_KEY, KEY_CAMERA_ACCESS_DISABLE);
#endif
	if (camera_get_blocked() > 0)
		__set_bit(SW_CAMERA_LENS_COVER, in->sw);

	ret = input_register_device(in);
	if (ret) {
		input_free_device(in);
		return ret;
	}
	ux.cam_input = in;
	return 0;
}

/* ASUS Dial ------------------------------------------------------------------ */

static void dial_key(struct input_dev *in, unsigned int code)
{
	input_report_key(in, code, 1);
	input_sync(in);
	input_report_key(in, code, 0);
	input_sync(in);
}

static void dial_wheel(struct input_dev *w, int dir)
{
	input_report_rel(w, REL_WHEEL, dir);
	input_report_rel(w, REL_WHEEL_HI_RES, dir * 120);
	input_sync(w);
}

static void dial_step_once(struct ux_dial *dial, int mode, int dir)
{
	switch (mode) {
	case DIAL_VOLUME:
		dial_key(dial->keys, dir > 0 ? KEY_VOLUMEUP : KEY_VOLUMEDOWN);
		break;
	case DIAL_BRIGHTNESS:
		dial_key(dial->keys, dir > 0 ? KEY_BRIGHTNESSUP : KEY_BRIGHTNESSDOWN);
		break;
	case DIAL_MEDIA:
		dial_key(dial->keys, dir > 0 ? KEY_NEXTSONG : KEY_PREVIOUSSONG);
		break;
	case DIAL_ZOOM:
		/* modifier state is seat-wide, so this Ctrl applies to the wheel below */
		input_report_key(dial->keys, KEY_LEFTCTRL, 1);
		input_sync(dial->keys);
		dial_wheel(dial->wheel, dir);
		input_report_key(dial->keys, KEY_LEFTCTRL, 0);
		input_sync(dial->keys);
		break;
	case DIAL_SCROLL:
		/* clockwise scrolls down, like rolling a wheel towards you */
		dial_wheel(dial->wheel, -dir);
		break;
	default:
		break;
	}
}

static void dial_click(struct ux_dial *dial, int mode)
{
	switch (mode) {
	case DIAL_VOLUME:
		dial_key(dial->keys, KEY_MUTE);
		break;
	case DIAL_MEDIA:
		dial_key(dial->keys, KEY_PLAYPAUSE);
		break;
	case DIAL_SCROLL:
	case DIAL_ZOOM:
		dial_key(dial->wheel, BTN_MIDDLE);
		break;
	default:
		break;
	}
}

static void dial_cycle_mode(void)
{
	static const int cycle[] = { DIAL_VOLUME, DIAL_BRIGHTNESS, DIAL_SCROLL };
	int i, next = cycle[0];

	for (i = 0; i < ARRAY_SIZE(cycle); i++)
		if (cycle[i] == READ_ONCE(ux.mode))
			next = cycle[(i + 1) % ARRAY_SIZE(cycle)];
	WRITE_ONCE(ux.mode, next);
	sysfs_notify(&ux.pdev->dev.kobj, NULL, "dial_mode");
}

static int dial_raw_event(struct hid_device *hdev, struct hid_report *report,
			  u8 *data, int size)
{
	struct ux_dial *dial = hid_get_drvdata(hdev);
	int delta, mode, steps, step = max(dial_step, 1);
	bool pressed;

	if (!dial || size < 4 || data[0] != DIAL_REPORT_ID)
		return 0;

	pressed = data[1] & 1;
	delta = (s16)(data[2] | (data[3] << 8));

	if (READ_ONCE(ux.mode) == DIAL_RAW) {
		input_report_key(dial->keys, BTN_0, pressed);
		input_report_rel(dial->keys, REL_DIAL, delta);
		input_sync(dial->keys);
		dial->pressed = pressed;
		return 0;
	}

	if (delta) {
		mode = pressed ? READ_ONCE(ux.pressed_mode) : READ_ONCE(ux.mode);
		dial->rotated |= pressed;
		dial->accum += delta;
		steps = dial->accum / step;
		dial->accum -= steps * step;
		for (; steps > 0; steps--)
			dial_step_once(dial, mode, 1);
		for (; steps < 0; steps++)
			dial_step_once(dial, mode, -1);
	}

	if (pressed != dial->pressed) {
		if (!pressed && !dial->rotated) {
			if (dial_press_cycles)
				dial_cycle_mode();
			else
				dial_click(dial, READ_ONCE(ux.mode));
		}
		if (!pressed)
			dial->rotated = false;
		dial->pressed = pressed;
	}
	return 0;
}

static void dial_set_id(struct input_dev *in, struct hid_device *hdev,
			const char *name, const char *phys)
{
	in->name = name;
	in->phys = phys;
	in->id.bustype = hdev->bus;
	in->id.vendor = hdev->vendor;
	in->id.product = hdev->product;
	in->dev.parent = &hdev->dev;
}

static int dial_probe(struct hid_device *hdev)
{
	static const unsigned int keys[] = {
		KEY_VOLUMEUP, KEY_VOLUMEDOWN, KEY_MUTE, KEY_BRIGHTNESSUP,
		KEY_BRIGHTNESSDOWN, KEY_NEXTSONG, KEY_PREVIOUSSONG, KEY_PLAYPAUSE,
		KEY_LEFTCTRL, BTN_0,
	};
	struct ux_dial *dial;
	struct input_dev *k, *w;
	int i, ret;

	dial = devm_kzalloc(&hdev->dev, sizeof(*dial), GFP_KERNEL);
	k = devm_input_allocate_device(&hdev->dev);
	w = devm_input_allocate_device(&hdev->dev);
	if (!dial || !k || !w)
		return -ENOMEM;

	dial->hdev = hdev;
	dial->keys = k;
	dial->wheel = w;

	dial_set_id(k, hdev, "ASUS Dial", DRV_NAME "/dial0");
	for (i = 0; i < ARRAY_SIZE(keys); i++)
		input_set_capability(k, EV_KEY, keys[i]);
	input_set_capability(k, EV_REL, REL_DIAL);

	/* udev only tags pointer devices (REL_X/Y plus a button) as mice */
	dial_set_id(w, hdev, "ASUS Dial Wheel", DRV_NAME "/dial1");
	input_set_capability(w, EV_REL, REL_X);
	input_set_capability(w, EV_REL, REL_Y);
	input_set_capability(w, EV_REL, REL_WHEEL);
	input_set_capability(w, EV_REL, REL_WHEEL_HI_RES);
	input_set_capability(w, EV_KEY, BTN_LEFT);
	input_set_capability(w, EV_KEY, BTN_MIDDLE);

	ret = input_register_device(k);
	if (!ret)
		ret = input_register_device(w);
	if (ret)
		return ret;

	hid_set_drvdata(hdev, dial);
	return 0;
}

/* HID driver ------------------------------------------------------------------ */

static int ux_input_mapping(struct hid_device *hdev, struct hid_input *hi,
			    struct hid_field *field, struct hid_usage *usage,
			    unsigned long **bit, int *max)
{
	/*
	 * The N-KEY vendor collections declare 256 array usages each, which
	 * hid-input would turn into an ABS_MISC axis. The hotkeys they carry
	 * also arrive through asus-nb-wmi, so drop them here.
	 */
	if ((usage->hid & HID_USAGE_PAGE) == HID_UP_ASUSVENDOR)
		return -1;
	return 0;
}

static int ux_probe(struct hid_device *hdev, const struct hid_device_id *id)
{
	bool is_dial = id->driver_data == UX_DIAL;
	int ret;

	ret = hid_parse(hdev);
	if (ret)
		return ret;

	ret = hid_hw_start(hdev, is_dial ? HID_CONNECT_HIDRAW : HID_CONNECT_DEFAULT);
	if (ret)
		return ret;

	if (is_dial) {
		/* without an open handle i2c-hid drops the input reports */
		ret = hid_hw_open(hdev);
		if (ret)
			goto err_stop;
		ret = dial_probe(hdev);
		if (ret) {
			hid_hw_close(hdev);
			goto err_stop;
		}
		return 0;
	}

	if (kbd_is_vendor_iface(hdev)) {
		ret = kbd_probe_vendor(hdev);
		if (ret)
			goto err_stop;
	}
	return 0;

err_stop:
	hid_hw_stop(hdev);
	return ret;
}

static void ux_remove(struct hid_device *hdev)
{
	void *data = hid_get_drvdata(hdev);

	if (hdev->product == PID_ASUS_DIAL)
		hid_hw_close(hdev);
	else if (data)
		kbd_remove_vendor(data);
	hid_hw_stop(hdev);
}

static int ux_raw_event(struct hid_device *hdev, struct hid_report *report,
			u8 *data, int size)
{
	if (hdev->product == PID_ASUS_DIAL)
		return dial_raw_event(hdev, report, data, size);
	return kbd_raw_event(hdev, report, data, size);
}

static int ux_suspend(struct hid_device *hdev, pm_message_t message)
{
	struct ux_kbd *kbd = hid_get_drvdata(hdev);

	/* system sleep only: an autosuspended idle keyboard keeps its light */
	if (hdev->product == PID_NKEY_KEYBOARD && kbd && !PMSG_IS_AUTO(message))
		kbd_send_level(kbd, 0);
	return 0;
}

static int ux_resume(struct hid_device *hdev)
{
	struct ux_kbd *kbd = hid_get_drvdata(hdev);

	if (hdev->product == PID_NKEY_KEYBOARD && kbd)
		schedule_work(&kbd->resume_work);
	return 0;
}

static const struct hid_device_id ux_devices[] = {
	{ HID_USB_DEVICE(USB_VENDOR_ID_ASUSTEK, PID_NKEY_KEYBOARD), .driver_data = UX_KBD },
	{ HID_I2C_DEVICE(USB_VENDOR_ID_ASUSTEK, PID_ASUS_DIAL), .driver_data = UX_DIAL },
	{ }
};
MODULE_DEVICE_TABLE(hid, ux_devices);

static struct hid_driver ux_hid_driver = {
	.name		= DRV_NAME,
	.id_table	= ux_devices,
	.probe		= ux_probe,
	.remove		= ux_remove,
	.raw_event	= ux_raw_event,
	.input_mapping	= ux_input_mapping,
	.suspend	= pm_ptr(ux_suspend),
	.resume		= pm_ptr(ux_resume),
	.reset_resume	= pm_ptr(ux_resume),
};

/* sysfs ------------------------------------------------------------------------ */

static ssize_t camera_blocked_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	int blocked;

	mutex_lock(&ux.lock);
	blocked = camera_get_blocked();
	mutex_unlock(&ux.lock);
	return blocked < 0 ? blocked : sysfs_emit(buf, "%d\n", blocked);
}

static ssize_t camera_blocked_store(struct device *dev, struct device_attribute *attr,
				    const char *buf, size_t count)
{
	bool blocked;
	int ret;

	ret = kstrtobool(buf, &blocked);
	if (ret)
		return ret;
	mutex_lock(&ux.lock);
	ret = camera_set_blocked(blocked);
	mutex_unlock(&ux.lock);
	return ret ? ret : count;
}
static DEVICE_ATTR_RW(camera_blocked);

/* "RRGGBB" or "<effect> [RRGGBB] [speed 1-3]" */
static ssize_t kbd_color_store(struct device *dev, struct device_attribute *attr,
			       const char *buf, size_t count)
{
	static const struct { const char *name; u8 code; bool colour; } effects[] = {
		{ "static", 0x00, true }, { "breathing", 0x01, true },
		{ "strobe", 0x0a, true }, { "cycle", 0x02, false },
		{ "rainbow", 0x03, false }, { "raindrop", 0x05, false },
	};
	char tok[3][16] = { "", "", "" };
	u8 rgb[3] = { 0xff, 0xff, 0xff };
	unsigned int speed = 2;
	int i, n, arg = 1, ret = -ENODEV;

	n = sscanf(buf, "%15s %15s %15s", tok[0], tok[1], tok[2]);
	if (n < 1)
		return -EINVAL;

	if (!parse_rgb(tok[0], rgb)) {
		i = 0;
	} else {
		for (i = 0; i < ARRAY_SIZE(effects); i++)
			if (!strcmp(tok[0], effects[i].name))
				break;
		if (i == ARRAY_SIZE(effects))
			return -EINVAL;
		if (effects[i].colour && arg < n && !parse_rgb(tok[arg], rgb))
			arg++;
		if (arg < n && kstrtouint(tok[arg], 10, &speed))
			return -EINVAL;
	}
	speed = clamp(speed, 1u, 3u);

	mutex_lock(&ux.lock);
	if (ux.kbd) {
		ret = kbd_set_effect(ux.kbd, effects[i].code, rgb,
				     effects[i].code ? 4 - speed : 0);
		if (!ret) {
			memcpy(ux.kbd->rgb, rgb, 3);
			ux.kbd->rgb_valid = effects[i].code == 0;
		}
	}
	mutex_unlock(&ux.lock);
	return ret ? ret : count;
}

static ssize_t kbd_color_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	ssize_t len;

	mutex_lock(&ux.lock);
	if (ux.kbd && ux.kbd->rgb_valid)
		len = sysfs_emit(buf, "%*phN\n", 3, ux.kbd->rgb);
	else
		len = sysfs_emit(buf, "unknown\n");
	mutex_unlock(&ux.lock);
	return len;
}
static DEVICE_ATTR_RW(kbd_color);

static ssize_t dial_mode_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	return sysfs_emit(buf, "%s\n", dial_mode_names[READ_ONCE(ux.mode)]);
}

static ssize_t dial_mode_store(struct device *dev, struct device_attribute *attr,
			       const char *buf, size_t count)
{
	int mode = sysfs_match_string(dial_mode_names, buf);

	if (mode < 0)
		return mode;
	WRITE_ONCE(ux.mode, mode);
	sysfs_notify(&dev->kobj, NULL, "dial_mode");
	return count;
}
static DEVICE_ATTR_RW(dial_mode);

static ssize_t dial_pressed_mode_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	return sysfs_emit(buf, "%s\n", dial_mode_names[READ_ONCE(ux.pressed_mode)]);
}

static ssize_t dial_pressed_mode_store(struct device *dev, struct device_attribute *attr,
				       const char *buf, size_t count)
{
	int mode = sysfs_match_string(dial_mode_names, buf);

	if (mode < 0 || mode == DIAL_RAW)
		return -EINVAL;
	WRITE_ONCE(ux.pressed_mode, mode);
	return count;
}
static DEVICE_ATTR_RW(dial_pressed_mode);

static struct attribute *ux_attrs[] = {
	&dev_attr_camera_blocked.attr,
	&dev_attr_kbd_color.attr,
	&dev_attr_dial_mode.attr,
	&dev_attr_dial_pressed_mode.attr,
	NULL
};

static umode_t ux_attr_visible(struct kobject *kobj, struct attribute *attr, int n)
{
	if (attr == &dev_attr_camera_blocked.attr && !ux.camera_supported)
		return 0;
	return attr->mode;
}

static const struct attribute_group ux_group = {
	.attrs = ux_attrs,
	.is_visible = ux_attr_visible,
};

static int __init ux_init(void)
{
	int ret;

	if (!dmi_match(DMI_SYS_VENDOR, "ASUSTeK COMPUTER INC."))
		return -ENODEV;

	mutex_init(&ux.lock);
	ux.mode = max(sysfs_match_string(dial_mode_names, dial_mode), 0);
	ux.pressed_mode = sysfs_match_string(dial_mode_names, dial_pressed_mode);
	if (ux.pressed_mode < 0 || ux.pressed_mode == DIAL_RAW)
		ux.pressed_mode = DIAL_BRIGHTNESS;

	ux.pdev = platform_device_register_simple(DRV_NAME, PLATFORM_DEVID_NONE, NULL, 0);
	if (IS_ERR(ux.pdev))
		return PTR_ERR(ux.pdev);

	ux.camera_supported = camera_detect();
	if (ux.camera_supported) {
		if (camera_boot_state >= 0) {
			mutex_lock(&ux.lock);
			camera_set_blocked(!camera_boot_state);
			mutex_unlock(&ux.lock);
		}
		ret = camera_input_init(&ux.pdev->dev);
		if (ret)
			pr_warn(DRV_NAME ": camera privacy switch not registered: %d\n", ret);
	}

	ret = sysfs_create_group(&ux.pdev->dev.kobj, &ux_group);
	if (ret)
		goto err_input;

	ret = hid_register_driver(&ux_hid_driver);
	if (ret)
		goto err_group;

	pr_info(DRV_NAME ": loaded, camera privacy control %s, keyboard LED %s\n",
		ux.camera_supported ? "enabled" : "not available",
		kbd_own_led || !UX_ASUS_LISTENER ? "own" : "via asus-wmi");
	return 0;

err_group:
	sysfs_remove_group(&ux.pdev->dev.kobj, &ux_group);
err_input:
	if (ux.cam_input)
		input_unregister_device(ux.cam_input);
	platform_device_unregister(ux.pdev);
	return ret;
}

static void __exit ux_exit(void)
{
	hid_unregister_driver(&ux_hid_driver);
	sysfs_remove_group(&ux.pdev->dev.kobj, &ux_group);
	if (ux.cam_input)
		input_unregister_device(ux.cam_input);
	platform_device_unregister(ux.pdev);
}

module_init(ux_init);
module_exit(ux_exit);

MODULE_DESCRIPTION("ASUS Zenbook Pro 16X (UX7602ZM) keyboard backlight, camera privacy and Dial");
MODULE_LICENSE("GPL");
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 13, 0)
MODULE_IMPORT_NS("ASUS_WMI");
#else
MODULE_IMPORT_NS(ASUS_WMI);
#endif
