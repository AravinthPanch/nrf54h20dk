# nrf54h20dk

Minimal Zephyr hello-world application for the **nRF54H20 DK** (PCA10175),
application core (`cpuapp`). Prints a boot banner over the VCOM0 serial console.

> Freestanding app — it lives **outside** the SDK west workspace
> (`/opt/nordic/ncs/v3.4.0`), so `ZEPHYR_BASE` must be set when building from the CLI.

Status: ✅ built, flashed, and verified booting on hardware (SN 1051113059).

## Hardware / environment

| Item | Value |
|------|-------|
| Board | nRF54H20 DK, **PCA10175** |
| Serial number | **1051113059** |
| Host | macOS (zsh) |
| nrfutil | 8.2.0 (device component 2.17.2) |
| NCS SDK | **v3.4.0** at `/opt/nordic/ncs/v3.4.0` (a `west` workspace) |
| Toolchain | `/opt/nordic/ncs/toolchains/ccc010f809` |
| IronSide SE | **v23.8.0+33** (provisioned) |
| Console | VCOM0 `/dev/tty.usbmodem0010511130591`, 115200 8N1, flow control none |

## Prerequisites

- nRF Connect SDK **v3.4.0** at `/opt/nordic/ncs/v3.4.0` and its toolchain.
- The DK already brought up (IronSide SE provisioned, LCS `RoT`) — see
  [SoC bring-up](#soc-bring-up-one-time) below.
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
  not a system/global one. The system-wide `west` was removed during setup because its
  PyYAML dependency was broken; the toolchain ships a working `west` plus the compiler,
  CMake, ninja, and the Zephyr SDK together.

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
Exit `picocom` with `Ctrl-A` then `Ctrl-Q`. (`screen` needs an interactive tty and a
stale session can lock the port — `screen -wipe` if you hit "Resource busy".)

## Build & flash (VS Code — nRF Connect extension)

1. **Add application** → open this `nrf54h20dk/` folder. Ensure the active SDK is
   `/opt/nordic/ncs/v3.4.0` (else the board list is empty).
2. **Add Build Configuration** → board `nrf54h20dk/nrf54h20/cpuapp`,
   **☑ System build (sysbuild)** → **Build Configuration**.
3. **Flash** from the Actions panel.
4. **nRF Terminal** → Connected Devices → DK → **VCOM0** @ **115200** for logs.
   Don't use the erase/recover flash options — they could disturb the provisioned
   Secure Domain.

## How the build works

Everyday build concepts (distinct from the one-time bring-up below). The app itself is
a thin overlay — one source file plus a couple of config lines — that Zephyr compiles
its kernel, drivers, and startup code *around*.

### The two environment pieces

The CLI build needs both, and they point at different things:

| Variable | Set by | Points at | Provides |
|----------|--------|-----------|----------|
| **Toolchain env** | `source <(nrfutil ... toolchain env ...)` | `/opt/nordic/ncs/toolchains/...` | The *tools*: the toolchain's `west`, compiler, CMake, ninja, Zephyr SDK — put on `PATH` for this shell |
| **`ZEPHYR_BASE`** | `export ZEPHYR_BASE=...` | `/opt/nordic/ncs/v3.4.0/zephyr` | The *OS source tree* your app is compiled into |

- `source <(nrfutil sdk-manager toolchain env --ncs-version v3.4.0 --as-script sh)` —
  the inner command only *prints* `export` lines; `--as-script sh` formats them as a
  POSIX script, `<(...)` (process substitution) feeds that output in as a file, and
  `source` runs it **in the current shell** so the `PATH` changes persist. Hence "once
  per terminal." (To inspect what it sets, run the inner command alone with
  `... --as-script sh > toolchain-env.sh`.)
- **`ZEPHYR_BASE`** is required *only because this app lives outside the west
  workspace* — it's the `HINTS` that lets CMake find Zephyr (see below). Inside a normal
  workspace it's discovered automatically.

### What `ZEPHYR_BASE` contains that the app needs

It's the **root of the Zephyr RTOS tree**, not a small include dir. The build reaches
into it for:

- `cmake/` — **`ZephyrConfig.cmake`**, the file `find_package(Zephyr ...)` searches for;
  finding it bootstraps the whole build and defines the `app` target.
- `kernel/`, `lib/`, `subsys/`, `drivers/`, `arch/` — the code compiled *into* the image
  (scheduler, `k_msleep`, libc, the UART driver behind VCOM0, M33 startup).
- `include/` — headers; `#include <zephyr/kernel.h>` resolves here.
- `boards/`, `soc/`, `dts/` — turn the `-b nrf54h20dk/nrf54h20/cpuapp` string into real
  pin/peripheral/memory config.
- `Kconfig*` + `scripts/` — the config system your one-line `prj.conf` overrides, plus
  the devicetree/Kconfig/linker generators.

### `CMakeLists.txt`, line by line

- `find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})` — locates and **bootstraps**
  Zephyr (defines the `app` target, runs Kconfig + devicetree, sets the toolchain).
  `REQUIRED` fails the build immediately if not found; `HINTS $ENV{ZEPHYR_BASE}` tells it
  where to look. Must come before anything references `app`.
- `target_sources(app PRIVATE src/main.c)` — adds our source to Zephyr's **pre-existing**
  `app` target (we never `add_executable` — Zephyr owns the executable and link step).
  `app` is the Zephyr-convention bucket for *your* code vs. the kernel/drivers; `PRIVATE`
  keeps the source local to the target (always correct for `.c` files).

### Cores — what `cpuapp` means

The board target is `board / soc / core`: `nrf54h20dk/nrf54h20/**cpuapp**`. The nRF54H20
is a **multicore SoC**, so you must say which core the image runs on:

| Core | Role |
|------|------|
| **`cpuapp`** | Application core (Cortex-M33) — where this app runs |
| `cpurad` | Radio core (Cortex-M33) — BLE / 802.15.4 stack |
| `cpuppr` | Peripheral Processor (Nordic VPR) — low-power offload |
| *Secure Domain* | Runs IronSide SE; boots first, then releases `cpuapp` (not a user Zephyr target) |

`CONFIG_BOARD_TARGET` in `main.c` prints this string back on boot.

### sysbuild — why `--sysbuild` is required

**Sysbuild** builds *multiple* coordinated images in one command instead of just the app.
On the nRF54H20 a bootable system isn't one binary — sysbuild builds the app-core image
**plus the UICR / multicore-domain artifacts**, keeps their memory maps consistent, and
merges them for flashing. Without it you'd build only the app `.hex` and miss the pieces
the chip needs to boot. (Sysbuild is also the standard way to build app + MCUboot
together.) `build/` gains a nested per-image layout; the app's config still comes from
`prj.conf`.

### UICR

**User Information Configuration Registers** — a small non-volatile region holding
**boot-time system configuration** the hardware/IronSide SE read at reset. On the
nRF54H20 it chiefly encodes the **multicore memory/resource split** (which RAM,
peripherals, and GPIOs belong to which core). Sysbuild generates it and `west flash`
programs it alongside the app.

It sits between the permanence extremes: rewritable (unlike the one-way LCS/fuses) but
rarely changed (unlike app flash). This is why a full **chip erase / recover can wipe
UICR** and disturb the provisioned Secure Domain — avoid those options; normal
`west flash` reprograms app flash + the sysbuild-produced UICR without touching the
irreversible security state.

| Region | Mutability | Holds |
|--------|-----------|-------|
| Fuses / LCS | One-way, permanent | Security lifecycle (`EMPTY → RoT`) |
| **UICR** | Rewritable, rarely | Boot config: multicore memory/resource split |
| BICR | Written once at bring-up | Board hardware facts (crystals, power scheme) |
| App flash | Every build/flash | Your program code + data |

## SoC bring-up (one-time)

The nRF54H20 is a multicore SoC with a hardware **Secure Domain** that boots first and
must be provisioned with Nordic firmware before any user application can run. A
factory-fresh DK is in lifecycle state (LCS) `EMPTY` and cannot simply be flashed with
an app — it has to be initialised through a specific, partly irreversible sequence.

The Secure Domain runs Nordic's **IronSide SE** firmware (Secure Domain + System
Controller), which configures clocks/power and then hands control to the application
core. On SDK v3.4.0 the flow is IronSide SE based (older, pre-3.2 SDKs used SUIT
binaries — stale instructions for that flow are actively wrong here).

**This is done once per device and does not need repeating.** The commands below are run
from the parent workspace folder, where the firmware lives under `bin/`. Steps completed,
in order:

1. **Install & unblock nrfutil** — the official binary (not brew/pip, which ship the
   legacy pre-7.0 tool); cleared the macOS quarantine
   (`xattr -d com.apple.quarantine /usr/local/bin/nrfutil`). Added components
   `sdk-manager`, `device`, `toolchain-manager`, `completion`.
2. **Install NCS SDK + toolchain** — v3.4.0 via `nrfutil sdk-manager`.
3. **Fix DK connectivity** — root cause was a bad USB cable plus the POWER switch off;
   confirmed with `nrfutil device list`.
4. **Configure the on-board debugger** — via `JLinkExe`: `MSDDisable` (MSD can interfere
   with programming) and `SetHWFC Force` (reliable UART), then power-cycle.
5. **Program the BICR** — the Board Information Configuration Registers describe the
   board's physical hardware (power/regulator scheme, LFXO/HFXO crystals, GPIO rails).
   IronSide SE reads it at boot; must be written **before** provisioning.
   ```bash
   nrfutil device program --options chip_erase_mode=ERASE_NONE \
     --firmware bin/bicr.hex --core Application --serial-number 1051113059
   ```
6. **Download IronSide SE binaries** — not shipped inside the SDK; a separate download.
   Nordic's guidance: always provision with the **latest** available (they keep ABI
   compatibility and do **not** support rollback). Used `v23.8.0+33`.
7. **Provision Secure Domain + System Controller** — only works while LCS is `EMPTY`;
   the device stays `EMPTY` afterward. **Silent on success** (exit 0, no output).
   ```bash
   nrfutil device x-provision-nrf54h \
     --firmware bin/nrf54h20_soc_binaries_v23.8.0+33.zip --serial-number 1051113059
   ```
8. **⚠️ Transition lifecycle EMPTY → RoT (permanent, one-way)** — moves the chip to
   **Root of Trust**, the normal secured operational state. Irreversible: it can never
   return to `EMPTY` or be re-provisioned with different binaries.
   ```bash
   nrfutil device x-adac-lcs-change --life-cycle rot --serial-number 1051113059
   nrfutil device reset --reset-kind RESET_PIN --serial-number 1051113059
   ```
   Gotcha: the first attempt failed with `ADAC_UNSUPPORTED (0x0003)`; re-running the
   transition and applying a **`RESET_PIN`** reset resolved it.

Verify state:

```bash
nrfutil device x-adac-discovery --serial-number 1051113059 | grep psa_lifecycle
# → psa_lifecycle  LIFECYCLE_ROT (0x2000)   ✅
```

## Handy reference commands

```bash
# Is the DK connected?
nrfutil device list

# Read lifecycle state + SoC identity
nrfutil device x-adac-discovery --serial-number 1051113059

# Reset the DK
nrfutil device reset --reset-kind RESET_PIN --serial-number 1051113059
```

## Gotchas

- Verify the flow against the **installed** SDK docs, not older web notes — the
  SUIT→IronSide change makes stale instructions actively wrong.
- IronSide SE binaries are a **separate download**; always use the **latest** (no rollback).
- `x-provision-nrf54h` is **silent on success**.
- `EMPTY → RoT` is **permanent**; a `RESET_PIN` reset helped when the first LCS attempt
  returned `ADAC_UNSUPPORTED`.
- Use the **toolchain's `west`**, not a broken system/global one.
- Only one program can hold VCOM0 at a time.

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
