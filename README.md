# MAC-to-MAC

What is MAC-to-MAC ?

it is a MAC spoofer pannel that offers 
```
[Apple]
[Synology]
[Cisco]
[Intel]
[Dell]
[VMware]
[Microsoft]
[QEMU]
[RedHat]
[Google]
```

its easy to install

## install

with commands you have to run this 

```
cd /opt
sudo git clone https://github.com/bzhkem/MAC-to-MAC.git
```

then before actualy running it you have to set it as a script/allow it to run 

```
pwd
```
you will get a path if you did not moved since you just have to put the file path you got (just replace path with what you got)
```
sudo chmod +x /opt/MAC-to-MAC/spoof_MAC.sh
```

if you want to make in sort that it works at each reboot you have to do this

```
sudo nano /etc/systemd/system/macspoof.service
```
past this inside
```
[Unit]
Description=MAC Address Spoofing at Boot
After=network-pre.target
Before=network.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/opt/MAC-to-MAC/spoof_MAC.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

now how to run it?

just run this command replace path with the curent place of `spoof_MAC.sh` which is probably
```
sudo /opt/MAC-to-MAC/spoof_MAC.sh
```
then run this
```
sudo systemctl enable macspoof.service
```
