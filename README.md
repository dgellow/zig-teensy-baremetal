# Running Zig baremetal on Teensy 4.1

Simple LED blinking example for Teensy 4.1 using Zig v0.15.

Note that the Zig compiler is still in development and its API changes frequently. The code in this repo is likely to
break in future versions.

## Prerequisites

- Install Zig v0.15 or later from https://ziglang.org/download/

No need to install the ARM toolchain, the build script will download it automatically.

## Building

```sh
# Build the executable
$ zig build

# Compile firmware to IHEX format
$ zig build hex
```

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

---

This repo has been originally based on https://github.com/tsunko/teensy-minimal-bare-metal-zig, and has been updated to
work with the latest Zig compiler, `regz` tool, a more comprehensive `build.zig` and examples.
