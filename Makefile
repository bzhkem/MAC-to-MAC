obj-m += spoof_disk_serial.o

all:
	$(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	$(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
	rm -f spoof_disk_serial.ko spoof_disk_serial.mod.c spoof_disk_serial.mod spoof_disk_serial.o
