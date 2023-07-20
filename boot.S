.intel_syntax noprefix
.global enter_kernel
enter_kernel:

# Disable interrupts while we mess around
cli

# Save the kernel entry point and uefi data
mov qword ptr [kernel_entry_point], rcx
mov qword ptr [uefi_information], rdx

# Enable: fxsave, fxrstor, unmasked simd floating point exceptions
mov rax, cr4
or rax, 0b11000000000
mov cr4, rax

# ---------- Kernel mapping ----------

# Load the first address of the first paging table layer
mov rsi, cr3

# Copy the entries to the new kernel paging table
lea rdi, [kernel_paging_table]
mov rcx, 0x1000
rep movsb

# Map the last entry to the first
lea rdi, [kernel_paging_table]
mov rax, qword ptr [rdi]
mov qword ptr [rdi+(0x100*8)], rax

# Reload the paging table
mov cr3, rdi

# ---------- GDT & TSS ----------

# Load the kernel mapping base
mov rax, 0xffff800000000000

# Use kernel mapping in TSS RSPs and ISTs
add qword ptr [tss64_rsp0], rax
add qword ptr [tss64_ist1], rax

# Insert address of TSS into GDT before loading it
lea rcx, [tss64]
add rcx, rax
mov word ptr [gdt64_tss_address_0], cx
shr rcx, 16
mov byte ptr [gdt64_tss_address_1], cl
shr rcx, 8
mov byte ptr [gdt64_tss_address_2], cl
shr rcx, 8
mov dword ptr [gdt64_tss_address_3], ecx

# Use kernel mapping with GDTR
add qword ptr [gdtr64_address], rax

# Load the 64-bit global descriptor table
lgdt [gdtr64]

# Register TSS from GDT
mov cx, 0x40
ltr cx

# ---------- Stack ----------

# Use kernel mapping with the stack
add rsp, rax

# ---------- Kernel ----------

# First argument
xor rdi, rdi

# Pass the interrupt tables to the kernel
lea rsi, [interrupt_tables]
add rsi, rax

# Pass the interrupt stack pointer
lea rdx, [interrupt_stack_start]
add rdx, rax

# Pass the physical address of GDTR
lea rcx, [gdtr64]

# Pass the uefi data
mov r8, rsi

push rdi # Push zero padding
push qword ptr [uefi_information]
push rcx
push rdx
push rsi
push rdi

# Jump to the kernel using the kernel mapping
add rax, qword ptr [kernel_entry_point]
jmp rax

.section .data

kernel_entry_point: .quad 0
uefi_information: .quad 0 

.align 8
gdt64_start:

# Null descriptor
.word      0x0000
.word      0x0000
.byte      0x00
.byte      0x00
.byte      0x00
.byte      0x00

# Kernel code segment (selector = 0x8)
gdt64_code:
.word      0x0000
.word      0x0000
.byte      0x00
.byte      0b10011010
.byte      0b00100000
.byte      0x00

# Kernel data segment (selector = 0x10)
gdt64_data:
.word      0x0000
.word      0x0000
.byte      0x00
.byte      0b10010010
.byte      0b00000000
.byte      0x00

# User data segment (selector = 0x18)
.word      0x0000
.word      0x0000
.byte      0x00
.byte      0b11110010
.byte      0b00000000
.byte      0x00

# User code segment (selector = 0x20)
.word      0x0000
.word      0x0000
.byte      0x00
.byte      0b11111010
.byte      0b00100000
.byte      0x00

# Padding
.quad 0

# Duplicate: Kernel data segment (selector = 0x30)
gdt64_data_uefi:
.word      0x0000
.word      0x0000
.byte      0x00
.byte      0b10010010
.byte      0b00000000
.byte      0x00

# Duplicate: Kernel code segment (selector = 0x38)
gdt64_code_uefi:
.word      0x0000
.word      0x0000
.byte      0x00
.byte      0b10011010
.byte      0b00100000
.byte      0x00

# TSS segment (selector = 0x40)
gdt64_tss:
.word      0x0068
gdt64_tss_address_0:
.word      0x0000    # TSS address (bits 0-16)
gdt64_tss_address_1:
.byte      0x00      # TSS address (bits 16-24)
.byte      0b10001001 # Present | 64-bit TSS (Available)
.byte      0b00000000
gdt64_tss_address_2:
.byte      0x00      # TSS address (bits 24-32)
gdt64_tss_address_3:
.quad      0x00      # TSS address (bits 32-64)

gdt64_end:

.align 8
gdtr64:
.word gdt64_end - gdt64_start - 1
gdtr64_address:
.quad gdt64_start

# --- TSS (64-bit) ---

.align 8
tss64:
.long 0 # reserved
tss64_rsp0:
.quad interrupt_stack_start # rsp0
.quad 0 # rsp1
.quad 0 # rsp2
.quad 0 # reserved
tss64_ist1:
.quad interrupt_stack_start # ist1
.quad 0 # ist2
.quad 0 # ist3
.quad 0 # ist4
.quad 0 # ist5
.quad 0 # ist6
.quad 0 # ist7
.quad 0 # reserved
.word 0 # reserved
.word 104 # iopb

# --- Configuration ---

.align 0x1000
kernel_paging_table:
.zero 0x1000

.align 0x1000
interrupt_tables:
.zero 0x1000 # interrupt descriptor table descriptor (idtr)
.zero 0x1000 # interrupt descriptor table (idt)
.zero 0x1000 # interrupt entries

.zero 0x25000
interrupt_stack_start:

.zero 0x25000
kernel_stack_start:
