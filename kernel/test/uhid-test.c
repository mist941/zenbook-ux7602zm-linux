// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Runtime test for asus_ux7602.ko: emulates the UX7602ZM N-KEY keyboard
 * (both USB interfaces) and the ASUS Dial through /dev/uhid, answers the
 * driver's feature reports, injects hotkeys and dial reports and checks the
 * LED, sysfs and evdev results.
 */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uhid.h>
#include <poll.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define BUS_USB 0x03
#define BUS_I2C 0x18

static int failures;

static void xwrite(int fd, const void *buf, size_t len)
{
	if (write(fd, buf, len) != (ssize_t)len)
		perror("write");
}

/* boot keyboard (interface 0) */
static const unsigned char rd_kbd[] = {
	0x05, 0x01, 0x09, 0x06, 0xa1, 0x01, 0x85, 0x01, 0x05, 0x07, 0x19, 0xe0,
	0x29, 0xe7, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01, 0x95, 0x08, 0x81, 0x02,
	0x95, 0x01, 0x75, 0x08, 0x81, 0x01, 0x95, 0x06, 0x75, 0x08, 0x15, 0x00,
	0x25, 0x65, 0x05, 0x07, 0x19, 0x00, 0x29, 0x65, 0x81, 0x00, 0xc0,
};

/* interface 1: N-KEY vendor 0x5a, consumer control 0x02, aura 0x5c */
static const unsigned char rd_vendor[] = {
	0x06, 0x31, 0xff, 0x09, 0x76, 0xa1, 0x01, 0x85, 0x5a, 0x19, 0x00, 0x2a,
	0xff, 0x00, 0x15, 0x00, 0x26, 0xff, 0x00, 0x75, 0x08, 0x95, 0x05, 0x81,
	0x00, 0x19, 0x00, 0x2a, 0xff, 0x00, 0x95, 0x3f, 0xb1, 0x00, 0xc0,
	0x05, 0x0c, 0x09, 0x01, 0xa1, 0x01, 0x85, 0x02, 0x19, 0x00, 0x2a, 0x3c,
	0x02, 0x15, 0x00, 0x26, 0x3c, 0x02, 0x75, 0x10, 0x95, 0x02, 0x81, 0x00,
	0xc0,
	0x06, 0x31, 0xff, 0x09, 0x77, 0xa1, 0x01, 0x85, 0x5c, 0x19, 0x00, 0x2a,
	0xff, 0x00, 0x15, 0x00, 0x26, 0xff, 0x00, 0x75, 0x08, 0x95, 0x1f, 0x81,
	0x00, 0x95, 0x3f, 0x91, 0x00, 0x95, 0x3f, 0xb1, 0x00, 0xc0,
};

/* ASUS Dial: System Multi-Axis Controller / Puck, button + 16-bit dial */
static const unsigned char rd_dial[] = {
	0x05, 0x01, 0x09, 0x0e, 0xa1, 0x01, 0x85, 0x01, 0x05, 0x0d, 0x09, 0x21,
	0xa1, 0x02, 0x05, 0x09, 0x09, 0x01, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01,
	0x95, 0x01, 0x81, 0x02, 0x75, 0x07, 0x81, 0x01, 0x05, 0x01, 0x09, 0x37,
	0x16, 0xf0, 0xf1, 0x26, 0x10, 0x0e, 0x75, 0x10, 0x95, 0x01, 0x81, 0x06,
	0x09, 0x48, 0x15, 0x00, 0x26, 0x10, 0x0e, 0xb1, 0x02, 0xc0, 0xc0,
};

struct dev {
	const char *name;
	int fd;
	/* last feature reports received, for checks */
	unsigned char last[16][8];
	int nlast;
};

static struct dev devs[3] = {
	{ .name = "N-KEY if0" }, { .name = "N-KEY if1" }, { .name = "ASUS Dial" },
};

static void check(int ok, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	printf("%s ", ok ? "PASS" : "FAIL");
	vprintf(fmt, ap);
	printf("\n");
	va_end(ap);
	if (!ok)
		failures++;
}

static int create(struct dev *d, const unsigned char *rd, size_t rd_size,
		  unsigned short bus, unsigned int pid)
{
	struct uhid_event ev = { .type = UHID_CREATE2 };

	d->fd = open("/dev/uhid", O_RDWR | O_CLOEXEC);
	if (d->fd < 0)
		return -errno;
	snprintf((char *)ev.u.create2.name, sizeof(ev.u.create2.name), "%s", d->name);
	ev.u.create2.rd_size = rd_size;
	ev.u.create2.bus = bus;
	ev.u.create2.vendor = 0x0b05;
	ev.u.create2.product = pid;
	memcpy(ev.u.create2.rd_data, rd, rd_size);
	return write(d->fd, &ev, sizeof(ev)) == sizeof(ev) ? 0 : -errno;
}

static void inject(struct dev *d, const unsigned char *data, size_t len)
{
	struct uhid_event ev = { .type = UHID_INPUT2 };

	ev.u.input2.size = len;
	memcpy(ev.u.input2.data, data, len);
	if (write(d->fd, &ev, sizeof(ev)) != sizeof(ev))
		perror("inject");
}

/* service uhid requests for ms milliseconds */
static void pump(int ms)
{
	struct timespec end, now;

	clock_gettime(CLOCK_MONOTONIC, &end);
	end.tv_nsec += (long)ms * 1000000;
	end.tv_sec += end.tv_nsec / 1000000000;
	end.tv_nsec %= 1000000000;

	for (;;) {
		struct pollfd pfd[3];
		int i, left;

		clock_gettime(CLOCK_MONOTONIC, &now);
		left = (end.tv_sec - now.tv_sec) * 1000 + (end.tv_nsec - now.tv_nsec) / 1000000;
		if (left <= 0)
			return;
		for (i = 0; i < 3; i++)
			pfd[i] = (struct pollfd){ .fd = devs[i].fd, .events = POLLIN };
		if (poll(pfd, 3, left) <= 0)
			continue;
		for (i = 0; i < 3; i++) {
			struct uhid_event ev, rep = { 0 };

			if (!(pfd[i].revents & POLLIN))
				continue;
			if (read(devs[i].fd, &ev, sizeof(ev)) <= 0)
				continue;
			if (ev.type == UHID_SET_REPORT) {
				struct dev *d = &devs[i];

				memcpy(d->last[d->nlast % 16], ev.u.set_report.data, 8);
				d->nlast++;
				printf("  %s SET_REPORT id=%02x:", d->name, ev.u.set_report.rnum);
				for (int j = 0; j < 8 && j < ev.u.set_report.size; j++)
					printf(" %02x", ev.u.set_report.data[j]);
				printf("\n");
				rep.type = UHID_SET_REPORT_REPLY;
				rep.u.set_report_reply.id = ev.u.set_report.id;
				xwrite(devs[i].fd, &rep, sizeof(rep));
			} else if (ev.type == UHID_GET_REPORT) {
				rep.type = UHID_GET_REPORT_REPLY;
				rep.u.get_report_reply.id = ev.u.get_report.id;
				rep.u.get_report_reply.size = 64;
				rep.u.get_report_reply.data[0] = ev.u.get_report.rnum;
				xwrite(devs[i].fd, &rep, sizeof(rep));
			}
		}
	}
}

static int saw(struct dev *d, const unsigned char *want, size_t len)
{
	int n = d->nlast < 16 ? d->nlast : 16;

	for (int i = 0; i < n; i++)
		if (!memcmp(d->last[i], want, len))
			return 1;
	return 0;
}

static int count_seen(struct dev *d, const unsigned char *want, size_t len)
{
	int n = d->nlast < 16 ? d->nlast : 16, hits = 0;

	for (int i = 0; i < n; i++)
		hits += !memcmp(d->last[i], want, len);
	return hits;
}

static int count_kbd_leds(void)
{
	DIR *dir = opendir("/sys/class/leds");
	struct dirent *e;
	int n = 0;

	while (dir && (e = readdir(dir)))
		n += strstr(e->d_name, "kbd_backlight") != NULL;
	if (dir)
		closedir(dir);
	return n;
}

static void clear(struct dev *d)
{
	d->nlast = 0;
	memset(d->last, 0, sizeof(d->last));
}

static int read_int(const char *path)
{
	char buf[32] = "";
	int fd = open(path, O_RDONLY);

	if (fd < 0)
		return -1;
	if (read(fd, buf, sizeof(buf) - 1) < 0)
		buf[0] = 0;
	close(fd);
	return atoi(buf);
}

static int write_now(const char *path, const char *s)
{
	int fd = open(path, O_WRONLY), ret;

	if (fd < 0)
		return -errno;
	ret = write(fd, s, strlen(s));
	close(fd);
	return ret < 0 ? -errno : 0;
}

/*
 * Some sysfs writes make the driver send feature reports synchronously, and
 * only this process answers them: write from a child while we keep pumping.
 */
static int write_str(const char *path, const char *s)
{
	int status;
	pid_t pid = fork();

	if (pid == 0)
		_exit(write_now(path, s) ? 1 : 0);
	pump(400);
	waitpid(pid, &status, 0);
	return WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : -1;
}

static int open_evdev(const char *name)
{
	DIR *dir = opendir("/sys/class/input");
	struct dirent *e;
	char path[300], buf[128];

	while (dir && (e = readdir(dir))) {
		int fd;

		if (strncmp(e->d_name, "event", 5))
			continue;
		snprintf(path, sizeof(path), "/sys/class/input/%s/device/name", e->d_name);
		fd = open(path, O_RDONLY);
		if (fd < 0)
			continue;
		memset(buf, 0, sizeof(buf));
		if (read(fd, buf, sizeof(buf) - 1) < 0)
			buf[0] = 0;
		close(fd);
		buf[strcspn(buf, "\n")] = 0;
		if (!strcmp(buf, name)) {
			snprintf(path, sizeof(path), "/dev/input/%s", e->d_name);
			closedir(dir);
			return open(path, O_RDONLY | O_NONBLOCK);
		}
	}
	if (dir)
		closedir(dir);
	return -1;
}

/* count events of type/code/value read from fd so far */
static int count_events(int fd, int type, int code, int value)
{
	struct input_event ev;
	int n = 0;

	while (read(fd, &ev, sizeof(ev)) == sizeof(ev))
		if (ev.type == type && ev.code == code && (value == -999 || ev.value == value))
			n++;
	return n;
}

int main(int argc, char **argv)
{
	static const unsigned char lvl2[] = { 0x5a, 0xba, 0xc5, 0xc4, 0x02 };
	static const unsigned char lvl3[] = { 0x5a, 0xba, 0xc5, 0xc4, 0x03 };
	static const unsigned char lvl0[] = { 0x5a, 0xba, 0xc5, 0xc4, 0x00 };
	static const unsigned char lvl1[] = { 0x5a, 0xba, 0xc5, 0xc4, 0x01 };
	static const unsigned char hs[] = { 0x5a, 'A', 'S', 'U', 'S' };
	static const unsigned char red_a0[] = { 0x5c, 0xa0, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00 };
	static const unsigned char red_a5[] = { 0x5c, 0xa5, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00 };
	static const unsigned char breathe[] = { 0x5c, 0xa0, 0x00, 0x01, 0x00, 0xff, 0x00, 0x01 };
	static const unsigned char key_f7[] = { 0x5a, 0xc7, 0, 0, 0, 0 };
	static const unsigned char key_up[] = { 0x5a, 0x00, 0, 0, 0, 0 };
	/* "listener": asus-nb-wmi is loaded and owns asus::kbd_backlight */
	int listener = argc > 1 && !strcmp(argv[1], "listener");
	static const char *led = "/sys/class/leds/asus::kbd_backlight/brightness";
	const char *base = "/sys/devices/platform/asus_ux7602";
	char path[256];
	int kfd, wfd;

	if (create(&devs[0], rd_kbd, sizeof(rd_kbd), BUS_USB, 0x8854) ||
	    create(&devs[1], rd_vendor, sizeof(rd_vendor), BUS_USB, 0x8854) ||
	    create(&devs[2], rd_dial, sizeof(rd_dial), BUS_I2C, 0x0220)) {
		perror("uhid create");
		return 2;
	}
	pump(1500);

	check(saw(&devs[1], hs, sizeof(hs)), "handshake 'ASUS Tech.Inc.' sent to interface 1");
	check(saw(&devs[1], lvl2, sizeof(lvl2)), "initial backlight level 2 sent");
	check(devs[0].nlast == 0, "nothing sent to interface 0 (got %d)", devs[0].nlast);
	check(read_int("/sys/class/leds/asus::kbd_backlight/max_brightness") == 3, "LED max_brightness = 3");
	check(read_int(led) == 2, "LED brightness reads 2");
	check(count_kbd_leds() == 1, "exactly one kbd_backlight LED (got %d)", count_kbd_leds());

	clear(&devs[1]);
	inject(&devs[1], key_f7, sizeof(key_f7));
	inject(&devs[1], key_up, sizeof(key_up));
	pump(800);
	check(saw(&devs[1], lvl3, sizeof(lvl3)) && read_int(led) == 3, "Fn+F7 (5a c7) steps 2 -> 3");
	clear(&devs[1]);
	inject(&devs[1], key_f7, sizeof(key_f7));
	inject(&devs[1], key_up, sizeof(key_up));
	pump(800);
	check(saw(&devs[1], lvl0, sizeof(lvl0)) && read_int(led) == 0, "Fn+F7 wraps 3 -> 0");

	if (listener) {
		/* the EC reports the same key through WMI: it must count once */
		clear(&devs[1]);
		inject(&devs[1], key_f7, sizeof(key_f7));
		write_now("/sys/kernel/debug/asus-nb-wmi/method_id", "0x54534554");
		write_now("/sys/kernel/debug/asus-nb-wmi/dev_id", "0xc7");
		read_int("/sys/kernel/debug/asus-nb-wmi/call");
		inject(&devs[1], key_up, sizeof(key_up));
		pump(800);
		check(count_seen(&devs[1], lvl1, sizeof(lvl1)) == 1 && !saw(&devs[1], lvl2, sizeof(lvl2)) &&
		      read_int(led) == 1, "Fn+F7 seen by HID and WMI steps once 0 -> 1");
	}

	clear(&devs[1]);
	write_str(led, "1");
	pump(300);
	check(saw(&devs[1], lvl1, sizeof(lvl1)), "writing LED brightness 1 sends level 1");

	clear(&devs[1]);
	snprintf(path, sizeof(path), "%s/kbd_color", base);
	check(write_str(path, "ff0000") == 0, "kbd_color accepts 'ff0000'");
	pump(300);
	check(saw(&devs[1], red_a0, 8) && saw(&devs[1], red_a5, 8), "static red sent as 5c a0 + 5c a5");
	clear(&devs[1]);
	check(write_str(path, "breathing 00ff00 3") == 0, "kbd_color accepts 'breathing 00ff00 3'");
	pump(300);
	check(saw(&devs[1], breathe, 8), "breathing green fast sent");
	check(write_str(path, "bogus") != 0, "kbd_color rejects 'bogus'");

	kfd = open_evdev("ASUS Dial");
	wfd = open_evdev("ASUS Dial Wheel");
	check(kfd >= 0 && wfd >= 0, "ASUS Dial input devices exist");

	inject(&devs[2], (const unsigned char[]){ 0x01, 0x00, 0x01, 0x00 }, 4);
	inject(&devs[2], (const unsigned char[]){ 0x01, 0x00, 0x01, 0x00 }, 4);
	pump(200);
	check(count_events(kfd, EV_KEY, KEY_VOLUMEUP, 1) == 2, "two clockwise detents -> 2x KEY_VOLUMEUP");
	inject(&devs[2], (const unsigned char[]){ 0x01, 0x00, 0xff, 0xff }, 4);
	pump(200);
	check(count_events(kfd, EV_KEY, KEY_VOLUMEDOWN, 1) == 1, "one counter-clockwise detent -> KEY_VOLUMEDOWN");
	inject(&devs[2], (const unsigned char[]){ 0x01, 0x01, 0x00, 0x00 }, 4);
	inject(&devs[2], (const unsigned char[]){ 0x01, 0x00, 0x00, 0x00 }, 4);
	pump(200);
	check(count_events(kfd, EV_KEY, KEY_MUTE, 1) == 1, "click -> KEY_MUTE");
	inject(&devs[2], (const unsigned char[]){ 0x01, 0x01, 0x00, 0x00 }, 4);
	inject(&devs[2], (const unsigned char[]){ 0x01, 0x01, 0x01, 0x00 }, 4);
	inject(&devs[2], (const unsigned char[]){ 0x01, 0x00, 0x00, 0x00 }, 4);
	pump(200);
	{
		struct input_event ev;
		int up = 0, mute = 0;

		while (read(kfd, &ev, sizeof(ev)) == sizeof(ev)) {
			up += ev.type == EV_KEY && ev.code == KEY_BRIGHTNESSUP && ev.value == 1;
			mute += ev.type == EV_KEY && ev.code == KEY_MUTE && ev.value == 1;
		}
		check(up == 1 && mute == 0, "press+rotate -> KEY_BRIGHTNESSUP, no mute on release");
	}

	snprintf(path, sizeof(path), "%s/dial_mode", base);
	write_str(path, "scroll");
	inject(&devs[2], (const unsigned char[]){ 0x01, 0x00, 0x02, 0x00 }, 4);
	pump(200);
	{
		struct input_event ev;
		int wheel = 0, hires = 0;

		while (read(wfd, &ev, sizeof(ev)) == sizeof(ev)) {
			if (ev.type == EV_REL && ev.code == REL_WHEEL)
				wheel += ev.value;
			if (ev.type == EV_REL && ev.code == REL_WHEEL_HI_RES)
				hires += ev.value;
		}
		check(wheel == -2 && hires == -240, "scroll mode: 2 detents -> REL_WHEEL -2 (hi-res -240)");
	}

	write_str(path, "raw");
	inject(&devs[2], (const unsigned char[]){ 0x01, 0x00, 0x05, 0x00 }, 4);
	pump(200);
	{
		struct input_event ev;
		int dial = 0;

		while (read(kfd, &ev, sizeof(ev)) == sizeof(ev))
			if (ev.type == EV_REL && ev.code == REL_DIAL)
				dial += ev.value;
		check(dial == 5, "raw mode: REL_DIAL +5");
	}
	check(write_str(path, "nonsense") != 0, "dial_mode rejects unknown mode");

	snprintf(path, sizeof(path), "%s/camera_blocked", base);
	if (access(path, F_OK) == 0) {
		static const unsigned char key_f10[] = { 0x5a, 0x85, 0, 0, 0, 0 };
		int cfd = open_evdev("ASUS Camera Privacy Switch");
		struct input_event ev;
		int sw = -1, off = 0, on = 0;

		check(cfd >= 0, "camera privacy switch input device exists");
		check(read_int(path) == 0, "camera available after load (camera_boot_state=1)");
		inject(&devs[1], key_f10, sizeof(key_f10));
		pump(400);
		check(read_int(path) == 1, "Fn+F10 (5a 85) blocks the camera");
		while (read(cfd, &ev, sizeof(ev)) == sizeof(ev)) {
			if (ev.type == EV_SW && ev.code == SW_CAMERA_LENS_COVER)
				sw = ev.value;
			off += ev.type == EV_KEY && ev.code == KEY_CAMERA_ACCESS_DISABLE && ev.value == 1;
		}
		check(sw == 1 && off == 1, "SW_CAMERA_LENS_COVER=1 and KEY_CAMERA_ACCESS_DISABLE reported");
		inject(&devs[1], key_f10, sizeof(key_f10));
		pump(400);
		check(read_int(path) == 0, "second Fn+F10 unblocks the camera");
		while (read(cfd, &ev, sizeof(ev)) == sizeof(ev)) {
			if (ev.type == EV_SW && ev.code == SW_CAMERA_LENS_COVER)
				sw = ev.value;
			on += ev.type == EV_KEY && ev.code == KEY_CAMERA_ACCESS_ENABLE && ev.value == 1;
		}
		check(sw == 0 && on == 1, "SW_CAMERA_LENS_COVER=0 and KEY_CAMERA_ACCESS_ENABLE reported");
		check(write_str(path, "1") == 0 && read_int(path) == 1, "writing 1 to camera_blocked blocks");
		check(write_str(path, "0") == 0 && read_int(path) == 0, "writing 0 to camera_blocked unblocks");
	} else {
		printf("SKIP camera tests (no ASUS WMI camera device)\n");
	}

	for (int i = 0; i < 3; i++) {
		struct uhid_event ev = { .type = UHID_DESTROY };

		xwrite(devs[i].fd, &ev, sizeof(ev));
		close(devs[i].fd);
	}
	printf("RESULT: %d failure(s)\n", failures);
	return failures ? 1 : 0;
}
