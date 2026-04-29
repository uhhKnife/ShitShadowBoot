#include <xtl.h>
#include "Kernel.h"
#include "Freeboot.h"
#include "HvxShadowBoot.h"

// 17559 kernel internals
//static VOID (*KiCallDriverNotificationRoutines)(ULONG, ULONG) = (decltype(KiCallDriverNotificationRoutines)) 0x80070E20;
static VOID (*KiIpiSendPacket)(ULONG TargetProcessors, PVOID Procedure, PVOID Arg1, ULONG Arg2, ULONG Arg3) = (decltype(KiIpiSendPacket)) 0x800783C8;
static VOID (*KiIpiSignalPacketDone)(PVOID) = (decltype(KiIpiSignalPacketDone)) 0x80078450;
static VOID (*KiIpiStallOnPacketTargets)(ULONG TargetProcessors) = (decltype(KiIpiStallOnPacketTargets)) 0x80074B08;

static VOID (*UsbdPowerDownNotification)() = (decltype(UsbdPowerDownNotification)) 0x800D8FC8;
static VOID (*UsbdDriverEntry)() = (decltype(UsbdDriverEntry)) 0x800D8D08;

// Number of hardware threads
#define NUM_PROCESSORS	6

// Some unused real mode address we can copy a payload to
#define EXEC_FROM_REAL_QUIESCE	0x8000010600032500
#define EXEC_FROM_REAL_SHADOW	0x8000010600033500

// Info about HV payload and shadowboot ROM
static DWORD szPayload, szXboxRom, offShadowBoot, offQuiesceProcessor;
static PVOID pPayload, pXboxRom;

static __declspec(naked) ULONG MyThreadId()
{
	__asm
	{
		lbz		r3,0x10C(r13)
		blr
	}
}

#define HVX_QUIESCE_PROCESSOR	2

static __declspec(naked) VOID HvxQuiesceProcessor(ULONG Reason)
{
	__asm
	{
		li		r0,HVX_QUIESCE_PROCESSOR
		sc
		blr
	}
}

struct MY_SHADOW_BOOT_PARAM
{
	KDPC DpcArray[NUM_PROCESSORS];
	LONG StartedCount;
	LONG RunningCount;
	LONG FinishedCount;
};

static VOID MyShadowBootIpi(PVOID a1)
{
	KiIpiSignalPacketDone(a1);
	
	//HvxQuiesceProcessor(2);

	HvxFreebootExecute(
		EXEC_FROM_REAL_QUIESCE,
		0x8000000000000000ULL + MmGetPhysicalAddress(pPayload) + offQuiesceProcessor,
		szPayload,
		0,
		0,
		0
	);
}

static VOID MySendShadowBootIpi(VOID)
{
	KiIpiSendPacket(0x3e, MyShadowBootIpi, NULL, 0, 0);
    KiIpiStallOnPacketTargets(0x3e);
}

static VOID MyShadowBootDpc(KDPC *Dpc, MY_SHADOW_BOOT_PARAM *Param)
{
	InterlockedIncrement(&Param->StartedCount);

	if (MyThreadId() == 0)
	{
		while (Param->StartedCount < NUM_PROCESSORS)
			KeRetireDpcList();

		// KiCallDriverNotificationRoutines(1, 0
		MySendShadowBootIpi();

		InterlockedIncrement(&Param->RunningCount);

		for (int i = 0; i < 10000000; i++)
			__asm nop

		// Execute shadowboot on thread 0
		HvxFreebootExecute(
			EXEC_FROM_REAL_SHADOW,
			0x8000000000000000ULL + MmGetPhysicalAddress(pPayload) + offShadowBoot,
			szPayload,
			/*r8=*/0x8000000000000000ULL + MmGetPhysicalAddress(pXboxRom),
			/*r9=*/szXboxRom,
			/*r10=*/0x200
		);

		while (Param->RunningCount < NUM_PROCESSORS)
			KeRetireDpcList();

		//KiCallDriverNotificationRoutines(0, 1);
	}
	else
	{
		while (Param->RunningCount == 0)
			KeRetireDpcList();

		InterlockedIncrement(&Param->RunningCount);

		while (Param->FinishedCount == 0)
			KeRetireDpcList();
	}

	InterlockedIncrement(&Param->FinishedCount);
}

static VOID MyShadowBoot()
{
	MY_SHADOW_BOOT_PARAM Param = {0};
	BYTE OldIrql;

	for (int i = 0; i < NUM_PROCESSORS; i++)
	{
		KeInitializeDpc(&Param.DpcArray[i], MyShadowBootDpc, &Param);
		Param.DpcArray[i].TargetNumber = i + 1; // NOTE: 1 based
	}

	OldIrql = KeRaiseIrqlToDpcLevel();
	for (int i = 0; i < NUM_PROCESSORS; i++)
		KeInsertQueueDpc(&Param.DpcArray[i], NULL, NULL);
	KfLowerIrql(OldIrql);

	while (Param.FinishedCount < NUM_PROCESSORS)
		;
}

void __cdecl main()
{
	HANDLE hXboxRom;
	DWORD szRead;

	// Load HvxShadowBoot payload from embedded binary
	szPayload = HvxShadowBoot_size;
	pPayload = XPhysicalAlloc(szPayload, MAXULONG_PTR, 0x10000, PAGE_READWRITE | MEM_LARGE_PAGES);
	if (pPayload == NULL)
	{
		DbgPrint("Failed to allocate HvxShadowBoot payload\n");
		return;
	}
	memcpy(pPayload, HvxShadowBoot, szPayload);
	DbgPrint("Loaded HvxShadowBoot payload at %#x size %#x\n", MmGetPhysicalAddress(pPayload), szPayload);

	if (memcmp(pPayload, "MATE", 4) != 0)
	{
		DbgPrint("Invalid HvxShadowBoot.bin magic\n");
		return;
	}
	offShadowBoot = ((DWORD *) pPayload)[1];
	offQuiesceProcessor = ((DWORD *) pPayload)[2];
	DbgPrint("  HvxShadowBoot = %#x\n  HvxQuiesceProcessor = %#x\n", offShadowBoot, offQuiesceProcessor);

	// Load shadowboot boot ROM
	hXboxRom = CreateFile("GAME:\\xboxromw2d.bin", GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
	if (hXboxRom == INVALID_HANDLE_VALUE)
	{
		DbgPrint("Failed to open xboxromw2d.bin\n");
		return;
	}
	szXboxRom = GetFileSize(hXboxRom, NULL);
	// NOTE: it is important the shadowboot ROM is allocated in a specific area of memory because the HV payload will
	// zero a lot of phyiscal memory.
	pXboxRom = MmAllocatePhysicalMemoryEx(2, szXboxRom, 4, 0x1000000, 0x1800000, 0x1000);
	if (pXboxRom == NULL)
	{
		DbgPrint("Failed to allocate xboxromw2d.bin\n");
		return;
	}
	if (ReadFile(hXboxRom, pXboxRom, szXboxRom, &szRead, NULL) == FALSE || szRead < szXboxRom)
	{
		DbgPrint("Failed to read xboxromw2d.bin\n");
		return;
	}
	DbgPrint("Loaded xboxromw2d.bin at %#x size %#x\n", MmGetPhysicalAddress(pXboxRom), szXboxRom);

	UsbdPowerDownNotification();

#if 0
	// Thanks hiddriver
	//Remove two usb related bugchecks to allow reinitialisation of the usb driver
	*(DWORD*)0x800E05E4 = 0x48000018;
	*(DWORD*)0x800DD8E0 = 0x48000018;

	// Prevent double registration of Usbd handlers because the console wont shutdown cleanly otherwise
	*(DWORD*)0x800D8F00 = 0x60000000;
	*(DWORD*)0x800D8EF0 = 0x60000000;
	
	UsbdDriverEntry();
#endif

	// Run shadowboot
	DbgPrint("Executing shadowboot\n");
	MyShadowBoot();
}
