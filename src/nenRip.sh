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

# width of runtime xterm
XTERMWIDTH=90

# Your Discogs API token
DISCOGSTOKEN=sGvVgNzyisfYBWkgctcqTVrWeKJLdCqXXxjQTqFc

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
    BAIL=1
    [ ! -d /usr/local/bin/nenrip-modules ] && installModules
    getFunctions || BAIL=0
    [ $BAIL -eq 0 ] &&  echo "Could not source modules" && exitCode
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
	chk && guessCdromDevice
	chk && logit "Setting configured cdrom speed : $CDROM_SPEED"
	chk && setcd -x $CDROM_SPEED $CDROMDEV
	chk && echo
}

mainFlow(){
	chk && getMetaData
	chk && makeTempFolders
	chk && getTrackData
	chk && grabWav
	chk && ejectCdromAndSaveCdId
	if [ $FLAC -eq 1 ]; then
	   chk && mp3Encode
	else
	   chk && flacEncode
	fi
	chk && cleanup
}

installModules(){
    isInstall=1
    echo "$ARGS" | grep "install" >/dev/null 2>&1 && isInstall=0
    [ $isInstall -eq 1 ] && echo "You are missing the main modules - run the installation in order to get them!" && BAIL=0 && exit 1
	[ `whoami` != "root" ] && echo "Son or girlie, you need to be root." && BAIL=0 && exit 1
    echo
    echo "Installing the nenRip modules"
    echo
    mkdir -p /usr/local/bin/nenrip-modules
    cd /usr/local/bin/nenrip-modules
    wget "http://thehole.black/nenRip/modules.tar.gz"
    tar zxvf modules.tar.gz
    chmod 777 *
    echo "Done."
    echo
}

getFunctions(){
. /usr/local/bin/nenrip-modules/install.sh || BAIL=0
. /usr/local/bin/nenrip-modules/metaData.sh || BAIL=0
. /usr/local/bin/nenrip-modules/cdrom.sh || BAIL=0
. /usr/local/bin/nenrip-modules/grabAndEncode.sh || BAIL=0
. /usr/local/bin/nenrip-modules/variousFunctions.sh || BAIL=0
. /usr/local/bin/nenrip-modules/usage.sh || BAIL=0
}

# Main
main
