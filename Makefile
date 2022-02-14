CC      = $(CC_PREFIX)-gcc
CFLAGS  = -std=c11 -O2 -ffreestanding -mno-red-zone -fno-stack-protector -Wshadow -Wall -Wunused -Werror-implicit-function-declaration -Werror
# FIXME(jeff): x86_64-w64-mingw32 headers must be configured to point to our
# local gnu-efi header files and library path at /usr/include and /usr/lib,
# respectively.
# GNUEFI_INC = $(pkg-config --cflags gnu-efi)
# GNUEFI_LIB = $(pkg-config --libs gnu-efi)
# GNUEFI_ARCH = x86_64
GNUEFI_INC = /usr/include/efi
GNUEFI_LIB = /usr/lib
CFLAGS += -I$(GNUEFI_INC) -I$(GNUEFI_INC)/$(GNUEFI_ARCH) -I$(GNUEFI_INC)/protocol
LDFLAGS = -nostdlib -shared -Wl,-dll -Wl,--subsystem,10 -e _EfiMain
LIBS    = -L$(GNUEFI_LIB) -lgcc  # -lefi

# GNUEFI_INC = /usr/$(CC_PREFIX)/include/efi
# GNUEFI_LIB = /usr/$(CC_PREFIX)/lib

FILES_C = src/main.c src/util.c src/types.c src/config.c
FILES_H = $(wildcard src/*.h)
FILES_CS = src/Setup.cs src/SetupHelper.cs src/Esp.cs src/Efi.cs
GIT_DESCRIBE = $(firstword $(shell git describe --tags) unknown)
CFLAGS += '-DGIT_DESCRIBE=L"$(GIT_DESCRIBE)"'
ZIPDIR = HackBGRT-$(GIT_DESCRIBE:v%=%)
ZIP = $(ZIPDIR).zip

efi: bootx64.efi bootia32.efi
setup: setup.exe
all: efi setup

zip: $(ZIP)
$(ZIP): bootx64.efi bootia32.efi config.txt splash.bmp setup.exe README.md CHANGELOG.md README.efilib LICENSE
	test ! -d "$(ZIPDIR)"
	mkdir "$(ZIPDIR)"
	cp -a $^ "$(ZIPDIR)" || (rm -rf "$(ZIPDIR)"; exit 1)
	7z a -mx=9 "$(ZIP)" "$(ZIPDIR)" || (rm -rf "$(ZIPDIR)"; exit 1)
	rm -rf "$(ZIPDIR)"

src/GIT_DESCRIBE.cs: $(FILES_CS) $(FILES_C) $(FILES_H)
	echo 'public class GIT_DESCRIBE { public static string data = "$(GIT_DESCRIBE)"; }' > $@

setup.exe: $(FILES_CS) src/GIT_DESCRIBE.cs
	csc /define:GIT_DESCRIBE /out:$@ $^

bootx64.efi: CC_PREFIX = x86_64-w64-mingw32
bootx64.efi: GNUEFI_ARCH = x86_64
bootx64.efi: $(FILES_C)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@ $(LIBS) -s

bootia32.efi: CC_PREFIX = i686-w64-mingw32
bootia32.efi: GNUEFI_ARCH = ia32
bootia32.efi: $(FILES_C)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@ $(LIBS) -s
