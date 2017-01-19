
# ---------- GRAB WAVS, ENCODE, ETC ----------

TRACKLIST_ALREADY_COMPOSED=1
GRABBED_ALREADY_FROM_MANUAL=1

##
# Try cddb for track data if applicable
#
getTrackData(){
    [ $GRABBED_ALREADY_FROM_MANUAL -eq 0 ] && return 0
    [ $TRACKLIST_ALREADY_COMPOSED -eq 0 ] && return 0
    [ -f $FS_ROOT/$ARTIST/$ALBUM/trackList ] && return 0
	if [ $NO_MATCH -eq 1 ]; then
		logit "cddb-data :"
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
     [ $GRABBED_ALREADY_FROM_MANUAL -eq 0 ] && return 0
	logit "Ripping cd.."
	rm -rf *.wav
	GRAB_FAIL=1

	if [ "$MODE" = "DAGRAB" ]; then
	   if [ $AUTO -eq 0 ]; then
          rm -rf /tmp/musicTracks
	      WEHAVEAWFULDATA_TRACKS=1
	      cat trackList | tr '[:upper:]' '[:lower:]' | grep "data.mp3" >/dev/null 2>&1 && WEHAVEAWFULDATA_TRACKS=0
          if [ $WEHAVEAWFULDATA_TRACKS -eq 0 ]; then
            touch /tmp/musicTracks
            cp trackList trackListNew
            cat trackList | while read track; do
               DATA=1
               echo $track | tr '[:upper:]' '[:lower:]' | grep "data.mp3" >/dev/null 2>&1 && DATA=0
               LEN=666
               [ $DATA -eq 0 ] && LEN=`echo $track | wc -c`
               if [ $LEN == 12 ]; then #ie, XX_Data.mp3
                  cat trackListNew | grep -v "$track" > /tmp/zz && mv /tmp/zz trackListNew
                  logit "Track $track is an AWFUL data track : I will ignore it"
               else
                  trackNum=`echo "$track" | cut -d'_' -f1`
                  [[ $trackNum == 0* ]] && trackNum=`echo $trackNum | cut -c 2`
                  echo $trackNum >> /tmp/musicTracks
               fi
             done
             echo
             echo "The new tracklist will be:"
             echo
             mv trackListNew trackList
             cat trackList
             tograb="`cat /tmp/musicTracks`"
             echo
             dagrab -n $CDROM_SPEED -d $CDROMDEV $tograb
          else
             dagrab -a -n $CDROM_SPEED -d $CDROMDEV
          fi
       fi
    fi

	if [ "$MODE" = "DAGRAB" ]; then
	   if [ $AUTO -eq 1 ]; then
	      GRABALL=1
	      yesToDoIt "Do you wish to grab ALL tracks (y) or just some" && GRABALL=0
	      if [ $GRABALL -eq 0 ]; then
	         dagrab -a -n $CDROM_SPEED -d $CDROMDEV || GRAB_BAIL=0
	      else
             ask "Specify specfifc tracks to grab - a comma separated list of track numbers" "1" TRACKSTOGRAB
             grablist=
             maxNumberplusOne=`cat trackList | wc -l`
             maxNumberplusOne=`expr $maxNumberplusOne + 1`
             if [ -z $TRACKSTOGRAB ]; then
                 dagrab -a -n $CDROM_SPEED -d $CDROMDEV || GRAB_BAIL=0
             else
                 t=`echo $TRACKSTOGRAB | sed s#" "##g | sed s#","#" "#g`
                 rm -rf /tmp/temp_tracks
                 for num in $t; do
                    numb=`echo $num | sed s#" "##g`
                    ISNUMBER=1
                    case $numb in
                       ''|*[!0-9]*) echo "bad" >/dev/null 2>&1 ;;
                        *) [ $numb -gt 0 ] && [ $numb -lt $maxNumberplusOne ] && grablist+=' '$numb && ISNUMBER=0 ;;
                    esac

                    if [ $ISNUMBER -eq 0 ]; then
                        if [ $numb -lt 10 ]; then
                          numb="0$numb"
                        fi
                        cat trackList | while read track; do
                             [[ $track == $numb* ]] && echo "$track" >> /tmp/temp_tracks && break
                        done
                    fi
                 done
                 GRABALL=0
                 [ -f /tmp/temp_tracks ] && cat /tmp/temp_tracks | egrep '[a-z]' > /dev/null 2>&1 && mv /tmp/temp_tracks trackList && GRABALL=1 && echo && logit "Thus the reduced tracklist becomes:" && cat trackList && echo
             fi
	         if [ $GRABALL -eq 0 ]; then
	            dagrab -a -n $CDROM_SPEED -d $CDROMDEV || GRAB_BAIL=0
	         else
	            if [[ $grablist == " "* ]]; then
	               tograb=`echo $grablist | cut -c1-`
	               dagrab -n $CDROM_SPEED -d $CDROMDEV $tograb || GRAB_BAIL=0
	            else
	               dagrab -n $CDROM_SPEED -d $CDROMDEV $grablist || GRAB_BAIL=0
	            fi
	         fi
	      fi
	   fi

	else
         echo "I've decided not to support cdparanoia anymore" && exit 1
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
    if [ ! -d $WORKROOT ]; then
	  mkdir -p $WORKROOT
	fi

    [ $GRABBED_ALREADY_FROM_MANUAL -eq 1 ] && tryDownloadAlbumArt
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
		if [ -z $ALBUMARTURL ]; then
            if [ $HIGHQ -eq 1 ]; then
                   logit "lame --tn $index --tt \"$trackTitle\" --tg \"$musicGenre\" --ta \"$trackArtist\" --tl \"$trackAlbum\" --ty \"$trackYear\" --add-id3v2 --quiet --preset $KBS_NORMAL $f $trackFn"
                   lame --tn $index --tt "$trackTitle" --ta "$trackArtist" --tl "$trackAlbum" --ty "$trackYear" --tg "$musicGenre" --add-id3v2 --quiet --preset $KBS_NORMAL $f $WORKROOT/$trackFn || BAIL=0
            else
                   logit "lame --tn $index --tt \"$trackTitle\" --tg \"$musicGenre\" --ta \"$trackArtist\" --tl \"$trackAlbum\" --ty \"$trackYear\" --add-id3v2 --quiet --preset $KBS_HIGHQ $f $trackFn"
                   lame --tn $index --tt "$trackTitle" --ta "$trackArtist" --tl "$trackAlbum" --ty "$trackYear" --tg "$musicGenre" --add-id3v2 --quiet --preset $KBS_HIGHQ $f $WORKROOT/$trackFn || BAIL=0
            fi
        else
            if [ $HIGHQ -eq 1 ]; then
                   logit "lame --tn $index --ti \"$WORKROOT/cover.jpg\" --tt \"$trackTitle\" --tg \"$musicGenre\" --ta \"$trackArtist\" --tl \"$trackAlbum\" --ty \"$trackYear\" --add-id3v2 --quiet --preset $KBS_NORMAL $f $trackFn"
                   lame --tn $index --ti "$WORKROOT/cover.jpg" --tt "$trackTitle" --ta "$trackArtist" --tl "$trackAlbum" --ty "$trackYear" --tg "$musicGenre" --add-id3v2 --quiet --preset $KBS_NORMAL $f $WORKROOT/$trackFn || BAIL=0
            else
                   logit "lame --tn $index --ti \"$WORKROOT/cover.jpg\" --tt \"$trackTitle\" --tg \"$musicGenre\" --ta \"$trackArtist\" --tl \"$trackAlbum\" --ty \"$trackYear\" --add-id3v2 --quiet --preset $KBS_HIGHQ $f $trackFn"
                   lame --tn $index --ti "$WORKROOT/cover.jpg" --tt "$trackTitle" --ta "$trackArtist" --tl "$trackAlbum" --ty "$trackYear" --tg "$musicGenre" --add-id3v2 --quiet --preset $KBS_HIGHQ $f $WORKROOT/$trackFn || BAIL=0
            fi
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

# Code MP3 files with appropriate tagging
#
flacEncode(){
	logit "FLAC encoding tracks.."
	rm -rf *.mp3
	tracks=`ls | grep \.wav`
	WORKROOT=$MP3_ROOT/$ARTIST/$ALBUM
    if [ ! -d $WORKROOT ]; then
	  mkdir -p $WORKROOT
	fi
	[ $GRABBED_ALREADY_FROM_MANUAL -eq 1 ] && tryDownloadAlbumArt
	index=1

	[ $HIGHQ -eq 0 ] && logit "NOTE : FLAC files are significantly larger than MP3s, say at least [mp3size]*3, - make sure to have sufficient disk space available"

    noOfTracks=`echo $tracks | wc -w`

	for f in ${tracks}; do
	    if [ $BAIL -eq 1 ]; then
		    trackIndex=`echo $f | cut -d"." -f1 | sed s#"track"##g`
	    	trackFn=`cat trackList | grep $trackIndex | sed s#"mp3"#"flac"#g`
	    	trackTitle=`echo $trackFn | cut -d"_" -f 2- | sed s#"_"#" "#g | sed s#".flac"##g`
		    trackAlbum=`echo $ALBUM | sed s#"_"#" "#g`
		    trackArtist=`echo $ARTIST | sed s#"_"#" "#g`
		    [ `echo $GENRE | wc -c` -lt 3 ] && GENRE="unknown"
		    [ "$GENRE" = "unknown" ] && [ `echo $CAT | wc -c` -gt 3 ] && GENRE=$CAT
		    [ `echo $YEAR | wc -c` -lt 3 ] && YEAR="1970"
		    musicGenre=`echo $GENRE | sed s#"_"#" "#g`
		    trackYear=`echo $YEAR | sed s#"_"#" "#g`

		    # rescue if, for any reason, the cddb/discogs match do no match no of actual tracks
		    [ `echo $trackTitle | wc -c` -lt 3 ] && trackTitle="extra track $index"

		    # just encode it
		    if [ -z $ALBUMARTURL ]; then
		       logit "flac -f -s --best --delete-input-file --tag=\"TRACK=$index/$noOfTracks\" --tag=\"TITLE=$trackTitle\" --tag=\"ALBUM=$trackAlbum\" --tag=\"ARTIST=$trackArtist\" --tag=\"GENRE=$musicGenre\" --tag=\"YEAR=$trackYear\" $f -o $WORKROOT/$trackFn"
		       flac -s -f --best --delete-input-file --tag="TRACK=$index/$noOfTracks" --tag="TITLE=$trackTitle" --tag="ALBUM=$trackAlbum" --tag="ARTIST=$trackArtist" --tag="GENRE=$musicGenre" --tag="YEAR=$trackYear" $f -o $WORKROOT/$trackFn
		    else
		       logit "flac -f -s --best --picture $WORKROOT/cover.jpg --delete-input-file --tag=\"TRACK=$index/$noOfTracks\" --tag=\"TITLE=$trackTitle\" --tag=\"ALBUM=$trackAlbum\" --tag=\"ARTIST=$trackArtist\" --tag=\"GENRE=$musicGenre\" --tag=\"YEAR=$trackYear\" $f -o $WORKROOT/$trackFn"
		       flac -f -s --best --picture $WORKROOT/cover.jpg --delete-input-file --tag="TRACK=$index/$noOfTracks" --tag="TITLE=$trackTitle" --tag="ALBUM=$trackAlbum" --tag="ARTIST=$trackArtist" --tag="GENRE=$musicGenre" --tag="YEAR=$trackYear" $f -o $WORKROOT/$trackFn
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
