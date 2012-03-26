CC	= gcc
DEBUGFLAGS = -D_FORTIFY_SOURCE=2 -DFIO_INC_DEBUG
CPPFLAGS= -D_GNU_SOURCE -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 \
	$(DEBUGFLAGS)
OPTFLAGS= -O3 -fno-omit-frame-pointer -g $(EXTFLAGS)
CFLAGS	= -std=gnu99 -Wwrite-strings -Wall $(OPTFLAGS)
LIBS	= -lm -lz $(EXTLIBS)
PROGS	= fio
SCRIPTS = fio_generate_plots
UNAME  := $(shell uname)

GTK_CFLAGS = `pkg-config --cflags gtk+-2.0 gthread-2.0`
GTK_LDFLAGS = `pkg-config --libs gtk+-2.0 gthread-2.0`

GTK_CFLAGS += -DGDK_DISABLE_DEPRECATED -DGTK_DISABLE_DEPRECATED

SOURCE := gettime.c ioengines.c init.c stat.c log.c time.c filesetup.c \
		eta.c verify.c memory.c io_u.c parse.c mutex.c options.c \
		lib/rbtree.c smalloc.c filehash.c profile.c debug.c lib/rand.c \
		lib/num2str.c lib/ieee754.c $(wildcard crc/*.c) engines/cpu.c \
		engines/mmap.c engines/sync.c engines/null.c engines/net.c \
		memalign.c server.c client.c iolog.c backend.c libfio.c flow.c \
		cconv.c lib/prio_tree.c

ifeq ($(UNAME), Linux)
  SOURCE += diskutil.c fifo.c blktrace.c helpers.c cgroup.c trim.c \
		engines/libaio.c engines/posixaio.c engines/sg.c \
		engines/splice.c engines/syslet-rw.c engines/guasi.c \
		engines/binject.c engines/rdma.c profiles/tiobench.c
  LIBS += -lpthread -ldl -lrt -laio
  LDFLAGS += -rdynamic
endif
ifeq ($(UNAME), SunOS)
  SOURCE += fifo.c lib/strsep.c helpers.c engines/posixaio.c \
		engines/solarisaio.c
  LIBS	 += -lpthread -ldl -laio -lrt -lnsl -lsocket
  CPPFLAGS += -D__EXTENSIONS__
endif
ifeq ($(UNAME), FreeBSD)
  SOURCE += helpers.c engines/posixaio.c
  LIBS	 += -lpthread -lrt
  LDFLAGS += -rdynamic
endif
ifeq ($(UNAME), NetBSD)
  SOURCE += helpers.c engines/posixaio.c
  LIBS	 += -lpthread -lrt
  LDFLAGS += -rdynamic
endif
ifeq ($(UNAME), AIX)
  SOURCE += fifo.c helpers.c lib/getopt_long.c engines/posixaio.c
  LIBS	 += -lpthread -ldl -lrt
  CPPFLAGS += -D_LARGE_FILES -D__ppc__
  LDFLAGS += -L/opt/freeware/lib -Wl,-blibpath:/opt/freeware/lib:/usr/lib:/lib -Wl,-bmaxdata:0x80000000
endif
ifeq ($(UNAME), HP-UX)
  SOURCE += fifo.c helpers.c lib/getopt_long.c lib/strsep.c engines/posixaio.c
  LIBS   += -lpthread -ldl -lrt
  CFLAGS += -D_LARGEFILE64_SOURCE
endif
ifeq ($(UNAME), Darwin)
  SOURCE += helpers.c engines/posixaio.c
  LIBS	 += -lpthread -ldl
endif
ifneq (,$(findstring CYGWIN,$(UNAME)))
  SOURCE := $(filter-out engines/mmap.c,$(SOURCE))
  SOURCE += engines/windowsaio.c os/windows/posix.c
  LIBS	 += -lpthread -lpsapi -lws2_32
  CFLAGS += -DPSAPI_VERSION=1 -Ios/windows/posix/include -Wno-format
  CC	  = x86_64-w64-mingw32-gcc
endif

OBJS = $(SOURCE:.c=.o)
FIO_OBJS = $(OBJS) fio.o
GFIO_OBJS = $(OBJS) gfio.o graph.o tickmarks.o ghelpers.o goptions.o gerror.o \
			gclient.o gcompat.o

T_SMALLOC_OBJS = t/stest.o
T_SMALLOC_OBJS += mutex.o smalloc.o t/log.o
T_SMALLOC_PROGS = t/stest

T_IEEE_OBJS = t/ieee754.o
T_IEEE_OBJS += ieee754.o
T_IEEE_PROGS = t/ieee754

T_OBJS = $(T_SMALLOC_OBJS)
T_OBJS += $(T_IEEE_OBJS)

ifneq ($(findstring $(MAKEFLAGS),s),s)
ifndef V
	QUIET_CC	= @echo '   ' CC $@;
	QUIET_DEP	= @echo '   ' DEP $@;
endif
endif

INSTALL = install
prefix = /usr/local
bindir = $(prefix)/bin

ifeq ($(UNAME), Darwin)
mandir = /usr/share/man
else
mandir = $(prefix)/man
endif

all: .depend $(PROGS) $(SCRIPTS) FORCE

.PHONY: all install clean
.PHONY: FORCE cscope

FIO-VERSION-FILE: FORCE
	@$(SHELL_PATH) ./FIO-VERSION-GEN
-include FIO-VERSION-FILE

CFLAGS += -DFIO_VERSION='"$(FIO_VERSION)"'

.c.o: .depend FORCE
	$(QUIET_CC)$(CC) -o $@ -c $(CFLAGS) $(CPPFLAGS) $<

gcompat.o: gcompat.c gcompat.h
	$(QUIET_CC)$(CC) $(CFLAGS) $(GTK_CFLAGS) $(CPPFLAGS) -c gcompat.c

goptions.o: goptions.c goptions.h
	$(QUIET_CC)$(CC) $(CFLAGS) $(GTK_CFLAGS) $(CPPFLAGS) -c goptions.c

ghelpers.o: ghelpers.c ghelpers.h
	$(QUIET_CC)$(CC) $(CFLAGS) $(GTK_CFLAGS) $(CPPFLAGS) -c ghelpers.c

gerror.o: gerror.c gerror.h
	$(QUIET_CC)$(CC) $(CFLAGS) $(GTK_CFLAGS) $(CPPFLAGS) -c gerror.c

gclient.o: gclient.c gclient.h
	$(QUIET_CC)$(CC) $(CFLAGS) $(GTK_CFLAGS) $(CPPFLAGS) -c gclient.c

gfio.o: gfio.c ghelpers.c
	$(QUIET_CC)$(CC) $(CFLAGS) $(GTK_CFLAGS) $(CPPFLAGS) -c gfio.c

graph.o: graph.c graph.h
	$(QUIET_CC)$(CC) $(CFLAGS) $(GTK_CFLAGS) $(CPPFLAGS) -c graph.c

t/stest: $(T_SMALLOC_OBJS)
	$(QUIET_CC)$(CC) $(LDFLAGS) $(CFLAGS) -o $@ $(T_SMALLOC_OBJS) $(LIBS) $(LDFLAGS)

t/ieee754: $(T_IEEE_OBJS)
	$(QUIET_CC)$(CC) $(LDFLAGS) $(CFLAGS) -o $@ $(T_IEEE_OBJS) $(LIBS) $(LDFLAGS)

fio: $(FIO_OBJS) FORCE
	$(QUIET_CC)$(CC) $(LDFLAGS) $(CFLAGS) -o $@ $(FIO_OBJS) $(LIBS) $(LDFLAGS)

gfio: $(GFIO_OBJS)
	$(QUIET_CC)$(CC) $(LIBS) -o gfio $(GFIO_OBJS) $(LIBS) $(GTK_LDFLAGS)

.depend: $(SOURCE)
	$(QUIET_DEP)$(CC) -MM $(CFLAGS) $(CPPFLAGS) $(SOURCE) 1> .depend

$(PROGS): .depend FORCE

clean: FORCE
	-rm -f .depend $(GFIO_OBJS) $(FIO_OBJS) $(T_OBJS) $(PROGS) $(T_PROGS) core.* core gfio FIO-VERSION-FILE

cscope:
	@cscope -b -R

install: $(PROGS) $(SCRIPTS) FORCE
	$(INSTALL) -m 755 -d $(DESTDIR)$(bindir)
	$(INSTALL) $(PROGS) $(SCRIPTS) $(DESTDIR)$(bindir)
	$(INSTALL) -m 755 -d $(DESTDIR)$(mandir)/man1
	$(INSTALL) -m 644 fio.1 $(DESTDIR)$(mandir)/man1
	$(INSTALL) -m 644 fio_generate_plots.1 $(DESTDIR)$(mandir)/man1

ifneq ($(wildcard .depend),)
include .depend
endif


