# Linux на ASUS Zenbook Pro 16X OLED (UX7602ZM)

Діагностика та виправлення для звуку, тачпада, камери з її «цифровим блокуванням»,
підсвітки клавіатури, Fn-клавіш і ASUS Dial. Усе з'ясовано на конкретному ноутбуці
(UX7602ZM, BIOS 303 від 2022-11-02, це остання версія BIOS) і перевірено на ядрі
Linux 7.3 в QEMU з емуляцією саме цих пристроїв.

## Коротко

| Проблема | Справжня причина | Виправлення |
|---|---|---|
| Гучність «не регулюється» | Пара низькочастотних динаміків (пін 0x17 кодека ALC285) підключена до DAC 0x06, у якого немає регулятора гучності. Повзунок змінює лише верхні частоти, а баси завжди грають на повну | Параметр `hda_model=1043:1caf` вмикає вже наявний у ядрі фіксап `SPEAKER2_TO_DAC1` разом з ініціалізацією CS35L41 (`config/modprobe.d/asus-ux7602-audio.conf`). Патч для ядра: `kernel/patches/0001` |
| Тачпад «не працює» | Це гаптичний тачпад PixArt 093A:3F01 без механічної кнопки. Windows при кожному запуску й виході зі сну записує йому інтенсивність кліку (HID feature 0x09). Linux 7.3 цього не робить, тому клік не спрацьовує | `zb-touchpad` + udev/systemd записують інтенсивність при старті та після сну. Патч для ядра: `kernel/patches/0003` |
| Камера не працює | Вхід «приватності» камери 13D3:5280 підключений до GPIO 0x090E000F (WMI 0x00060078, той самий, що світлодіод на F10). `0` = камера заблокована (чорний кадр), `1` = доступна. У Windows цю лінію перемикає служба ASUS, у Linux її ніхто не чіпає | Модуль `asus_ux7602` при завантаженні робить камеру доступною |
| «Цифрове блокування» (Fn+F10) не працює | Прошивка лише повідомляє про натискання (USB `5A 85` і WMI-подія 0x85), а саме перемикання має зробити ОС | Модуль перемикає лінію по Fn+F10 і повідомляє стан (`SW_CAMERA_LENS_COVER`, `KEY_CAMERA_ACCESS_*`), `zb-notify` показує сповіщення. Патч для ядра: `kernel/patches/0002` |
| Підсвітка клавіатури не працює | Клавіатура N-KEY 0B05:8854 (RGB) відсутня в драйвері `hid-asus`, тож їй ніхто не надсилає ініціалізацію і рівень яскравості. BIOS для `0x00050021` повертає статус без біта присутності, тому `asus-wmi` теж мовчить | Модуль керує підсвіткою через `asus::kbd_backlight` (рівні 0–3; на ядрах 7.x цей LED створює `asus-wmi`, а модуль під'єднується до нього): працюють повзунок у GNOME/KDE, екранне сповіщення і Fn+F7. Колір і ефекти задаються через `zb-kbd` |
| ASUS Dial мовчить | HID-колекція «System Multi-Axis Controller» не потрапляє під `IS_INPUT_APPLICATION`, тому ядро не створює для неї пристрою вводу | Модуль створює «ASUS Dial»: поворот змінює гучність, поворот із натиснутим колесом змінює яскравість, клік вимикає звук. Інші режими: прокрутка, масштаб, медіа, raw |

## Fedora Workstation 44 — покроково

Fedora 44 підходить добре: ядро 7.2.x з оновлень (на ISO — 6.19), `cirrus-audio-firmware`
вже містить прошивки підсилювачів для 10431f62, WirePlumber 0.5, dkms 3.4 сам створює ключ
для підпису модуля і перезбирає модуль після кожного оновлення ядра. Модуль перевірено
збіркою з GCC 16 проти `kernel-devel-7.2.11-200.fc44` і повним циклом DKMS (збірка,
підпис, встановлення) у контейнері Fedora 44.

### 0. Підготовка у Windows

1. **Вимкніть швидкий запуск** (Fast Startup): «Панель керування → Електроживлення → Дії кнопок
   живлення → Змінити недоступні зараз параметри» і зніміть «Увімкнути швидкий запуск».
   Інакше Windows не вимикається повністю: розділ NTFS лишається «сплячим» (Fedora відкриє
   його тільки для читання), а пристрої зберігають стан з Windows.
2. **Звільніть місце:** «Керування дисками» → C: → «Стиснути том», наприклад на 200–300 ГБ.
   Те саме може зробити встановлювач Fedora (пункт «Reclaim space»).
3. **Скопіюйте теку `zenbook-ux7602zm-linux` на флешку.** Можна й без флешки: якщо BitLocker вимкнений,
   Fedora прочитає диск C: напряму.
4. **BIOS** (F2 під час увімкнення): Secure Boot можна лишити вимкненим, тоді модуль завантажиться
   без реєстрації ключа. Intel VMD (RST) лишіть як є, Fedora з ним працює. Флешку Fedora
   запускайте через меню завантаження (Esc або F8).

### 1. Встановлення Fedora

1. Запишіть ISO Fedora Workstation 44 на флешку (Fedora Media Writer) і завантажтеся з неї.
2. В Anaconda виберіть SSD і автоматичне розбиття у вільному місці. Наявний EFI-розділ
   Windows (200 МБ) буде використаний спільно, це нормально.
3. Після першого входу оновіть систему й перезавантажтеся. Заголовки ядра (`kernel-devel`) у
   репозиторії є тільки для найновішого ядра, а модуль збирається під те, що зараз запущене:
   ```bash
   sudo dnf upgrade --refresh
   sudo reboot
   ```

### 2. Набір виправлень

```bash
cp -r /run/media/$USER/<назва_флешки>/zenbook-ux7602zm-linux ~/
cd ~/zenbook-ux7602zm-linux
sudo bash install.sh
sudo reboot
```

Диск Windows Fedora показує в Nautilus в «Інших місцях» (том на 951 ГБ). Скрипти запускаються
через `bash`, бо при копіюванні з флешки чи NTFS біт виконання може загубитися.

Що робить `install.sh` у Fedora:
- через `dnf` ставить `dkms`, `kernel-devel-$(uname -r)`, `cirrus-audio-firmware`,
  `alsa-sof-firmware` (мікрофони), `v4l-utils`, `alsa-utils`, `libnotify`;
- збирає модуль `asus_ux7602` через DKMS і підписує його. Після кожного `dnf upgrade` з новим
  ядром dkms сам перезбере модуль;
- кладе опцію для звуку в `/etc/modprobe.d`, утиліти в `/usr/local/sbin`, правило udev,
  служби systemd (тачпад після сну, сповіщення в сесії GNOME) і правило WirePlumber, яке
  ховає ІЧ-камеру від застосунків.

**Якщо Secure Boot увімкнений**, ядро Fedora не завантажить непідписаний модуль. Скрипт
запропонує `mokutil --import /var/lib/dkms/mok.pub` і попросить одноразовий пароль. Після
перезавантаження з'явиться синій екран MOK Manager: «Enroll MOK» → «Continue» → «Yes» →
введіть пароль → «Reboot». Якщо драйвер NVIDIA з RPM Fusion уже стоїть, скрипт підпише
модуль ключем akmods, і реєструвати доведеться лише один ключ.

### 3. Перевірка після перезавантаження

- **звук:** повзунок гучності змінює і баси; `cat /sys/module/snd_sof_intel_hda_generic/parameters/hda_model` → `1043:1caf`;
- **тачпад:** працює натискання; сила кліку — `sudo zb-touchpad set 25|50|75|100`.
  Тап-для-кліку вмикається в «Налаштування → Миша і тачпад»;
- **клавіатура:** Fn+F7 перемикає яскравість (GNOME показує індикатор рівня); колір —
  `sudo zb-kbd color 00aaff`, ефект — `sudo zb-kbd effect rainbow 2`;
- **камера:** `zb-camera status` → `available`; Fn+F10 вимикає й вмикає камеру, GNOME показує
  сповіщення, світлодіод на F10 горить, коли камера вимкнена;
- **ASUS Dial:** поворот змінює гучність, поворот із натиснутим колесом — яскравість, клік вимикає
  звук. Інший режим: `echo scroll | sudo tee /sys/devices/platform/asus_ux7602/dial_mode`.

### 4. Корисне для Fedora 44

- **Режими живлення** (меню у верхньому правому куті, tuned-ppd) перемикають профілі вентиляторів
  ASUS. Перевірити: `cat /sys/firmware/acpi/platform_profile`.
- **Обмеження заряду до 80 %:**
  ```bash
  echo 'w /sys/class/power_supply/BAT0/charge_control_end_threshold - - - - 80' | sudo tee /etc/tmpfiles.d/battery-limit.conf
  sudo systemd-tmpfiles --create /etc/tmpfiles.d/battery-limit.conf
  ```
- **Відбиток пальця:** «Налаштування → Користувачі → Вхід за відбитком»; libfprint підтримує
  ELAN 04F3:0C6E, `fprintd` у Fedora вже встановлений.
- **NVIDIA RTX 3060:** без додаткових дій працюють nouveau і NVK, дискретна відеокарта засинає,
  коли не потрібна. Для ігор і CUDA: GNOME Software → увімкнути сторонні репозиторії →
  драйвер NVIDIA (akmod з RPM Fusion). Із Secure Boot доведеться зареєструвати ключ:
  `sudo mokutil --import /etc/pki/akmods/certs/public_key.der`.
- **Чорний екран завантаження або мерехтіння OLED:**
  `sudo grubby --update-kernel=ALL --args="i915.enable_psr=0"` (батарея сідає трохи швидше).
- **NumberPad:** [asus-numberpad-driver](https://github.com/asus-linux-drivers/asus-numberpad-driver)
  підтримує Fedora, розкладка `up5401ea`.

Інші дистрибутиви: потрібні ядро **≥ 6.7** (з цієї версії ядро знає підсилювачі 1043:1F62) і
`linux-firmware` **від 2024-01**. Зі старішими версіями (наприклад, Linux Mint 21 зі штатним ядром)
динаміки грають ледь чутно або мовчать — саме цей симптом описують на форумах. `install.sh`
підтримує також apt, pacman і zypper.

Тільки користувацькі виправлення, без модуля ядра: `sudo bash install.sh --no-dkms`. Тоді Dial
обслуговує демон `zb-dial`, а камеру можна перемикати через `zb-camera`, але лише з вимкненим
Secure Boot (lockdown забороняє запис у debugfs).

## Подробиці

### 1. Звук

- **Залізо:** Realtek ALC285 (PCI SSID 1043:1F62) через Intel SST/SOF, два підсилювачі
  Cirrus CS35L41 на SPI1 (`\_SB.PC00.SPI1.SPK1`, `_HID CSC3551`, `_SUB 10431F62`). Таблиця
  `SSDT SPKRAMPS` не містить `_DSD`, тому ядро бере конфігурацію з власної таблиці
  (`cs35l41_hda_property.c`, запис `10431F62`: зовнішній boost, reset = GPIO 0x131,
  spkid = 0x12E, CS другого підсилювача = GPIO 0x17). Цей запис з'явився в ядрі 6.7.
- **Причина:** з фіксапом `ALC245_FIXUP_CS35L41_SPI_2` генеричний парсер підключає пін 0x14
  («Speaker») до DAC 0x02, а пін 0x17 («Bass Speaker») до DAC 0x06 без підсилювача гучності.
  Те саме описав власник UX7602VI, а Paweł Hofman у лютому 2026 запропонував для UX7602ZM
  фіксап `ALC285_FIXUP_ASUS_SPI_REAR_SPEAKERS` (патч не прийнято, бо в ньому не було Signed-off-by).
- **Рішення без перекомпіляції:** опція `hda_model=1043:1caf`. Кодек-драйвер підтримує
  «аліас SSID»: бере ланцюжок фіксапів іншого SSID (`REAR_SPEAKERS → ASUS_HEADSET_MIC →
  ASUS_SPEAKER2_TO_DAC1 → CS35L41_SPI_2`). Конфігурація підсилювачів береться з ACPI `_SUB`,
  тому від аліасу не залежить. Якщо з'явиться зайвий «мікрофон», спробуйте `1043:1c9f`
  (той самий ланцюжок без перевизначення піна 0x14).
- **Запасний варіант:** програмна гучність у WirePlumber
  (`sudo bash install.sh --softvol`, `config/wireplumber/51-...`).
- **Перевірити:** `grep -A3 'Node 0x17' /proc/asound/card*/codec#0` має показувати
  `Connection: 1` / `0x02`, а `dmesg | grep -i cs35l41` має містити `Firmware Loaded`.
- Вбудовані мікрофони підключені до DSP (DMIC), для них потрібна прошивка SOF
  (у Fedora — `alsa-sof-firmware`, у Debian/Ubuntu — `firmware-sof-signed`).

### 2. Тачпад

- **Залізо:** I2C HID PixArt 093A:3F01 (`ACPI ASUP1413`, I2C1, адреса 0x15). Колекція «Simple
  Haptic Controller» з єдиним параметром «Intensity» (report 0x09, 0–100); прошивка приймає
  0/25/50/75/100.
- **Причина:** у ядрі є `hid-haptic`, але воно працює лише з тачпадами, де клік і віддачею
  керує хост (потрібні звіти тиску й тригерів). Цей тачпад усе робить сам і чекає тільки
  значення інтенсивності. Тест у QEMU це підтверджує: оригінальний `hid-multitouch` 7.3
  ніколи не записує report 0x09.
- **Рішення:** `zb-touchpad` (через hidraw), udev-правило та `zb-resume.service`.
  Тап-для-кліку вмикається окремо в налаштуваннях середовища.
- **NumberPad** (цифровий блок на тачпаді) — проєкт
  [asus-numberpad-driver](https://github.com/asus-linux-drivers/asus-numberpad-driver),
  розкладка `up5401ea` (так налаштований UX7602VI).

### 3. Камера і Fn+F10

- **Залізо:** USB UVC 13D3:5280 (Azurewave): FHD-камера, ІЧ-камера і DFU-інтерфейс.
  У DSDT немає ні керування живленням камери, ні пристрою 0x00060013. Пристрій 0x00060078
  (`CLED`, GPIO 0x090E000F) пишеться через `DEVS` і читається через `DSTS` (біт 0).
- **Доказ (Windows, права адміністратора, `research/windows/camera-gpio-test.result.txt`):**
  `DEVS 0x00060078 ← 0` дає UVC privacy = 1 менш ніж за 250 мс, `← 1` повертає privacy = 0.
  Fn+F10 надсилає `5A 85 00` по USB і WMI-подію 0x85, а приблизно через 0,5 с служба ASUS
  перемикає лінію.
- **Рішення:** модуль `asus_ux7602` (параметр `camera_boot_state`, атрибут
  `/sys/devices/platform/asus_ux7602/camera_blocked`, вхідний пристрій «ASUS Camera Privacy
  Switch»). `zb-notify` показує сповіщення. ІЧ-камера прихована від застосунків через
  PipeWire (`52-...-hide-ir-camera.conf`), а Howdy бачить її, як і раніше.

### 4. Клавіатура: підсвітка, колір, Fn-клавіші

- **Залізо:** USB 0B05:8854 «N-KEY Device», per-key RGB. Інтерфейс 0 — звичайна клавіатура.
  Інтерфейс 1 — вендорські колекції 0xFF31 (report 0x5A: ініціалізація «ASUS Tech.Inc.»,
  яскравість `5A BA C5 C4 <0-3>`), Aura (report 0x5C: колір/ефект `5C A0 ...` + `5C A5 ...`)
  і consumer control.
- **Перевірено на цьому ноутбуці:** прошивка повідомляє про підтримку підсвітки
  (`5A 05 20 31 00 08` → байт 6 = 0x01), команда через інтерфейс 1 зробила клавіатуру
  червоною і яскравою.
- **Fn-клавіші (виміряно):** Fn+F7 → `5A C7` + WMI 0xC7, Fn+F10 → `5A 85` + WMI 0x85,
  Fn+F12 → `5A 86` + WMI 0x86 (`KEY_PROG1`), Fn+Esc → `5A 4E` + WMI 0x4E (Fn-lock).
  Решта Fn-клавіш — стандартні HID-коди. Щоб не було подвійних натискань, модуль
  з вендорських кодів обробляє тільки C4/C5/C7 і 85, а решту віддає `asus-nb-wmi`.
- **Хто володіє `asus::kbd_backlight`:** з ядра 7.0 цей LED належить `asus-wmi`. На першу ж
  WMI-подію Fn+F7 він реєструє його сам, навіть коли BIOS керувати підсвіткою не вміє.
  Тому на 7.x (Fedora 44 з оновленнями) модуль підключається до `asus-wmi` як «слухач»:
  LED один, Fn+F7 крокує `asus-wmi`, а модуль передає рівень клавіатурі. Якщо EC не
  надіслав WMI-подію протягом 300 мс після відпускання клавіші, модуль крокує сам. На
  ядрах до 7.0 (ISO Fedora 44 з 6.19) модуль реєструє LED сам (`kbd_own_led=1`). На час
  сну підсвітка гасне, після пробудження рівень і колір повертаються.
- **Не вивантажуйте `asus-nb-wmi`** (`modprobe -r asus_nb_wmi`) на ядрах 7.x без патча 0004:
  `asus-wmi` звільняє пам'ять LED раніше, ніж знімає його, і ядро падає (use-after-free).
  Звичайного вимкнення й сну це не стосується.

### 5. ASUS Dial

- **Залізо:** I2C HID 0B05:0220 (`ACPI ASUS2020`, I2C4, адреса 0x1D), звіт
  `01 <кнопка> <delta lo> <delta hi>`.
- **Режими** (`/sys/devices/platform/asus_ux7602/dial_mode`): `volume`, `brightness`,
  `scroll`, `zoom`, `media`, `raw` (`REL_DIAL` + `BTN_0` для власних скриптів).
  `dial_pressed_mode` визначає дію при повороті з натиснутим колесом.
  `dial_press_cycles=1` перемикає режими кліком.

### 6. Інше обладнання

- **Екран** Samsung ATNA60YV02 (OLED 3840×2400), підключений до Intel Iris Xe; дискретна
  NVIDIA RTX 3060 (GA106) працює через PRIME offload.
- **Відбиток пальця** ELAN 04F3:0C6E — драйвер `elan` у libfprint.
- **Профілі вентиляторів:** `asus-wmi` (`THROTTLE_THERMAL_POLICY_VIVO`, 0x00110019).
  **Ліміт заряду:** `charge_control_end_threshold` (0x00120057). **Fn-lock** (0x00100023) і
  світлодіод вимкнення мікрофона (0x00040017) `asus-wmi` теж підтримує.
- **Intel VMD (RST)** увімкнений у BIOS, Linux з ним працює. Якщо встановлювач раптом не бачить
  SSD, VMD вимикають у BIOS, але перед цим Windows треба перевести на звичайний драйвер NVMe,
  інакше вона перестане завантажуватися.

## Діагностика на Linux

```bash
sudo bash diag/zb-diag.sh --hotkeys
```

Скрипт збирає `dmesg`, кодек, HID-дескриптори, стан ASUS WMI, камери, модулів і 30 секунд
натискань Fn-клавіш і Dial в архів `/tmp/zb-diag-*.tar.gz`.

## Патчі для ядра

`kernel/patches/` — чотири коміти поверх Linux 7.3 (компілюються з `W=1`, перевірені в QEMU):

1. `ALSA: hda/realtek: Fix speaker volume on ASUS Zenbook UX7602ZM`
2. `platform/x86: asus-wmi: Toggle the webcam privacy line on Zenbook UX7602ZM`
3. `HID: multitouch: Set the haptic intensity of firmware-driven haptic touchpads`
4. `platform/x86: asus-wmi: Fix use-after-free of kbd_led on removal` — помилка в самому
   ядрі 7.0+, знайдена тестами (`Fixes: fac55d29581f`). Стосується всіх ноутбуків ASUS,
   де `asus-wmi` реєструє LED клавіатури.

Перед відправкою їх треба перевірити на реальному ноутбуці, після чого додати свій
`Signed-off-by` (`git commit --amend -s`, DCO) і надіслати адресатам з
`scripts/get_maintainer.pl`. Якщо ваше ядро вже містить патч 2, завантажуйте модуль з
`camera_control=0`, інакше Fn+F10 перемкне камеру двічі.

## Як це перевірено

- **На цьому ноутбуці (Windows):** дамп і розбір ACPI (DSDT і 16 SSDT), HID-дескриптори
  всіх пристроїв, живі HID-команди підсвітки, журнал Fn-клавіш (USB і WMI одночасно),
  опитування UVC privacy, тест GPIO з правами адміністратора (`research/`).
- **Linux 7.3 у QEMU** (`kernel/test/run-qemu-tests.sh`): емуляція обох інтерфейсів
  клавіатури, Dial і тачпада через `uhid` та BIOS-методу WMNB через SSDT. 92 перевірки
  модуля у трьох сценаріях: власний LED; через `asus-wmi`, коли `asus-nb-wmi` завантажується
  пізніше або раніше за клавіатуру (зокрема «Fn+F7 від HID і WMI — один крок»). Також
  перевірено патч asus-wmi з подією 0x85, порівняно оригінальний і пропатчений
  hid-multitouch, а `asus-nb-wmi` з патчем 0004 вивантажується чисто (без нього — Oops).
- **Fedora 44** (контейнер `fedora:44` зі справжніми пакетами Fedora): модуль зібраний GCC 16
  проти `kernel-devel-7.2.11-200.fc44` і `6.19.10-300.fc44` з `W=1` без попереджень.
  `install.sh` з DKMS відпрацював із кодом 0: dkms 3.4.4 створив ключ MOK, підписав модуль
  і встановив його, а `dkms autoinstall` для другого ядра (так спрацьовує хук `kernel-install`
  після оновлення ядра) зібрав і підписав модуль і для нього. У контейнері з systemd
  `install.sh`/`uninstall.sh` пройшли повністю, `systemd-analyze verify` і `udevadm verify`
  без зауважень. Також перевірено: `cirrus-audio-firmware-20261019` містить прошивки 10431f62,
  а `tuned-ppd` 2.28 перемикає `platform_profile` (енергозбереження → `quiet`).
- **Що лишилося:** запуск на справжній Fedora на цьому ноутбуці. Якщо щось не спрацює,
  надішліть архів `zb-diag`.

## Джерела

- [taminomara/zenbook-ux7602-linux](https://github.com/taminomara/zenbook-ux7602-linux) — аналіз UX7602VI (той самий тачпад, клавіатура і Dial)
- [Novaryu/zenauracore](https://github.com/Novaryu/zenauracore) — протокол RGB-клавіатури UX7602ZM
- [Alex Spataru: quirk UX7602ZM](https://lkml.iu.edu/hypermail/linux/kernel/2311.0/03390.html) і [asus_zenbook_ux7602zm_sound](https://github.com/alex-spataru/asus_zenbook_ux7602zm_sound)
- [Paweł Hofman: rear speaker fixup для UX7602ZM](https://patchew.org/linux/20260222213224.216805-1-phofman@o2.pl/)
- [asus-numberpad-driver](https://github.com/asus-linux-drivers/asus-numberpad-driver), [libfprint](https://fprint.freedesktop.org/supported-devices.html)
