/*
 * Memory Layout for Teensy 4.1 (i.MX RT1062)
 * ==========================================
 *
 * The RT1062 has multiple types of RAM with different characteristics:
 *
 * 1. FlexRAM (512KB total) - Configurable as ITCM/DTCM/OCRAM
 *    - ITCM: Instruction Tightly Coupled Memory - zero-wait-state code execution
 *    - DTCM: Data Tightly Coupled Memory - zero-wait-state data access
 *    - OCRAM: On-Chip RAM - general purpose RAM, DMA-accessible
 *
 * 2. Fixed OCRAM (512KB) - Always OCRAM, cannot be reconfigured
 *
 * 3. External RAM (16MB) - Optional external PSRAM on Teensy 4.1
 *
 * Configuration chosen:
 *   - 128KB ITCM: Fast code execution (CPU cache)
 *   - 128KB DTCM: Fast data/stack (CPU cache)
 *   - 256KB OCRAM: DMA buffers, heap (from FlexRAM)
 *   - 512KB RAM: Additional general-purpose memory (fixed OCRAM)
 */
MEMORY
{
    /* ITCM - Instruction Tightly Coupled Memory
     * CPU fetches code from here with zero wait states
     * Located at address 0x00000000 (CPU's memory map) */
    ITCM (rwx):  ORIGIN = 0x00000000, LENGTH = 128K

    /* DTCM - Data Tightly Coupled Memory
     * CPU accesses data here with zero wait states
     * Used for stack, initialized data (.data), and zero-initialized data (.bss) */
    DTCM (rwx):  ORIGIN = 0x20000000, LENGTH = 128K

    /* OCRAM - On-Chip RAM (from FlexRAM)
     * General-purpose RAM, accessible by DMA controllers
     * Used for DMA buffers (USB, etc.) and heap */
    OCRAM (rwx): ORIGIN = 0x20200000, LENGTH = 256K

    /* RAM - Additional On-Chip RAM (fixed OCRAM, not from FlexRAM)
     * This 512KB is always OCRAM and cannot be reconfigured
     * Provides additional general-purpose memory beyond FlexRAM */
    RAM (rwx):   ORIGIN = 0x20240000, LENGTH = 512K

    /* FLASH - External QSPI Flash Memory
     * 8MB total, but first 64KB reserved for bootloader
     * Code and constant data are stored here and copied to RAM at boot */
    FLASH (rwx): ORIGIN = 0x60000000, LENGTH = 7936K

    /* ERAM - External PSRAM (optional on Teensy 4.1)
     * 16MB external RAM chip, useful for large buffers
     * Slower than on-chip RAM but provides much more space */
    ERAM (rwx):  ORIGIN = 0x70000000, LENGTH = 16384K
}

/* Entry point for the bootloader */
ENTRY(ImageVectorTable)

SECTIONS
{
    /* ===== FLASH SECTIONS ===== */
    /* These sections remain in flash and are not copied to RAM */

    /* Flash configuration and bootloader data
     * The RT1062 bootloader expects specific structures at fixed offsets:
     * - 0x0000-0x0FFF: Flash configuration (FCB)
     * - 0x1000: Image Vector Table (IVT) - tells bootloader where code is
     * - After IVT: Boot data - describes flash image */
    .text.headers : {
        KEEP(*(.flashconfig))     /* Flash Configuration Block (FCB) at offset 0 */
        FILL(0xFF)                /* Pad with 0xFF (erased flash state) */
        . = ORIGIN(FLASH) + 0x1000;  /* IVT must be at offset 0x1000 */
        KEEP(*(.ivt))             /* Image Vector Table */
        KEEP(*(.bootdata))        /* Boot data structure */
        . = ALIGN(1024);          /* Align to 1KB boundary */
    } > FLASH

    /* Startup code and initialization arrays
     * This code runs from flash before main() is called
     * Includes C++ constructors and initialization functions */
    .text.code : {
        KEEP(*(.startup))         /* Early startup code (stack setup, etc.) */
        *(.flashmem*)             /* Code that should stay in flash */
        . = ALIGN(4);
        KEEP(*(.init))            /* Initialization code */
        __preinit_array_start = .;
        KEEP (*(.preinit_array))  /* Pre-initialization function pointers */
        __preinit_array_end = .;
        __init_array_start = .;
        KEEP (*(.init_array))     /* Initialization function pointers (C++ constructors) */
        __init_array_end = .;
        . = ALIGN(4);
    } > FLASH

    /* Read-only data that stays in flash
     * Used for large constant data that doesn't need to be in RAM */
    .text.progmem : {
        *(.progmem*)              /* Program memory (const data in flash) */
        . = ALIGN(4);
    } > FLASH

    /* ===== ITCM SECTION ===== */
    /* Main program code - copied from flash to ITCM at startup
     * The "> ITCM AT> FLASH" syntax means:
     *   - Runtime address (VMA): ITCM (where code executes from)
     *   - Load address (LMA): FLASH (where code is stored)
     * Startup code copies from FLASH to ITCM before main() */
    .text.itcm : {
        . = . + 32;               /* 32-byte guard zone - MPU can trap NULL pointer dereference */
        *(.fastrun)               /* Functions marked for fast execution */
        *(.text*)                 /* All program code */
        . = ALIGN(16);            /* Align for cache line efficiency */
    } > ITCM AT> FLASH

    /* ===== OCRAM SECTION ===== */
    /* ARM exception index table (used for C++ exceptions and stack unwinding)
     * Placed in OCRAM but currently unused in Zig baremetal code */
    .ARM.exidx.ram : {
        __exidx_start = .;
        /* Explicitly empty section - our Zig code provides the content */
        . = ALIGN(8);             /* ARM requires 8-byte alignment */
        __exidx_end = .;
    } > OCRAM AT> FLASH

    /* ===== DTCM SECTIONS ===== */
    /* Fast-access data - initialized variables and constants
     * Copied from flash to DTCM at startup, similar to .text.itcm */
    .data : {
        *(.endpoint_queue)        /* USB endpoint queue (needs fast access) */
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.rodata*)))  /* Read-only data (constants) */
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.data*)))    /* Initialized global variables */
        KEEP(*(.vectorsram))      /* Interrupt vector table in RAM */
    } > DTCM AT> FLASH

    /* Zero-initialized data (BSS - Block Started by Symbol)
     * Not stored in flash - just allocated space in DTCM
     * Startup code zeros this section before main()
     * NOLOAD is implied for .bss sections */
    .bss ALIGN(4) : {
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.bss*)))     /* Zero-initialized variables */
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(COMMON)))    /* Common symbols */
        . = ALIGN(32);            /* Align for cache efficiency */
        . = . + 32;               /* 32-byte guard zone - MPU can trap stack overflow */
    } > DTCM

    /* DMA buffers - must be in OCRAM (DMA controllers cannot access DTCM/ITCM)
     * NOLOAD means this section is not stored in flash - just reserves space
     * Used for USB buffers, peripheral DMA, etc. */
    .bss.dma (NOLOAD) : {
        *(.hab_log)               /* High Assurance Boot log */
        *(.dmabuffers)            /* DMA-accessible buffers (USB, SPI, etc.) */
        . = ALIGN(32);            /* DMA often requires 32-byte alignment */
    } > OCRAM

    /* External RAM data (optional PSRAM chip)
     * Used for large buffers that don't fit in on-chip RAM
     * Slower access than on-chip RAM but provides 16MB space */
    .bss.extram (NOLOAD) : {
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.externalram)))  /* Large buffers */
        . = ALIGN(32);            /* Cache line alignment */
    } > ERAM

    /* Code Signing Format (CSF) section
     * Used for NXP's High Assurance Boot (HAB) security
     * Must be at end of flash image for proper signing */
    .text.csf : {
        FILL(0xFF)                /* Pad with erased flash state */
        . = ALIGN(1024);          /* CSF requires 1KB alignment */
        KEEP(*(.csf))             /* Code signing data */
        __text_csf_end = .;       /* Mark end of flash image */
    } > FLASH

    /* ===== LINKER SYMBOLS ===== */
    /* These symbols are used by startup code to copy/initialize memory */

    /* Text (code) section symbols - for copying code from FLASH to ITCM */
    _stext = ADDR(.text.itcm);          /* Start address in ITCM (where to copy TO) */
    _etext = ADDR(.text.itcm) + SIZEOF(.text.itcm);  /* End address in ITCM */
    _stextload = LOADADDR(.text.itcm);  /* Start address in FLASH (where to copy FROM) */

    /* Data section symbols - for copying initialized data from FLASH to DTCM */
    _sdata = ADDR(.data);               /* Start address in DTCM (where to copy TO) */
    _edata = ADDR(.data) + SIZEOF(.data);  /* End address in DTCM */
    _sdataload = LOADADDR(.data);       /* Start address in FLASH (where to copy FROM) */

    /* BSS section symbols - for zeroing uninitialized data in DTCM */
    _sbss = ADDR(.bss);                 /* Start of BSS section */
    _ebss = ADDR(.bss) + SIZEOF(.bss);  /* End of BSS section */

    /* Heap boundaries (dynamic memory allocation area in OCRAM) */
    _heap_start = ADDR(.bss.dma) + SIZEOF(.bss.dma);  /* After DMA buffers */
    _heap_end = ORIGIN(OCRAM) + LENGTH(OCRAM);        /* End of OCRAM region */

    /* External RAM boundaries */
    _extram_start = ADDR(.bss.extram);
    _extram_end = ADDR(.bss.extram) + SIZEOF(.bss.extram);

    /* FlexRAM Bank Configuration
     * FlexRAM is 512KB split into 16 banks of 32KB each
     * Each bank can be configured as ITCM, DTCM, or OCRAM via GPR17 register
     *
     * Our configuration (128KB ITCM + 128KB DTCM + 256KB OCRAM):
     *   Banks 0-3:   ITCM  (4 banks × 32KB = 128KB)
     *   Banks 4-7:   DTCM  (4 banks × 32KB = 128KB)
     *   Banks 8-15:  OCRAM (8 banks × 32KB = 256KB)
     *
     * GPR17 encoding: 2 bits per bank
     *   00 = unused
     *   01 = OCRAM
     *   10 = DTCM
     *   11 = ITCM
     *
     * Value breakdown:
     *   Bits 0-7   (Banks 0-3):   0xAF = 0b10101111 = ITCM, ITCM, ITCM, ITCM
     *   Bits 8-15  (Banks 4-7):   0xAA = 0b10101010 = DTCM, DTCM, DTCM, DTCM
     *   Bits 16-31 (Banks 8-15):  0x5555 = 0b0101010101010101 = OCRAM × 8
     */
    _flexram_bank_config = 0x5555AAAF;

    /* Stack pointer - grows downward from end of DTCM */
    _estack = ORIGIN(DTCM) + LENGTH(DTCM);

    /* Flash image metadata */
    _flashimagelen = __text_csf_end - ORIGIN(FLASH);  /* Total size of flash image */
    _teensy_model_identifier = 0x25;                  /* 0x25 = Teensy 4.1 */

    /* ===== DEBUG SECTIONS ===== */
    /* Debug information for GDB and other debuggers
     * These sections are not loaded to the device (address 0 = not allocated)
     * They remain in the .elf file for debugging purposes */
    .debug_info     0 : { *(.debug_info) }      /* Debug information entries */
    .debug_abbrev   0 : { *(.debug_abbrev) }    /* Abbreviations used in debug_info */
    .debug_line     0 : { *(.debug_line) }      /* Line number information */
    .debug_frame    0 : { *(.debug_frame) }     /* Call frame information */
    .debug_str      0 : { *(.debug_str) }       /* String table for debug info */
    .debug_loc      0 : { *(.debug_loc) }       /* Location lists */
}