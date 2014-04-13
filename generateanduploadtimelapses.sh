#!/bin/bash

self=`readlink -f "$0"`
scriptname=`basename "$self"`
scriptdir=${self%$scriptname}

. $scriptdir/generateanduploadconfig
. $nlogrotatepath/redirectlog.src.sh

if [ "$1" = "quiet" ]; then
	quietmode=1
	redirectlog
fi

mkdir -p $videooutputdir
mkdir -p $tempimagesequencedir
mkdir -p $tempsounddir

for idx in ${!contexts[*]}; do
	echo "processing context ${contexts[$idx]}..."

#	if [ ! -z "`ls $save_path/${contexts[$idx]}/*.mp3 2>/dev/null`" ]; then
	if [ 0 -eq 1 ]; then
		echo "  sounds detected"
		echo "    moving sounds from $save_path/${contexts[$idx]} to $tempsounddir"

		numberofsoundfiles=0
		for sndfile in `ls $save_path/${contexts[$idx]}/*.mp3`; do
#			mv -f $imgfile $tempsounddir/`printf "%02d\n" $numberofsoundfiles`.mp3
			cp -f $imgfile $tempsounddir/`printf "%02d\n" $numberofsoundfiles`.mp3
			numberofsoundfiles=$((numberofsoundfiles + 1))
		done

		mkdir -p "$tempsounddir/faded"
		filenum=1
		for sndfile in `ls $tempsounddir/*.mp3`; do
			sndfilename=`basename $sndfile`
		    length=`sox $sndfile -n stat 2>&1 | grep Length | awk '{ print $3 }' | cut -d'.' -f 1`
		    if [ $filenum = 1 ]; then
				echo "    fading the end of $sndfilename..."
				sox -q $sndfile "$tempsounddir/faded/$sndfilename" fade t 0 $length $((length/4))
			else
				if [ $filenum = $numberofsoundfiles ]; then
					echo "    fading the start, and padding $sndfilename..."
					sox -q $sndfile "$tempsounddir/faded/$sndfilename" fade t $((length/4)) pad $(( (filenum-1)*($length-5) ))
				else
					echo "    fading and padding $sndfilename..."
					sox -q $sndfile "$tempsounddir/faded/$sndfilename" fade t $((length/4)) $length pad $(( (filenum-1)*($length-5) ))
				fi
			fi
			filenum=$((filenum + 1))
		done

		mkdir -p "$tempsounddir/mixed"
		filenum=1
		for sndfile in `ls $tempsounddir/faded/*.mp3`; do
			$sndfilename=`basename ${sndfile/.mp3/}`
			if [ ! -z "$mixwith" ]; then
				echo "    mixing $mixwith.mp3 and $sndfilename.mp3"
				if [ $filenum = 2 ]; then
					sox -q -m $tempsounddir/faded/$mixwith.mp3 $tempsounddir/faded/$sndfilename.mp3 sounds/mixed/$mixwith$sndfilename.mp3
				else
					sox -q -m $tempsounddir/mixed/$mixwith.mp3 $tempsounddir/faded/$sndfilename.mp3 sounds/mixed/$mixwith$sndfilename.mp3
				fi
			fi
			mixwith=$mixwith$sndfilename
			filenum=$((filenum+1))
		done
		echo "    clearing $tempsounddir/faded/"
		rm -r $tempsounddir/faded/*.mp3

		sndfilename="${contexts[$idx]}-`date +%Y-%m-%d -d 'yesterday'`.mp3"
		echo "    creating $sndfilename"
		# TODO
		videolength=115
		sox -q $tempsounddir/mixed/$mixwith.mp3 $tempsounddir/$sndfilename norm compand 0.3,1 6:-70,-60,-20 -5 -90 0.2 fade t 5 $videolength

		echo "    clearing $tempsounddir/mixed/"
		rm -r $tempsounddir/mixed/*.mp3
	fi

	echo "  moving images from $save_path/${contexts[$idx]} to $tempimagesequencedir"
	i=1
	for imgfile in `ls $save_path/${contexts[$idx]}/*.jpg`; do
		mv -f $imgfile $tempimagesequencedir/`printf "%05d\n" $i`.jpg
#		cp -f $imgfile $tempimagesequencedir/`printf "%05d\n" $i`.jpg
		i=$((i + 1))
	done

	videofilename="${contexts[$idx]}-`date +%Y-%m-%d -d 'yesterday'`.avi"
	echo "  creating $videofilename"
	if [ ! -z "$sndfilename" ]; then
		ffmpeg -i $tempimagesequencedir/%05d.jpg -i $tempsounddir/$sndfilename -vcodec mpeg4 -vb 10000000 -r 25 -acodec copy -f avi -y $videooutputdir/$videofilename &>/dev/null
		result=$?
	else
		ffmpeg -i $tempimagesequencedir/%05d.jpg -vcodec mpeg4 -vb 10000000 -r 25 -an -f avi -y $videooutputdir/$videofilename &>/dev/null
		result=$?
	fi
	if [ $result -ne 0 ]; then
		echo "  ffmpeg error"
	fi

	echo "  clearing $tempimagesequencedir"
	rm -f $tempimagesequencedir/*.jpg
	echo "  clearing $tempsounddir"
	rm -f $tempsounddir/*.mp3

	if [ -f "$videooutputdir/$videofilename" ]; then
		echo "  uploading $videooutputdir/$videofilename"
		videourl=`$youtubeuploadbinary --email="${contextyoutubeemails[$idx]}" \
			--password="${contextyoutubepasswords[$idx]}" \
			--title="${contexttitles[$idx]}" \
			--category="Travel" \
			--description="${contextyoutubedescriptions[$idx]}" \
			--keywords="${contextyoutubekeywords[$idx]}" \
			--location="${contextyoutubelocations[$idx]}" \
			"$videooutputdir/$videofilename"`
		echo "  adding $videourl to the context playlist"
		$youtubeuploadbinary --email=${contextyoutubeemails[$idx]} \
			--password=${contextyoutubepasswords[$idx]} \
			--add-to-playlist="http://gdata.youtube.com/feeds/api/playlists/${contextyoutubeplaylistids[$idx]}" \
			$videourl
	fi

	echo "  clearing $videooutputdir"
	rm -f $videooutputdir/*.avi
done
