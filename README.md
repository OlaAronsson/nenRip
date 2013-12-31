#***nenRip***  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;![[nenRip image]](http://nollettnoll.net/nenRip/nenRip.png "nenRip") 

Script utility to rip CDs in ubuntu. Upon installation it will setup and install a .desktop file too 
so you can run it from your dash home directly. Example runs and details can be found at 

http://www.nollettnoll.net/nenRip

This little tool can rip CDs. It was written by Ola Aronsson ages ago for some
old ubuntu version. Then Ola suddenly needed to rip CDs again so he needed it to
run on Ubuntu 12.04, a lot of things (see cddb-support in particular) had changed.
So - he re-wrote it. It now supports a high-quality switch, cdrom detection,
toggling between CDPARANOIA/DAGRAB mode and an auto-flag to simply go on forever if
you happen to be sitting by your cdrom and can keep feeding discs.

BEFORE RUNNING - PLEASE CONFIGURE THE (small) To Configure-SECTION ON TOP OF THE SCRIPT!

It will, as before, try to ask gracenote via cddbget for cddb-data. Should this
fail, it will try curl to poll discogs for info. It has to be considered quite rare
failing both these polls, however, it will rip your cd anyway.  

<pre>
Syntax:  

        ripcd.sh  
        ripcd.sh install  
        ripcd.sh uninstall  
        ripcd.sh auto | highq  
        ripcd.sh -h

ripcd.sh                : simply rips your CD at an avarage 160-200 kps  
sudo ripcd.sh install   : tries to fetch and install binaries needed  
sudo ripcd.sh uninstall : will uninstall nenrip  
ripcd.sh auto           : keep going if you manage to feed your cdrom 
                          during mp3-decoding  
ripcd.sh highq          : use (really) high quality encoding. 320 kps
                          is default hq, it's a configurable  
ripcd.sh -h             : display help
</pre>

The script is delivered as is, there will be no fixes unless I really find it proper
and enjoyable to dig in again. Fact is, it works swell for me at least, having
ripped some 1000 CDs with it. Alright - enjoy ola@nollettnoll.net

