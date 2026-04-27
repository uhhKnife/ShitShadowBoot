#pragma once
#include <xtl.h>

// Freeboot backdoor syscall
#define HVX_FREEBOOT_BACKDOOR				0

// Freeboot backdoor key
#define FREEBOOT_KEY						0x72627472

// Freeboot backdoor actions
#define FREEBOOT_DISABLE_MEM_PROTECTIONS	2
#define FREEBOOT_ENABLE_MEM_PROTECTIONS		3
#define FREEBOOT_EXECUTE					4
#define FREEBOOT_MEMCPY						5

// Freeboot backdoor syscall wrapper
ULONG HvxFreebootBackdoor
(
	ULONGLONG Key,
	ULONGLONG Action,
	ULONGLONG r5,
	ULONGLONG r6,
	ULONGLONG r7,
	ULONGLONG r8,
	ULONGLONG r9,
	ULONGLONG r10
);

// Disable memory protections
#define HvxFreebootDisableMemProtections()	\
	HvxFreebootBackdoor(FREEBOOT_KEY, FREEBOOT_DISABLE_MEM_PROTECTIONS, 0, 0, 0, 0, 0, 0)

// Enable memory protections
#define HvxFreebootEnableMemProtections()	\
	HvxFreebootBackdoor(FREEBOOT_KEY, FREEBOOT_ENABLE_MEM_PROTECTIONS, 0, 0, 0, 0, 0, 0)

// Copy code from/to 64-bit real addresses SrcAddr/DestAddr and call it at DestAddr
#define HvxFreebootExecute(DestAddr, SrcAddr, Size, Arg1, Arg2, Arg3)	\
	HvxFreebootBackdoor(FREEBOOT_KEY, FREEBOOT_EXECUTE, DestAddr, SrcAddr, Size, Arg1, Arg2, Arg3)

// Perform a memory copy from/to 64-bit real addresses SrcAddr/DestAddr
#define HvxFreebootMemcpy(SrcAddr, DestAddr, Size)	\
	HvxFreebootBackdoor(FREEBOOT_KEY, FREEBOOT_MEMCPY, SrcAddr, DestAddr, Size)