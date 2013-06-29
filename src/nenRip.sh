#!/bin/sh
 
# -------- To Configure Mandatory --------

# Basic file root - where temporary files and wavs
# will be put (and removed at the end of execution)
FS_ROOT=/tmp/rips/

# Where my MP3s should eventually end up
MP3_ROOT=/media/KOZAK/mp3

# Setup if needed, empty if not to be
# used (syntax : host:port).
#
# Example :
#PROXY=localhost:3128
PROXY=

# -------- To Configure Optional --------

# cdrom speed (default it will be around 4x when grabbing..)
CDROM_SPEED=32

# mode cdparanoia or dagrab
MODE=DAGRAB

# MP3 kps Quality
KBS_NORMAL=192
KBS_HIGHQ=320

# set this to 1 in order to ask whether to move on
GO_ON_EVEN_IF_GRAB_FAILED=0

# -------- Runtime environment --------

# PATH
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# UTF-8 support
export LANG=en_US.UTF-8
export LESSCHARSET=utf-8
export PERL_UTF8_LOCALE=1 PERL_UNICODE=AS

# grab the args
ARGS="$@"

# grab current fs location
HERE=`pwd`

# ------------------  MAIN  -------------------

main(){
	preFlow
	if [ $INSTALL -eq 1 ] && [ $UNINSTALL -eq 1 ]; then    
	    initFlow
	    thenewcd=`gotNewCd`
	    if [ $thenewcd -eq 1 ]; then
	        logit "Either no cd in drive or it was just ripped.."
	    else   
		    while [ true ]; do 
				mainFlow
				thenewcd=`gotNewCd`
				[ $thenewcd -eq 1 ] && logit "Either no cd in drive or it was just ripped.." && break
		    done
	    fi
	else
	    [ $INSTALL -eq 0 ] && runInstallation
	    [ $UNINSTALL -eq 0 ] && runUnInstall
	fi
	exitCode
	cd $HERE
}


# -----------------  FLOWS  ------------------

preFlow(){
	chk && setupArgs
	chk && basicSetup   
}

initFlow(){
    chk && init
    chk && chkForConfig
    chk && guessCdromDevice
    chk && logit "Setting configured cdrom speed : $CDROM_SPEED"
    chk && setcd -x $CDROM_SPEED $CDROMDEV
    chk && echo
}

mainFlow(){
   chk && testCddb
   chk && mkFs
   chk && getTrackData
   chk && grabWav
   chk && ejectCdromAndSaveCdId
   chk && mp3Encode
   chk && cleanup
}

# -----------  INSTALL/UNINSTALL -------------

runInstallation(){
	chkRootAccess
	chkPackages	
	runUnInstall
	
	logit "Installing linking.."
	mkdir -p /usr/local/share/nenRip/
	[ ! -d /usr/share/app-install/icons ] && mkdir -p /usr/share/app-install/icons
	[ ! -d /usr/share/icons/hicolor/64x64/apps ] && mkdir -p /usr/share/icons/hicolor/64x64/apps
	wget "http://nollettnoll.net/nenRip/nenRip.png" && cp nenRip.png /usr/share/app-install/icons/nenRip.png
	mv nenRip.png /usr/share/icons/hicolor/64x64/apps/nenRip.png
	LINKCONTENT="`getDesktopFileContent '/usr/bin/nenRip /usr/share/icons/hicolor/64x64/apps/nenRip.png nenRip'`"
	echo "$LINKCONTENT" > /tmp/nenTmpLink.desktop
	desktop-file-validate /tmp/nenTmpLink.desktop && desktop-file-install /tmp/nenTmpLink.desktop && update-desktop-database -q
	
	logit "Installing binary.."
	[ ! -d /usr/local/bin ] && mkdir -p /usr/local/bin
	cp nenRip.sh /usr/local/bin/nenRip.sh && chmod 777 /usr/local/bin/nenRip.sh
	echo "#!/bin/sh" > /usr/bin/nenRip 
	echo "if [ \$1 = 'uninstall' ]; then" >> /usr/bin/nenRip 
	echo "   /usr/bin/gnome-terminal --window-with-profile=StayOpen -t \"N-E-N-R-I-P buhu - uninstall\" --geometry 90x70 -x sh -c \"sudo /usr/local/bin/nenRip.sh uninstall;read apa\"" >> /usr/bin/nenRip
	echo "else" >> /usr/bin/nenRip
	echo "  if [ \$1 = 'nonauto' ]; then" >> /usr/bin/nenRip
	echo "     /usr/bin/gnome-terminal --window-with-profile=StayOpen -t \"N-E-N-R-I-P is ripping\" --geometry 90x70 -x sh -c \"/usr/local/bin/nenRip.sh \$2;read apa\"" >> /usr/bin/nenRip	
	echo "  else" >> /usr/bin/nenRip                      
	echo "     /usr/bin/gnome-terminal --window-with-profile=StayOpen -t \"N-E-N-R-I-P is ripping\" --geometry 90x70 -x sh -c \"/usr/local/bin/nenRip.sh \$1 auto;read apa\"" >> /usr/bin/nenRip
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
	cp $LOCAL_CFG $GLOBAL_CFG
	
	# Set up local permission perms
    logit "setting up local perms"
    makeWritableFromSudo "$LOCAL_CFG $LOGFILE"
	
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
    # unity --reset-icons
    # gconftool-2 -s -t string /apps/gnome-settings/gnome-panel/history-gnome-run
    # rm -rf $HOME/.local/share/webkit/icondatabase/WebpageIcons.db
    cd $HERE
}

# -----------  SETUP ETC -------------

setupArgs(){ 
    # Check args
	INSTALL=1
	UNINSTALL=1
	AUTO=1
	HIGHQ=1
	INSTALL_FAULTY_ARG="\nDon't know what you want.\n\nRun me with something like\n no arg to just rip\n install to install\n uninstall to uninstall\n or use auto or highq for high quality ripping (slow).\n\nWhy not try -h if you're confused.\n"
	
	# Only allow max 2 args
	NUMARGS=`echo "$ARGS" | wc -w`
	[ $NUMARGS -gt 2 ] && echo $INSTALL_FAULTY_ARG && exit 1
	
	if [ $NUMARGS -eq 1 ]; then
	    [ $ARGS = "-h" ] && echoUsage && exit 0
	    [ $ARGS = "--h" ] && echoUsage && exit 0
	    [ $ARGS = "-help" ] && echoUsage && exit 0
	    [ $ARGS = "--help" ] && echoUsage && exit 0
	    [ $ARGS = "install" ] && INSTALL=0
	    [ $ARGS = "uninstall" ] && UNINSTALL=0
	    [ $ARGS = "auto" ] && AUTO=0 && logit "\nAUTO mode activated"
	    [ $ARGS = "highq" ] && HIGHQ=0 && logit "\nHIGH-QUALITY mode activated"
	    [ $AUTO -eq 1 ] && [ $HIGHQ -eq 1 ] && [ $ARGS != "install" ] && [ $ARGS != "uninstall" ] && echo $INSTALL_FAULTY_ARG && exit 1
	fi
	
	if [ $NUMARGS -eq 2 ]; then
	    ARG1=`echo $ARGS | cut -d" " -f1`
	    ARG2=`echo $ARGS | cut -d" " -f2`
	    [ $ARG1 = "uninstall" ] && UNINSTALL=0
	    if [ $UNINSTALL -eq 1 ]; then  
			[ $ARG1 = "auto" ] && AUTO=0 && logit "\nAUTO mode activated"
			[ $ARG2 = "auto" ] && AUTO=0 && logit "\nAUTO mode activated"
			[ $ARG1 = "highq" ] && HIGHQ=0 && logit "\nHIGH-QUALITY mode activated"
			[ $ARG2 = "highq" ] && HIGHQ=0 && logit "\nHIGH-QUALITY mode activated"
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
	    CURLCMD="curl -s --proxy $PROXY --user-agent "$UA" --location"
	    echo "proxy.."
	else
	    CURLCMD="curl -s --user-agent "$UA" --location"
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
	    echo
	    logit "Local nor global settings were found. Suggest you edit the config section in this script"
	    logit "and then re-try with the install flag in order to install your local config"
	    echo
	    BAIL=1
	    exitCode
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
	logit " "
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
    which dagrab || BAIL=0
    which dagrab || echo "You need dagrab - get the source like wget http://web.tiscalinet.it/marcellou/dagrab-0.3.5.tar.gz & build it!"
    which lame >/dev/null 2>&1 || BAIL=0
    which lame || echo "You need lame - as root (or sudo) do apt-get install lame"
    which cd-discid >/dev/null 2>&1 || BAIL=0
    which cd-discid || echo "You need cd-discid - as root (or sudo) do apt-get install cd-discid"
    which curl >/dev/null 2>&1 || BAIL=0
    which curl || echo "You need curl - as root (or sudo) do apt-get install curl"
    which setcd >/dev/null 2>&1 || BAIL=0
    which setcd || echo "You need curl - as root (or sudo) do apt-get install setcd"
    which cdparanoia >/dev/null 2>&1 || BAIL=0
    which cdparanoia || echo "You need curl - as root (or sudo) do apt-get install cdparanoia"
    which wget || echo "You need wget - as root (or sudo) do apt-get install wget"
    which id3v2 >/dev/null 2>&1 || BAIL=0
    which id3v2 || echo "You need id3v2 - as root (or sudo) do apt-get install id3v2"
    [ ! -x /usr/bin/gnome-terminal ] && echo "cannot find /usr/bin/gnome-terminal - you are not running gnome?!" && BAIL=0
    logit "DONE."
    echo

    [ $BAIL -eq 0 ] && echo "You might want to run the with the install flag to install missing binaries"

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
	which wget >/dev/null 2>&1 || apt-get install wget
	
	# DaGrab is sort of special. But faster than cdparanoia
	haveDaGrab=1
	which dagrab >/dev/null 2>&1 && haveDaGrab=0	
	if [ $haveDaGrab -eq 1 ]; then
		mkdir -p /usr/local/src/dagrab
		cd /usr/local/src/dagrab
		wget "http://nollettnoll.net/dagrab-0.3.4.tar.gz"
		tar zxvf dagrab-0.3.4.tar.gz 
		cd dagrab-0.3.4
		make && make install
	fi
	
    # UTF-8 fonts, etc
	echo "checking (and installing if needed) proper UTF-8 fonts.."
	apt-get install  xfonts-efont-unicode xfonts-efont-unicode-ib > /dev/null 2>&1   
}    

# ----------- CDDB/DISCOGS --------------

##
# Try fetching cddb data
#
testCddb(){
    
    logit "Getting CDDB data.."
 
    # Stuff to find out
    ARTIST=""
    CDID=""
    GENRE=""
    ALBUM=""

    # first, just check if there's a cd loaded
    ERROR=1
    cdOut=`cd-discid $CDROMDEV`
    [ `echo $cdOut | wc -c` -lt 3 ] && ERROR=0
    [ $ERROR -eq 0 ] && echo "You got no cd loaded it seems.." && BAIL=0 

    if [ $ERROR -eq 1 ]; then
		NO_MATCH=1
	    #$CDDBCMD cddb query "${cdOut}" > /tmp/cddbOut1 || NO_MATCH=0
	    cddbget -I -c $CDROMDEV > /tmp/cddbOut1 || NO_MATCH=0 	
	    #cat /tmp/cddbOut1 | sed s#" "#"_"#g | sed s#"'"##g > /tmp/cddbOut2
		cepa=`cat /tmp/cddbOut1 | sed s#" "#"_"#g` 
		kindReplace $cepa > /tmp/cddbOut2
		apa=`cat /tmp/cddbOut2`
		echo $apa | grep No_match >/dev/null 2>&1 && NO_MATCH=0
		cat /tmp/cddbOut1 | grep -C1 artist > /tmp/apa2
        ARTIST=`cat /tmp/apa2 | grep artist | tail -1 | cut -d":" -f2 | cut -b 2- | sed s#" "#"_"#g`
        ALBUM=`cat /tmp/apa2 | grep title | tail -1 | cut -d":" -f2 | cut -b 2- | sed s#" "#"_"#g`  
	    HIT="$ARTIST:$ALBUM"
        l=`echo $HIT | wc -c | sed s#" "##g`
        if [ $l -gt 4 ]; then
	       NO_MATCH=0
           if [ $AUTO -eq 0 ]; then
              echo "Auto detect assumed $HIT to be correct. Ripping now!"
              NO_MATCH=1
           else  
             yesToDoIt "cddb query returned $HIT. This seem fine" && NO_MATCH=1
           fi  			
        fi

        # A _really_ ugly m.i.a hack. Yepp.
        [ `echo $HIT | cut -d: -f1` = "M.I.A" ] && [ `echo $HIT | cut -b 7` = "/" ] && ALBUM=MAYA

        # for testing purposes..
	   if [ $NO_MATCH -eq 0 ]; then
		    echo "We had a no-match.."
		    ask "Who is the artist? (you HAVE TO exchange spaces with _)" unknown ARTIST
		    artistL=`echo $ARTIST`_
		    ask "What is the name of this album? (you HAVE TO exchange spaces with _)" unknown ALBUM
	            ask "What is the genre of this album? (you HAVE TO exchange spaces with _)" unknown GENRE
		    echo "$GENRE_6666_$artistL/_$ALBUM" > /tmp/cddbOut2
		    whenCddbDoesNotWork $ARTIST:$ALBUM
		    apa=`cat /tmp/cddbOut2`
	   else 
		    GENRE=`cat /tmp/cddbOut1 | grep genre | cut -d":" -f2 | cut -b 2-`
		    CAT=`cat /tmp/cddbOut1 | grep category | cut -d":" -f2 | cut -b 2-`
		    YEAR=`cat /tmp/cddbOut1 | grep year | cut -d":" -f2 | cut -b 2-`
		    CDID=`cat /tmp/cddbOut1 | grep cddbid | cut -d":" -f2 | cut -b 2-`
        fi
		rm -rf /tmp/cddbOut2
		logit "DONE."
		echo
    fi
    
    ARTIST=`removeDangerousChars "$ARTIST"`
    ALBUM=`removeDangerousChars "$ALBUM"`
}


##
# Check for discogs for this album and artist
#
whenCddbDoesNotWork(){
    args="$@"
    rm -rf /tmp/discogs_tracks1 /tmp/discogs_tracks2
    artist=`echo ${args}| sed s#'_'#' '#g | cut -d":" -f1 | tr '[:upper:]' '[:lower:]' | sed s#' '#'+'#g`
    album=`echo ${args} | sed s#'_'#' '#g | cut -d":" -f2 | tr '[:upper:]' '[:lower:]'| sed s#' '#'+'#g`
    logit "Trying discogs : $CURLCMD \"http://www.discogs.com/search?q=$artist+$album&format_exact=CD&btn=Search\"" 
    relLink=`$CURLCMD "http://www.discogs.com/search?q=$artist+$album&format_exact=CD&btn=Search" | grep "<a" | grep href | grep release | grep -v Release | head -1 | cut -d"=" -f2 | sed s#'\"'##g | sed s#">"##g`
    DISCOGS_HIT=1
    [ `echo $relLink | wc -c` -gt 4 ] && echo $relLink | egrep "[0-9]" >/dev/null 2>&1 && echo "Got discocs hit!" && DISCOGS_HIT=0 

    if [ $DISCOGS_HIT -eq 0 ]; then
        actualLink="http://www.discogs.com$relLink"
        logit "going for : $CURLCMD \"$actualLink\""
        echo
        $CURLCMD "$actualLink" > /tmp/discopage
        GENRE=`cat /tmp/discopage | grep "<a" | grep "genre=" | head -1 | cut -d">" -f2 | cut -d"<" -f1`
        YEAR=`cat /tmp/discopage | grep "<a" | grep "decade=" | head -1 | cut -d"=" -f4 | sed s#">"##g | sed s#'\"'##g`
        ARTIST=`cat /tmp/discopage | grep "<a" | grep artist | head -2 | tail -1 | cut -d">" -f2 | cut -d"<" -f1 | sed s#" "#"_"#g`
        ALBUM=`cat /tmp/discopage | grep "<title" | cut -d"-" -f 2- | cut -d">" -f 2 | cut -d"(" -f1 | rev | cut -c 2- | rev | sed s#" "#"_"#g | cut -c 2-`
        logit "discogs artist        : $ARTIST"
        logit "discogs album         : $ALBUM"
        logit "discogs genre         : $GENRE"
        logit "discogs released year : $YEAR"
        cat /tmp/discopage | grep -A1 "track_title" > /tmp/apa
        cat /tmp/apa | grep -v "<span" | egrep -v "^[--]" > /tmp/discogs_tracks1
	   index=1
	   cat /tmp/discogs_tracks1 | while read stuff; do
		    if [ $index -lt 10 ]; then
			     r_index="0$index"
		    else
			     r_index="$index"
		    fi
		    s_index=$r_index"_"
		    trackDiscogs=`echo $s_index$stuff | sed s#' '#'_'#g`
		    disc=`removeDangerousChars ${trackDiscogs}`
		    trackDiscog=$disc".mp3"
	        logit "discogs track         : $trackDiscog" 
		    echo $trackDiscog >> /tmp/discogs_tracks2
		    index=`expr $index + 1`
		done
        rm -rf /tmp/apa /tmp/discogs_tracks1 /tmp/discopage
    else
	   echo "Got no discogs hit.."
    fi
    logit "DONE."
    echo
}

# ---------- GRAB WAVS, ENCODE, ETC ----------

##
# Try cddb for track data if applicable
#
getTrackData(){
    if [ $NO_MATCH -eq 1 ]; then
		logit "Cddb-data :"
        echo
        logit "cddb artist        : $ARTIST"
        logit "cddb album         : $ALBUM"
        logit "cddb genre         : $GENRE"
        logit "cddb released year : $YEAR"
	
		[ -f trackList ] && rm -rf trackList
	    cat /tmp/cddbOut1 | grep track | grep -v trackno | cut -d":" -f2 | cut -b 2- > /tmp/tracks
		index=1
		cat /tmp/tracks | while read stuff; do
		    track=`echo $stuff`	
		    if [ $index -gt 9 ]; then
			r_track="`echo $index $track | sed s#' '#'_'#g`"
		    else
			index_small="0$index"
			r_track="`echo $index_small $track | sed s#' '#'_'#g`"
		    fi    
		    t_track="$r_track.mp3"
	
		    # remove bad chars..
		    s_track=`removeDangerousChars ${t_track}` || BAIL=0
	
		    echo $s_track >> trackList
	        logit "cddb track         : $s_track"        
		    index=`expr $index + 1`
		done
		rm -rf /tmp/cddb*
		logit "DONE."
		echo
    fi
}


##
# Fetch WAVs
#
grabWav(){
    logit "Ripping cd.."
    rm -rf *.wav
    GRAB_FAIL=1
    if [ "$MODE" = "DAGRAB" ]; then
        echo "Just ignore the dagrab cddb error.."
    	dagrab -a -n $CDROM_SPEED -d $CDROMDEV || GRAB_BAIL=0
    else
    	cdparanoia -S $CDROM_SPEED -B -Z -X -d $CDROMDEV || GRAB_BAIL=0
	    cddafiles=`ls | grep cdda`
        for f in ${cddafiles}; do
           newName=`echo "$f" | sed s#".cdda"##g`
           mv $f $newName
        done
    fi

    if [ $GRAB_FAIL -eq 0 ]; then
       #last_file=`ls -lart $FS_ROOT/$ARTIST/$ALBUM/ | tail -1 | awk '{ print $9 }'`
       #rm -rf $FS_ROOT/$ARTIST/$ALBUM/$last_file
       [ $GO_ON_EVEN_IF_GRAB_FAILED -eq 1 ] && yesToDoIt "Some grabbing failed. Either we actually failed to read or there was some data file or film or something on your cd. You wanna exit" && BAIL=0   
    else 
	    if [ $NO_MATCH -eq 0 ] || [ $ERROR -eq 0 ]; then
			outP=`ls`
			rm -rf trackList
	
			if [ $DISCOGS_HIT -eq 0 ]; then
			    mv /tmp/discogs_tracks2 trackList
			    rm -rf /tmp/discogs_tracks2
		    else
		        # right. We got nuthin else..
			    echo "Got no cddb-hit and not discogs-hit - will provide simple numbered tracks.."
			    for f in ${outP}; do
					echo $f | sed s#"wav"#"mp3"#g >> trackList
				done
		    fi
        fi
	fi
    logit "DONE."
    echo
}

##
# Code MP3 files with appropriate tagging
#
mp3Encode(){
    logit "MP3 encoding tracks.."
    rm -rf *.mp3
    tracks=`ls | grep \.wav`
    
    WORKROOT=$MP3_ROOT/$ARTIST/$ALBUM
    mkdir -p $WORKROOT
    index=1
    
    [ $HIGHQ -eq 0 ] && logit "NOTE : High quality mode (320 kps) means significantly longer encoding time and larger MP3s (40-50%)" 

    for f in ${tracks}; do
        if [ $BAIL -eq 1 ]; then
			trackIndex=`echo $f | cut -d"." -f1 | sed s#"track"##g`
			trackFn=`cat trackList | grep $trackIndex`
			trackTitle=`echo $trackFn | cut -d"_" -f 2- | sed s#"_"#" "#g | sed s#".mp3"##g`
			trackAlbum=`echo $ALBUM | sed s#"_"#" "#g`
			trackArtist=`echo $ARTIST | sed s#"_"#" "#g`
	        [ `echo $GENRE | wc -c` -lt 3 ] && GENRE="unknown"
	        [ "$GENRE" = "unknown" ] && [ `echo $CAT | wc -c` -gt 3 ] && GENRE=$CAT
	        [ `echo $YEAR | wc -c` -lt 3 ] && YEAR="1970"
	        musicGenre=`echo $GENRE | sed s#"_"#" "#g`  
	        trackYear=`echo $YEAR | sed s#"_"#" "#g`
	
	        # rescue if, for any reason, the cddb/discogs match do no match no of actual tracks
			[ `echo $trackTitle | wc -c` -lt 3 ] && trackTitle="extra track $index"
			[ `echo $trackFn | wc -c` -lt 3 ] && trackFn="extra-track-$index.mp3"
		
	        # standard or HIGHQ
	        if [ $HIGHQ -eq 1 ]; then
		       logit "lame --tn $index --tt \"$trackTitle\" --tg \"$musicGenre\" --ta \"$trackArtist\" --tl \"$trackAlbum\" --ty \"$trackYear\" --add-id3v2 --quiet --preset $KBS_NORMAL $f $trackFn"
		       lame --tn $index --tt "$trackTitle" --ta "$trackArtist" --tl "$trackAlbum" --ty "$trackYear" --tg "$musicGenre" --add-id3v2 --quiet --preset $KBS_NORMAL $f $WORKROOT/$trackFn || BAIL=0
	        else
		       logit "lame --tn $index --tt \"$trackTitle\" --tg \"$musicGenre\" --ta \"$trackArtist\" --tl \"$trackAlbum\" --ty \"$trackYear\" --add-id3v2 --quiet --preset $KBS_HIGHQ $f $trackFn"
		       lame --tn $index --tt "$trackTitle" --ta "$trackArtist" --tl "$trackAlbum" --ty "$trackYear" --tg "$musicGenre" --add-id3v2 --quiet --preset $KBS_HIGHQ $f $WORKROOT/$trackFn || BAIL=0
	        fi
	
		   index=`expr $index + 1`
		
		   [ $BAIL -eq 1 ] && rm -rf $f
        fi
    done	
    rm -rf trackList > /dev/null 2>&1
    cd $FS_ROOT && rm -rf $ARTIST
    logit "DONE."
    echo    
}

# -------------- CDROM STUFF ---------------

ejectCdromAndSaveCdId(){
    cd-discid $CDROMDEV > $CDID_FILE
    eject $CDROMDEV >/dev/null 2>&1   
}

possiblyValidCdrom(){
  brainzid=`cd-discid --musicbrainz $1 | sed s#" "##g`
  [ "$brainzid" != "1150150" ] && [ "$brainzid" != "11501151999" ] && return 0
  return 1	
}

guessCdromDevice(){
	logit "Looking for a cdrom.."
    # method 1 - check for udev entries
	logit "method 1 - udev entries"
	 if [ -f /var/log/udev ]; then 
	    dev=`cat /var/log/udev | grep /dev/cdrom | tail -1 | cut -d"=" -f2 | cut -d" " -f1 | sed s#" "##g`
	    if [ `echo $CDROMDEV | wc -c` -gt 3 ] && possiblyValidCdrom $dev; then
	       logit "Found out from udev - cdrom device seems to be $dev"
	       CDROMDEV=$dev
	       echo
	       return 0
	    else
	       logit "No cdrom entry in udev log"
	    fi
	 else
	    logit "No udev log"
	 fi
	
    # ok method 2 - check sr-linking
	logit "method 2 - sr-linking"
	sr_linked=`ls -l /dev/cdrom* | grep sr | awk '{ print $9 }'`
	if [ `echo $sr_linked | wc -c` -gt 3 ]; then
	   champion=0
	   device=""
	   for d in ${sr_linked}; do
	      brainzid=`cd-discid --musicbrainz $d | sed s#" "##g`
	      GOODID=1
	      # these are... special. we don't like them, simply
	      [ "$brainzid" != "1150150" ] && [ "$brainzid" != "11501151999" ] && GOODID=0
	      if [ $GOODID -eq 0 ]; then
	        weight=`echo $brainzid | wc -c`
	        [ $weight -gt 0 ] && [ $weight -gt $champion ] && champion=$weight && device=$d
	      fi
	   done
	   [ `echo $device | wc -c` -lt 3 ] && logit "we cannot find any proper cdrom connected for which reason we simply bail. goodbye." && BAIL=1 && exitCode
	   logit "champion device is : $device"
	   CDROMDEV=$device
	   echo
	else
	   logit "we cannot find any cdrom connected for which reason we simply bail. goodbye." && BAIL=1 && exitCode
	fi
}

gotNewCd(){
	GOTNEWCD=0
	cd-discid $CDROMDEV >/dev/null 2>&1 || GOTNEWCD=1
	if [ $GOTNEWCD -eq 0 ]; then 
	   oldcd="`cat $CDID_FILE`"
	   newcd="`cd-discid $CDROMDEV`"
	   [ "$oldcd" = "$newcd" ] && echo 1 && return
	   echo 0 && return
	else
	   echo 1 && return
	fi
	echo $GOTNEWCD
}

# -----------  The... rest -------------

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
	echo "failing both these polls, however, it will rip your cd anyway."
	echo
	echo "Syntax: ripcd.sh"
	echo "        ripcd.sh install" 
	echo "        ripcd.sh uninstall" 
	echo "        ripcd.sh auto | highq"
	echo
	echo "ripcd.sh                - simply rips your CD at an avarage 160-200 kps"
	echo "sudo ripcd.sh install   - tries to fetch and install binaries needed"
	echo "sudo ripcd.sh uninstall - will uninstall nenrip"
	echo "ripcd.sh auto           - keep going if you manage to feed your cdrom during mp3-decoding"
	echo "ripcd.sh highq          - use (really) high quality encoding. 320 kps"
	echo
	echo "The script is delivered as is, there will be no fixes unless I really find it proper"
	echo "and enjoyable to dig in again. Fact is, it works swell for me at least, just having"
	echo "ripped some 1000 CDs with it. Alright - enjoy ola@nollettnoll.net"
	echo 	
}



##
# Create artist and album folder
#
mkFs(){
    logit "Making fs.."
    cd $FS_ROOT
    [ ! -d $ARTIST ] && mkdir $ARTIST
    [ ! -d $ARTIST/$ALBUM ] && mkdir $ARTIST/$ALBUM
    cd $ARTIST/$ALBUM || BAIL=0
    logit "DONE."
    echo
}


##
# Move files into MP3_ROOT
#
cleanup(){
    logit "Cleaning up.."
    rm -rf $FS_ROOT/$ARTIST > /dev/null 2>&1
    logit "DONE."
    echo    
}

# ------------- Some help functions ------------

testWriteInDir(){
    paramName=$1
    myPath=$2
    CANWR=1
    touch $myPath/test >/dev/null 2>&1 && CANWR=0
    if [ $CANWR -eq 1 ]; then
       echo "I cannot write to configured $paramName:$myPath - another day perhaps?" && BAIL=0 && exitCode
    else
       rm -rf $myPath/test
    fi
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
Actions=Normal;HighQ;NonAuto;NonAuto-HighQ;UnInstall;\n\
\n\
[Desktop Action Normal]\n\
Exec=PATHTOEXEC\n\
Name=Rip normally\n\
\n\
[Desktop Action HighQ]\n\
Exec=PATHTOEXEC highq\n\
Name=Rip at abnormal quality\n\
\n\
[Desktop Action NonAuto]\n\
Exec=PATHTOEXEC nonauto\n\
Name=Rip without auto\n\
\n\
[Desktop Action NonAuto-HighQ]\n\
Exec=PATHTOEXEC nonauto highq\n\
Name=Rip without auto at abnormal quality\n\
\n\
[Desktop Action UnInstall]\n\
Exec=PATHTOEXEC uninstall\n\
Name=Uninstall nenRip\n"
echo "$contentTemp" | sed s#"PATHTOEXEC"#"$pathToExec"#g |\
 		      sed s#"PATHTOICON"#"$pathToIcon"#g |\
 		      sed s#"TITLE"#"$title"#g
}

##
# Remove bad characters
#
removeDangerousChars(){
    args="${@}"
    echo $args | sed s#">"##g | sed s#"<"##g | sed s#"\/"#""#g | sed s#"__"#"_"#g | sed s#"\'"##g | sed s#"\""##g | sed s#"\;"##g
}

chkRootAccess(){
	logit "Checking root access.. "
	[ `whoami` != "root" ] && echo "Son or girlie, you need to be root." && BAIL=0 && exitCode
}

##
# A simple log function
# Syntax:
# logit()
logit(){
	echo "$@" | tee -ai ${LOGFILE}
}

##
# This function just sets the answer of some question
# Syntax:
# ask(quest | default | variable to set
ask(){
echo -n "$1: [$2] "; read val
if [ -z "$val" ]; then
read $3 <<EOF
$2
EOF
else
read $3 <<EOF
$val
EOF
fi
eval gotit=\$$3
}

##
# This function takes a list
# of args that are supposed
# to be choosen from and
# outputs a numbered menu
# to choose from and will
# set a named variable sent
# which HAS TO BE the first arg!
# chooseFrom(arg1 param to set|args list of alternatives)
chooseFrom(){
	rgs="$@"
	args=`echo $rgs | cut -d" " -f 2-`
	param=`echo $rgs | cut -d" " -f 1`
	num=`echo $args | wc -w`
	
	happy=1;i=1; val=
	while [ $happy -eq 1 ]; do
	   
	    # echo the menu
		for a in ${args}; do
			echo "$i. $a"
			i=`expr $i + 1`
		done
		
	    # Adding exit
		exit_num=$i
		echo "$exit_num. Exit"
		num=`expr $num + 1`
		
	    # input
		echo -n "your choice : "; read val
		
	    # if val is not a number, we're
	    # not happy or too big - still in loop
		bad_format=1
		
	    # empty?
		[ `echo $val | cut -f 1 | wc -c` -eq 1 ] && bad_format=0
		
		if [ $bad_format -eq 1 ]; then
			echo $val | egrep "[^0-9]" >/dev/null 2>&1 && bad_format=0
			[ $bad_format -eq 1 ] && [ $val -gt $num ] && bad_format=0
			if [ $bad_format -eq 0 ]; then
				i=1
				echo "nope - bad input; not a number or out of range"
			else
				# yep - got a valid choice
				happy=0
			fi
		else
			i=1
			echo "Looping complaint : you have to make a choice.."
		fi
	done
	
	
	[ $val -eq $exit_num ] && echo "Exiting.." && echo && exit 0
	
	apa=`kindReplace ${args}`  
    
    # finally - set the param
	eval "$param"=`echo $apa | cut -d" " -f$val` 
}

kindReplace(){
	bepa="${@}"
	echo $bepa | sed s#"'"##g | sed s#\&#and#g
}

##
# A simple log file
# init
# Syntax:
# initLog()
initLog(){
	if [ -w $LOGFILE ] && [ -s $LOGFILE ]; then
	    echo >> $LOGFILE
	fi
	logit "* Running $SLOGAN.sh at `getDate` *"
}                                            

## --------- FLOW CTRL --------------

chkOk(){
    [ $BAIL -eq 1 ] && echo "OK" && return 0
    return 1
}

chk(){
    [ $BAIL -eq 1 ] && return 0
    return 1
}

bail(){
    echo "FAILED"
    BAIL=0
}

##
# This function just exits nicely
# Syntax:
# exitCode()
exitCode(){
if [ $BAIL -eq 1 ]; then
	logit "* $SLOGAN.sh executed fine - done at `getDate` *"
	echo
	exit 0
else
	logit "$SLOGAN.sh failed"
	echo
	if [ `echo $ERRMSG | cut -d" " -f1 | wc -c` -gt 1 ] && [ "${ERRMSG}" != "${NULL}" ]; then
	    logit "errlog says : $ERRMSG"
	fi
	exit 1
fi
}

##
# Date the way
# I like it
# Syntax:
# getDate() - ret : echoes date
getDate(){
    echo `date '+%y%m%d'_'%H%M%S'`
}

##
# This function will just
# return 1 if we don't
# get 'y' or 'n'
# Syntax:
# checkyesno(arg y/n) ret(0/1)
checkyesno(){
  if [ $# -ne 1 ]; then
     return 1
  fi
  case "$1" in
    "y") return 0 ;;
    "n")  return 0 ;;
    *) echo "${voice} A looping complaint - y or n will do!"
    return 1 ;
  esac
}

##
# And one to just ask
# for a yes or no with
# a default value
# Syntax:
# askYesNo(arg1 quest|arg2 default answer|arg3 variable to set) ret(0/1)
askYesNo(){
echo -n "$1: [$2] "; read val
if [ -z "$val" ]; then
read $3 <<EOF
$2
EOF
else
read $3 <<EOF
$val
EOF
fi
eval gotit=\$$3
checkyesno $gotit || return 1
return 0
}

##
# Wrapper for askYesNo - returns
# 0 for 'y' to given quest, 1 for
# 'n'
yesToDoIt(){
	quest="$@"
	pass=1
	while [ $pass -eq 1 ]; do
	        askYesNo "${quest}" y go && pass=0
	done
	if [ "$go" = "y" ]; then
		return 0
	else
		return 1
	fi
}

makeWritableFromSudo(){
    files="$@"
	WHOSUDOEDME=`env | grep SUDO_USER | cut -d'=' -f2`
	USERGRP=`groups $WHOSUDOEDME | cut -d' ' -f1`
	GOTGRP=1
	echo $USERGRP | egrep "[a-zA-Z]" > /dev/null 2>&1 && GOTGRP=0
	if [ $GOTGRP -eq 0 ]; then
	    logit "chown $WHOSUDOEDME:$USERGRP $files"
	    for f in "$files"; do
	        chown $WHOSUDOEDME:$USERGRP $f
	    done
	else
	    logit "chown $WHOSUDOEDME $files"
	    for f in "$files"; do
	        chown $WHOSUDOEDME $f 
	    done
    fi
    for f in "$files"; do
	    chmod 660 $f
	done
}

# run main
BAIL=1
main
