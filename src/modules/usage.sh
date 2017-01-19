#/bin/sh

echoUsage(){
	echo
	echo "This little tool can rip CDs. It was written by Ola Aronsson ages ago for some"
	echo "old ubuntu version. Then Ola suddenly needed to rip CDs again so he needed it to"
	echo "run on Ubuntu 12.04, a lot of things (see cddb-support in particular) had changed."
	echo "So - he re-wrote it. It now supports a high-quality switch, cdrom detection,"
	echo "toggling between CDPARANOIA/DAGRAB mode and an auto-flag to simply go on forever if"
	echo "you happen to be sitting by your cdrom and can keep feeding discs."
	echo
	echo "BEFORE RUNNING - PLEASE CONFIGURE THE (small) To Configure-SECTION ON TOP OF THE SCRIPT!"
	echo
	echo "It will, as before, try to ask gracenote via cddbget for cddb-data. Should this"
	echo "fail, it will try curl to poll discogs for info. It has to be considered quite rare"
	echo "failing _both_ these polls, however, it will rip your cd anyway."
	echo
    echo "A small note on sizing, reflecting the very nature of data, the lesser compression,"
    echo "the bigger file. A small example : say I rip Dinosaur JR's latest brilliant album"
    echo "'Give a Glimpse Of What Yer Not', it would result in something like the following:"
    echo
    echo "@192 KBS : 63.7  MB of output"
    echo "@320 KBS : 103.6 MB of output"
    echo "@FLAC    : 333.8 MB of output"
    echo
    echo "So - differences in footprint, sure. Still, I can FLAC-rip some 3000 of these before"
    echo "even thinking about breaching a 1TB disk."
    echo
	echo "Syntax: ripcd.sh"
	echo "        ripcd.sh install" 
	echo "        ripcd.sh uninstall" 
	echo "        ripcd.sh auto | highq | flac"
	echo
	echo "ripcd.sh                - simply rips your CD at an avarage 160-200 kps"
	echo "sudo ripcd.sh install   - tries to fetch and install binaries needed"
	echo "sudo ripcd.sh uninstall - will uninstall nenrip"
	echo "ripcd.sh auto           - keep going if you manage to feed your cdrom during mp3-decoding"
	echo "ripcd.sh highq          - use high quality encoding. 320 kps default or higher."
	echo "ripcd.sh flac           - use flac encoding"
	echo
	echo "The script is delivered as is, there will be no fixes unless I really find it proper"
	echo "and enjoyable to dig in again. Fact is, it works swell for me at least, just having"
	echo "ripped some 1000 CDs with it. Alright - enjoy ola@nollettnoll.net"
	echo 	
}

