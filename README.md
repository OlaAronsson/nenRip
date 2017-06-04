#***nenRip 2.0***

Script utility to rip CDs in Linux (ie, systems supporting apt), I've been running it on various Debians and Ubuntus and now also Mints. Upon installation it will setup and install a .desktop file too so you can run it from your dash home directly. Example runs and details can be found at

http://www.thehole.black/nenRip

This little tool can rip CDs. It was written by Ola Aronsson ages ago for some old ubuntu version. Then Ola suddenly needed to rip CDs again so he needed it to run on Ubuntu 12.04, a lot of things (see cddb-support in particular) had changed. So - he re-wrote it. It now supports a high-quality switch, cdrom detection, toggling between CDPARANOIA/DAGRAB mode and an auto-flag to simply go on forever if you happen to be sitting by your cdrom and can keep feeding discs.

BEFORE RUNNING - PLEASE CONFIGURE THE (small) To Configure-SECTION ON TOP OF THE SCRIPT!

It will, as before, try to ask gracenote via cddbget for cddb-data. Should this fail, it will try curl to poll discogs for info. It has to be considered quite rare failing _both_ these polls, however, it will rip your cd anyway.

A small note on sizing, reflecting the very nature of data, the lesser compression, the bigger file. A small example : say I rip Dinosaur JR's latest brilliant album 'Give a Glimpse Of What Yer Not', it would result in something like the following:

<pre>
@192 KBS : 63.7  MB of output
@320 KBS : 103.6 MB of output
@FLAC    : 333.8 MB of output
</pre>

So - differences in footprint, sure. Still, I can FLAC-rip some 3000 of these before even thinking about breaching a 1TB disk.

<pre>
Syntax: ripcd.sh
        ripcd.sh install
        ripcd.sh uninstall
        ripcd.sh auto | highq | flac

ripcd.sh                - simply rips your CD at an avarage 160-200 kps
sudo ripcd.sh install   - tries to fetch and install binaries needed
sudo ripcd.sh uninstall - will uninstall nenrip
ripcd.sh auto           - keep going if you manage to feed your cdrom during mp3-decoding
ripcd.sh highq          - use high quality encoding. 320 kps default or higher.
ripcd.sh flac           - use flac encoding

</pre>

The script is delivered as is, there will be no fixes unless I really find it proper and enjoyable to dig in again. Fact is, it works swell for me at least, just having ripped some 1000 CDs with it. Alright - enjoy ola@nollettnoll.net


News 170119: 
I realised I wanted all my CDs in flac so I added flac encoding and started re-ripping all. There was the ancient (well known) problem of dagrab (I threw out CDPARANOIA) not coping with CDs featuring data tracks - so I rebuilt dagrab too and added the new source code to this release, this patched version of Marcello Urbani's simple and great original ripper code will simply skip data tracks (I removed the cddb support too, calling it dagrab-0.3.5-minified). Then I wanted album art to be included too so I added that feature as well. And.. what else.. yeah added "fully" manual support so that I could rip really anything my cdrom could read, home-burnt CDs or just whatever. I added support for the Discogs meta data API and included an API token (I cannot guarantee  that this token will be around, I strongly urge users to go and get their own instead, it's a free and simple procedure). I'm always running Debian these days and the gnome-terminal originally used just didn't cut it anymore, threw it out and replaced it with a good old reliable xterm. And.. well just a bit more of everything, splitting the main script into modules, adding a python script for Discogs (woho, my first real python script I think, so surely it could be greatly improved but I have to move on and it works just fine).

News 170604:
Tested and verified the thing on Mint 18.1 Mate

Ok, enough said - enjoy!
