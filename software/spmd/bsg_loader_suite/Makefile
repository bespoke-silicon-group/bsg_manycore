SUBDIRS :=
SUBDIRS += loopback
SUBDIRS += loopback_cache
SUBDIRS += loopback_fail
SUBDIRS += loopback_big_text

SUBDIRS_CLEAN := $(foreach subdir, $(SUBDIRS), $(subdir)-clean)
SUBDIRS_ALL   := $(foreach subdir, $(SUBDIRS), $(subdir)-all)
SUBDIRS_MAIN  := $(foreach subdir, $(SUBDIRS), $(subdir)/main.riscv)

.PHONY: all clean main.riscv $(SUBDIRS_CLEAN) $(SUBDIRS_ALL) $(SUBDIRS_MAIN)

all:        $(SUBDIRS_ALL)
clean:      $(SUBDIRS_CLEAN)
main.riscv: $(SUBDIRS_MAIN)

$(SUBDIRS_MAIN): %/main.riscv: %
	$(MAKE) -C $< main.riscv

$(SUBDIRS_CLEAN): %-clean: %
	$(MAKE) -C $< clean

$(SUBDIRS_ALL):   %-all: %
	$(MAKE) -C $< all
