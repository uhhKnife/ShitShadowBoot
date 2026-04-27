# Special purpose registers
.set	CTRLr,0x88
.set	CTRLw,0x98
.set	HSPRG0,0x130
.set	HSPRG1,0x131
.set	HRMOR,0x139
.set	LPCR,0x13e
.set	TSCR,0x399
.set	PPE_TLB_Index,0x3b3
.set	PPE_TLB_VPN,0x3b4
.set	PPE_TLB_RPN,0x3b5
.set	HID1,0x3f1
.set	HID4,0x3f4

# Symbols (17559 retail)
.set	CopyNandQws,0x484
.set	HvpSaveThread,0x84e0
.set	XeCryptHmacSha,0xb458
.set	XeCryptRc4Ecb,0xb4b0
.set	XeCryptRc4Key,0xb4b8

# Symbols (17489 retail)
# .set	CopyNandQws,0x484
# .set	HvpSaveThread,0x84e0
# .set	XeCryptHmacSha,0xb440
# .set	XeCryptRc4Ecb,0xb498
# .set	XeCryptRc4Key,0xb4a0

# Both 17559 and 17489 retail
.set	ProtScratchPage,0x6c01f40000
.set	ProtPage0,0x62001b0000			# PROTDATA
.set	ProtPage1,0x6401f10000
.set	ProtPage2,0x6601f20000
.set	ProtPage3,0x6801f50000
.set	ProtPage4,0x6a01f60000
.set	ProtPage5,0x6e01f30000
.set	ProtPage6,0x7601ee0000

# Load a 64-bit immediate into a register
.macro LOADIMM64 reg, val
	li		\reg,(\val >> 32) & 0xffff
	oris		\reg,\reg,(\val >> 48) & 0xffff
	rldicr		\reg,\reg,0x20,0x1f
	oris		\reg,\reg,(\val >> 16) & 0xffff
	ori		\reg,\reg,\val & 0xffff
.endm

#
# Symbol table
#
	.global		HvxSymtab
HvxSymtab:
	.ascii		"MATE"
	.long		HvxShadowBoot
	.long		HvxQuiesceProcessor

#
# HvxShadowBoot(r8 = ROM pointer, r9 = ROM size, r10 = Media flags)
#
HvxShadowBoot:
	# Copy argument registers
	mr		%r31,%r8			# %r31 = ROM pointer
	mr		%r30,%r9			# %r30 = ROM size
	mr		%r29,%r10			# %r29 = Media flags

	li		%r3,'X'
	bl		PrintChar

	# Save main thread
	li		%r3,0x2
	LOADIMM64	%r11,HvpSaveThread
	mtctr		%r11
	bctrl

	li		%r3,'E'
	bl		PrintChar

	# Get pointer to a page of protected scratch memory we can use
	LOADIMM64	%r28,ProtScratchPage		# %r28 = Scratch pointer

	# Zero protected scratch memory
	mr		%r3,%r28
	li		%r11,0x200
	mtspr		%CTR,%r11
ZeroProtectedScratch:
	dcbf		0,%r3
	addi		%r3,%r3,0x80
	bdnz		ZeroProtectedScratch

	# Check ROM magic
	lhz		%r3,0x0(%r31)			# %r3 = ROM magic
	andi.		%r3,%r3,0xf0f
	cmplwi		%r3,0xf0f
	bne		Deadloop

	# Check SB offset
	lwz		%r3,0x8(%r31)			# %r3 = SB offset
	cmplw		%r3,%r30
	bge		Deadloop

	# Calculate pointers for next 2 checks
	add		%r10,%r30,%r31			# %r10 = ROM end pointer
	add		%r16,%r31,%r3			# %r16 = SB pointer

	# Check SB entry
	lwz		%r14,0x8(%r16)			# %r14 = SB entry offset
	add		%r14,%r16,%r14			# %r14 = SB entry pointer
	cmplw		%r14,%r10
	bge		Deadloop

	# Check SB size
	lwz		%r15,0xc(%r16)			# %r15 = SB size
	add		%r31,%r16,%r15			# %r31 = SB end pointer
	cmplw		%r31,%r10
	bge		Deadloop

	li		%r3,'N'
	bl		PrintChar

	# Calculate address of 1BL key block
	LOADIMM64	%r10,0x8000020000000000		# %r10 = 1BL address
	lwz		%r6,0xfc(%r10)			# %r6 = 1BL keys offset

	# Decrypt shadow SB (but don't verify signature)
	or		%r3,%r16,%r16			# SB pointer
	or		%r4,%r28,%r28			# Scratch pointer
	or		%r5,%r15,%r15			# SB size
	add		%r6,%r6,%r10			# 1BL keys pointer
	bl		LoadShadowSb
	cmplwi		%r3,0x0
	beq		Deadloop

	li		%r3,'O'
	bl		PrintChar

	# Flush protected pages used for HV data
	LOADIMM64	%r9,ProtPage0
	LOADIMM64	%r8,ProtPage1
	LOADIMM64	%r7,ProtPage2
	LOADIMM64	%r6,ProtPage3
	LOADIMM64	%r5,ProtPage4
	LOADIMM64	%r4,ProtPage5
	LOADIMM64	%r3,ProtPage6

	li		%r11,0x200
	mtspr		%CTR,%r11
ProtFlushLoop:
	dcbf		0,%r9
	dcbf		0,%r8
	dcbf		0,%r7
	dcbf		0,%r6
	dcbf		0,%r5
	dcbf		0,%r4
	dcbf		0,%r3
	addi		%r9,%r9,0x80
	addi		%r8,%r8,0x80
	addi		%r7,%r7,0x80
	addi		%r6,%r6,0x80
	addi		%r5,%r5,0x80
	addi		%r4,%r4,0x80
	addi		%r3,%r3,0x80
	bdnz		ProtFlushLoop

	# Load address of SB in secure SRAM
	LOADIMM64	%r16,0x8000020000011000		# %r16 = 0x8000020000011000

	# Copy shadow SB to secure SRAM
	rlwinm		%r5,%r15,0x1d,0x3,0x1f		# %r5 = SB size >> 3
	subi		%r4,%r28,0x8			# %r4 = Decrypted shadow SB pointer
	subi		%r3,%r16,0x8			# %r3 = Secure SRAM pointer
	mtspr		%CTR,%r5
CopyToSecureSRAMLoop:
	ldu		%r5,0x8(%r4)
	stdu		%r5,0x8(%r3)
	bdnz		CopyToSecureSRAMLoop

	# Flush page of protected scratch memory
	li		%r11,0x200
	mtspr		%CTR,%r11
FlushProtectedScratch:
	dcbf		0,%r28
	addi		%r28,%r28,0x80
	bdnz		FlushProtectedScratch

	# Zero top of secure SRAM
	li		%r3,0x0
	LOADIMM64	%r4,0x8000020000020000
	li		%r11,0x10
	mtspr		%CTR,%r11
ZeroTopOfSecureSRAMLoop:
	stwu		%r3,-0x4(%r4)
	bdnz		ZeroTopOfSecureSRAMLoop

	# Write media flags to shadow SB header
	lhz		%r3,0x6(%r16)
	or		%r3,%r3,%r29
	sth		%r3,0x6(%r16)

	li		%r3,'N'
	bl		PrintChar

	# Run without HRMOR
	bl		CopyHrmorToAddress

	# Update HRMOR
	li		%r3,0x200
	rldicr		%r3,%r3,0x20,0x1f
	isync
	mtspr		HRMOR,%r3

	# Clear SLB
	slbia
	isync

	# Load pairing block from shadow SB
	ld		%r27,0x20(%r16)
	ld		%r28,0x28(%r16)
	ld		%r29,0x30(%r16)
	ld		%r30,0x38(%r16)

	# %r26 = shadow SB base address
	or		%r26,%r16,%r16

	# %r25 = shadow SB entry point
	lwz		%r25,0x8(%r16)
	addi		%r25,%r25,0x1000

	# Zero and flush physical memory in one pass
	lis		%r3,-0x8000
	rldicr		%r3,%r3,0x20,0x1f
	oris		%r3,%r3,0x40
	li		%r4,0x2000
	mtspr		%CTR,%r4
ZeroFlushPhysicalLoop:
	dcbz		0,%r3
	dcbf		0,%r3
	addi		%r3,%r3,0x80
	bdnz		ZeroFlushPhysicalLoop
	sync		0x0
	isync

	li		%r3,'!'
	bl		PrintChar
	li		%r3,'\r'
	bl		PrintChar
	li		%r3,'\n'
	bl		PrintChar

	# Run the shadow boot ROM
	b		RunFromSecureSRAM

Deadloop:
	li		%r5,0x0
	mtspr		CTRLw,%r5
	b		Deadloop

#
# HvxQuiesceProcessor()
#
HvxQuiesceProcessor:
	# Get thread ID
	mfspr		%r31,HSPRG1
	lbz		%r31,0x80(%r31)

	# Save secondary thread
	li		%r3,0x2
	LOADIMM64	%r11,HvpSaveThread
	mtctr		%r11
	bctrl

	# Clear HSPRG0 and HSPRG1
	li		%r0,0x0
	mtspr		HSPRG0,%r0
	mtspr		HSPRG1,%r0

	# Check if odd/even thread
	andi.		%r0,%r31,0x1
	beq		SetupEvenThread

	# Halt odd threads (SMT) here
	# These share registers with the even ones we set below
HaltOddThread:
	li		%r0,0x0
	mtspr		CTRLw,%r0
	b		HaltOddThread

SetupEvenThread:
	# Run without HRMOR
	bl		CopyHrmorToAddress

	# Update HRMOR
	li		%r3,0x200
	rldicr		%r3,%r3,0x20,0x1f
	isync
	mtspr		HRMOR,%r3

	# Clear SLB
	slbia
	isync

	# Copy the HoldSecondary() function to SRAM
	bl		LoadAddressOfHoldSecondary	# %r3 = sizeof(HoldSecondary)
	mflr		%r4				# %r4 = HoldSecondary
	LOADIMM64	%r8,0x8000020000011000		# %r8 = 0x8000020000011000
	subf		%r8,%r3,%r8			# %r8 -= sizeof(HoldSecondary)
	rlwinm		%r3,%r3,0x1d,0x3,0x1f		# %r3 >>= 3
	rldicr		%r8,%r8,0x0,0x3c		# align %r8 to multiple of 4
	li		%r6,0x0				# %r6 = 0 (index)
	rlwinm		%r25,%r8,0x0,0x10,0x1f		# %r25 = entry point
	mtctr		%r3
CopyHoldSeconaryLoop:
	ldx		%r5,%r4,%r6
	stdx		%r5,%r8,%r6
	addi		%r6,%r6,0x8
	bdnz		CopyHoldSeconaryLoop

	# Run the function we copied from SRAM
	b		RunFromSecureSRAM

#
# This loads the address of the function below in position independent way
#
LoadAddressOfHoldSecondary:
	li		%r3,0x20
	blrl

#
# HoldSecondary()
# This code gets copied to secure SRAM to hold secondary threads
#
HoldSecondary:
	li		%r3,0x0
	mtspr		HID1,%r3
	mfspr		%r3,TSCR
	oris		%r3,%r3,0x10
	mtspr		TSCR,%r3
DeadLoopSram:
	li		%r0,0x0
	mtspr		CTRLw,%r0
	b		DeadLoopSram

#
# LoadShadowBootSb(void *SbPtr, void *DestPtr, ulonglong InSbSize, void *Keys1BL)
#
LoadShadowSb:
	mfspr		%r12,%LR
	bl		__savegprlr_27
	stdu		%r1,-0x1c0(%r1)

	or		%r27,%r3,%r3			# %r27 = SB pointer
	or		%r31,%r4,%r4			# %r31 = Dest pointer
	or		%r28,%r6,%r6			# %r28 = 1BL key block

	# Copy SB header to destination
	or		%r3,%r31,%r31
	or		%r4,%r27,%r27
	li		%r5,0x2
	LOADIMM64	%r11,CopyNandQws
	mtctr		%r11
	bctrl

	# Load SB size and entry offset
	lwz		%r11,0xc(%r31)			# %r11 = SB size (from header)
	lwz		%r10,0x8(%r31)			# %r10 = SB entry (from header)

	# Check size
	subi		%r9,%r11,0x10
	cmplwi		%cr6,%r9,0xabf0
	bgt		%cr6,LoadShadowSbFail

	# Check magic
	lhz		%r9,0x0(%r31)			# %r9 = SB magic
	rlwinm		%r9,%r9,0x0,0x1c,0x17
	rlwinm		%r9,%r9,0x0,0x14,0xf
	cmpwi		%cr6,%r9,0x302
	bne		%cr6,LoadShadowSbFail

	# Check entry alignemnt
	rlwinm		%r9,%r10,0x0,0x1e,0x1f
	cmplwi		%cr6,%r9,0x0
	bne		%cr6,LoadShadowSbFail

	# Ensure entry >= sizeof (SB header)
	cmplwi		%cr6,%r10,0x10
	blt		%cr6,LoadShadowSbFail

	# Ensure entry < size
	rlwinm		%r9,%r11,0x0,0x0,0x1d
	cmplw		%cr6,%r10,%r9
	bge		%cr6,LoadShadowSbFail

	# %r29 = rounded SB size
	addi		%r11,%r11,0xf
	rlwinm		%r29,%r11,0x0,0x0,0x1b

	# %r30 = dest pointer + 0x10
	addi		%r30,%r31,0x10

	# Copy SB body
	or		%r3,%r30,%r30			# dest
	addi		%r4,%r27,0x10			# src
	or		%r5,%r29,%r29
	subi		%r5,%r5,0x10
	rldicl		%r5,%r5,0x3d,0x3
	rlwinm		%r5,%r5,0x0,0x0,0x1f		# (rounded SB size - 0x10) >> 3 & 0xffffffff
	LOADIMM64	%r11,CopyNandQws
	mtctr		%r11
	bctrl

	# Calculate SB decryption key
	addi		%r3,%r28,0x148			# 1BL symmetric key
	li		%r4,0x10			# 1BL symmetric key size
	or		%r5,%r30,%r30			# SB nonce
	li		%r6,0x10			# SB nonce size
	li		%r7,0x0
	li		%r8,0x0
	li		%r9,0x0
	li		%r10,0x0
	std		%r30,0x50(%r1)			# HMAC (replace nonce with it)
	li		%r11,0x10
	stw		%r11,0x5c(%r1)			# HMAC size
	LOADIMM64	%r11,XeCryptHmacSha
	mtctr		%r11
	bctrl

	# Setup RC4 ctx
	addi		%r3,%r1,0x60			# Context
	or		%r4,%r30,%r30			# Key
	li		%r5,0x10			# Key size
	LOADIMM64	%r11,XeCryptRc4Key
	mtctr		%r11
	bctrl

	# Decrypt SB
	addi		%r3,%r1,0x60			# Context
	addi		%r4,%r31,0x20			# SB body
	subi		%r5,%r29,0x20			# SB body size
	LOADIMM64	%r11,XeCryptRc4Ecb
	mtctr		%r11
	bctrl

	# Success
	li		%r3,0x1
	b		LoadShadowSbEnd

LoadShadowSbFail:
	# Failure
	li		%r3,0x0

LoadShadowSbEnd:
	addi		%r1,%r1,0x1c0
	b		__restgprlr_27

#
# CopyHrmorToAddress()
#
CopyHrmorToAddress:
	mfspr		%r4,%LR
	mfspr		%r3,HRMOR
	li		%r5,0x1
	or		%r3,%r3,%r4
	rldimi		%r3,%r5,0x3f,0x0
	mtspr		%LR,%r3
	blr

#
# RunFromSecureSRAM(%r25 = dest address, %r31 = next BL pointer)
#
RunFromSecureSRAM:
	# Update HID4
	mfspr		%r3,HID4
	li		%r4,0x0
	rldimi		%r3,%r4,0x28,0x14
	isync
	mtspr		HID4,%r3
	sync		0x0
	isync

	# Update LPCR
	mfspr		%r3,LPCR
	li		%r4,0x1
	rldimi		%r3,%r4,0xa,0x35
	isync
	mtspr		LPCR,%r3
	isync

	# Invalidate previous SLB entries
	slbia
	isync

	# Setup new SLB entries
	li		%r3,0x100
	lis		%r4,0x800
	slbmte		%r3,%r4
	isync

	# Invalide previous TLB entries
	li		%r3,0xc00
	li		%r4,0x100
	mtspr		%CTR,%r4
TlbInvalidateLoop:
	.long		0x7c001a24			# tlbiel	%r3
	addi		%r3,%r3,0x1000
	bdnz		TlbInvalidateLoop

	# Setup new TLB entry
	li		%r3,0x208
	li		%r4,0x200
	rldicr		%r4,%r4,0x20,0x1f
	oris		%r4,%r4,0x1
	ori		%r4,%r4,0x1b3
	li		%r5,0x205
	mtspr		PPE_TLB_Index,%r3
	mtspr		PPE_TLB_RPN,%r4
	isync
	mtspr		PPE_TLB_VPN,%r5
	isync

	# Transfer control to SRAM
	or		%r3,%r31,%r31
	addis		%r4,%r25,0x200
	mfmsr		%r5
	ori		%r5,%r5,0x20
	mtspr		%SRR1,%r5
	mtspr		%SRR0,%r4
	rfid

#
# PrintChar(char ch)
#
PrintChar:
	blr

	lis		%r4, 0x8000
	ori		%r4, %r4, 0x200
	sldi		%r4, %r4, 0x20
	oris		%r4, %r4, 0xea00
	slwi		%r3, %r3, 0x18
	stw		%r3, 0x1014(%r4)
ClearLoop:
	lwz		%r3, 0x1018(%r4)
	rlwinm.		%r3, %r3, 0, 6, 6
	beq		ClearLoop
	blr

#
# Standard save/restore sleds
#

__savegprlr_27:
	std		%r27,-0x30(%r1)
__savegprlr_28:
	std		%r28,-0x28(%r1)
__savegprlr_29:
	std		%r29,-0x20(%r1)
__savegprlr_30:
        std		%r30,-0x18(%r1)
__savegprlr_31:
	std		%r31,-0x10(%r1)
	std		%r12,-0x8(%r1)
	blr

__restgprlr_27:
	ld		%r27,-0x30(%r1)
__restgprlr_28:
	ld		%r28,-0x28(%r1)
__restgprlr_29:
	ld		%r29,-0x20(%r1)
__restgprlr_30:
	ld		%r30,-0x18(%r1)
__restgprlr_31:
	ld		%r31,-0x10(%r1)
	ld		%r12,-0x8(%r1)
	mtspr		%LR,%r12
	blr
