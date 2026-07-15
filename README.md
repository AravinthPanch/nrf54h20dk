# nrf54h20dk

Minimal Zephyr hello-world application for the **nRF54H20 DK** (PCA10175),
application core (`cpuapp`). Prints a boot banner over the VCOM0 serial console.

> Freestanding app — it lives **outside** the SDK west workspace
> (`/opt/nordic/ncs/v3.4.0`), so `ZEPHYR_BASE` must be set when building from the CLI.

Status: ✅ built, flashed, and verified booting on hardware (SN 1051113059).

## Prerequisites

- nRF Connect SDK **v3.4.0** at `/opt/nordic/ncs/v3.4.0` and its toolchain.
- The DK already brought up (IronSide SE provisioned, LCS `RoT`). See the repo-level
  `../CLAUDE.md` for the one-time SoC bring-up history.
- `nrfutil` with the `sdk-manager` and `device` components.

## Build & flash (west CLI)

```bash
# Once per terminal: pull the NCS toolchain env into this shell + point west at Zephyr
source <(nrfutil sdk-manager toolchain env --ncs-version v3.4.0 --as-script sh)
export ZEPHYR_BASE=/opt/nordic/ncs/v3.4.0/zephyr

# From this app folder:
west build -p -b nrf54h20dk/nrf54h20/cpuapp --sysbuild .   # -p = pristine
west flash --dev-id 1051113059
```

- `--sysbuild` is required on the nRF54H20 (builds the app + UICR domains).
- Incremental rebuilds: drop `-p`. Keep `-p` when changing board/config or on CMake
  cache errors.
- `which west` should resolve to `/opt/nordic/ncs/toolchains/.../bin/west` (v1.5.0),
  not a system/global one.

## View serial output

```bash
picocom /dev/tty.usbmodem0010511130591 -b 115200   # 115200 8N1, flow control none
```

Expected on reset:

```
*** Booting nRF Connect SDK v3.4.0-... ***
*** Using Zephyr OS v4.4.0-... ***
Hello from nrf54h20dk on nrf54h20dk/nrf54h20/cpuapp
```

Only one program can hold VCOM0 at a time — close other terminals first.
Exit `picocom` with `Ctrl-A` then `Ctrl-Q`.

## Build & flash (VS Code — nRF Connect extension)

1. **Add application** → open this `nrf54h20dk/` folder. Ensure the active SDK is
   `/opt/nordic/ncs/v3.4.0` (else the board list is empty).
2. **Add Build Configuration** → board `nrf54h20dk/nrf54h20/cpuapp`,
   **☑ System build (sysbuild)** → **Build Configuration**.
3. **Flash** from the Actions panel.
4. **nRF Terminal** → Connected Devices → DK → **VCOM0** @ **115200** for logs.

## Layout

```
nrf54h20dk/
├── CMakeLists.txt   # Zephyr app entry (find_package Zephyr + target_sources)
├── prj.conf         # Kconfig fragment (CONFIG_PRINTK=y)
├── src/main.c       # application entry — printk boot banner, then idle loop
├── .gitignore       # ignores build/
└── README.md
```

`build/` is generated and git-ignored.
