constant ELF_MAGIC_NUMBER = 0x464c457F

constant ELF_CLASS_32_BIT = 1
constant ELF_CLASS_64_BIT = 2

constant ELF_LITTLE_ENDIAN = 1
constant ELF_BIG_ENDIAN = 2

constant ELF_OBJECT_FILE_TYPE_RELOCATABLE = 1
constant ELF_OBJECT_FILE_TYPE_EXECUTABLE = 2
constant ELF_OBJECT_FILE_TYPE_DYNAMIC = 3

constant ELF_MACHINE_TYPE_X64 = 0x3E
constant ELF_MACHINE_TYPE_ARM64 = 0xB7

constant ELF_SEGMENT_TYPE_LOADABLE = 1
constant ELF_SEGMENT_TYPE_DYNAMIC = 2
constant ELF_SEGMENT_TYPE_INTERPRETER = 3
constant ELF_SEGMENT_TYPE_PROGRAM_HEADER = 6

constant ELF_SEGMENT_FLAG_EXECUTE = 1
constant ELF_SEGMENT_FLAG_WRITE = 2
constant ELF_SEGMENT_FLAG_READ = 4

plain FileHeader {
	magic_number: u32 = 0x464c457F
	class: u8 = 2
	endianness: u8 = 1
	version: u8 = 1
	os_abi: u8 = 0
	abi_version: u8 = 0
	padding1: u32 = 0
	padding2: u16 = 0
	padding3: u8 = 0
	type: u16
	machine: u16
	version2: u32 = 1
	entry: u64 = 0
	program_header_offset: u64
	section_header_offset: u64
	flags: u32
	file_header_size: u16
	program_header_size: u16
	program_header_entry_count: u16
	section_header_size: u16
	section_header_table_entry_count: u16
	section_name_entry_index: u16
}

plain ProgramHeader {
	type: u32
	flags: u32
	offset: u64
	virtual_address: u64
	physical_address: u64
	segment_file_size: u64
	segment_memory_size: u64
	alignment: u64
}

constant ELF_SECTION_TYPE_NONE = 0x00
constant ELF_SECTION_TYPE_PROGRAM_DATA = 0x1
constant ELF_SECTION_TYPE_SYMBOL_TABLE = 0x02
constant ELF_SECTION_TYPE_STRING_TABLE = 0x03
constant ELF_SECTION_TYPE_RELOCATION_TABLE = 0x04
constant ELF_SECTION_TYPE_HASH = 0x05
constant ELF_SECTION_TYPE_DYNAMIC = 0x06
constant ELF_SECTION_TYPE_DYNAMIC_SYMBOLS = 0x0B

constant ELF_SECTION_FLAG_NONE = 0x00
constant ELF_SECTION_FLAG_WRITE = 0x01
constant ELF_SECTION_FLAG_ALLOCATE = 0x02
constant ELF_SECTION_FLAG_EXECUTABLE = 0x04
constant ELF_SECTION_FLAG_INFO_LINK = 0x40

plain SectionHeader {
	name: u32
	type: u32
	flags: u64
	virtual_address: u64
	offset: u64
	section_file_size: u64
	link: u32
	info: u32
	alignment: u64
	entry_size: u64
}

constant ELF_SYMBOL_BINDING_LOCAL = 0x00
constant ELF_SYMBOL_BINDING_GLOBAL = 0x01

plain SymbolEntry {
	name: u32 = 0
	info: u8 = 0
	other: u8 = 0
	section_index: u16 = 0
	value: u64 = 0
	symbol_size: u64 = 0

	set_info(binding: i32, type: i32) {
		info = (binding <| 4) | type
	}

	is_exported => (info |> 4) === ELF_SYMBOL_BINDING_GLOBAL and section_index !== 0
}

constant ELF_SYMBOL_TYPE_NONE = 0x00
constant ELF_SYMBOL_TYPE_ABSOLUTE64 = 0x01
constant ELF_SYMBOL_TYPE_PROGRAM_COUNTER_RELATIVE = 0x02
constant ELF_SYMBOL_TYPE_PLT32 = 0x04
constant ELF_SYMBOL_TYPE_JUMP_SLOT = 0x07
constant ELF_SYMBOL_TYPE_BASE_RELATIVE_64 = 0x08
constant ELF_SYMBOL_TYPE_ABSOLUTE32 = 0x0A

plain RelocationEntry {
	offset: u64
	info: u64 = 0
	addend: i64

	symbol => (info |> 32) as i32
	type => (info & 0xFFFFFFFF) as i32

	init() {}

	init(offset: u64, addend: i64) {
		this.offset = offset
		this.addend = addend
	}

	set_info(symbol: u64, type: u64) {
		info = (symbol <| 32) | type
	}
}

constant ELF_DYNAMIC_SECTION_TAG_NEEDED = 0x01
constant ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_BYTES = 0x02
constant ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_GLOBAL_OFFSET_TABLE = 0x03
constant ELF_DYNAMIC_SECTION_TAG_HASH_TABLE = 0x04
constant ELF_DYNAMIC_SECTION_TAG_STRING_TABLE = 0x05
constant ELF_DYNAMIC_SECTION_TAG_SYMBOL_TABLE = 0x06
constant ELF_DYNAMIC_SECTION_TAG_RELOCATION_TABLE = 0x07
constant ELF_DYNAMIC_SECTION_TAG_RELOCATION_TABLE_SIZE = 0x08
constant ELF_DYNAMIC_SECTION_TAG_RELOCATION_ENTRY_SIZE = 0x09
constant ELF_DYNAMIC_SECTION_TAG_STRING_TABLE_SIZE = 0x0A
constant ELF_DYNAMIC_SECTION_TAG_SYMBOL_ENTRY_SIZE = 0x0B
constant ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_TYPE = 0x14
constant ELF_DYNAMIC_SECTION_TAG_FUNCTION_LINKAGE_TABLE_RELOCATION_TABLE = 0x17
constant ELF_DYNAMIC_SECTION_TAG_BIND_NOW = 0x18
constant ELF_DYNAMIC_SECTION_TAG_RELOCATION_COUNT = 0x6ffffff9

plain DynamicEntry {
	constant POINTER_OFFSET = 8

	tag: u64
	value: u64

	init(tag: u64, value: u64) {
		this.tag = tag
		this.value = value
	}
}

constant TEXT_SECTION = '.text'
constant DATA_SECTION = '.data'
constant SYMBOL_TABLE_SECTION = '.symtab'
constant STRING_TABLE_SECTION = '.strtab'
constant SECTION_HEADER_STRING_TABLE_SECTION = '.shstrtab'
constant DYNAMIC_SECTION = '.dynamic'
constant DYNAMIC_SYMBOL_TABLE_SECTION = '.dynsym'
constant DYNAMIC_STRING_TABLE_SECTION = '.dynstr'
constant HASH_SECTION = '.hash'
constant RELOCATION_TABLE_SECTION_PREFIX = '.rela'
constant DYNAMIC_RELOCATIONS_SECTION = '.rela.dyn'
constant GLOBAL_OFFSET_TABLE_SECTION = '.got'
constant FUNCTION_LINKAGE_TABLE_SECTION = '.plt'
constant INTERPRETER_SECTION = '.interp'
