TARGET = lfs_hello.run
ifdef DEBUG
	TARGET = lfs_hello.out
endif

CC ?= gcc
DIS ?= objdump

SRC = lfs.c lfs_util.c lfs_bd.c lfs_hello.c
OBJS = $(subst .c,.o,$(SRC))
INCS = -I.

ifdef DEBUG
override CFLAGS += -O0 -g3
else
override CFLAGS += -Os
endif
override CFLAGS += -I.
override CFLAGS += -std=c99 -Wall -pedantic
override CFLAGS += -Wshadow -Wunused-parameter -Wjump-misses-init -Wsign-compare

all: $(TARGET)

%.o: %.c
	$(CC) $(CFLAGS) $(INCS) -o $@ -c $^

%.out: $(OBJS)
	$(CC) $(CFLAGS) $(INCS) -o $@ $^

%.run: %.out
	./$^

%.dis: %.out
	$(DIS) -D $^ > $@

clean:
	rm *.o *.dis *.out
