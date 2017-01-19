#!/bin/sh

# ------------- Some help functions ------------

wordsInitialUpper(){
   echo "$@" | tr '[:upper:]' '[:lower:]' | sed s#'_'#' '#g | sed -e "s/\b\(.\)/\u\1/g" | sed s#' '#'_'#g
}

formatInput(){
input="$@"
HAVEINPUT=1
echo $input | egrep "[a-z0-9]" >/dev/null 2>&1 && HAVEINPUT=0
if [ $HAVEINPUT -eq 0 ]; then
   output=`removeDangerousChars "$input"`
   output=`wordsInitialUpper "$output"`
   echo $output
fi
echo ""
}

formatArtistAlbumGenre(){
    # Yep.. it's a hack for M.I.A. _again_
    [ "$ARTIST" != "M.I.A." ] && ARTIST=`formatInput "$ARTIST"`
	ALBUM=`formatInput "$ALBUM"`
    GENRE=`formatInput "$GENRE"`
}

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

##
# Remove bad characters
#
removeDangerousChars(){
    args="${@}"
    echo $args | sed "s#\&amp;#&#g; s#\&lt;#<#g; s#\&gt;#>#g; s#\&\#39;#'#g; s#\&quot;#"\""#g" | sed s#">"##g | sed s#"<"##g | sed s#"\/"#""#g | sed s#"__"#"_"#g | sed s#"\'"##g | sed s#"\""##g | sed s#"\;"##g
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
        input="$@"
        echo "$input" | tee -ai ${LOGFILE}
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

# Syntax _w (wrapReturn)
# arg1 : method to wrap
# arg2 : variable to set
_w(){
eval $1
read $2 <<EOF
$?
EOF
eval $2=\$$2
}


