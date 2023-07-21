#include <uefi.h>

const int switch_video_mode = 0;

struct MemoryMap {
	efi_memory_descriptor_t* descriptors;
	uintn_t descriptor_size;
	uintn_t size;
};

#define REGION_UNKNOWN -1
#define REGION_AVAILABLE 1
#define REGION_RESERVED 2

struct Segment {
	uint64_t type;
	uint8_t* start;
	uint8_t* end;
};

struct LoadInformation {
	uint64_t image_base;
	uint64_t image_size;
	uint64_t entry_point;
};

struct GraphicsInformation {
	uint64_t framebuffer_physical_address;
	int64_t horizontal_stride;
	int64_t width;
	int64_t height;
};

struct UefiData {
	efi_system_table_t* system_table;
	struct Segment* regions;
	uint64_t region_count;
	uint64_t physical_memory_size;
	uint64_t memory_map_end;
	uint8_t* bitmap_font_file;
	uint64_t bitmap_font_file_size;
	uint8_t* bitmap_font_descriptor_file;
	uint64_t bitmap_font_descriptor_file_size;
	struct GraphicsInformation graphics_information;
};

extern int64_t _V4loadPhPP7SegmentyP15LoadInformation_ry(uint8_t* data, struct Segment* available_regions, uint64_t available_region_count, struct LoadInformation* load_information);

extern void enter_kernel(uint64_t entry_point, struct UefiData* data);

const char* memory_map_types[] = {
	"EfiReservedMemoryType",
	"EfiLoaderCode",
	"EfiLoaderData",
	"EfiBootServicesCode",
	"EfiBootServicesData",
	"EfiRuntimeServicesCode",
	"EfiRuntimeServicesData",
	"EfiConventionalMemory",
	"EfiUnusableMemory",
	"EfiACPIReclaimMemory",
	"EfiACPIMemoryNVS",
	"EfiMemoryMappedIO",
	"EfiMemoryMappedIOPortSpace",
	"EfiPalCode"
};

void print_memory_map(struct MemoryMap map) {
	printf("Memory map:\n");
	printf("Address              Size Type\n");

	uintn_t total_available_pages = 0;
	uintn_t total_boot_pages = 0;
	uintn_t total_reserved_pages = 0;

	for (efi_memory_descriptor_t* descriptor = map.descriptors; (uint8_t*)descriptor < (uint8_t*)map.descriptors + map.size; descriptor = NextMemoryDescriptor(descriptor, map.descriptor_size)) {
		printf("%016x %8d %02x %s\n", descriptor->PhysicalStart, descriptor->NumberOfPages, descriptor->Type, memory_map_types[descriptor->Type]);

		if (descriptor->Type == EfiConventionalMemory) {
			total_available_pages += descriptor->NumberOfPages;
		} else if (descriptor->Type == EfiBootServicesCode || descriptor->Type == EfiBootServicesData) {
			total_boot_pages += descriptor->NumberOfPages;
		} else {
			total_reserved_pages += descriptor->NumberOfPages;
		}
	}

	printf("Total available memory: %d MiB\n", (total_available_pages * 0x1000) / (0x100000));
	printf("Total boot memory: %d MiB\n", (total_boot_pages * 0x1000) / (0x100000));
	printf("Total reserved memory: %d MiB\n", (total_reserved_pages * 0x1000) / (0x100000));
}

struct MemoryMap load_memory_map() {
	uintn_t memory_map_size = 0;
	uintn_t map_key = 0;
	uintn_t descriptor_size = 0;

	// Load the size of the memory map first
	efi_status_t status = BS->GetMemoryMap(&memory_map_size, 0, &map_key, &descriptor_size, 0);

	if (status != EFI_BUFFER_TOO_SMALL || !memory_map_size) {
		printf("Failed to get memory map\n");
		exit(1);
	}

	// Allocate memory for the memory map
	memory_map_size += 4 * descriptor_size;

	efi_memory_descriptor_t* descriptors = (efi_memory_descriptor_t*)malloc(memory_map_size);

	if (!descriptors) {
		printf("Failed to allocate memory for memory map\n");
		exit(1);
	}

	// Load the memory map into the allocated memory
	status = BS->GetMemoryMap(&memory_map_size, descriptors, &map_key, &descriptor_size, 0);

	if (EFI_ERROR(status)) {
		printf("Failed to get memory map\n");
		exit(1);
	}

	return (struct MemoryMap) { .descriptors = descriptors, .descriptor_size = descriptor_size, .size = memory_map_size };
}

void add_memory_info(struct UefiData* data, struct MemoryMap* map) {
	// Reset the number of regions just in case
	data->region_count = 0;
	data->physical_memory_size = 0;
	data->memory_map_end = 0;

	// Count the number of regions and find out memory limits
	for (efi_memory_descriptor_t* descriptor = map->descriptors; (uint8_t*)descriptor < (uint8_t*)map->descriptors + map->size; descriptor = NextMemoryDescriptor(descriptor, map->descriptor_size)) {
		data->region_count++;

		uint64_t end = descriptor->PhysicalStart + descriptor->NumberOfPages * 0x1000;

		if (descriptor->Type != EfiConventionalMemory) {
			data->memory_map_end = end;
			continue;
		}

		data->physical_memory_size = end;
	}

	// Allocate memory for the regions
	data->regions = (struct Segment*)malloc(data->region_count * sizeof(struct Segment));

	if (!data->regions) {
		printf("Failed to allocate memory for regions\n");
		exit(1);
	}

	uintn_t current_region = 0;

	for (efi_memory_descriptor_t* descriptor = map->descriptors; (uint8_t*)descriptor < (uint8_t*)map->descriptors + map->size; descriptor = NextMemoryDescriptor(descriptor, map->descriptor_size)) {
		uint8_t* start = (uint8_t*)descriptor->PhysicalStart;
		uint8_t* end = (uint8_t*)descriptor->PhysicalStart + descriptor->NumberOfPages * 0x1000;
		uint64_t type = descriptor->Type == EfiConventionalMemory ? REGION_AVAILABLE : REGION_RESERVED;

		data->regions[current_region++] = (struct Segment) { .start = start, .end = end, .type = type };
	}

	printf("Physical memory size: %d MiB\n", data->physical_memory_size / (0x100000));
	printf("Memory map end: %d MiB\n", data->memory_map_end / (0x100000));
}

void configure_gop(struct GraphicsInformation* information) {
	// Locate GOP so that we can find a suitable video mode
	efi_guid_t gop_guid = EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;
	efi_gop_t* gop = 0;

	efi_status_t status = BS->LocateProtocol(&gop_guid, 0, (void**)&gop);

	if (EFI_ERROR(status)) {
		printf("Unable to locate GOP\n");
		exit(1);
		return;
	}

	efi_gop_mode_info_t* mode_info = 0;
	uintn_t mode_info_size = 0;
	
	status = gop->QueryMode(gop, gop->Mode == 0 ? 0 : gop->Mode->Mode, &mode_info_size, &mode_info);

	if (status == EFI_NOT_STARTED) {
		status = gop->SetMode(gop, 0);
	}

	if (EFI_ERROR(status)) {
		printf("Unable to get native GOP video mode\n");
		exit(1);
	}

	uintn_t current_mode = gop->Mode->Mode;
	uintn_t mode_count = gop->Mode->MaxMode;

	// Find the video mode with largest area:
	printf("Available video modes:\n");

	int best_mode = -1;
	int64_t best_mode_area = -1;

	for (int i = 0; i < mode_count; i++) {
		// Load information about the current mode
		status = gop->QueryMode(gop, i, &mode_info_size, &mode_info);

		if (EFI_ERROR(status)) {
			printf("Unable to get video mode %d\n", i);
			continue;
		}

		int64_t width = mode_info->HorizontalResolution;
		int64_t height = mode_info->VerticalResolution;

		printf("Mode %d: width=%d, height=%d, format=%x %s\n",
			i,
			width,
			height,
			mode_info->PixelFormat,
			i == current_mode ? "(current)" : ""
		);

		// Calculate the area of the current mode
		int64_t area = width * height;

		// If this mode has a larger area than the previous best, use it instead
		if (area > best_mode_area) {
			best_mode = i;
			best_mode_area = area;
		}
	}

	// If we did not find a suitable video mode, exit
	if (best_mode < 0) {
		printf("No suitable video mode found\n");
		exit(1);
	}

	// Set the best video mode, if it is not already set
	if (switch_video_mode && best_mode != current_mode) {
		printf("Switching to video mode %d\n", best_mode);

		status = gop->SetMode(gop, best_mode);

		if (EFI_ERROR(status)) {
			printf("Unable to set video mode %d\n", best_mode);
			exit(1);
		}

		printf("Switched to video mode %d\n", best_mode);
		current_mode = best_mode;

	} else {
		printf("No need to switch the video mode\n");
	}

	status = gop->QueryMode(gop, current_mode, &mode_info_size, &mode_info);

	if (EFI_ERROR(status)) {
		printf("Unable to get the current video mode %d\n", current_mode);
		exit(1);
	}

	information->framebuffer_physical_address = gop->Mode->FrameBufferBase;
	information->horizontal_stride = mode_info->PixelsPerScanLine * sizeof(uint32_t);
	information->width = mode_info->HorizontalResolution;
	information->height = mode_info->VerticalResolution;

	// Log where the framebuffer is located
	printf("Framebuffer physical address: 0x%x\n", information->framebuffer_physical_address);
	printf("Framebuffer horizontal stride: 0x%x\n", information->horizontal_stride);
	printf("Framebuffer width: 0x%x\n", information->width);
	printf("Framebuffer height: 0x%x\n", information->height);
}

void load_file(const char* path, uint8_t** data, uint64_t* size) {
	printf("Loading file %s\n", path);
	FILE* file = fopen(path, "r");

	if (!file) {
		printf("Failed to open kernel file\n");
		exit(1);
	}

	fseek(file, 0, SEEK_END);
	*size = ftell(file);
	fseek(file, 0, SEEK_SET);

	printf("File size = %d\n", *size);

	*data = malloc(*size);

	if (!*data) {
		printf("Failed to allocate memory for a file\n");
		exit(1);
	}

	fread(*data, 1, *size, file);
	fclose(file);

	printf("Loaded the file\n");
}

int main(int argument_count, char** arguments) {
	(void)argument_count;
	(void)arguments;

	ST->BootServices->SetWatchdogTimer(0, 0, 0, NULL);

	struct UefiData data;
	data.system_table = ST;

	configure_gop(&data.graphics_information);

	printf("Getting ready for kernel...\n");
	printf("Kernel loader: 0x%x\n", (uint64_t)&enter_kernel);

	uint8_t* kernel_file = 0;
	uint64_t kernel_file_size = 0;
	load_file("EFI\\BOOT\\KERNEL.SO", &kernel_file, &kernel_file_size);
	load_file("EFI\\BOOT\\FONT.BMP", &data.bitmap_font_file, &data.bitmap_font_file_size);
	load_file("EFI\\BOOT\\FONT.FNT", &data.bitmap_font_descriptor_file, &data.bitmap_font_descriptor_file_size);

	// Add the memory map into UEFI information
	struct MemoryMap map = load_memory_map();
	print_memory_map(map);

	add_memory_info(&data, &map);

	printf("Loading the kernel into memory\n");
	struct LoadInformation information = {0};

	if (_V4loadPhPP7SegmentyP15LoadInformation_ry(kernel_file, data.regions, data.region_count, &information) != 0) {
		printf("Failed to load kernel\n");
		exit(1);
	}

	printf("Image base: 0x%x\n", (uint64_t)information.image_base);
	printf("Image size: 0x%x\n", (uint64_t)information.image_size);
	printf("Entry point: 0x%x\n", (uint64_t)information.entry_point);
	printf("All done\n");

	enter_kernel(information.entry_point, &data);
	while (1) {}
	return 0;
}
