#!/bin/sh

# -----------  INSTALL/UNINSTALL/SETUP ETC -------------

runInstallation(){
	chkRootAccess
	chkPackages	
	runUnInstall

	logit "Installing linking.."
	mkdir -p /usr/local/share/nenRip/
	[ ! -d /usr/share/app-install/icons ] && mkdir -p /usr/share/app-install/icons
	[ ! -d /usr/share/icons/hicolor/64x64/apps ] && mkdir -p /usr/share/icons/hicolor/64x64/apps
	wget "http://nollettnoll.net/nenRip/nenRip.png" && cp nenRip.png /usr/share/app-install/icons/nenRip.png
	wget "http://thehole.black/images/nenRipCover.jpg" && cp nenRipCover.jpg /usr/local/share/nenRip/nenRipCover.jpg
	mv nenRip.png /usr/share/icons/hicolor/64x64/apps/nenRip.png
	LINKCONTENT="`getDesktopFileContent '/usr/bin/nenRip /usr/share/icons/hicolor/64x64/apps/nenRip.png nenRip'`"
	printf "$LINKCONTENT" > /tmp/nenTmpLink.desktop
	desktop-file-validate /tmp/nenTmpLink.desktop && desktop-file-install /tmp/nenTmpLink.desktop && update-desktop-database -q

	logit "Installing binary.."
	[ ! -d /usr/local/bin ] && mkdir -p /usr/local/bin
	cp nenRip.sh /usr/local/bin/nenRip.sh && chmod 777 /usr/local/bin/nenRip.sh
	echo "#!/bin/sh" > /usr/bin/nenRip
    echo >> /usr/bin/nenRip
    echo "# nenRip Wrapper script" >> /usr/bin/nenRip
    echo >> /usr/bin/nenRip
	echo "arg=\$1" >> /usr/bin/nenRip
    echo "[ -z \$arg ] && arg=auto" >> /usr/bin/nenRip
	echo "PID=\`( sh -c 'echo \$PPID' && : )\`" >> /usr/bin/nenRip
	echo "USR=\`ps -auxwww | grep \$PID | cut -d' ' -f1\`" >> /usr/bin/nenRip
	echo "DEFDIM=\"x70+70+70\"" >> /usr/bin/nenRip
	echo "if [ -r /home/\$USR/.nenRip.cfg ]; then" >> /usr/bin/nenRip
	echo "  . /home/\$USR/.nenRip.cfg" >> /usr/bin/nenRip
    echo "else" >> /usr/bin/nenRip
    echo "  cp $GLOBAL_CFG /home/\$USR/.nenRip.cfg" >> /usr/bin/nenRip
    echo "  chown \$USR /home/\$USR/.nenRip.cfg" >> /usr/bin/nenRip
    echo "  chmod u+w /home/\$USR/.nenRip.cfg" >> /usr/bin/nenRip
	echo "  . /home/\$USR/.nenRip.cfg" >> /usr/bin/nenRip
    echo "fi" >> /usr/bin/nenRip
    echo "if [ -z \$LOCALXTERMWIDTH ]; then" >> /usr/bin/nenRip
    echo "  WIDTH=$XTERMWIDTH" >> /usr/bin/nenRip
    echo "else" >> /usr/bin/nenRip
    echo "  WIDTH=\`echo \$LOCALXTERMWIDTH | sed s#' '##g\`" >> /usr/bin/nenRip
    echo "fi" >> /usr/bin/nenRip
    echo "XTERMBIN=\"/usr/bin/xterm -fa 'Monospace' -fs 9 -bw 4 -fg green -bd orange -geometry \$WIDTH\$DEFDIM\"" >> /usr/bin/nenRip
	echo "if [ \$arg = 'uninstall' ]; then" >> /usr/bin/nenRip
	echo "    \$XTERMBIN -T \"nenRip - uninstall\" +hold -bw \$WIDTH -e /bin/sh -c \"sudo /usr/local/bin/nenRip.sh uninstall;read apa;\"" >> /usr/bin/nenRip
	echo "else" >> /usr/bin/nenRip
	echo "  if [ \$arg = 'nonauto' ]; then" >> /usr/bin/nenRip
	echo "     \$XTERMBIN -T \"nenRip - mode: no auto\" +hold -bw \$WIDTH -e /bin/sh -c \"/usr/local/bin/nenRip.sh \$2;read apa;\"" >> /usr/bin/nenRip
	echo "  else" >> /usr/bin/nenRip                      
	echo "     \$XTERMBIN -T \"nenRip - mode: auto\" +hold -bw \$WIDTH -e /bin/sh -c \"/usr/local/bin/nenRip.sh \$1 auto;read apa;\"" >> /usr/bin/nenRip
	echo "  fi" >> /usr/bin/nenRip	
	echo "fi" >> /usr/bin/nenRip
	chmod 777 /usr/bin/nenRip
	
	# try the init
	logit "Re-init post installation"
	init
	
	# If we are still around, write the local config
	logit "Saving local and global config"
	echo "FS_ROOT=$FS_ROOT" > $LOCAL_CFG
	echo "MP3_ROOT=$MP3_ROOT" >> $LOCAL_CFG
	echo "PROXY=$PROXY" >> $LOCAL_CFG
	echo "CDROM_SPEED=$CDROM_SPEED" >> $LOCAL_CFG
	echo "MODE=$MODE" >> $LOCAL_CFG
	echo "KBS_NORMAL=$KBS_NORMAL" >> $LOCAL_CFG
	echo "KBS_HIGHQ=$KBS_HIGHQ" >> $LOCAL_CFG
	echo "GO_ON_EVEN_IF_GRAB_FAILED=$GO_ON_EVEN_IF_GRAB_FAILED" >> $LOCAL_CFG
    echo "XTERMWIDTHLOCAL=$XTERMWIDTH" >> $LOCAL_CFG
	cp $LOCAL_CFG $GLOBAL_CFG
	chmod 555 $GLOBAL_CFG

	# Set up local permission perms
	logit "setting up local perms"
	makeWritableFromSudo "$LOCAL_CFG $LOGFILE"

	# make sure /etc/fstab won't cause trouble
	fixFsTab

	# Others
	rm -rf $FS_ROOT/*
	chmod -R a+w $FS_ROOT
	rm -rf $CDID_FILE
	
	# By now we can simply remove ourselves too :)
	rm $HERE/nenRip.sh
	echo
	cd $HERE
}

runUnInstall(){
	chkRootAccess
	logit "Running uninstall.."
	rm -rf /tmp/nenTmpLink.desktop
	rm -rf /usr/share/app-install/icons/nenRip.png > /dev/null 2>&1
	rm -rf /usr/share/icons/hicolor/64x64/apps/nenRip.png > /dev/null 2>&1
	rm -rf /usr/share/applications/nenRip.desktop > /dev/null 2>&1    
	rm -rf /usr/bin/nenRip > /dev/null 2>&1
	rm /usr/local/bin/nenRip.sh > /dev/null 2>&1
	rm -rf /usr/local/share/nenRip > /dev/null 2>&1
	rm -rf /usr/share/applications/nenTmpLink.desktop > /dev/null 2>&1   
	rm -rf $LOCAL_CFG > /dev/null 2>&1
	update-desktop-database -q > /dev/null 2>&1
	cd $HERE
}

# -----------  SETUP ETC -------------

setupArgs(){ 
	# Check args
	INSTALL=1
	UNINSTALL=1
	AUTO=1
	HIGHQ=1
	FLAC=1
	INSTALL_FAULTY_ARG="\nDon't know what you want.\n\nRun me with something like\n no arg to just rip\n install to install\n uninstall to uninstall\n or use auto or highq for high quality ripping (slow).\n\nWhy not try -h if you're confused.\n"

	# Only allow max 2 args
	NUMARGS=`echo "$ARGS" | wc -w`
	[ $NUMARGS -gt 2 ] && echo $INSTALL_FAULTY_ARG && exit 1

    echo "Activating modes :"
	if [ $NUMARGS -eq 1 ]; then
	    [ $ARGS = "-h" ] && echoUsage && exit 0
	    [ $ARGS = "--h" ] && echoUsage && exit 0
	    [ $ARGS = "-help" ] && echoUsage && exit 0
	    [ $ARGS = "--help" ] && echoUsage && exit 0
	    [ $ARGS = "install" ] && INSTALL=0
	    [ $ARGS = "uninstall" ] && UNINSTALL=0
	    [ $ARGS = "auto" ] && AUTO=0 && logit "AUTO mode activated"
	    [ $ARGS = "highq" ] && HIGHQ=0 && logit "HIGH-QUALITY mode activated"
        [ $ARGS = "flac" ] && FLAC=0 && logit "FLAC mode activated"

	    [ $AUTO -eq 1 ] && [ $HIGHQ -eq 1 ] && [ $FLAC -eq 1 ] && [ $ARGS != "install" ] && [ $ARGS != "uninstall" ] && echo $INSTALL_FAULTY_ARG && exit 1
	fi

	if [ $NUMARGS -eq 2 ]; then
	   ARG1=`echo $ARGS | cut -d" " -f1`
	   ARG2=`echo $ARGS | cut -d" " -f2`
	   [ $ARG1 = "uninstall" ] && UNINSTALL=0
	   if [ $UNINSTALL -eq 1 ]; then
		  [ $ARG1 = "auto" ] && AUTO=0 && logit "AUTO mode activated"
		  [ $ARG2 = "auto" ] && AUTO=0 && logit "AUTO mode activated"
	      [ $ARG1 = "highq" ] && HIGHQ=0 && logit "HIGH-QUALITY mode activated"
		  [ $ARG2 = "highq" ] && HIGHQ=0 && logit "HIGH-QUALITY mode activated"
	      [ $ARG1 = "flac" ] && FLAC=0 && logit "FLAC mode activated"
		  [ $ARG2 = "flac" ] && FLAC=0 && logit "FLAC mode activated"
	   fi
	fi

	# CDDB_CMD over proxy if proxy was set
	PROXY_IS_ON=1
	[ `echo $PROXY | wc -c` -gt 3 ] && PROXY_IS_ON=0
	if [ $PROXY_IS_ON -eq 0 ]; then
	    CDDBCMD="cddbcmd -m http -p $PROXY -h ca.us.cddb.com"
	    echo "proxy.."
	else
	    # CDDBCMD="cddbcmd -m http -h ca.us.cddb.com"
	    CDDBCMD=cddbget
	fi

	# CURL over proxy if proxy was set
	UA="Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.93 Safari/537.36"
	if [ $PROXY_IS_ON -eq 0 ]; then
	    CURLCMD="curl -s --proxy $PROXY --user-agent \"$UA\" --location"
	    echo "proxy.."
	else
	    CURLCMD="curl -s --user-agent \"$UA\" --location"
	fi

	# we got a proper mode?
	GRAB_MODE=""
	if [ `echo $MODE | wc -c` -gt 3 ]; then
	   [ "$MODE" != "CDPARANOIA" ] &&  [ "$MODE" != "DAGRAB" ] &&  echo "got not proper MODE to run : provide CDPARANOIA or DAGRAB!" && BAIL=0 && exitCode	
	else
	  echo "got not proper MODE to run : provide CDPARANOIA or DAGRAB!" && BAIL=0 && exitCode	
	fi
}

basicSetup(){
	# Program name
	SLOGAN="ripCd"

	# LOGFILE 
	LOGFILE=$HOME/.$SLOGAN".log"

	# Std Initial state - nothing has crashed on us yet
	BAIL=1

	LOCAL_CFG=$HOME/.nenRip.cfg
	GLOBAL_ROOT=/usr/local/share/nenRip
	GLOBAL_CFG=$GLOBAL_ROOT/.nenRip.cfg

	CDID_FILE=/tmp/cdid

	GRABBED_ALREADY_FROM_MANUAL=1
}

chkForConfig(){
	# Now - override settings!
	OVERRIDE=1
	if [ -f $LOCAL_CFG ]; then
	    . $LOCAL_CFG && echo && logit "Loaded local config $LOCAL_CFG" && OVERRIDE=0
	else
	    [ -f $GLOBAL_CFG ] && . $GLOBAL_CFG && echo && logit "Falling back to global config $GLOBAL_CFG" && OVERRIDE=0 && logit "Note - $GLOBAL_CFG CAN (and maybe should) be overriden by your own $LOCAL_CFG.." 
	fi
	if [ $OVERRIDE -eq 1 ]; then
        if [ $INSTALL -eq 1 ]; then
	      echo
	      logit "Local nor global settings were found. Suggest you edit the config section in this script"
	      logit "and then re-try with the install flag in order to install your local config"
	      echo
	      BAIL=1
	      exitCode
        fi
	fi
	logit " "
	logit "Running with settings:"
	logit "FS_ROOT=$FS_ROOT"
	logit "MP3_ROOT=$MP3_ROOT"
	logit "PROXY=$PROXY"
	logit "CDROM_SPEED=$CDROM_SPEED"
	logit "MODE=$MODE"
	logit "KBS_NORMAL=$KBS_NORMAL"
	logit "KBS_HIGHQ=$KBS_HIGHQ"
	logit "GO_ON_EVEN_IF_GRAB_FAILED=$GO_ON_EVEN_IF_GRAB_FAILED"
    logit "XTERMWIDTH=$XTERMWIDTH"
    logit "XTERMWIDTHLOCAL=$XTERMWIDTHLOCAL (will override global setting)"
    logit "LOGFILE=$LOGFILE"
    logit "DISCOGSTOKEN=$DISCOGSTOKEN"
	logit " "

    usedMP3RootIsFAT && FATMODE=0 && echo "Since your MP3-ROOT $MP3_ROOT seems to be" && echo "mounted on a FAT-filesystem, '?' and ':' in filenames" && echo "will unfortunately NOT be allowed.."
}

usedMP3RootIsFAT(){
    mount -l | grep "/dev/"  | cut -d' ' -f3 | egrep "[ a-z ]" > /tmp/devicesMounted
    mp3RootDepth=`echo $MP3_ROOT | sed s#"/"#" "#g | wc -w`
    candidate=
    while [ $mp3RootDepth -gt 0 ]
    do
       candidate=`echo $MP3_ROOT | cut -d'/' -f -$mp3RootDepth`
       hit=`cat /tmp/devicesMounted | grep $candidate | wc -l`
       if [ $hit -eq 1 ]; then
          if [ "$candidate" == "`cat /tmp/devicesMounted | grep $candidate`" ]; then
             break
           else
             candidate=
             break
          fi
        fi
       candidate=
       mp3RootDepth=`expr $mp3RootDepth - 1`
    done
    rm -rf /tmp/devicesMounted
    [ ! -z $candidate ] && mount -l | grep $candidate | cut -d' ' -f5 | grep fat > /dev/null 2>&1 && return 0
    return 1
}

##
# Check for binaries and paths
#
init(){
	echo
	initLog
	[ ! -d ${FS_ROOT} ] && mkdir -p ${FS_ROOT}
	cd ${FS_ROOT}
	logit "Checking for binaries needed.."
	which dagrab >/dev/null 2>&1 || BAIL=0
	which dagrab || echo "You need dagrab - get the source like wget http://web.tiscalinet.it/marcellou/dagrab-0.3.5.tar.gz & build it!"
	which lame >/dev/null 2>&1 || BAIL=0
	which lame || echo "You need lame - as root (or sudo) do apt-get install lame"
	which cd-discid >/dev/null 2>&1 || BAIL=0
	which cd-discid || echo "You need cd-discid - as root (or sudo) do apt-get install cd-discid"
	which curl >/dev/null 2>&1 || BAIL=0
	which curl || echo "You need curl - as root (or sudo) do apt-get install curl"
	which python >/dev/null 2>&1 || BAIL=0
	which python || echo "You need python - as root (or sudo) do apt-get install python"
	which setcd >/dev/null 2>&1 || BAIL=0
	which setcd || echo "You need setcd - as root (or sudo) do apt-get install setcd"
    which wget >/dev/null 2>&1 || BAIL=0
	which wget || echo "You need wget - as root (or sudo) do apt-get install wget"
	which id3v2 >/dev/null 2>&1 || BAIL=0
	which id3v2 || echo "You need id3v2 - as root (or sudo) do apt-get install id3v2"
	which flac >/dev/null 2>&1 || BAIL=0
	which flac || echo "You need flac - as root (or sudo) do apt-get install flac"
	which mogrify >/dev/null 2>&1 || BAIL=0
    which mogrify || echo "You need mogrify - as root (or sudo) do apt-get install mogrify"
	which xterm >/dev/null 2>&1 || BAIL=0
    which xterm || echo "You need xterm - as root (or sudo) do apt-get install xterm"
    [ ! -f /var/lib/dpkg/info/python-requests.postinst ] && echo "You need python-requests - as root (or sudo) do apt-get install python-requests" && BAIL=0
    argparselib=`find /usr/lib/python* -name "argparse.py"`
    have_arg_parse=0
    echo $argparselib | grep argparse > /dev/null 2>&1 || have_arg_parse=1
    [ $have_arg_parse -eq 1 ] && echo "You need python-argparse - as root (or sudo) do apt-get install python-argparse" && BAIL=0
    [ -f /tmp/discogsHits ] && rm -rf /tmp/discogsHits
	logit "DONE."
	echo

	[ $BAIL -eq 0 ] && echo "You might want to run the with the install flag to install missing binaries"

	# check for configuration
	chkForConfig

	logit "Checking paths.."
	echo "FS_ROOT : $FS_ROOT"
	[ ! -d $FS_ROOT ] && mkdir -p $FS_ROOT
	[ ! -d $FS_ROOT ] && BAIL=0
	testWriteInDir FS_ROOT $FS_ROOT  

	echo "MP3_ROOT : $MP3_ROOT"
	[ ! -d $MP3_ROOT ] && mkdir -p $MP3_ROOT
	[ ! -d $MP3_ROOT ] && BAIL=0  
	testWriteInDir FS_ROOT $MP3_ROOT
	logit "DONE."
	echo

	[ $BAIL -eq 0 ] && echo "If binaries are missing, you could try running this script with the install flag : ripcd.sh install"

	[ $BAIL -eq 0 ] && echo "Init FAILED - either some binary is missing or your configuration paths are bad!"
	echo "UNKNOWN" > $CDID_FILE
	[ $BAIL -eq 0 ] && exitCode	
}

chkPackages(){
	logit "Checking for packages.."
	which lame >/dev/null 2>&1 || apt-get install lame 
	which cd-discid >/dev/null 2>&1 || apt-get install cd-discid
	which setcd >/dev/null 2>&1 || apt-get install setcd
	which cdparanoia >/dev/null 2>&1 || apt-get install cdparanoia
	which cddbget >/dev/null 2>&1 || apt-get install libcddb-perl libcddb-get-perl libcddb-file-perl
	which id3v2  >/dev/null 2>&1 || apt-get install id3v2
	which curl >/dev/null 2>&1 || apt-get install curl
    which python >/dev/null 2>&1 || apt-get install python
	which wget >/dev/null 2>&1 || apt-get install wget
	which flac >/dev/null 2>&1 || apt-get install flac
    which mogrify >/dev/null 2>&1 || apt-get install mogrify
    which xterm >/dev/null 2>&1 || apt-get install xterm
    [ ! -f /var/lib/dpkg/info/python-requests.postinst ] && apt-get install python-requests
    argparselib=`find /usr/lib/python* -name "argparse.py"`
    have_arg_parse=0
    echo $argparselib | grep argparse > /dev/null 2>&1 || have_arg_parse=1
    [ $have_arg_parse -eq 1 ] && apt-get install python-argparse

	# dagrab is sort of special and I patched this version myself. Loads faster than cdparanoia
	# the code is simple enough and this version works with data-tracks!
	haveDaGrabMinified=0
	[ ! -d /usr/local/src/dagrab/dagrab-0.3.5-minified ] && haveDaGrabMinified=1
    which dagrab >/dev/null 2>&1 || haveDaGrabMinified=1
	if [ $haveDaGrabMinified -eq 1 ]; then
	    echo
	    logit "Installing the new tailored dagrab.."
	    echo
		mkdir -p /usr/local/src/dagrab
		cd /usr/local/src/dagrab
		wget "http://thehole.black/nenRip/dagrab-0.3.5-minified.tar.gz"
		tar zxvf dagrab-0.3.5-minified.tar.gz
		cd dagrab-0.3.5-minified
		make && make install
		echo "Done."
		echo
	else
		logit " - dagrab-0.3.5-minified is installed."
		echo
	fi

	# UTF-8 fonts, etc
	echo "checking (and installing if needed) proper UTF-8 fonts.."
	apt-get install xfonts-efont-unicode xfonts-efont-unicode-ib > /dev/null 2>&1
} 

getDesktopFileContent(){
   rgs="$@"
   pathToExec=`echo $rgs | cut -d" " -f 1`
   pathToIcon=`echo $rgs | cut -d" " -f 2`
   title=`echo $rgs | cut -d" " -f 3`
   contentTemp="#!/usr/bin/env xdg-open\n\
[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
GenericName=CD Ripper\n\
Terminal=false\n\
Icon[en_US]=PATHTOICON\n\
Icon=PATHTOICON\n\
Categories=GNOME;GTK;AudioVideo;\n\
Name[en_US]=TITLE\n\
Name=TITLE\n\
Comment[en_US]=Starting TITLE\n\
Comment=Starting TITLE\n\
StartupNotify=true\n\
TryExec=PATHTOEXEC\n\
Exec=PATHTOEXEC\n\
Hidden=false\n\
NoDisplay=false\n\
Actions=Normal;HighQ;FLAC;NonAuto;NonAuto-HighQ;NonAuto-FLAC;UnInstall;\n\
\n\
[Desktop Action Normal]\n\
Exec=PATHTOEXEC\n\
Name=Rip and MP3 encode\n\
\n\
[Desktop Action HighQ]\n\
Exec=PATHTOEXEC highq\n\
Name=Rip and MP3 encode HQ\n\
\n\
[Desktop Action FLAC]\n\
Exec=PATHTOEXEC flac\n\
Name=Rip and FLAC encode\n\
\n\
[Desktop Action NonAuto]\n\
Exec=PATHTOEXEC nonauto\n\
Name=Rip and MP3 encode no auto\n\
\n\
[Desktop Action NonAuto-HighQ]\n\
Exec=PATHTOEXEC nonauto highq\n\
Name=Rip and MP3 encode HQ no auto\n\
\n\
[Desktop Action NonAuto-FLAC]\n\
Exec=PATHTOEXEC nonauto flac\n\
Name=Rip and FLAC encode no auto\n\
\n\
[Desktop Action UnInstall]\n\
Exec=PATHTOEXEC uninstall\n\
Name=Uninstall nenRip\n"
echo "$contentTemp" | sed s#"PATHTOEXEC"#"$pathToExec"#g |\
 		      sed s#"PATHTOICON"#"$pathToIcon"#g |\
 		      sed s#"TITLE"#"$title"#g
}

fixFsTab(){
   echo
   logit "Checking /etc/fstab.."
   echo
   rm -rf /tmp/fstab /tmp/fstab2 >/dev/null 2>&1
   NEEDS_FIXING=1
   HAS_PROPER_DEV=1

   NEW_DEV=
   guessCdromDevice 'SIMPLECHECK'
   HAS_PROPER_NEW_DEV=1
   if [ -b $CDROMDEV ]; then
      NEW_DEV=/dev/`ls -l $CDROMDEV | cut -d">" -f2 | sed s#' '##g`
      echo $NEW_DEV | egrep "^(\/)dev{1}(\/){1}[a-z]{1}[a-z]{1}[0-9]$" >/dev/null 2>&1 && HAS_PROPER_NEW_DEV=0 && echo "$NEW_DEV" >/tmp/deviceNew
   fi

   [ $HAS_PROPER_NEW_DEV -eq 1 ] && logit "Cannot seem to find a good device right now.." && return 0

   ENTRIES=`cat /etc/fstab  | grep cdrom | grep -v "#" | egrep "/dev" | egrep "[a-z]" | wc -l`
   if [ $ENTRIES -eq 0 ] || [ $ENTRIES -eq 1 ]; then
      if [ $ENTRIES -eq 1 ]; then
        DEV=`cat /etc/fstab | grep -v "#" | grep cdrom | tail -1 | egrep "/dev" | egrep "[a-z]"|  cut -d' ' -f1`
        HAS_PROPER_DEV=1
        echo $DEV | egrep "^(\/)dev{1}(\/){1}[a-z]{1}[a-z]{1}[0-9]$" >/dev/null 2>&1 && HAS_PROPER_DEV=0
        if [ $HAS_PROPER_DEV -eq 0 ]; then
           NEEDS_FIXING=0
           cat /etc/fstab | grep -v "#" | grep $DEV | grep defaults | grep user | grep ro > /dev/null 2>&1 && NEEDS_FIXING=1
           if [ $NEEDS_FIXING -eq 1 ]; then
               NEW_DEV=`cat /tmp/deviceNew`
               if [ "$DEV" != "$NEW_DEV" ]; then
                  NEEDS_FIXING=0
               else
                   logit "Device $DEV is already fine : /etc/fstab seems fine already"
               fi
           else
                logit "Cdrom entry in /etc/fstab could be better.."
           fi
        fi
      else
        NEEDS_FIXING=0
      fi
      if [ $NEEDS_FIXING -eq 0 ]; then
         FIXTYPE="modifying existing entry"
         cp -rp /etc/fstab /tmp/fstab
         NEW_DEV=
         guessCdromDevice 'SIMPLECHECK'
         HAS_PROPER_DEV=0
         if [ $HAS_PROPER_DEV -eq 0 ] && [ $ENTRIES -eq 1 ]; then
            cat /tmp/fstab | grep -v $DEV > /tmp/fstab2
         else
            FIXTYPE="adding new entry"
            cp -rp /tmp/fstab /tmp/fstab2
         fi
         if [ $HAS_PROPER_DEV -eq 0 ]; then
             NEW_DEV=`cat /tmp/deviceNew`
             echo "DEV /mnt/cdrom  iso9660  defaults,noauto,user,ro  0  0" | sed s#DEV#$NEW_DEV#g >> /tmp/fstab2
             echo "Suggesting the following change of your /etc/fstab ($FIXTYPE) :"
             echo
             diff /etc/fstab /tmp/fstab2
             echo
             DOIT=1
             yesToDoIt "Will you allow me to make this change (I will backup original to /etc/fstab.orig)" && DOIT=0
             if [ $DOIT -eq 0 ]; then
                rm -rf /etc/fstab.orig >/dev/null 2>&1
                cp -rp /etc/fstab /etc/fstab.orig
                cp -rp /tmp/fstab2 /etc/fstab
             fi
         fi
      fi
   else
      logit "You have mutliple cdrom entries in your /etc/fstab : I dare not touch it.."
   fi
}

##
# Create artist and album folder
#
makeTempFolders(){
    [ -f $FS_ROOT/"$ARTIST/$ALBUM"/trackList ] && return 0
	logit "Creating wav dump folders at $FS_ROOT artist $ARTIST album $ALBUM.."
	cd $FS_ROOT
	[ ! -d "$ARTIST" ] && mkdir "$ARTIST"
	[ ! -d "$ARTIST/$ALBUM" ] && mkdir "$ARTIST/$ALBUM"
	cd "$ARTIST/$ALBUM" || BAIL=0
	logit "DONE."
	echo
}


##
# Move files into MP3_ROOT
#
cleanup(){
	logit "Cleaning up.."
	rm -rf $FS_ROOT/$ARTIST > /dev/null 2>&1
	rm -rf /tmp/cdid /tmp/nenTmpLink.desktop /tmp/tracks /tmp/discopage /tmp/apa2 > /dev/null 2>&1
	logit "DONE."
	echo    
}
