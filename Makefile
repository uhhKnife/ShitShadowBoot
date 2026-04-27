PATH := $(HOME)/xenon/bin/:$(PATH)

HvxShadowBoot.bin: HvxShadowBoot.asm
	xenon-as HvxShadowBoot.asm -o HvxShadowBoot.o
	xenon-ld --oformat binary -Ttext 0 -e HvxSymtab -o HvxShadowBoot.bin HvxShadowBoot.o

clean:
	rm -f *.bin *.o

.PHONY: clean
