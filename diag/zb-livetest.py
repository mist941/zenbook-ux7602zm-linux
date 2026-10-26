#!/usr/bin/python3 -I
"""Перевірка виправлень для ASUS Zenbook UX7602ZM з Live USB Fedora 44, без встановлення.

    sudo python3 diag/zb-livetest.py

Покроково перевіряє тачпад, підсвітку клавіатури, Fn-клавіші, камеру, ASUS Dial і звук,
питає, що ви бачите й чуєте, і зберігає результати та повну діагностику в архів
поруч зі скриптом (або в /tmp, якщо туди не можна писати).
"""
import datetime
import fcntl
import glob
import math
import os
import pwd
import re
import select
import shutil
import struct
import subprocess
import sys
import tarfile
import time
import wave

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEBUGFS = "/sys/kernel/debug/asus-nb-wmi"
TRACE = "/sys/kernel/tracing"
KPROBE = "zbtest/wmi"

EV_KEY, EV_REL, EV_ABS, EV_SW = 1, 2, 3, 5
BTN_LEFT = 0x110
KEY_MUTE, KEY_VOLUMEDOWN, KEY_VOLUMEUP = 113, 114, 115
UI_SET_EVBIT, UI_SET_KEYBIT = 0x40045564, 0x40045565
UI_DEV_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x405C5503, 0x5501, 0x5502
VIDIOC_QUERYCAP, VIDIOC_G_CTRL = 0x80685600, 0xC008561B
V4L2_CID_PRIVACY = 0x009A0910

HANDSHAKE = b"\x5aASUS Tech.Inc.\x00"
AUDIO_OPTIONS = """options snd_sof_intel_hda_generic hda_model=1043:1caf
options snd_sof_intel_hda_common hda_model=1043:1caf
options snd_hda_intel model=1043:1caf
"""

results = []
log_file = None
out_dir = None


# --- output and questions ------------------------------------------------------

def log(msg=""):
    print(msg)
    log_file.write(msg + "\n")
    log_file.flush()


def ask(question):
    try:
        answer = input(question + " ").strip().lower()
    except EOFError:
        answer = ""
    log_file.write(f"? {question} -> {answer!r}\n")
    return answer


def yes(question):
    """True / False, or None when skipped with Enter."""
    answer = ask(question + " [т/н, Enter — не знаю]")
    if answer in ("т", "так", "y", "yes", "д"):
        return True
    if answer in ("н", "ні", "n", "no"):
        return False
    return None


def start_section(title):
    log(f"\n=== {title}")
    return ask("Enter — почати, s — пропустити розділ:") != "s"


def record(name, status, detail):
    results.append((name, status, detail))
    log(f"[{status}] {name}: {detail}")


# --- devices -------------------------------------------------------------------

def hid_devices(ids):
    return sorted(glob.glob(f"/sys/bus/hid/devices/{ids}.*"))


def hidraw_of(dev):
    nodes = glob.glob(dev + "/hidraw/hidraw*")
    return "/dev/" + os.path.basename(nodes[0]) if nodes else None


def keyboard_vendor_hidraw():
    for dev in hid_devices("0003:0B05:8854"):
        if ":1.1/" in os.path.realpath(dev) + "/":
            return hidraw_of(dev)
    return None


def evdev_by_name(*parts):
    for ev in sorted(glob.glob("/sys/class/input/event*")):
        try:
            with open(ev + "/device/name") as f:
                name = f.read().strip()
        except OSError:
            continue
        if all(p in name for p in parts):
            return "/dev/input/" + os.path.basename(ev), name
    return None, None


def set_feature(node, data, length):
    buf = bytearray(length)
    buf[:len(data)] = data
    fd = os.open(node, os.O_RDWR)
    try:
        fcntl.ioctl(fd, (3 << 30) | (length << 16) | (ord("H") << 8) | 0x06, buf)
    finally:
        os.close(fd)


def read_events(fds, seconds, show=True):
    """Collect (fd, bytes) chunks from non-blocking fds for some seconds."""
    chunks = []
    end = time.time() + seconds
    shown = None
    while (left := end - time.time()) > 0:
        if show and math.ceil(left) != shown:
            shown = math.ceil(left)
            print(f"\r  ...{shown:2d} с ", end="", flush=True)
        ready, _, _ = select.select(fds, [], [], min(0.1, left))
        for fd in ready:
            try:
                chunks.append((fd, os.read(fd, 4096)))
            except OSError:
                pass
    if show:
        print("\r" + " " * 14 + "\r", end="", flush=True)
    return chunks


def input_events(data):
    for i in range(0, len(data) - 23, 24):
        _, _, etype, code, value = struct.unpack_from("llHHi", data, i)
        yield etype, code, value


def open_nb(path):
    return os.open(path, os.O_RDONLY | os.O_NONBLOCK)


# --- ASUS WMI through debugfs --------------------------------------------------

def wmi_call(name, dev_id, ctrl=None):
    with open(f"{DEBUGFS}/dev_id", "w") as f:
        f.write(hex(dev_id))
    if ctrl is not None:
        with open(f"{DEBUGFS}/ctrl_param", "w") as f:
            f.write(str(ctrl))
    with open(f"{DEBUGFS}/{name}") as f:
        out = f.read()
    m = re.search(r"= (0x[0-9a-f]+|\d+)\s*$", out)
    return int(m.group(1), 0) if m else None


def camera_line():
    """1 = camera available, 0 = blocked, None = unknown."""
    try:
        value = wmi_call("dsts", 0x00060078)
    except OSError:
        return None
    if value is None or not value & 0x10000:
        return None
    return value & 1


def video_nodes():
    found = []
    for dev in sorted(glob.glob("/dev/video*")):
        try:
            fd = os.open(dev, os.O_RDWR | os.O_NONBLOCK)
        except OSError:
            continue
        try:
            cap = bytearray(104)
            fcntl.ioctl(fd, VIDIOC_QUERYCAP, cap)
            card = cap[16:48].split(b"\0")[0].decode(errors="replace")
            if not struct.unpack_from("<I", cap, 88)[0] & 0x1:
                continue
            ctrl = bytearray(struct.pack("<Ii", V4L2_CID_PRIVACY, 0))
            try:
                fcntl.ioctl(fd, VIDIOC_G_CTRL, ctrl)
                privacy = struct.unpack_from("<i", ctrl, 4)[0]
            except OSError:
                privacy = None
            found.append((dev, card, privacy))
        except OSError:
            pass
        finally:
            os.close(fd)
    return found


def rgb_privacy():
    for dev, card, privacy in video_nodes():
        if "IR" not in card:
            return privacy
    return None


# --- hotkey watcher (USB vendor reports + WMI events via a kprobe) -------------

class HotkeyWatcher:
    def __init__(self):
        self.fds = {}
        self.kprobe = False
        node = keyboard_vendor_hidraw()
        if node:
            self.fds[open_nb(node)] = "hid"
        self._remove_kprobe()
        try:
            with open(f"{TRACE}/kprobe_events", "a") as f:
                f.write(f"p:{KPROBE} asus_wmi:asus_wmi_notify code=+8(%di):x32\n")
            with open(f"{TRACE}/events/{KPROBE}/enable", "w") as f:
                f.write("1")
            with open(f"{TRACE}/tracing_on", "w") as f:
                f.write("1")
            self.fds[open_nb(f"{TRACE}/trace_pipe")] = "wmi"
            self.kprobe = True
        except OSError as e:
            log(f"(WMI-події не видно: kprobe не вдалося створити: {e})")

    def collect(self, seconds):
        hid, wmi = [], []
        for fd, data in read_events(list(self.fds), seconds):
            if self.fds[fd] == "hid":
                if len(data) >= 2 and data[0] == 0x5A and data[1]:
                    hid.append(data[1])
            else:
                wmi += [int(c, 16) for c in re.findall(r"code=(0x[0-9a-f]+)", data.decode(errors="replace"))]
        return hid, wmi

    @staticmethod
    def _remove_kprobe():
        """Also clears a probe left behind by an interrupted earlier run."""
        for path, text in ((f"{TRACE}/events/{KPROBE}/enable", "0"), (f"{TRACE}/kprobe_events", f"-:{KPROBE}\n")):
            try:
                with open(path, "a" if path.endswith("kprobe_events") else "w") as f:
                    f.write(text)
            except OSError:
                pass

    def close(self):
        for fd in self.fds:
            os.close(fd)
        if self.kprobe:
            self._remove_kprobe()


def codes(values):
    return " ".join(f"{v:#04x}" for v in values) or "—"


# --- 1. touchpad ---------------------------------------------------------------

def click_round(ev, node, intensity, seconds=8):
    if intensity is not None:
        set_feature(node, bytes([0x09, intensity]), 2)
        time.sleep(0.3)
    fd = open_nb(ev)
    presses, moved = 0, False
    try:
        for _, data in read_events([fd], seconds):
            for etype, code, value in input_events(data):
                presses += etype == EV_KEY and code == BTN_LEFT and value == 1
                moved |= etype == EV_ABS
    finally:
        os.close(fd)
    return presses, moved


def test_touchpad():
    if not start_section("1. Тачпад (гаптичний клік)"):
        return
    ev, name = evdev_by_name("093A:3F01", "Touchpad")
    devs = hid_devices("0018:093A:3F01")
    node = hidraw_of(devs[0]) if devs else None
    if not ev or not node:
        record("тачпад", "FAIL", "пристрій 093A:3F01 не знайдено — надішліть архів")
        return
    log(f"пристрій: {name} ({ev}, {node})")
    log("Кожен раунд — 8 секунд. Поводіть пальцем і ТРИЧІ ФІЗИЧНО натисніть на тачпад")
    log("(саме натисніть до відчутного кліку, а не торкніться).")

    ask("Раунд 1 — як є, без виправлення. Enter, коли готові:")
    p0, moved = click_round(ev, node, None)
    log(f"без виправлення: кліків {p0}, рух курсора {'є' if moved else 'немає'}")

    ask("Раунд 2 — сила кліку 50. Enter, коли готові:")
    p1, _ = click_round(ev, node, 50)
    log(f"із силою 50: кліків {p1}")

    ask("Раунд 3 — сила 0 (клік має зникнути). Enter, коли готові:")
    p2, _ = click_round(ev, node, 0)
    log(f"із силою 0: кліків {p2}")
    set_feature(node, bytes([0x09, 50]), 2)
    felt = yes("Чи відчувався клік (вібровідгук) у раунді 2?")

    counts = f"кліки: без виправлення {p0}, сила 50 → {p1}, сила 0 → {p2}"
    if not moved:
        record("тачпад", "FAIL", "курсор не рухається — причина інша, ніж сила кліку; " + counts)
    elif p1 >= 2:
        verdict = ("без виправлення кліку не було — причину підтверджено" if p0 == 0
                   else "клік працював і без виправлення — справжня причина була іншою")
        record("тачпад", "PASS", f"із силою 50 клік працює, {verdict}; {counts}")
    else:
        record("тачпад", "FAIL", "із силою 50 клік не працює; " + counts)
    record("тачпад: відчуття кліку", "INFO", {True: "так", False: "ні", None: "не відповіли"}[felt])
    log("Сила кліку лишилася 50.")


# --- 2. keyboard backlight -------------------------------------------------------

def kbd_send(node, *reports):
    for report in reports:
        set_feature(node, report, 64)


def kbd_color(rgb):
    return [bytes([0x5C, sub, 0, 0, *rgb, 0]) for sub in (0xA0, 0xA5)]


def test_keyboard():
    if not start_section("2. Підсвітка клавіатури"):
        return
    node = keyboard_vendor_hidraw()
    if not node:
        record("підсвітка", "FAIL", "інтерфейс 1 клавіатури 0B05:8854 не знайдено")
        return
    leds = [os.path.basename(p) for p in glob.glob("/sys/class/leds/*kbd_backlight*")]
    log(f"LED-пристрої підсвітки до тесту: {', '.join(leds) or 'немає'}")

    answers = []
    kbd_send(node, HANDSHAKE, *kbd_color((0xFF, 0xFF, 0xFF)), bytes([0x5A, 0xBA, 0xC5, 0xC4, 3]))
    answers.append(yes("Підсвітка зараз увімкнена, біла, на максимумі?"))
    kbd_send(node, *kbd_color((0xFF, 0, 0)))
    answers.append(yes("Тепер вона червона?"))
    kbd_send(node, bytes([0x5A, 0xBA, 0xC5, 0xC4, 1]))
    answers.append(yes("Стала тьмянішою (рівень 1 з 3)?"))
    kbd_send(node, *kbd_color((0xFF, 0xFF, 0xFF)), bytes([0x5A, 0xBA, 0xC5, 0xC4, 2]))

    if all(answers):
        record("підсвітка", "PASS", "команди через USB-інтерфейс 1 працюють у Linux")
    elif False in answers:
        record("підсвітка", "FAIL", f"відповіді: {answers}")
    else:
        record("підсвітка", "INFO", f"не на всі питання відповіли: {answers}")
    log("Підсвітка лишилася білою, рівень 2.")


# --- 3. Fn keys ------------------------------------------------------------------

def test_hotkeys(watcher):
    if not start_section("3. Fn-клавіші (звідки приходять події)"):
        return
    for keys, note in (("Fn+F7", "яскравість підсвітки"), ("Fn+F12", "MyASUS"),
                       ("Fn+Esc", "Fn-lock; наприкінці натиснемо ще раз")):
        ask(f"Натисніть {keys} ({note}) ОДИН раз після Enter:")
        hid, wmi = watcher.collect(5)
        record(f"{keys}", "INFO", f"USB: {codes(hid)}; WMI: {codes(wmi) if watcher.kprobe else 'не видно'}")
        if keys == "Fn+F7":
            changed = yes("Чи змінилась яскравість підсвітки від цього натискання?")
            record("Fn+F7 сам змінює яскравість", "INFO",
                   {True: "так (прошивка/EC)", False: "ні", None: "не відповіли"}[changed])
    ask("Натисніть Fn+Esc ще раз (повернути Fn-lock) після Enter:")
    watcher.collect(4)


# --- 4. camera -------------------------------------------------------------------

def describe_camera():
    line = camera_line()
    nodes = video_nodes()
    text = f"лінія 0x00060078={line if line is not None else '?'}; " + "; ".join(
        f"{dev} «{card}» privacy={p if p is not None else '?'}" for dev, card, p in nodes)
    return line, rgb_privacy(), text


def test_camera(watcher):
    if not start_section("4. Камера і Fn+F10"):
        return
    if not os.path.isdir(DEBUGFS):
        record("камера", "FAIL", "немає /sys/kernel/debug/asus-nb-wmi (asus-nb-wmi не завантажився?)")
        return
    line, privacy, text = describe_camera()
    log(f"одразу після завантаження: {text}")
    record("камера після завантаження Linux", "INFO",
           {1: "доступна", 0: "ЗАБЛОКОВАНА — це пояснює, чому камера не працювала"}.get(line, "невідомо"))

    ask("Натисніть Fn+F10 ОДИН раз після Enter:")
    hid, wmi = watcher.collect(5)
    line1, privacy1, text1 = describe_camera()
    log(f"після Fn+F10: {text1}")
    record("Fn+F10 без драйвера", "INFO",
           f"USB: {codes(hid)}; WMI: {codes(wmi) if watcher.kprobe else 'не видно'}; "
           f"лінія {'змінилась' if line1 != line else 'не змінилась'}")

    try:
        wmi_call("devs", 0x00060078, 0)
        time.sleep(0.6)
        blocked = describe_camera()
        wmi_call("devs", 0x00060078, 1)
        time.sleep(0.6)
        freed = describe_camera()
    except OSError as e:
        record("камера: перемикання через WMI", "FAIL", f"debugfs не приймає запис ({e}); Secure Boot увімкнений?")
        return
    log(f"після DEVS 0: {blocked[2]}")
    log(f"після DEVS 1: {freed[2]}")
    if blocked[1] == 1 and freed[1] == 0:
        record("камера: перемикання через WMI", "PASS", "0 блокує, 1 розблоковує — драйвер працюватиме")
    else:
        record("камера: перемикання через WMI", "FAIL", f"privacy: після 0 → {blocked[1]}, після 1 → {freed[1]}")

    apps = [a for a in ("snapshot", "cheese", "guvcview") if shutil.which(a)]
    if apps:
        log(f"Камера зараз увімкнена. Відкрийте застосунок «{apps[0]}» (Камера) і подивіться на картинку.")
        record("камера показує зображення", "INFO",
               {True: "так", False: "ні", None: "не перевіряли"}[yes("Є кольорове зображення?")])


# --- 5. ASUS Dial ------------------------------------------------------------------

def dial_reports(fd, seconds):
    deltas, presses, last_button = [], 0, 0
    for _, data in read_events([fd], seconds):
        if len(data) >= 4 and data[0] == 0x01:
            button = data[1] & 1
            delta = struct.unpack_from("<h", data, 2)[0]
            if delta:
                deltas.append(delta)
            presses += button and not last_button
            last_button = button
    return deltas, presses


def dial_volume_demo(node, seconds=12):
    fd_ui = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
    fcntl.ioctl(fd_ui, UI_SET_EVBIT, EV_KEY)
    for key in (KEY_MUTE, KEY_VOLUMEDOWN, KEY_VOLUMEUP):
        fcntl.ioctl(fd_ui, UI_SET_KEYBIT, key)
    fcntl.ioctl(fd_ui, UI_DEV_SETUP, struct.pack("HHHH80sI", 0x18, 0x0B05, 0x0220, 1, b"ASUS Dial (live test)", 0))
    fcntl.ioctl(fd_ui, UI_DEV_CREATE)

    def tap(key):
        for value in (1, 0):
            os.write(fd_ui, struct.pack("llHHi", 0, 0, EV_KEY, key, value))
            os.write(fd_ui, struct.pack("llHHi", 0, 0, 0, 0, 0))

    fd = open_nb(node)
    try:
        for _, data in read_events([fd], seconds):
            if len(data) >= 4 and data[0] == 0x01:
                delta = struct.unpack_from("<h", data, 2)[0]
                for _ in range(min(abs(delta), 10)):
                    tap(KEY_VOLUMEUP if delta > 0 else KEY_VOLUMEDOWN)
    finally:
        os.close(fd)
        fcntl.ioctl(fd_ui, UI_DEV_DESTROY)
        os.close(fd_ui)


def test_dial():
    if not start_section("5. ASUS Dial"):
        return
    devs = hid_devices("0018:0B05:0220")
    node = hidraw_of(devs[0]) if devs else None
    if not node:
        record("Dial", "FAIL", "пристрій 0B05:0220 не знайдено")
        return
    fd = open_nb(node)
    try:
        ask("Після Enter поверніть Dial ЗА годинниковою стрілкою рівно на 5 клацань (8 с):")
        cw, _ = dial_reports(fd, 8)
        ask("Після Enter поверніть його ПРОТИ годинникової стрілки на 5 клацань (8 с):")
        ccw, _ = dial_reports(fd, 8)
        ask("Після Enter двічі натисніть на Dial (5 с):")
        _, presses = dial_reports(fd, 5)
    finally:
        os.close(fd)
    log(f"за годинниковою: {cw}; проти: {ccw}; натискань: {presses}")
    per_click = sum(cw) / 5 if cw else 0
    if sum(cw) > 0 > sum(ccw) and presses:
        record("Dial", "PASS", f"{per_click:g} од. на клацання (dial_step={max(1, round(per_click))}), "
                               f"натискання видно")
    else:
        record("Dial", "FAIL", f"суми {sum(cw)} / {sum(ccw)}, натискань {presses}")

    if ask("Показати Dial як регулятор гучності на 12 секунд? [т/Enter — пропустити]") in ("т", "так", "y"):
        dial_volume_demo(node)
        record("Dial як гучність", "INFO",
               {True: "працює", False: "не працює", None: "не відповіли"}[yes("Гучність змінювалась?")])


# --- 6. audio ----------------------------------------------------------------------

def alc285_dump():
    for path in sorted(glob.glob("/proc/asound/card*/codec#*")):
        try:
            with open(path) as f:
                text = f.read()
        except OSError:
            continue
        if "ALC285" in text or "0x10ec0285" in text.lower():
            return path, text
    return None, None


def codec_nodes(text):
    nodes = {}
    for m in re.finditer(r"^Node (0x[0-9a-f]+) \[([^\]]+)\].*?(?=^Node 0x|\Z)", text, re.M | re.S):
        nodes[int(m.group(1), 16)] = m.group(0)
    return nodes


def node_connections(block):
    m = re.search(r"Connection: (\d+)\n\s*([0-9a-fx* ]+)", block)
    if not m:
        return [], None
    entries = m.group(2).split()
    nids = [int(e.rstrip("*"), 16) for e in entries]
    chosen = [int(e.rstrip("*"), 16) for e in entries if e.endswith("*")]
    return nids, chosen[0] if chosen else (nids[0] if len(nids) == 1 else None)


def dac_has_volume(block):
    m = re.search(r"Amp-Out caps: ofs=0x[0-9a-f]+, nsteps=0x([0-9a-f]+)", block)
    return bool(m and int(m.group(1), 16) > 0)


def speaker_routing():
    path, text = alc285_dump()
    if not text:
        return None, "кодек ALC285 не знайдено в /proc/asound"
    nodes = codec_nodes(text)
    lines, bass_dac_volume = [], None
    for pin in (0x14, 0x17, 0x19, 0x1B, 0x21):
        block = nodes.get(pin, "")
        cfg = re.search(r"Pin Default (0x[0-9a-f]+): (.*)", block)
        conns, chosen = node_connections(block)
        dac = f"{chosen:#04x}" if chosen is not None else "?"
        vol = dac_has_volume(nodes.get(chosen, "")) if chosen is not None else None
        if pin == 0x17:
            bass_dac_volume = vol
        lines.append(f"pin {pin:#04x}: {cfg.group(1) + ' ' + cfg.group(2).strip() if cfg else '?'}; "
                     f"з'єднання {[f'{c:#04x}' for c in conns]} → {dac}"
                     + ("" if vol is None else f" (регулятор гучності: {'є' if vol else 'НЕМАЄ'})"))
    return bass_dac_volume, "\n".join(lines)


def as_user(*cmd, timeout=30):
    user = os.environ.get("SUDO_USER") or "liveuser"
    uid = pwd.getpwnam(user).pw_uid
    env = ["env", f"XDG_RUNTIME_DIR=/run/user/{uid}", f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus"]
    return subprocess.run(["runuser", "-u", user, "--", *env, *cmd],
                          capture_output=True, text=True, timeout=timeout)


def write_tone(path, freq=90, seconds=2.5, rate=48000):
    frames = bytearray()
    total = int(seconds * rate)
    for i in range(total):
        fade = min(1.0, i / 2400, (total - i) / 2400)
        sample = int(14000 * fade * math.sin(2 * math.pi * freq * i / rate))
        frames += struct.pack("<hh", sample, sample)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(bytes(frames))


def listening_test(tone, label):
    player = next((p for p in ("pw-play", "paplay", "aplay") if shutil.which(p)), None)
    if not player:
        log("немає pw-play/paplay/aplay — прослуховування пропущено")
        return None
    os.chmod(tone, 0o644)
    as_user("wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0")
    log(f"{label}: зараз прозвучить низький тон двічі — на гучності 100%, потім 25%.")
    ask("Відключіть навушники й HDMI. Enter — грати:")
    for volume in ("1.0", "0.25"):
        as_user("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volume)
        as_user(player, tone)
        time.sleep(0.4)
    as_user("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.5")
    answer = ask("Другий тон був: а) майже такий самий, б) трохи тихіший, в) значно тихіший? [а/б/в]")
    return {"а": "майже такий самий", "a": "майже такий самий", "б": "трохи тихіший",
            "b": "трохи тихіший", "в": "значно тихіший", "v": "значно тихіший"}.get(answer)


def try_audio_fix():
    conf = "/etc/modprobe.d/zb-livetest-audio.conf"
    with open(conf, "w") as f:
        f.write(AUDIO_OPTIONS)
    as_user("systemctl", "--user", "stop", "wireplumber.service", "pipewire-pulse.service",
            "pipewire-pulse.socket", "pipewire.service", "pipewire.socket")
    time.sleep(1.5)
    r = subprocess.run(["modprobe", "-r", "snd_sof_pci_intel_tgl"], capture_output=True, text=True)
    ok = r.returncode == 0
    if ok:
        subprocess.run(["modprobe", "snd_sof_pci_intel_tgl"], capture_output=True)
        for _ in range(30):
            time.sleep(0.5)
            if alc285_dump()[1]:
                break
    else:
        log(f"не вдалося вивантажити драйвер звуку: {r.stderr.strip()}")
    as_user("systemctl", "--user", "start", "pipewire.socket", "pipewire-pulse.socket",
            "pipewire.service", "pipewire-pulse.service", "wireplumber.service")
    time.sleep(3)
    return ok


def test_audio():
    if not start_section("6. Звук"):
        return
    bass_volume, routing = speaker_routing()
    log(routing)
    if bass_volume is False:
        record("звук: причина", "PASS", "пін 0x17 (баси) іде на DAC без регулятора гучності — причину підтверджено")
    elif bass_volume is True:
        record("звук: причина", "FAIL", "баси вже йдуть на DAC з регулятором — причина інша, надішліть архів")
    else:
        record("звук: причина", "INFO", "не вдалося розібрати кодек — дивіться архів")

    dmesg = subprocess.run(["dmesg"], capture_output=True, text=True).stdout
    amps = [l for l in dmesg.splitlines() if "cs35l41" in l.lower()]
    loaded = sum("Firmware Loaded" in l for l in amps)
    errors = [l for l in amps if re.search(r"error|fail", l, re.I)]
    firmware = glob.glob("/lib/firmware/cirrus/cs35l41-dsp1-spk-prot-10431f62*")
    record("звук: підсилювачі CS35L41", "PASS" if loaded >= 2 and not errors else "INFO",
           f"прошивку завантажено {loaded} раз(и), помилок {len(errors)}, файлів 10431f62: {len(firmware)}")

    tone = os.path.join(out_dir, "tone-90hz.wav")
    write_tone(tone)
    before = listening_test(tone, "До виправлення")
    record("звук до виправлення (90 Гц, 100% → 25%)", "INFO", before or "не відповіли")

    if ask("Спробувати виправлення звуку просто зараз? Звук на кілька секунд зникне. [т/Enter — ні]") \
            not in ("т", "так", "y"):
        return
    if not try_audio_fix():
        record("звук: виправлення наживо", "FAIL", "драйвер не перезапустився — перезавантажте live-сесію")
        return
    bass_volume, routing = speaker_routing()
    log(routing)
    param = "/sys/module/snd_sof_intel_hda_generic/parameters/hda_model"
    model = open(param).read().strip() if os.path.exists(param) else "?"
    record("звук: виправлення наживо", "PASS" if bass_volume else "FAIL",
           f"hda_model={model}; баси {'тепер на DAC з регулятором' if bass_volume else 'досі без регулятора'}")
    after = listening_test(tone, "Після виправлення")
    record("звук після виправлення (90 Гц, 100% → 25%)", "INFO", after or "не відповіли")


# --- main ----------------------------------------------------------------------------

def environment():
    def read(path):
        try:
            with open(path) as f:
                return f.read().strip()
        except OSError:
            return "?"
    lockdown = read("/sys/kernel/security/lockdown")
    log(f"ядро {os.uname().release}; {read('/sys/class/dmi/id/product_name')}; "
        f"BIOS {read('/sys/class/dmi/id/bios_version')}; lockdown: {lockdown}")
    if read("/sys/class/dmi/id/board_name") != "UX7602ZM":
        log("Увага: це не UX7602ZM, частина перевірок не має сенсу.")
    if "[none]" not in lockdown and lockdown != "?":
        log("Увага: kernel lockdown увімкнений (Secure Boot) — перевірка камери через debugfs не спрацює.")


def main():
    global log_file, out_dir
    if os.geteuid() != 0:
        sys.exit("запустіть від root: sudo python3 " + " ".join(sys.argv))
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    for base in (KIT, "/tmp"):
        out_dir = os.path.join(base, f"livetest-{stamp}")
        try:
            os.makedirs(out_dir)
            break
        except OSError:
            continue
    log_file = open(os.path.join(out_dir, "log.txt"), "w")
    if not os.path.ismount("/sys/kernel/debug"):
        subprocess.run(["mount", "-t", "debugfs", "none", "/sys/kernel/debug"])

    log("Перевірка ASUS Zenbook UX7602ZM. На кожне питання відповідайте т/н або просто Enter.")
    environment()
    with open(os.path.join(out_dir, "dmesg-before.txt"), "w") as f:
        f.write(subprocess.run(["dmesg"], capture_output=True, text=True).stdout)

    watcher = HotkeyWatcher()
    try:
        for step in (test_touchpad, test_keyboard, lambda: test_hotkeys(watcher),
                     lambda: test_camera(watcher), test_dial, test_audio):
            try:
                step()
            except Exception as e:
                record("помилка в розділі", "FAIL", f"{type(e).__name__}: {e}")
    finally:
        watcher.close()

    dmesg_after = subprocess.run(["dmesg"], capture_output=True, text=True).stdout
    with open(os.path.join(out_dir, "dmesg-after.txt"), "w") as f:
        f.write(dmesg_after)
    with open(os.path.join(out_dir, "dmesg-before.txt")) as f:
        known = set(f.read().splitlines())
    warnings = [l for l in dmesg_after.splitlines() if l not in known and re.search(r"WARNING:|BUG:|Oops", l)]
    record("попередження ядра під час перевірки", "INFO", warnings[0] if warnings else "немає")
    diag = os.path.join(KIT, "diag", "zb-diag.sh")
    if os.path.exists(diag):
        log("\nЗбираю повну діагностику (zb-diag.sh)...")
        before = set(glob.glob("/tmp/zb-diag-*.tar.gz"))
        subprocess.run(["bash", diag], capture_output=True)
        for archive in set(glob.glob("/tmp/zb-diag-*.tar.gz")) - before:
            shutil.copy(archive, out_dir)

    log("\n=== Підсумок")
    for name, status, detail in results:
        log(f"[{status:4}] {name}: {detail}")
    with open(os.path.join(out_dir, "summary.txt"), "w") as f:
        f.writelines(f"[{s}] {n}: {d}\n" for n, s, d in results)
    log_file.close()
    archive = out_dir + ".tar.gz"
    with tarfile.open(archive, "w:gz") as tar:
        tar.add(out_dir, arcname=os.path.basename(out_dir))
    print(f"\nГотово. Надішліть цей файл: {archive}")
    if archive.startswith("/tmp"):
        print("Він у /tmp і зникне після вимкнення — скопіюйте його на флешку.")


if __name__ == "__main__":
    main()
