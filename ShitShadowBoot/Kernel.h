#pragma once
#include <xtl.h>

#ifdef __cplusplus
extern "C" {
#endif

// ULONG DbgPrint(PCSTR Format, ...);
#define DbgPrint(...)

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