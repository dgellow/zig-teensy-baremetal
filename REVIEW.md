# Project Review: Linker Script and Memory Configuration

## Summary
Reviewed the entire project to verify correctness after updating the linker script with proper FlexRAM configuration for Teensy 4.1 (i.MX RT1062).

## Status: ✅ MOSTLY CORRECT

The project's memory configuration is now correct and properly aligned with the linker script. However, there is **one potential issue** in third-party code that could cause problems during USB reboot.

---

## Memory Configuration

### Linker Script (`linker_script.ld`)
✅ **CORRECT** - Properly configured for RT1062 hardware:
- **ITCM**: 128KB @ 0x00000000 (zero-wait-state code execution)
- **DTCM**: 128KB @ 0x20000000 (zero-wait-state data access, stack)
- **OCRAM**: 256KB @ 0x20200000 (from FlexRAM, DMA-accessible)
- **RAM**: 512KB @ 0x20240000 (fixed OCRAM, general purpose)
- **FLASH**: 7936KB @ 0x60000000 (QSPI flash)
- **ERAM**: 16MB @ 0x70000000 (external PSRAM)

### FlexRAM Configuration
✅ **CORRECT** - `_flexram_bank_config = 0x5555AAAF`
- Banks 0-3: ITCM (0xAF = 0b10101111)
- Banks 4-7: DTCM (0xAA = 0b10101010)
- Banks 8-15: OCRAM (0x5555 = 0b0101010101010101)

---

## Code Review Results

### 1. Startup Code (`src/_startup.zig`)
✅ **CORRECT**

**FlexRAM Initialization** (lines 401-415):
```zig
peripherals.IOMUXC_GPR.GPR17.raw = _flexram_bank_config;  // ✅ Uses value, not pointer
peripherals.IOMUXC_GPR.GPR16.raw = 0x00000007;           // ✅ Correct
peripherals.IOMUXC_GPR.GPR14.raw = 0x00770000;           // ✅ Correct (128KB ITCM+DTCM)
```

**Memory Initialization** (lines 423-426):
```zig
_startup_memcpy(&_stext, &_stextload, &_etext);   // ✅ Copy code to ITCM
_startup_memcpy(&_sdata, &_sdataload, &_edata);   // ✅ Copy data to DTCM
_startup_memclr(&_sbss, &_ebss);                  // ✅ Zero BSS in DTCM
```

**Vector Table Initialization** (lines 369-371, 429-431):
```zig
pub export var _VectorsRam: [NVIC_NUM_INTERRUPTS + 16]?*const fn () callconv(.C) void =
    [_]?*const fn() callconv(.C) void{unused_interrupt_vector} ** (NVIC_NUM_INTERRUPTS + 16);
```
✅ Properly initialized to default handler (prevents crashes on early interrupts)

**Stack Setup** (lines 417-420):
```zig
asm volatile ("mov sp, %[arg1]"
    :
    : [arg1] "{r0}" (@intFromPtr(&_estack)),
);
```
✅ Stack pointer set to end of DTCM (0x20020000)

### 2. Build Configuration (`build.zig`)
✅ **CORRECT**

- Target: ARM Cortex-M7 (thumb mode, freestanding)
- Linker script: `linker_script.ld` (line 101)
- Entry point: `ImageVectorTable` (line 98)
- FPU settings: `-mfloat-abi=hard -mfpu=fpv5-d16` ✅
- Teensy startup.c is **NOT** compiled (line 208 commented out) ✅

### 3. USB Library Memory Layout
✅ **CORRECT**

**Endpoint Queue** (`deps/teensyduino-lib/teensy4/usb.c:61`):
```c
endpoint_t endpoint_queue_head[(NUM_ENDPOINTS+1)*2]
    __attribute__ ((used, aligned(4096), section(".endpoint_queue")));
```
- Placed in `.endpoint_queue` section → goes to DTCM (fast access) ✅
- Requires 4096-byte alignment
- DTCM starts at 0x20000000 (4096-byte aligned) ✅
- `.endpoint_queue` is first in `.data` section → placed at 0x20000000 ✅

**DMA Buffers** (`deps/teensyduino-lib/teensy4/avr/pgmspace.h:28`):
```c
#define DMAMEM __attribute__ ((section(".dmabuffers"), used))
```
- DMAMEM buffers placed in `.dmabuffers` section
- Linker script places `.bss.dma` (containing `.dmabuffers`) in OCRAM ✅
- DMA controllers can access OCRAM but NOT DTCM/ITCM ✅

### 4. Section Placement
✅ **CORRECT**

| Section | Memory | Reason |
|---------|--------|--------|
| `.text.itcm` | ITCM | Fast code execution |
| `.data` | DTCM | Fast data access |
| `.bss` | DTCM | Zero-initialized data |
| `.endpoint_queue` | DTCM | Fast USB endpoint access |
| `.dmabuffers` | OCRAM | DMA controllers need OCRAM access |
| `.bss.dma` | OCRAM | DMA-accessible buffers |
| `.externalram` | ERAM | Large buffers (optional PSRAM) |

---

## Issues Found

### ⚠️ Issue #1: USB Reboot Function Has Hardcoded Memory Addresses
**File**: `deps/teensyduino-lib/teensy4/usb.c`
**Lines**: 218-224
**Severity**: MEDIUM (only affects reboot functionality)

```c
FLASHMEM __attribute__((noinline)) void _reboot_Teensyduino_(void)
{
    ...
    IOMUXC_GPR_GPR16 = 0x00200003;  // ⚠️ Conflicts with our 0x00000007
    __asm__ volatile("mov sp, %0" : : "r" (0x20201000) : );  // ⚠️ Stack in middle of OCRAM
    volatile uint32_t * const p = (uint32_t *)0x20208000;    // ⚠️ Hardcoded OCRAM address
    ...
}
```

**Analysis**:
- This function is called when the device needs to reboot into bootloader mode
- It sets GPR16 to `0x00200003` which would reconfigure FlexRAM differently than our setup
- It moves stack to `0x20201000` (in our OCRAM region at 0x20200000-0x20240000)
- These hardcoded addresses assume a different memory layout (likely the original Teensyduino configuration)

**Impact**:
- USB reboot functionality may not work correctly
- System reboot/bootloader entry might fail or behave unexpectedly
- Does NOT affect normal operation (LED blinking, USB serial during runtime)

**Recommendation**:
1. **If USB reboot is not needed**: No action required. The main firmware works fine.
2. **If USB reboot is needed**: Create a custom reboot function that uses our memory layout:
   ```zig
   // In src/_startup.zig or separate file
   export fn _reboot_Teensyduino_() callconv(.C) void {
       // Disable interrupts
       asm volatile("cpsid i");

       // Restore default FlexRAM config or use bootloader config
       peripherals.IOMUXC_GPR.GPR17.raw = 0xAAAAAAAA;  // All DTCM (or bootloader default)
       peripherals.IOMUXC_GPR.GPR16.raw = 0x00000007;  // Or appropriate boot config

       // Jump to bootloader (platform-specific)
       // ...
   }
   ```

---

## Memory Initialization Verification

### Symbols from Linker Script
All symbols are correctly defined and used:

| Symbol | Purpose | Used In |
|--------|---------|---------|
| `_stext` | ITCM start address | _startup.zig:424 |
| `_etext` | ITCM end address | _startup.zig:424 |
| `_stextload` | FLASH code location | _startup.zig:424 |
| `_sdata` | DTCM data start | _startup.zig:425 |
| `_edata` | DTCM data end | _startup.zig:425 |
| `_sdataload` | FLASH data location | _startup.zig:425 |
| `_sbss` | BSS start | _startup.zig:426 |
| `_ebss` | BSS end | _startup.zig:426 |
| `_flexram_bank_config` | FlexRAM config value | _startup.zig:404 |
| `_estack` | Stack top (DTCM end) | _startup.zig:419 |

✅ All symbols properly used in startup code

---

## Conclusion

### What Works ✅
1. **Memory layout**: Correctly matches RT1062 hardware capabilities
2. **FlexRAM configuration**: Properly splits 512KB between ITCM/DTCM/OCRAM
3. **Startup code**: Correctly initializes memory and peripherals
4. **Section placement**: All sections placed in appropriate memory regions
5. **DMA buffers**: Correctly placed in OCRAM (DMA-accessible)
6. **Vector table**: Properly initialized and aligned
7. **Build system**: Correct compiler flags and linker settings

### What May Not Work ⚠️
1. **USB reboot to bootloader**: Hardcoded addresses in `_reboot_Teensyduino_()` conflict with our memory layout

### Recommendations
1. ✅ **No immediate action needed** - The core firmware is correct
2. ⚠️ **Future consideration**: If USB bootloader reboot is needed, implement custom reboot function
3. ✅ **Documentation**: Linker script is now well-documented (added in commit c1ba45c)

---

## Files Reviewed
- ✅ `linker_script.ld` - Memory layout and section placement
- ✅ `src/_startup.zig` - System initialization and memory setup
- ✅ `src/main.zig` - Application code
- ✅ `build.zig` - Build configuration
- ✅ `deps/teensyduino-lib/teensy4/usb.c` - USB driver (found reboot issue)
- ✅ `deps/teensyduino-lib/teensy4/usb_desc.c` - USB descriptors
- ✅ `deps/teensyduino-lib/teensy4/avr/pgmspace.h` - DMAMEM definition

**Review Date**: 2025-11-25
**Reviewed By**: Claude (Sonnet 4.5)
**Project**: zig-teensy-baremetal (Teensy 4.1)
