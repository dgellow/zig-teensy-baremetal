MEMORY
{
    /* Define memory regions */
    ITCM (rwx):  ORIGIN = 0x00000000, LENGTH = 512K
    DTCM (rwx):  ORIGIN = 0x20000000, LENGTH = 512K
    RAM (rwx):   ORIGIN = 0x20200000, LENGTH = 512K
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

    /* The ARM.exidx section is now placed in RAM directly */
    /* We'll explicitly place this in RAM instead of ITCM to avoid relocation issues */
    .ARM.exidx.ram : {
        __exidx_start = .;
        /* Explicitly empty section - our Zig code provides the content */
        . = ALIGN(8);
        __exidx_end = .;
    } > RAM AT> FLASH

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

    /* DMA buffers in RAM */
    .bss.dma (NOLOAD) : {
        *(.hab_log)
        *(.dmabuffers)
        . = ALIGN(32);
    } > RAM

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
    _heap_end = ORIGIN(RAM) + LENGTH(RAM);

    _extram_start = ADDR(.bss.extram);
    _extram_end = ADDR(.bss.extram) + SIZEOF(.bss.extram);

    /* FlexRAM configuration without referencing ARM.exidx section */
    _itcm_block_count = (SIZEOF(.text.itcm) + 0x7FFF) >> 15;
    _flexram_bank_config = 0xAAAAAAAA | ((1 << (_itcm_block_count * 2)) - 1);
    _estack = ORIGIN(DTCM) + ((16 - _itcm_block_count) << 15);

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