<?php
	function ntimelapse_generatethumbnail($origimgpath, $thumbnail_dstpath, $thumbnail_height) {
		$img = imagecreatefromjpeg($origimgpath);
		$width = imagesx($img);
		$height = imagesy($img);
		if ($thumbnail_height >= $height) {
			imagedestroy($img);
			copy($origimgfilepath, $thumbnail_dstpath);
			return;
		}
		$newheight = $thumbnail_height;
		$newwidth = floor(($newheight/$height)*$width);
		$tmpimg = imagecreatetruecolor($newwidth, $newheight);
		imagecopyresized($tmpimg, $img, 0, 0, 0, 0, $newwidth, $newheight, $width, $height);
		imageinterlace($tmpimg, 1);
		imagejpeg($tmpimg, $thumbnail_dstpath, 90);
		imagedestroy($img);
		imagedestroy($tmpimg);
	}

	function ntimelapse_addoverlay($dst, $contextid, $datetext) {
		global $overlays_path, $datetext_xpos, $datetext_ypos, $datetext_size;

		$overlaypath = "$overlays_path/$contextid.png";
		if (!file_exists($overlaypath))
			return;

		$overlay = imagecreatefrompng($overlaypath);
		$img = imagecreatefromjpeg($dst);
		imagecopy($img, $overlay, 0, 0, 0, 0, imagesx($img), imagesy($img));
		imagefttext($img, $datetext_size[$contextid], 0, $datetext_xpos[$contextid]+1, $datetext_ypos[$contextid]+1, imagecolorallocate($img, 0, 0, 0), "$overlays_path/$contextid.ttf", $datetext);
		imagefttext($img, $datetext_size[$contextid], 0, $datetext_xpos[$contextid], $datetext_ypos[$contextid], imagecolorallocate($img, 255, 255, 255), "$overlays_path/$contextid.ttf", $datetext);
		imageinterlace($img, 1);
		imagejpeg($img, $dst, 100);
		imagedestroy($img);
		imagedestroy($overlay);
	}

	function ntimelapse_gettemptext($contextid) {
		global $tempdata_mysql_hosts, $tempdata_mysql_users, $tempdata_mysql_passwords,
			$tempdata_mysql_dbs, $tempdata_mysql_querys, $tempdata_format;

		if (!array_key_exists($contextid, $tempdata_mysql_querys))
			return;
		$mysqlconn = new mysqli($tempdata_mysql_hosts[$contextid], $tempdata_mysql_users[$contextid], $tempdata_mysql_passwords[$contextid], $tempdata_mysql_dbs[$contextid]);
		if ($mysqlconn->connect_error)
			return;
		$res = $mysqlconn->query($tempdata_mysql_querys[$contextid]);
		if (!$res)
			return;
		$row = $res->fetch_row();
		if (!$row || !isset($row[0]))
			return;
		$res->free();
		$mysqlconn->close();
		return sprintf($tempdata_format, $row[0]);
	}
?>
