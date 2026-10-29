# Makefile — builds 32-bit libsteam-wifi-fix.so for Steam Game Mode
CC ?= gcc
CFLAGS ?= -m32 -shared -fPIC -O2 -Wall -Wextra -Wno-unused-parameter
LDFLAGS ?= -ldl

all: libsteam-wifi-fix.so

libsteam-wifi-fix.so: steam-wifi-fix.c
	$(CC) $(CFLAGS) $< -o $@ $(LDFLAGS)
	strip -s $@ 2>/dev/null || true

clean:
	rm -f libsteam-wifi-fix.so

.PHONY: all clean
