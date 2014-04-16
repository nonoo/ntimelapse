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
#idx=2
	echo "processing context ${contexts[$idx]}..."

	contextsounddir=$save_path/${contexts[$idx]}
	if [ ! -z "${contextgetsoundfromsubdir[$idx]}" ]; then
		contextsounddir=$save_path/${contextgetsoundfromsubdir[$idx]}
	fi

#	if [ ! -z "`ls $contextsounddir/*.mp3 2>/dev/null`" ]; then
	if [ 0 -eq 1 ]; then
		echo "  sounds detected"
		numberofsoundfiles=0
		for srcfile in `ls $contextsounddir/*.mp3`; do
			dstfile="$tempsounddir/`printf "%02d\n" $numberofsoundfiles`.wav"
			echo "    decompressing $srcfile to $dstfile"
			$lame --quiet --decode $srcfile $dstfile
			numberofsoundfiles=$((numberofsoundfiles + 1))
#			rm -f $srcfile
		done

		mkdir -p "$tempsounddir/faded"
		filenum=1
		for sndfile in `ls $tempsounddir/*.wav`; do
			echo "    processing $sndfile..."
			sndfilename=`basename $sndfile`

		    length=`sox $sndfile -n stat 2>&1 | grep Length | awk '{ print $3 }' | cut -d'.' -f 1`
		    echo "      length $length seconds"

			if [ ! -z "${contextsoundgain[$idx]}" ]; then
				echo "      adding gain of ${contextsoundgain[$idx]}..."
				sox -q $sndfile "$tempsounddir/gained.wav" gain ${contextsoundgain[$idx]}
				mv -f "$tempsounddir/gained.wav" $sndfile
			fi

		    if [ $filenum = 1 ]; then
				echo "      fading the end of $sndfilename..."
				sox -q $sndfile "$tempsounddir/faded/$sndfilename" fade t 0 $length $((length/4))
			else
				if [ $filenum = $numberofsoundfiles ]; then
					echo "      fading the beginning of $sndfilename..."
					sox -q $sndfile "$tempsounddir/faded/$sndfilename" fade t $((length/4))
				else
					echo "      fading the beginning and the end of $sndfilename..."
					sox -q $sndfile "$tempsounddir/faded/$sndfilename" fade t $((length/4)) $length
				fi

				# We are not using sox padding because it generates noise.
				silencelength=$(( (filenum-1)*($length-5) ))
				echo "      adding $silencelength seconds silence to the beginning of the file"
				sox -n -r 48000 -c 2 -b 16 "$tempsounddir/silence.wav" trim 0.0 $silencelength
				sox -q "$tempsounddir/silence.wav" "$tempsounddir/faded/$sndfilename" "$tempsounddir/faded.wav"
				rm -f "$tempsounddir/silence.wav"
				mv -f "$tempsounddir/faded.wav" "$tempsounddir/faded/$sndfilename"
			fi
			filenum=$((filenum + 1))
		done

		sndfilename="${contexts[$idx]}-`date +%Y-%m-%d -d 'yesterday'`"
		echo "    mixing..."
		sox -q -m $tempsounddir/faded/*.wav $tempsounddir/$sndfilename.wav
		echo "    clearing $tempsounddir/faded/"
		rm -r $tempsounddir/faded/*.wav

		echo "    normalizing, audio compressing, trimming and fading $sndfilename.wav"
		# TODO
		videolength=115
		echo "      video length is $videolength seconds"
		reducegain=-5
		if [ ! -z "${contextsoundgain[$idx]}" ]; then
			reducegain=-${contextsoundgain[$idx]}
			reducegain=$((reducegain-5))
		fi
		sox -q "$tempsounddir/$sndfilename.wav" "$tempsounddir/$sndfilename-tmp.wav" norm compand 0.3,1 6:-70,-60,-20 $reducegain -60 0.2 fade t 5 $videolength
		sox -q "$tempsounddir/$sndfilename-tmp.wav" "$tempsounddir/$sndfilename.wav" norm

		echo "    creating $tempsounddir/$sndfilename.mp3 with lame"
		$lame --quiet -S -b 320 -m s -q 0 $tempsounddir/$sndfilename.wav 2>/dev/null
		sndfilename=$sndfilename.mp3

		echo "    clearing $tempsounddir"
		rm -r $tempsounddir/*.wav
exit
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
