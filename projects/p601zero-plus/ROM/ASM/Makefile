UNIASM = ../DEVEL/uniasm

all: $(UNIASM)		\
    DEMO1.CMD		\
    DEMO9.CMD		\
    IRQTEST.CMD		\
    VIRQTEST.CMD	\
    RAMCHK.CMD		\
    RAMCHKX.CMD		\
    RAMTEST.CMD		\
    RAMTESTX.CMD	\
    RAMPAGECHK.CMD	\
    VPUDMATEST.CMD	\
    VPUMODES.CMD	\
    VIDEOMODES.CMD	\
    TEXTMODE.CMD	\
    VIDEODRV.CMD	\
    MICROBASIC.CMD	\
    MICROBASICPLUS.CMD	\
    SDTEST.CMD		\
    BOOTSEC.CMD		\
    FAT16.CMD		\
    cmd2srec

#    SPITEST.CMD		\
#    SDSECRW.CMD		\
#    CHIPTUNE.CMD	\
#    ymstreamer		\


$(UNIASM):
	make -C $(shell dirname $(UNIASM)) $(shell basename $(UNIASM))

.SUFFIXES: .ASM .CMD

.ASM.CMD: ../DEVMAP.INC ../BOOTROM.INC
	$(UNIASM) $< $(basename $@) $@

clean:
	rm -f *.LST *.CMD ymstreamer
