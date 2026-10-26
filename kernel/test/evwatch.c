// SPDX-License-Identifier: GPL-2.0-or-later
/* evwatch NAME MS: print EV_KEY/EV_SW events of the input device NAME for MS milliseconds */
#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	DIR *dir = opendir("/sys/class/input");
	struct dirent *e;
	char path[300], name[128];
	int fd = -1;

	if (argc < 3)
		return 2;
	while (dir && (e = readdir(dir)) && fd < 0) {
		FILE *f;

		if (strncmp(e->d_name, "event", 5))
			continue;
		snprintf(path, sizeof(path), "/sys/class/input/%s/device/name", e->d_name);
		f = fopen(path, "r");
		if (!f || !fgets(name, sizeof(name), f)) {
			if (f)
				fclose(f);
			continue;
		}
		fclose(f);
		name[strcspn(name, "\n")] = 0;
		if (!strcmp(name, argv[1])) {
			snprintf(path, sizeof(path), "/dev/input/%s", e->d_name);
			fd = open(path, O_RDONLY);
		}
	}
	if (fd < 0) {
		printf("evwatch: no input device '%s'\n", argv[1]);
		return 1;
	}
	if (argc > 3) {
		unsigned long sw[(SW_MAX + 64) / 64] = { 0 };

		ioctl(fd, EVIOCGSW(sizeof(sw)), sw);
		printf("state SW_CAMERA_LENS_COVER=%lu\n", (sw[SW_CAMERA_LENS_COVER / 64] >> (SW_CAMERA_LENS_COVER % 64)) & 1);
	}
	for (;;) {
		struct pollfd p = { .fd = fd, .events = POLLIN };
		struct input_event ev;

		if (poll(&p, 1, atoi(argv[2])) <= 0)
			break;
		if (read(fd, &ev, sizeof(ev)) != sizeof(ev))
			break;
		if (ev.type == EV_KEY || ev.type == EV_SW)
			printf("event type=%s code=%d value=%d\n", ev.type == EV_SW ? "SW" : "KEY", ev.code, ev.value);
	}
	return 0;
}
