TARGET_ARCH:=arm

LOCAL_SRC_FILES:= \
	arch/$(TARGET_ARCH)/begin.S \
	linker.c \
	linker_format.c \
	rt.c \
	dlfcn.c \
	debugger.c \
	linker_environ.c

OBJECTS := linker.o linker_format.o rt.o dlfcn.o debugger.o linker_environ.o begin.o

ifeq ($(TARGET_ARCH),sh)
# SH-4A series virtual address range from 0x00000000 to 0x7FFFFFFF.
LINKER_TEXT_BASE := 0x70000100
else
# This is aligned to 4K page boundary so that both GNU ld and gold work.  Gold
# actually produces a correct binary with starting address 0xB0000100 but the
# extra objcopy step to rename symbols causes the resulting binary to be misaligned
# and unloadable.  Increasing the alignment adds an extra 3840 bytes in padding
# but switching to gold saves about 1M of space.
LINKER_TEXT_BASE := 0xB0001000
endif

# The maximum size set aside for the linker, from
# LINKER_TEXT_BASE rounded down to a megabyte.
LINKER_AREA_SIZE := 0x01000000

PLATFORM_LIB_DIR := $(HOME)/droid/android-ndk-r5b/platforms/android-8/arch-arm/usr/lib/

LOCAL_LDFLAGS := -Wl,-Ttext,$(LINKER_TEXT_BASE)
LOCAL_LDFLAGS += -nostdlib $(PLATFORM_LIB_DIR)/crtend_android.o
LOCAL_LDFLAGS += -L$(PLATFORM_LIB_DIR) -Wl,-rpath-link=$(PLATFORM_LIB_DIR)

TOOLCHAIN=$(HOME)/droid/android-ndk-r5b/toolchains/arm-linux-androideabi-4.4.3
LIBGCC=$(TOOLCHAIN)/prebuilt/linux-x86/lib/gcc/arm-linux-androideabi/4.4.3/libgcc.a

LOCAL_CFLAGS += -DPRELINK
LOCAL_CFLAGS += -DLINKER_TEXT_BASE=$(LINKER_TEXT_BASE)
LOCAL_CFLAGS += -DLINKER_AREA_SIZE=$(LINKER_AREA_SIZE)

# Set LINKER_DEBUG to either 1 or 0
#
LOCAL_CFLAGS += -DLINKER_DEBUG=0

# we need to access the Bionic private header <bionic_tls.h>
# in the linker; duplicate the HAVE_ARM_TLS_REGISTER definition
# from the libc build
ifeq ($(TARGET_ARCH)-$(ARCH_ARM_HAVE_TLS_REGISTER),arm-true)
    LOCAL_CFLAGS += -DHAVE_ARM_TLS_REGISTER
endif
LOCAL_CFLAGS += -Ilibc/private

ifeq ($(TARGET_ARCH),arm)
LOCAL_CFLAGS += -DANDROID_ARM_LINKER
else
  ifeq ($(TARGET_ARCH),x86)
    LOCAL_CFLAGS += -DANDROID_X86_LINKER
    LOCAL_CFLAGS += -I$(LOCAL_PATH)/../libc/arch-x86/bionic
  else
    ifeq ($(TARGET_ARCH),sh)
      LOCAL_CFLAGS += -DANDROID_SH_LINKER
    else
      $(error Unsupported TARGET_ARCH $(TARGET_ARCH))
    endif
  endif
endif

TARGET_OBJCOPY := aobjcopy

linker: $(OBJECTS)
	agcc -static $(LOCAL_LDFLAGS) -o $@ -Wl,--start-group $(OBJECTS) -Wl,--end-group -Wl,--start-group -lc $(LIBGCC) -Wl,--end-group
	@echo "target PrefixSymbols: $(PRIVATE_MODULE) ($@)"
	$(TARGET_OBJCOPY) --prefix-symbols=__dl_ $@
	astrip $@

clean:
	rm -f $(OBJECTS) linker

.PHONY: clean

begin.o: arch/$(TARGET_ARCH)/begin.S
	agcc $(LOCAL_CFLAGS) -c $<

%.o: %.c
	agcc $(LOCAL_CFLAGS) -c $<
