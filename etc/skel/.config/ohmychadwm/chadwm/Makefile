# ohmychadwm - dynamic window manager based on dwm
# See LICENSE file for copyright and license details.

include config.mk

# list source files
SRC = drw.c dwm.c util.c
# list object files
OBJ = ${SRC:.c=.o}

all: options ohmychadwm

options:
	@echo ohmychadwm build options:
	@echo "CFLAGS   = ${CFLAGS}"
	@echo "LDFLAGS  = ${LDFLAGS}"
	@echo "CC       = ${CC}"

# defines how to compile .c files into .o files using specified compiler and compiler flags
.c.o:
	${CC} -c ${CFLAGS} $<

# Specifies that the object files depend on these two files
${OBJ}: config.h config.mk

# creates config.h from config.def.h if it does not exist
config.h:
	cp config.def.h $@

# The ohmychadwm target builds the ohmychadwm executable by linking the object files with the specified linker flags (LDFLAGS).
ohmychadwm: ${OBJ}
	${CC} -o $@ ${OBJ} ${LDFLAGS}

# The clean target removes the ohmychadwm executable, object files, and other generated files to clean up the build directory.
clean:
	rm -f ohmychadwm ${OBJ} ohmychadwm-${VERSION}.tar.gz config.h

install: all
	# Create the target directory for the binary if it doesn't exist
	mkdir -p ${DESTDIR}${PREFIX}/bin
	# Copy the compiled binary to the target directory, force overwriting if it exist
	cp -f ohmychadwm ${DESTDIR}${PREFIX}/bin
	# Set the permissions of the copied binary to be readable and executable by everyone, writable by the owner
	chmod 755 ${DESTDIR}${PREFIX}/bin/ohmychadwm

uninstall:
	# Remove the installed ohmychadwm binary and its manual page
	rm -f ${DESTDIR}${PREFIX}/bin/ohmychadwm

.PHONY: all options clean install uninstall
# Declare these targets as phony to indicate that they are not files
# This prevents make from being confused if there are files named 'all', 'options', 'clean', 'install', or 'uninstall'

