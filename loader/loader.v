constant none = 0

allocate(size: u64): link { return 0 as link }
deallocate(address: link): _ { }
internal_is(a: link, b: link): bool { return false }

min(a, b) {
	if a < b return a
	return b
}

page_of(address): u64 { return (address as u64) & (-PAGE_SIZE) }
round_to_page(address): u64 { return ((address as u64) + PAGE_SIZE - 1) & (-PAGE_SIZE) }

constant PAGE_SIZE = 0x1000

constant ERROR_UNSUPPORTED = -1
constant ERROR_OUT_OF_MEMORY = -2
constant ERROR_INVALID_DATA = -3

constant REGION_UNKNOWN = -1
constant REGION_AVAILABLE = 1
constant REGION_RESERVED = 2

pack Segment {
	type: u64
	start: link
	end: link

	size => end - start
}

plain LoadInformation {
	image_base: u64
	image_size: u64
	entry_point: u64
}

compute_image_size(program_headers: link, program_header_count: u64): u64 {
	# Compute how many bytes are required for containing the image in contiguous memory
	image_size = 0

	# Add all the program headers to the output list
	loop (i = 0, i < program_header_count, i++) {
		program_header = (program_headers + i * sizeof(ProgramHeader)) as ProgramHeader

		# Compute the end of this segment
		end = round_to_page(program_header.virtual_address + program_header.segment_memory_size)

		# Segments are relative to the image base, so we can find out the image size this way
		if end > image_size { image_size = end }
	}

	return image_size
}

find_region(available_regions: Segment*, available_region_count: u64, size: u64): i64 {
	if size % PAGE_SIZE != 0 return ERROR_INVALID_DATA

	# Find a region of memory that is large enough to hold the image
	loop (i = 0, i < available_region_count, i++) {
		region = available_regions[i]

		# Verify the region is large enough
		if region.type != REGION_AVAILABLE or region.size < size continue

		start = region.start

		# Take away the required space
		region.start += size
		available_regions[i] = region

		return start as u64
	}

	return ERROR_OUT_OF_MEMORY
}

process_dynamic_section(image_base: u64, program_headers: ProgramHeader*, program_header_count: u64): i64 {
	# Find the dynamic section first
	dynamic_section_entries = none as link

	loop (i = 0, i < program_header_count, i++) {
		program_header = (program_headers + i * sizeof(ProgramHeader)) as ProgramHeader
		if program_header.type != ELF_SEGMENT_TYPE_DYNAMIC continue

		dynamic_section_entries = (image_base + program_header.virtual_address) as link
		stop
	}

	# If we do not find a dynamic section, we just assume there are no dynamic relocations
	if dynamic_section_entries === none return 0

	# Iterate over the entries in the dynamic section and collect information for relocations
	string_table = none as link
	symbol_table = none as link
	relocation_table = none as link
	relocation_table_size = 0
	relocation_table_entry_size = 0
	string_table_size = 0
	symbol_table_entry_size = 0

	entry = dynamic_section_entries as DynamicEntry

	loop {
		if entry.tag == ELF_DYNAMIC_SECTION_TAG_STRING_TABLE {
			string_table = (image_base + entry.value) as link
		} else entry.tag == ELF_DYNAMIC_SECTION_TAG_SYMBOL_TABLE {
			symbol_table = (image_base + entry.value) as link
		} else entry.tag == ELF_DYNAMIC_SECTION_TAG_RELOCATION_TABLE {
			relocation_table = (image_base + entry.value) as link
		} else entry.tag == ELF_DYNAMIC_SECTION_TAG_RELOCATION_TABLE_SIZE {
			relocation_table_size = entry.value
		} else entry.tag == ELF_DYNAMIC_SECTION_TAG_RELOCATION_ENTRY_SIZE {
			relocation_table_entry_size = entry.value
		} else entry.tag == ELF_DYNAMIC_SECTION_TAG_STRING_TABLE_SIZE {
			string_table_size = entry.value
		} else entry.tag == ELF_DYNAMIC_SECTION_TAG_SYMBOL_ENTRY_SIZE {
			symbol_table_entry_size = entry.value
		} else entry.tag == 0 {
			stop
		}

		entry += sizeof(DynamicEntry)
	}

	# Verify we got all
	if string_table === none or 
		symbol_table === none or 
		relocation_table === none or 
		relocation_table_size == 0 or 
		relocation_table_entry_size == 0 or 
		string_table_size == 0 or 
		symbol_table_entry_size == 0 {
		return ERROR_INVALID_DATA
	}

	# Resolve all the relocations
	relocation_count = relocation_table_size / relocation_table_entry_size

	loop (i = 0, i < relocation_count, i++) {
		relocation = (relocation_table + i * relocation_table_entry_size) as RelocationEntry

		# Verify we support the relocation
		if relocation.type != ELF_SYMBOL_TYPE_BASE_RELATIVE_64 {
			return ERROR_INVALID_DATA
		}

		# Figure out where we want to patch and what we want there
		destination = (image_base + relocation.offset) as u64*
		value = (image_base + relocation.addend) as u64

		kernel_mapping = 0xffff800000000000
		destination[] = (kernel_mapping + value)
	}

	return 0
}

export load(data: link, available_regions: Segment*, available_region_count: u64, load_information: LoadInformation): u64 {
	header = data as FileHeader

	# Verify the specified file is a ELF-file and that we support it
	if header.magic_number != ELF_MAGIC_NUMBER or 
		header.class != ELF_CLASS_64_BIT or 
		header.endianness != ELF_LITTLE_ENDIAN or 
		header.machine != ELF_MACHINE_TYPE_X64 or 
		header.type != ELF_OBJECT_FILE_TYPE_DYNAMIC {
		return ERROR_UNSUPPORTED
	}

	# Verify the specified file uses the same data structure for program headers
	if header.program_header_size != sizeof(ProgramHeader) {
		return ERROR_UNSUPPORTED
	}

	# Load information about the program headers
	program_headers = (data + header.program_header_offset) as link
	program_header_count = header.program_header_entry_count

	image_size = compute_image_size(program_headers, program_header_count)

	# Find a contiguous region of memory large enough to hold the executable
	image_base = find_region(available_regions, available_region_count, image_size)
	if image_base < 0 return image_base

	# Load each segment into memory
	loop (i = 0, i < program_header_count, i++) {
		# Load only the loadable segments into memory
		program_header = (program_headers + i * sizeof(ProgramHeader)) as ProgramHeader
		if program_header.type != ELF_SEGMENT_TYPE_LOADABLE and program_header.type != ELF_SEGMENT_TYPE_DYNAMIC continue

		destination = (image_base + program_header.virtual_address) as link
		source = (data + program_header.offset) as link
		remaining = min(program_header.segment_file_size, program_header.segment_memory_size) # Determine how many bytes should be copied from the file into memory

		# Copy the segment into memory
		loop (j = 0, j < remaining, j++) {
			destination[j] = source[j]
		}
	}

	# Process the dynamic section (e.g. dynamic relocations)
	result = process_dynamic_section(image_base, program_headers, program_header_count)
	if result < 0 return result

	# Output information about the loaded executable
	load_information.image_base = image_base
	load_information.image_size = image_size
	load_information.entry_point = image_base + header.entry

	return 0
}
