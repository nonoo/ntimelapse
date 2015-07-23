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

	contextsounddir=$save_path/${contexts[$idx]}
	contextmixedsndfile="${contexts[idx]}-`date +%Y-%m-%d -d 'yesterday'`-mixed.wav"
	if [ ! -z "${contextgetsoundfromsubdir[$idx]}" ]; then
		contextsounddir=$save_path/${contextgetsoundfromsubdir[$idx]}
		echo "  this context is using sounds from $contextsounddir"
		contextmixedsndfile="${contextgetsoundfromsubdir[$idx]}-`date +%Y-%m-%d -d 'yesterday'`-mixed.wav"
	fi

	if [ ! -f "$tempsounddir/$contextmixedsndfile" ]; then
		echo "  $tempsounddir/$contextmixedsndfile not found, creating it."

		if [ ! -z "`ls $contextsounddir/*.mp3 2>/dev/null`" ]; then
			echo "  sounds detected"

			mkdir -p "$tempsounddir/raw"
			numberofsoundfiles=0
			for srcfile in `ls $contextsounddir/*.mp3`; do
				dstfile="$tempsounddir/raw/`printf "%02d\n" $numberofsoundfiles`.wav"
				echo "    decompressing $srcfile to $dstfile"
				$lame --quiet --decode $srcfile $dstfile
				numberofsoundfiles=$((numberofsoundfiles + 1))
				if [ $testrun != 1 ]; then
					rm -f $srcfile
				fi
			done

			mkdir -p "$tempsounddir/faded"
			filenum=1
			for sndfile in `ls $tempsounddir/raw/*.wav`; do
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

			echo "    deleting $tempsounddir/raw"
			rm -r $tempsounddir/raw/*.wav
			rmdir $tempsounddir/raw

			echo "    mixing to $tempsounddir/$contextmixedsndfile..."
			sox -q -m $tempsounddir/faded/*.wav $tempsounddir/$contextmixedsndfile

			echo "    deleting $tempsounddir/faded"
			rm -r $tempsounddir/faded/*.wav
			rmdir $tempsounddir/faded
		else
			echo "  can't find any sounds"
		fi
	fi

	if [ -f "$tempsounddir/$contextmixedsndfile" ]; then
		echo "  found $tempsounddir/$contextmixedsndfile, processing"

		echo "    calculating video length"
		i=1
		for imgfile in `ls $save_path/${contexts[$idx]}/*.jpg`; do
			i=$((i + 1))
		done
		videolength=$((i / ${contextfps[$idx]}))
		echo "      video length is $videolength seconds"

		echo "    normalizing, audio compressing, trimming and fading $tempsounddir/$contextmixedsndfile"
		reducegain=-5
		if [ ! -z "${contextsoundgain[$idx]}" ]; then
			reducegain=-${contextsoundgain[$idx]}
			reducegain=$((reducegain-5))
		fi
		sox -q "$tempsounddir/$contextmixedsndfile" "$tempsounddir/normalized.wav" norm compand 0.3,1 6:-70,-60,-20 $reducegain -60 0.2 fade t 5 $videolength
		sox -q "$tempsounddir/normalized.wav" "$tempsounddir/final.wav" norm
		rm -f "$tempsounddir/normalized.wav"

		echo "    creating $tempsounddir/final.mp3 with lame"
		$lame --quiet -S -b 320 -m s -q 0 "$tempsounddir/final.wav" 2>/dev/null
		rm -f "$tempsounddir/final.wav"
	fi

	echo "  moving images from $save_path/${contexts[$idx]} to $tempimagesequencedir"
	i=1
	for imgfile in `ls $save_path/${contexts[$idx]}/*.jpg`; do
		if [ $testrun = 1 ]; then
			cp -f $imgfile $tempimagesequencedir/`printf "%05d\n" $i`.jpg
		else
			mv -f $imgfile $tempimagesequencedir/`printf "%05d\n" $i`.jpg
		fi
		i=$((i + 1))
	done

	videofilename="${contexts[$idx]}-`date +%Y-%m-%d -d 'yesterday'`.avi"
	if [ -e "$tempsounddir/final.mp3" ]; then
		echo "  creating $videofilename with sound"
		ffmpeg -i $tempimagesequencedir/%05d.jpg -i "$tempsounddir/final.mp3" -vcodec mpeg4 -vb 10000000 -r ${contextfps[$idx]} -acodec copy -f avi -y $videooutputdir/$videofilename &>/dev/null
		rm -f "$tempsounddir/final.mp3"
		result=$?
	else
		echo "  creating $videofilename without sound"
		ffmpeg -i $tempimagesequencedir/%05d.jpg -vcodec mpeg4 -vb 10000000 -r ${contextfps[$idx]} -an -f avi -y $videooutputdir/$videofilename &>/dev/null
		result=$?
	fi
	if [ $result -ne 0 ]; then
		echo "  ffmpeg error"
	fi

	echo "  clearing $tempimagesequencedir"
	rm -f $tempimagesequencedir/*.jpg

	if [ $testrun = 1 ]; then
		continue
	fi

	if [ -f "$videooutputdir/$videofilename" ]; then
		echo "  uploading $videooutputdir/$videofilename"
		videourl=`$youtubeuploadbinary \
			--credentials-file=$youtubeuploadcredentialsdir/credential-${contexts[$idx]}.json \
			--client-secrets=$youtubeuploadcredentialsdir/secret-${contexts[$idx]}.json \
			--title="${contexttitles[$idx]}" \
			--description="${contextyoutubedescriptions[$idx]}" \
			--tags="${contextyoutubekeywords[$idx]}" \
			--location="${contextyoutubelocations[$idx]}" \
			"$videooutputdir/$videofilename"`
		rm -f "$videooutputdir/$videofilename"
	fi
done

echo "cleaning up"
rmdir $videooutputdir
rmdir $tempimagesequencedir

rm -f $tempsounddir/*.wav
rmdir $tempsounddir

checklogsize
