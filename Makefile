PPU_AS = ppu-lv2-as
PPU_LD = ppu-lv2-ld

BUILD = build

$(BUILD)/HvxShadowBoot.bin: HvxShadowBoot.asm | $(BUILD)
	$(PPU_AS) HvxShadowBoot.asm -o $(BUILD)/HvxShadowBoot.o
	$(PPU_LD) -r -o $(BUILD)/HvxShadowBoot_reloc.o $(BUILD)/HvxShadowBoot.o
	$(PPU_LD) --oformat binary -Ttext 0 -e HvxSymtab -o $(BUILD)/HvxShadowBoot.bin $(BUILD)/HvxShadowBoot_reloc.o
	rm -f $(BUILD)/HvxShadowBoot.o $(BUILD)/HvxShadowBoot_reloc.o

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)

.PHONY: clean
