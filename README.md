# Running Zig baremetal on Teensy 4.1

Simple LED blinking example for Teensy 4.1 using Zig v0.15.

Note that the Zig compiler is still in development and its API changes frequently. The code in this repo is likely to
break in future versions.

## Prerequisites

- Install Zig v0.15 or later from https://ziglang.org/download/
- Install the GNU ARM toolchain from https://developer.arm.com/downloads/-/gnu-rm
  - On Windows you can install it using `winget install Arm.GnuArmEmbeddedToolchain`. You may need to log out of your
    Windows session to have your `$env:Path` updated.
    Or run `$env:Path = "C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi\14.2 rel1\bin;$env:Path"` in your PowerShell session.
- TyTools (optional, but recommended) for flashing the board, from https://koromix.dev/tytools

## Building

```sh
# Build the executable
$ zig build

# Build the IHEX file for flashing
$ arm-none-eabi-objcopy --output-target ihex --remove-section .eeprom ./zig-out/bin/teensy_zig teensy_zig.hex
```

### Generating register wrapper

The generated file is `src/imxrt1062.zig`. It has been generated using `regz`, with a minimal amount of manually fixes.

The original file can be re-generated, using `MIMXRT1062.svd` as the input:

```sh
$ git submodule update --init
$ cd deps/microzig/tools/regz
$ zig build
$ ./zig-out/bin/regz --output_path ../../../../src/imxrt1062.zig --format svd ../../../../MIMXRT1062.svd
```

`zig build` does require that file to be present in `./src`.

## Flashing

You can use TyTools to flash the generated IHEX file to the Teensy 4.1 board.

```sh
$ tycmd list
add 16740150-Teensy Teensy 4.1 (HalfKay)
$ tycmd upload --board 16740150-Teensy teensy_zig.hex
upload@16740150-Teensy  Uploading to board '16740150-Teensy' (Teensy 4.1)
upload@16740150-Teensy  Firmware: teensy_zig.hex
upload@16740150-Teensy  Flash usage: 6 kiB (0.1%)
upload@16740150-Teensy  Uploading... 100%
upload@16740150-Teensy  Sending reset command (with RTC)
upload@16740150-Teensy  Board '16740150-Teensy' has disappeared
```

---

This repo has been originally based on https://github.com/tsunko/teensy-minimal-bare-metal-zig, and has been updated to
work with the latest Zig compiler and `regz` tool.
