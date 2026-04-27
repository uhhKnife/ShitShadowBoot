#include "Freeboot.h"

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
)
{
	_asm
    {
        li      r0, HVX_FREEBOOT_BACKDOOR
        sc
        blr
    }
}
