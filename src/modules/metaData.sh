#!/bin/sh

# ----------- FUNCTIONS RELATING META DATA TAGS --------------

getMetaData(){
  GRABBED_ALREADY_FROM_MANUAL=1
  TRACKLIST_ALREADY_COMPOSED=1
  _w getArtistAndAlbumFromCddb CDDG_NO_HIT
  if [ $CDDG_NO_HIT -eq 0 ]; then
    getMetaDataFromDiscogs "$ARTIST:$ALBUM:$GENRE"
    [ $DISCOGS_GOT_HIT -eq 1 ] && _w whenCddbDoesNotWork DISCOGS_GOT_HIT
    if [ $DISCOGS_GOT_HIT -eq 1 ]; then
       enterMetadataManually "$ARTIST:$ALBUM:$GENRE"
    fi
  else
   getMetaDataFromDiscogs "$ARTIST:$ALBUM"
  fi
  formatArtistAlbumGenre
}

##
# Try fetching cddb data
#
getArtistAndAlbumFromCddb(){

	logit "Getting CDDB data.."

	# Stuff to find out
	ARTIST=""
	CDID=""
	GENRE=""
	ALBUM=""
    ALBUMARTURL=""

	# first, just check if there's a cd loaded
	ERROR=1
	cdOut=`cd-discid $CDROMDEV`
	[ `echo $cdOut | wc -c` -lt 3 ] && ERROR=0
	[ $ERROR -eq 0 ] && echo "You got no cd loaded it seems.." && BAIL=0 

	if [ $ERROR -eq 1 ]; then
		NO_MATCH=1
	    cddbget -I -c $CDROMDEV > /tmp/cddbOut1 || NO_MATCH=0
		cepa=`cat /tmp/cddbOut1 | sed s#" "#"_"#g`
		kindReplace $cepa > /tmp/cddbOut2
		apa=`cat /tmp/cddbOut2`
		echo $apa | grep No_match >/dev/null 2>&1 && NO_MATCH=0
		cat /tmp/cddbOut1 | grep -C1 artist > /tmp/apa2
      	ARTIST=`cat /tmp/apa2 | grep artist | tail -1 | cut -d":" -f2 | cut -b 2- | sed s#" "#"_"#g | sed -E "s#_\([0-9]+\)##g"`
	    ALBUM=`cat /tmp/apa2 | grep title | tail -1 | cut -d":" -f2 | cut -b 2- | sed s#" "#"_"#g | sed -E "s#_\([0-9]+\)##g"`
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

    	# A _really_ ugly m.i.a hack. Yep.
	    echo $HIT | egrep '[A-Z]' && [ `echo $HIT | cut -d: -f1` = "M.I.A" ] && [ `echo $HIT | cut -b 7` = "/" ] && ALBUM=MAYA

	    if [ $NO_MATCH -eq 0 ]; then
		    echo "We had a no-match.."
		    ask "Who is the artist? (you HAVE TO exchange spaces with _)" unknown ARTIST
		    artistL=`echo $ARTIST`_
		    ask "What is the name of this album? (you HAVE TO exchange spaces with _)" unknown ALBUM
		    ask "What is the genre of this album? (you HAVE TO exchange spaces with _)" unknown GENRE
		    echo "$GENRE_6666_$artistL/_$ALBUM" > /tmp/cddbOut2
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
    return $NO_MATCH
}

getMetaDataFromDiscogs(){
artistAlbum=$1
USE_API=0
[ -z $DISCOGSTOKEN ] && USE_API=1
if [ $USE_API -eq 0 ]; then
   logit "Testing your Discogs API token $DISCOGSTOKEN.."
   if testToken; then
       logit "Discogs API token $DISCOGSTOKEN is FINE"
      getMetaDataFromDiscogsviAPI $artistAlbum
   else
      logit "Nope, your Discogs API token $DISCOGSTOKEN is not working - falling back to parsing HTML for $artistAlbum"
      getMetaDataFromDiscogsParseHTML $artistAlbum
   fi
else
   logit "You have no Discogs API token - falling back to parsing HTML for $artistAlbum"
   getMetaDataFromDiscogsParseHTML $artistAlbum
fi
}

testToken(){
   result=`curl -SsL "https://api.discogs.com/database/search?artist=kfsdf&release_title=ewfw&token=$DISCOGSTOKEN"`
   works=1
   echo $result | grep "results" >/dev/null 2>&1 && works=0
   return $works
}

getMetaDataFromDiscogsviAPI(){
    artistAlbum=$1
    artist=`echo ${artistAlbum}| sed s#'_'#' '#g | cut -d':' -f1 | tr '[:upper:]' '[:lower:]'`
    album=`echo ${artistAlbum} | sed s#'_'#' '#g | cut -d':' -f2 | tr '[:upper:]' '[:lower:]'`
    numberOftracksPlusLead=`cat /tmp/cddbOut1 | grep frames | wc -l` # every cd has a first frame 0-150, the lead.
    numberOftracksOnCd=`expr $numberOftracksPlusLead - 1`
    rm -rf /tmp/discogsMeta_*
    echo
    logit "Discog's API query : /usr/local/bin/nenrip-modules/discogs_search.py -t $DISCOGSTOKEN -a $artist -r $album -n $numberOftracksOnCd -m 1 -s"
    /usr/local/bin/nenrip-modules/discogs_search.py -t $DISCOGSTOKEN -a $artist -r $album -n $numberOftracksOnCd -m 1 -s
    if [ -f /tmp/discogsMeta_1 ]; then
       logit "Successfull Discog's API query!"
       ARTIST=`cat /tmp/discogsMeta_1 | grep ARTIST | cut -d":" -f2 | sed s#' '#'_'#g | sed s#"_(2)"##g`
       ALBUM=`cat /tmp/discogsMeta_1 | grep "ALBUM       :" | cut -d":" -f2 | sed s#' '#'_'#g`
       YEAR=`cat /tmp/discogsMeta_1 | grep YEAR | cut -d":" -f2`
       GENRE=`cat /tmp/discogsMeta_1 | grep GENRE | cut -d":" -f2 | sed s#' '#'_'#g`
       ALBUMARTURL="`cat /tmp/discogsMeta_1 | grep ALBUMARTURL | cut -d":" -f 2-`"
       TRACKS=`cat /tmp/discogsMeta_1 | grep TRACKS | cut -d":" -f2`

       formatArtistAlbumGenre
       makeTempFolders
       cat /tmp/discogsMeta_1 | grep "01_" -A$TRACKS | sed s#' '#'_'#g > "$FS_ROOT/$ARTIST/$ALBUM/"trackList

       logit "Located meta-data from Discog's API:"
       logit "ARTIST      : $ARTIST"
       logit "ALBUM       : $ALBUM"
       logit "YEAR        : $YEAR"
       logit "GENRE       : $GENRE"
       logit "ALBUMARTURL : $ALBUMARTURL"
       echo
       echo "Tracklist:"
       cat "$FS_ROOT/$ARTIST/$ALBUM/"trackList

       echo
       DISCOGS_GOT_HIT=0
    else
       DISCOGS_GOT_HIT=1
       logit "You got no Discog's results via API - falling back to parsing HTML for $artistAlbum"
       echo
       getMetaDataFromDiscogsParseHTML $artistAlbum
    fi
}

getMetaDataFromDiscogsParseHTML(){
    logit "Entering getMetaDataFromDiscogsParseHTML.."
    artistAlbum=$1
	rm -rf /tmp/discogs_tracks1 /tmp/discogs_tracks2
    artist=`echo ${artistAlbum}| sed s#'_'#' '#g | cut -d':' -f1 | tr '[:upper:]' '[:lower:]' | sed s#' '#'+'#g`
    album=`echo ${artistAlbum} | sed s#'_'#' '#g | cut -d':' -f2 | tr '[:upper:]' '[:lower:]'| sed s#' '#'+'#g`

    artistAlbumEncoded=`/usr/local/bin/nenrip-modules/discogs_search.py -a $artist -r $album -e`
    artistEncoded=`echo "$artistAlbumEncoded" | cut -d"|" -f2`
    releaseEncoded=`echo "$artistAlbumEncoded" | cut -d"|" -f4`

    echo "Using : $CURLCMD \"http://www.discogs.com/search?q=$artistEncoded+$releaseEncoded&format_exact=CD&btn=Search\" | grep href | grep release | grep -v needs_delegated_tooltip | grep -v Release | grep thumbnail | head -3 | sed s#'_'#' '#g | cut -d':' -f2 | tr '[:upper:]' '[:lower:]' | cut -d\"=\" -f2 | sed s#'\"'##g | sed s#\">\"##g | cut -d\" \" -f1 | sed s#'-'#'+'#g > /tmp/topThree" #>> ${LOGFILE}
    $CURLCMD "http://www.discogs.com/search?q=$artistEncoded+$releaseEncoded&format_exact=CD&btn=Search" | grep href | grep release | grep -v needs_delegated_tooltip | grep -v Release | grep thumbnail | head -3 | sed s#'_'#' '#g | cut -d':' -f2 | tr '[:upper:]' '[:lower:]' | cut -d"=" -f2 | sed s#'\"'##g | sed s#">"##g | cut -d" " -f1 | sed s#'-'#'+'#g> /tmp/topThree
    GOT_HTML_HIT=1
    if [ -f /tmp/topThree ]; then
       cat /tmp/topThree | egrep "[a-z]" > /dev/null 2>&1 && GOT_HTML_HIT=0
    fi

    if [ $GOT_HTML_HIT -eq 0 ]; then
        rm -rf /tmp/albumArtSrc
        relLink=
        albumNoparanthesis=`echo $album | cut -d'(' -f1 | sed s'/[^a-zA-Z]$//'`
        albumNoQuotes=`removeDangerousChars $albumNoparanthesis | sed s#\'##g`

        # search for album hit
        cat /tmp/topThree | while read example; do
           echo "found : $example looking for $album"
           echo $example | grep $album > /dev/null 2>&1 && echo $example > /tmp/albumArtSrc && logit "settled for $example source for locating album art" && break;
           echo "found : $example looking for $albumNoparanthesis"
           echo $example | grep $albumNoparanthesis > /dev/null 2>&1 && echo $example > /tmp/albumArtSrc && logit "settled for $example source for locating album art" && break;
           echo "found : $example looking for $albumNoQuotes"
           echo $example | grep $albumNoQuotes > /dev/null 2>&1 && echo $example > /tmp/albumArtSrc && logit "settled for $example source for locating album art" && break;
        done

        # search for artist hit
        if [ ! -f /tmp/albumArtSrc ]; then
        cat /tmp/topThree | while read example; do
           echo "found : $example looking for $artist"
           echo $example | grep $artist > /dev/null 2>&1 && echo $example > /tmp/albumArtSrc && logit "settled for $example source for locating album art" && break;
           done
        fi

        [ -f /tmp/albumArtSrc ] && relLink=`cat /tmp/albumArtSrc` && rm -rf /tmp/albumArtSrc && logit "Located relative link : $relLink"
        rm -rf /tmp/topThree
        DISCOGS_HIT=1
        [ `echo $relLink | wc -c` -gt 4 ] && echo $relLink | egrep "[0-9]" >/dev/null 2>&1 && echo "Got discocs hit!" && DISCOGS_HIT=0

        if [ $DISCOGS_HIT -eq 0 ]; then
            [ "`echo $ALBUM | tr '[:upper:]' '[:lower:]'`" == ".cd" ] && ALBUM='666'
            actualLink="http://www.discogs.com$relLink"
            echo
            $CURLCMD "$actualLink" > /tmp/discopage
            GENRE_SHORT=`echo $GENRE | cut -d' ' -f1`
            [ -z $GENRE_SHORT ] && GENRE=`cat /tmp/discopage | grep "/genre/" | head -1 | cut -d">" -f2 | cut -d"<" -f1 | sed s#" "#"_"#g`
            [ -z $YEAR ] && YEAR=`cat /tmp/discopage | grep "year=" | head -1 | cut -d"<" -f2 | cut -d"=" -f4 | cut -d'"' -f1`
            echo $ARTIST | egrep "[a-zA-Z]" > /dev/null 2>&1 || ARTIST=`cat /tmp/discopage | grep "/artist/" | head -1 | cut -d">" -f2 | cut -d"<" -f1 | sed s#" "#"_"#g`
            echo $ALBUM | egrep "[a-zA-Z]" > /dev/null 2>&1 || ALBUM=`cat /tmp/discopage | grep '/artist/' -C5 | head -10 | tail -1 | sed "s/^[ \t]*//" | sed s#" "#"_"#g | sed s#"_.Cd"##g`
            ALBUM_URL=`cat /tmp/discopage | grep og:image | cut -d"=" -f 3- | sed s#'"'##g | sed s#'>'##g`
            echo $ALBUM_URL | grep "\.gif" > /dev/null 2>&1 && ALBUM_URL= && logit "discogs only had a spacer gif though - no album art.."
            ALBUMARTURL=$ALBUM_URL

            formatArtistAlbumGenre

            echo
            logit "Located discogs meta-data from HTML parsing:"
            logit "ARTIST      : $ARTIST"
            logit "ALBUM       : $ALBUM"
            logit "YEAR        : $YEAR"
            logit "GENRE       : $GENRE"
            logit "ALBUMARTURL : $ALBUMARTURL"
            echo
        else
            echo ""
        fi
    else
        logit "Nope, we got no DISCOGS-html-parse hit.."
    fi
}

##
# Check for discogs for this album and artist
#
whenCddbDoesNotWork(){
    GOTHIT=1
    echo $ALBUMARTURL | egrep '[a-z]' > /dev/null 2>&1 && GOTHIT=0
    if [ $GOTHIT -eq 0 ] && [ -r /tmp/discopage ]; then
	   cat /tmp/discopage | grep -A1 "track_title" > /tmp/apa
	   cat /tmp/apa | grep tracklist_track_title | cut -d">" -f 3- | cut -d"<" -f1 > /tmp/discogs_tracks1
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
	return $GOTHIT
}

enterMetadataManually(){
    logit "Entering metadata manual approach."
    artistAlbum=$1
    ARTIST=`echo ${artistAlbum}| sed s#'_'#' '#g | cut -d':' -f1 | tr '[:upper:]' '[:lower:]'`
    ALBUM=`echo ${artistAlbum} | sed s#'_'#' '#g | cut -d':' -f2 | tr '[:upper:]' '[:lower:]'`
    GENRE=`echo ${artistAlbum} | sed s#'_'#' '#g | cut -d':' -f3 | tr '[:upper:]' '[:lower:]'`
    ask "What year was this album released?" unknown YEAR

    formatArtistAlbumGenre

    echo
    logit "You have specified this metadata:"
    echo
    logit "ARTIST      : $ARTIST"
    logit "ALBUM       : $ALBUM"
    logit "YEAR        : $YEAR"
    logit "GENRE       : $GENRE"
    echo
    echo  "is correct."

    ask "Could you paste in an URL to some album-art you'd wanna use (jpg)?" /usr/local/share/nenRip/nenRipCover.jpg ALBUMARTURL

    isJpg=1
    echo "$ALBUMARTURL" | tr '[:upper:]' '[:lower:]' | grep "jpg" > /dev/null 2>&1 && isJpg=0
    WORKROOT=$MP3_ROOT/$ARTIST/$ALBUM
    if [ ! -d $WORKROOT ]; then
	  mkdir -p "$WORKROOT"
	fi
    DOMOGRIFY=0
    if [ $isJpg -eq 0 ]; then
        echo $ALBUMARTURL | grep nenRipCover > /dev/null 2>&1 && DOMOGRIFY=1
    else
        echo "Sorry, that's no JPG : falling back to default album art.."
        ALBUMARTURL=/usr/local/share/nenRip/nenRipCover.jpg && DOMOGRIFY=1
    fi

    tryDownloadAlbumArt
    if [ $DOMOGRIFY -eq 0 ]; then
       logit "Converting image using mogrify.."
       mogrify -format jpg -quality 100 -resize 300x300! $WORKROOT/cover.jpg > /dev/null 2>&1
       echo "Done."
    fi

    logit "ALBUMARTURL : $WORKROOT/cover.jpg"
    echo

    numberOftracksPlusLead=`cat /tmp/cddbOut1 | grep frames | wc -l` # every cd has a first frame 0-150, the lead.
    numberOftracks=`expr $numberOftracksPlusLead - 1`
    GRABALL=1
    ask "Do you wish to grab ALL tracks (y) or just some (provide a comma-separated list)" y toGrab
    toGrab=`echo $toGrab | sed s#" "##g`
    echo $toGrab | grep "y" >/dev/null 2>&1 && GRABALL=0

    echo "artist: "$ARTIST | sed s#'_'#' '#g > /tmp/zepa
    echo "title: "$ALBUM | sed s#'_'#' '#g >> /tmp/zepa
    echo "category: rock" >> /tmp/zepa
    echo "genre: "$GENRE | sed s#'_'#' '#g >> /tmp/zepa
    echo "year: "$YEAR | sed s#'_'#' '#g >> /tmp/zepa
    echo "cddbid: UNKNOWN" >> /tmp/zepa
    echo "trackno: $numberOftracks" >> /tmp/zepa

    grablist=
    if [ $GRABALL -eq 0 ]; then
       index=1
	   while [ $index -lt $numberOftracksPlusLead ]; do
          ask "Provide the name of track $index (please use '_' for space!)" unknown trackName
          trackName=`echo $trackName | sed s#'_'#' '#g`
          trackName=`formatInput $trackName`
          indexString=$index
          if [ $index -lt 10 ]; then
             indexString="0$index"
          fi
          echo "track $indexString: $trackName.mp3" >> /tmp/zepa
          index=`expr $index + 1`
       done
    else
        upForGrabs=`echo $toGrab | sed s#','#' '#g`
        for index in ${upForGrabs}; do
           grablist+=' '$index
           ask "Provide the name of track $index (please use '_' for space!)" unknown trackName
           trackName=`echo $trackName | sed s#'_'#' '#g`
           trackName=`formatInput $trackName`
           indexString=$index
           if [ $index -lt 10 ]; then
              indexString="0$index"
           fi
           echo "track $indexString: $trackName.mp3" >> /tmp/zepa
        done
        echo "$toGrab" > /tmp/toGrab
    fi
    cat /tmp/zepa | grep -v "trackno" | grep "track" | sed s#'track '##g | sed s#' '#'_'#g | sed s#':'##g > /tmp/tracklist
    echo
    echo "The tracklist thus becomes:"
    echo
    cat /tmp/tracklist
    echo

    makeTempFolders
    mv /tmp/tracklist ./trackList

    logit "Ripping cd.."
    if [ $GRABALL -eq 0 ]; then
       dagrab -a -n $CDROM_SPEED -d $CDROMDEV
    else
        if [[ $grablist == " "* ]]; then
           tograb=`echo $grablist | cut -c1-`
           dagrab -n $CDROM_SPEED -d $CDROMDEV $tograb || GRAB_BAIL=0
        else
           dagrab -n $CDROM_SPEED -d $CDROMDEV $grablist || GRAB_BAIL=0
        fi
    fi
    GRABBED_ALREADY_FROM_MANUAL=0
    DISCOGS_GOT_HIT=0
}

tryDownloadAlbumArt(){
DODOWNLOAD=1
echo $ALBUMARTURL | egrep '[a-z]' | egrep '^(http|https)://' > /dev/null 2>&1 && DODOWNLOAD=0
if [ $DODOWNLOAD -eq 0 ]; then
   CURLCMD_NOSILENT=`echo $CURLCMD | sed s#"-s"#"-g"#g`
   cp /dev/null $WORKROOT/cover.jpg
   EXEC="$CURLCMD_NOSILENT \"$ALBUMARTURL\" --output \"$WORKROOT/cover.jpg\""
   echo "$EXEC" | tee -ai /tmp/down.sh
   chmod 777 /tmp/down.sh
   /tmp/down.sh
   rm -rf /tmp/down.sh
else
   logit "I have no link to album art, sorry : using /usr/local/share/nenRip/nenRipCover.jpg"
   cp /usr/local/share/nenRip/nenRipCover.jpg $WORKROOT/cover.jpg
   ALBUMARTURL=$WORKROOT/cover.jpg
fi
}

writeMetadataFile(){
WORKROOT=$MP3_ROOT/$ARTIST/$ALBUM
if [ ! -d $WORKROOT ]; then
  mkdir -p $WORKROOT
fi
[ -f $WORKROOT/.metadata ] && rm -rf $WORKROOT/.metadata
cd-discid $CDROMDEV > $CDID_FILE
echo
logit "Writing metadata file to $WORKROOT/.metadata"
echo
CDID=`cat $CDID_FILE`
echo "CDID        : $CDID" > $WORKROOT/.metadata
echo "ARTIST      : $ARTIST" >> $WORKROOT/.metadata
echo "ALBUM       : $ALBUM" >> $WORKROOT/.metadata
echo "YEAR        : $YEAR" >> $WORKROOT/.metadata
echo "GENRE       : $GENRE" >> $WORKROOT/.metadata
echo "ALBUMARTURL : $ALBUMARTURL" >> $WORKROOT/.metadata
}
