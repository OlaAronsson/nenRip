#!/bin/sh

# -------------- CDROM STUFF ---------------

ejectCdromAndSaveCdId(){
    writeMetadataFile
	eject $CDROMDEV
}

possiblyValidCdrom(){
	brainzid=`cd-discid --musicbrainz $1 | sed s#" "##g`
	[ "$brainzid" != "1150150" ] && [ "$brainzid" != "11501151999" ] && return 0
	return 1	
}

guessCdromDevice(){
    [ $# -eq 1 ] && SIMPLECHECK=0
    [ -z $SIMPLECHECK ] && SIMPLECHECK=1
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
	   [ `echo $device | wc -c` -lt 3 ] && [ $SIMPLECHECK -eq 1 ] && logit "we cannot find any proper cdrom connected for which reason we simply bail. goodbye." && BAIL=1 && exitCode
	   logit "champion device is : $device"
	   CDROMDEV=$device
	   echo
	else
	   [ $SIMPLECHECK -eq 1 ] && logit "we cannot find any cdrom connected for which reason we simply bail. goodbye." && BAIL=1 && exitCode
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
