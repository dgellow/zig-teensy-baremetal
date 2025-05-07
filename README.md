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

```sh
# You can see the list of Teensy devices. Prints nothing if no board in bootloader mode is connected.
$ zig build port
usb:0/140000/0/A hid#vid_16c0&pid_0478 (Teensy 4.1) Bootloader

# And upload the firmware to the Teensy device
$ zig build upload # by default will try to select a board

# You can also specify the port
$ zig build upload -Dupload-port=usb:0/140000/0/A
```

---

This repo has been originally based on https://github.com/tsunko/teensy-minimal-bare-metal-zig, and has been updated to
work with the latest Zig compiler, `regz` tool, a more comprehensive `build.zig` and examples.
