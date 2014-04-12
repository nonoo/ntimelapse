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

for idx in ${!contexts[*]}; do
	echo "processing context ${contexts[$idx]}..."

	echo "  moving images from $save_path/${contexts[$idx]} to $tempimagesequencedir"
	i=1
	for imgfile in `ls $save_path/${contexts[$idx]}/*.jpg`; do
		mv -f $imgfile $tempimagesequencedir/`printf "%05d\n" $i`.jpg
		i=$((i + 1))
	done

	videofilename="${contexts[$idx]}-`date +%Y-%m-%d -d 'yesterday'`.avi"
	echo "  creating $videofilename"
	# TODO: audio mix
	ffmpeg -i $tempimagesequencedir/%05d.jpg -vcodec mpeg4 -vb 10000000 -r 25 -an -f avi -y $videooutputdir/$videofilename &>/dev/null
	if [ $? -ne 0 ]; then
		echo "  ffmpeg error"
	fi

	echo "  clearing $tempimagesequencedir"
	rm -f $tempimagesequencedir/*.jpg

	if [ -f "$videooutputdir/$videofilename" ]; then
		echo "  uploading $videooutputdir/$videofilename"
		videourl=`youtube-upload --email="${contextyoutubeemails[$idx]}" \
			--password="${contextyoutubepasswords[$idx]}" \
			--title="${contexttitles[$idx]}" \
			--category="Travel" \
			--description="${contextyoutubedescriptions[$idx]}" \
			--keywords="${contextyoutubekeywords[$idx]}" \
			--location="${contextyoutubelocations[$idx]}" \
			"$videooutputdir/$videofilename"`
		echo "  adding $videourl to the context playlist"
		youtube-upload --email=${contextyoutubeemails[$idx]} \
			--password=${contextyoutubepasswords[$idx]} \
			--add-to-playlist="http://gdata.youtube.com/feeds/api/playlists/${contextyoutubeplaylistids[$idx]}" \
			$videourl
	fi

	echo "  clearing $videooutputdir"
	rm -f $videooutputdir/*.avi
done
