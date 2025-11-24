MEMORY
{
    /* Define memory regions - RT1062 has 512KB FlexRAM split between ITCM/DTCM/OCRAM */
    /* This config: 128KB ITCM + 128KB DTCM + 256KB OCRAM (from FlexRAM) + 512KB fixed OCRAM */
    ITCM (rwx):  ORIGIN = 0x00000000, LENGTH = 128K
    DTCM (rwx):  ORIGIN = 0x20000000, LENGTH = 128K
    OCRAM (rwx): ORIGIN = 0x20200000, LENGTH = 256K   /* From FlexRAM */
    RAM (rwx):   ORIGIN = 0x20240000, LENGTH = 512K   /* Fixed OCRAM */
    FLASH (rwx): ORIGIN = 0x60000000, LENGTH = 7936K
    ERAM (rwx):  ORIGIN = 0x70000000, LENGTH = 16384K
}

ENTRY(ImageVectorTable)

SECTIONS
{
    /* Flash configuration and bootloader data */
    .text.headers : {
        KEEP(*(.flashconfig))
        FILL(0xFF)
        . = ORIGIN(FLASH) + 0x1000;
        KEEP(*(.ivt))
        KEEP(*(.bootdata))
        . = ALIGN(1024);
    } > FLASH

    /* Code in flash */
    .text.code : {
        KEEP(*(.startup))
        *(.flashmem*)
        . = ALIGN(4);
        KEEP(*(.init))
        __preinit_array_start = .;
        KEEP (*(.preinit_array))
        __preinit_array_end = .;
        __init_array_start = .;
        KEEP (*(.init_array))
        __init_array_end = .;
        . = ALIGN(4);
    } > FLASH

    /* Program memory sections */
    .text.progmem : {
        *(.progmem*)
        . = ALIGN(4);
    } > FLASH

    /* Text section in instruction TCM */
    .text.itcm : {
        . = . + 32; /* MPU to trap NULL pointer deref */
        *(.fastrun)
        *(.text*)
        . = ALIGN(16);
    } > ITCM AT> FLASH

    /* The ARM.exidx section is now placed in OCRAM directly */
    .ARM.exidx.ram : {
        __exidx_start = .;
        /* Explicitly empty section - our Zig code provides the content */
        . = ALIGN(8);
        __exidx_end = .;
    } > OCRAM AT> FLASH

    /* Data in data TCM */
    .data : {
        *(.endpoint_queue)
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.rodata*)))
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.data*)))
        KEEP(*(.vectorsram))
    } > DTCM AT> FLASH

    /* BSS section in data TCM */
    .bss ALIGN(4) : {
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.bss*)))
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(COMMON)))
        . = ALIGN(32);
        . = . + 32; /* MPU to trap stack overflow */
    } > DTCM

    /* DMA buffers in OCRAM */
    .bss.dma (NOLOAD) : {
        *(.hab_log)
        *(.dmabuffers)
        . = ALIGN(32);
    } > OCRAM

    /* External RAM data */
    .bss.extram (NOLOAD) : {
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.externalram)))
        . = ALIGN(32);
    } > ERAM

    /* CSF section */
    .text.csf : {
        FILL(0xFF)
        . = ALIGN(1024);
        KEEP(*(.csf))
        __text_csf_end = .;
    } > FLASH

    /* Define important symbols - without referencing ARM.exidx section */
    _stext = ADDR(.text.itcm);
    _etext = ADDR(.text.itcm) + SIZEOF(.text.itcm);
    _stextload = LOADADDR(.text.itcm);

    _sdata = ADDR(.data);
    _edata = ADDR(.data) + SIZEOF(.data);
    _sdataload = LOADADDR(.data);

    _sbss = ADDR(.bss);
    _ebss = ADDR(.bss) + SIZEOF(.bss);

    _heap_start = ADDR(.bss.dma) + SIZEOF(.bss.dma);
    _heap_end = ORIGIN(OCRAM) + LENGTH(OCRAM);

    _extram_start = ADDR(.bss.extram);
    _extram_end = ADDR(.bss.extram) + SIZEOF(.bss.extram);

    /* FlexRAM configuration: Fixed 128KB ITCM + 128KB DTCM + 256KB OCRAM */
    /* Each bank is 32KB, total 16 banks in 512KB FlexRAM */
    /* Banks 0-3: ITCM (4 * 32K = 128K), Banks 4-7: DTCM (4 * 32K = 128K), Banks 8-15: OCRAM (8 * 32K = 256K) */
    /* GPR17 format: 2 bits per bank - 00=unused 01=OCRAM 10=DTCM 11=ITCM */
    _flexram_bank_config = 0x5555AAAF;  /* Bits0-7: 0xAF=ITCM, Bits8-15: 0xAA=DTCM, Bits16-31: 0x5555=OCRAM */
    _estack = ORIGIN(DTCM) + LENGTH(DTCM);

    _flashimagelen = __text_csf_end - ORIGIN(FLASH);
    _teensy_model_identifier = 0x25;

    /* Debug sections */
    .debug_info     0 : { *(.debug_info) }
    .debug_abbrev   0 : { *(.debug_abbrev) }
    .debug_line     0 : { *(.debug_line) }
    .debug_frame    0 : { *(.debug_frame) }
    .debug_str      0 : { *(.debug_str) }
    .debug_loc      0 : { *(.debug_loc) }
}