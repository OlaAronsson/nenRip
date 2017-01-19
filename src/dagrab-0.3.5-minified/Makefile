CC=gcc
#uncomment the following line for linux 2.0.x  (and maybe 2.1.x or 1.x too ...)
#UCD=-DUSE_UCDROM
CFLAGS=-Wall -g ${UCD}
all:dagrab

dagrab:dagrab.o
	$(CC) -o $@ dagrab.o
#	strip dagrab

clean:
	rm dagrab *.o *.wav

install: dagrab
	strip dagrab
	cp dagrab /usr/local/bin
	cp dagrab.1 /usr/local/man/man1