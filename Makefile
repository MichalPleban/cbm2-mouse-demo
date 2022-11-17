
all: mouse.prg

mouse.prg: mouse.asm stub.bin
	ca65 mouse.asm
	ld65 mouse.o -C 6509.cfg -o mouse.prg
	rm mouse.o
