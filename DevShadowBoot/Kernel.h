#pragma once
#include <xtl.h>

#ifdef __cplusplus
extern "C" {
#endif

// Part of the kernel binary
#define XBOX_HW_FLAG_PLATFORM_MASK			0x3
#define XBOX_HW_FLAG_PLATFORM_ALPHA			0x0
#define XBOX_HW_FLAG_PLATFORM_MONGREL		0x1
#define XBOX_HW_FLAG_PLATFORM_SHIVA			0x2
#define XBOX_HW_FLAG_PLATFORM_WATERNOOSE	0x3

// Set by VdDetectSystemType() to indicate XBOX_HW_FLAG_SYSTEM_MASK is valid
// Also set in the kernel binary for test kit kernels??
#define XBOX_HW_FLAG_DETECTED_SYSTEM		0x4

// Set by KdInitializeSystem() along with XBOX_HW_FLAG_KD_INITIALIZED if KdpLiteOnly is true
// Also set by KiInitializeKernel()??
#define XBOX_HW_FLAG_KD_LITE_ONLY			0x8

// Part of the kernel binary, for dev and test kernels but not retail
#define XBOX_HW_FLAG_NOT_RETAIL				0x10

// Set by SataDiskInitialize() to indicate the hard disk is initialized
#define XBOX_HW_FLAG_HDD					0x20

// Set by AudioChipCorderDeviceAvailable() if hardware type is CORONA or WINCHESTER AudioChipCorderDeviceAvailable() == 0
#define XBOX_HW_FLAG_CORDER_UNAVAIL			0x40

// Set by KdInitializeSystem() to indicate KD is initialized
#define XBOX_HW_FLAG_KD_INITIALIZED			0x80

// Gets set/cleared when various KD packets are sent or received
#define XBOX_HW_FLAG_KD_SEND_RECV			0x100

// Set by VdDriverEntry to indicate video driver is initialized
#define XBOX_HW_FLAG_VD_INITIALIZED			0x200

// Set by KiQuiesceDpc() when (HvxSetPowerMode() & 0x100000000) == 0
#define XBOX_HW_FLAG_POWER_MODE				0x800

// FIXME: These and 0x4000 are set/tested by HalpDpcForSMCRequest()
#define XBOX_HW_FLAG_1000					0x1000
#define XBOX_HW_FLAG_2000					0x2000

// Toggled by HalpStartAsyncSMCOperation() when entering/exiting background mode
#define XBOX_HW_FLAG_BACKGROUND_TRANSITION	0x4000

// Set by HalInitializePowerLossRecovery() when HalpGetRealTimeClockAlarmFlag() != 0
#define XBOX_HW_FLAG_ALARM_AT_BOOT			0x8000

// Set by KiInitializeKernel() if 1GB of RAM is available
#define XBOX_HW_FLAG_1GB					0x10000

// Set by HalpDetectFlashControllerType() on MMC/eMMC consoles
#define XBOX_HW_FLAG_MMC					0x20000

// FIXME: Set by HalpFlagsInitialization() in some unclear way
#define XBOX_HW_FLAG_HALP_FLAGS_UNK			0x40000

// Part of the kernel binary
#define XBOX_HW_FLAG_TESTKIT				0x2000000

// Set by VdDetectSystemType
#define XBOX_HW_FLAG_SYSTEM_MASK			0xF0000000
#define XBOX_HW_FLAG_SYSTEM_XENON			0x00000000
#define XBOX_HW_FLAG_SYSTEM_ZEPHYR			0x10000000
#define XBOX_HW_FLAG_SYSTEM_FALCON			0x20000000
#define XBOX_HW_FLAG_SYSTEM_JASPER			0x30000000
#define XBOX_HW_FLAG_SYSTEM_TRINITY			0x40000000
#define XBOX_HW_FLAG_SYSTEM_CORONA			0x50000000
#define XBOX_HW_FLAG_SYSTEM_WINCHESTER		0x60000000
#define XBOX_HW_FLAG_SYSTEM_RIDGEWAY		0x80000000

typedef struct _XBOX_HARDWARE_INFO {
	DWORD Flags;
	BYTE NumberOfProcessors;
	BYTE PCIBridgeRevisionID;
	BYTE Reserved[6];
	WORD BldrMagic;
	WORD BldrFlags;
} XBOX_HARDWARE_INFO, *PXBOX_HARDWARE_INFO;

extern PXBOX_HARDWARE_INFO XboxHardwareInfo;

typedef struct _XBOX_KRNL_VERSION {
	WORD Major;
	WORD Minor;
	WORD Build;
	WORD Qfe;
} XBOX_KRNL_VERSION, *PXBOX_KRNL_VERSION;

extern PXBOX_KRNL_VERSION XboxKrnlBaseVersion;

extern PXBOX_KRNL_VERSION XboxKrnlVersion;

ULONG DbgPrint(PCSTR Format, ...);
// #define DbgPrint(...)

ULONG MmGetPhysicalAddress(PVOID VirtualAddress);

PVOID MmAllocatePhysicalMemoryEx(ULONG Region, ULONG Size, ULONG Protect, ULONG MinAddress, ULONG MaxAddress, ULONG Alignment);

typedef struct _KDPC {
    SHORT Type;
    BYTE InsertedNumber;
    BYTE TargetNumber;
    LIST_ENTRY DpcListEntry;
    PVOID DeferredRoutine;
    PVOID DeferredContext;
    PVOID SystemArgument1;
    PVOID SystemArgument2;
} KDPC, *PKDPC;

VOID KeInitializeDpc(KDPC *Dpc, PVOID DeferredRoutine, PVOID DeferredContext);

BOOL KeInsertQueueDpc(KDPC *Dpc, PVOID SystemArgument1, PVOID SystemArgument2);

VOID KeRetireDpcList(VOID);

BYTE KeRaiseIrql(BYTE NewIrql);

BYTE KeRaiseIrqlToDpcLevel(VOID);

VOID KfLowerIrql(BYTE Irql);

#ifdef __cplusplus
}
#endif