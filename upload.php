<?php
	function handleerror($msg) {
		header('HTTP/1.1 500 Internal Server Error');
		die($msg);
	}
	//ini_set('display_errors','On'); error_reporting(E_ALL ^ E_NOTICE);
	ini_set('display_errors','Off'); error_reporting(E_NONE);

	include_once('upload-config.inc.php');
	include_once('ntimelapse.inc.php');

	$contextid = $_GET['i'];

	// Password check.
	$idpassok = false;
	foreach ($upload_passwords as $id => $pass) {
		if ($contextid == $id && $_GET['p'] == $pass)
			$idpassok = true;
	}
	if (!$idpassok)
		handleerror('access denied');

	if (!isset($_GET['d']) || !is_numeric($_GET['d']) || $_GET['d'] <= 0)
		handleerror('invalid date given');

	// Check post_max_size (http://us3.php.net/manual/en/features.file-upload.php#73762)
	$POST_MAX_SIZE = ini_get('post_max_size');
	$unit = strtoupper(substr($POST_MAX_SIZE, -1));
	$multiplier = ($unit == 'M' ? 1048576 : ($unit == 'K' ? 1024 : ($unit == 'G' ? 1073741824 : 1)));

	if ((int)$_SERVER['CONTENT_LENGTH'] > $multiplier*(int)$POST_MAX_SIZE && $POST_MAX_SIZE)
		handleerror('POST exceeded maximum allowed size');

	// Validate the upload
	$uploaderrors = array(
        0 => 'There is no error, the file uploaded with success',
        1 => 'The uploaded file exceeds the upload_max_filesize directive in php.ini',
        2 => 'The uploaded file exceeds the MAX_FILE_SIZE directive that was specified in the HTML form',
        3 => 'The uploaded file was only partially uploaded',
        4 => 'No file was uploaded',
        6 => 'Missing a temporary folder'
	);
	if (!isset($_FILES[$upload_name]))
		handleerror("no upload found in \$_FILES for $upload_name");
	if (isset($_FILES[$upload_name]["error"]) && $_FILES[$upload_name]["error"] != 0)
		handleerror($uploaderrors[$_FILES[$upload_name]["error"]]);
	if (!isset($_FILES[$upload_name]["tmp_name"]) || !@is_uploaded_file($_FILES[$upload_name]["tmp_name"]))
		handleerror('upload failed is_uploaded_file test');
	if (!isset($_FILES[$upload_name]['name']))
		handleerror('file has no name');

	$file_size = @filesize($_FILES[$upload_name]["tmp_name"]);
	if (!$file_size || $file_size > $max_file_size_in_bytes)
		handleerror('file exceeds the maximum allowed size');

	if ($file_size <= 0)
		handleerror('file size outside allowed lower bound');

	if (!file_exists("$save_path/$contextid")) {
		if (!mkdir("$save_path/$contextid", 0777, true))
			handleerror("can't create directory $save_path/$contextid");
		chmod("$save_path/$contextid", 0775);
    }

	// Validating extension.
	$path_info = pathinfo($_FILES[$upload_name]['name']);
	$file_extension = strtolower($path_info['extension']);
	$is_valid_extension = false;
	foreach ($extension_whitelist as $extension) {
		if ($file_extension == $extension) {
			$is_valid_extension = true;
			break;
		}
	}
	if (!$is_valid_extension)
		handleerror('invalid file extension');

	$file_name = date('YmdHis', $_GET['d']) . '.' . $file_extension;
	$dst = "$save_path/$contextid/$file_name";
	if (!@move_uploaded_file($_FILES[$upload_name]['tmp_name'], $dst))
		handleerror('file could not be saved');

	// Generating a thumbnail.
	if ($file_extension == 'jpg') {
		ntimelapse_addoverlay($dst, $contextid, date('Y/m/d  H:i:s', $_GET['d']) . '  UTC' . ntimelapse_gettemptext($contextid));
		foreach ($thumbnail_heights as $height)
			ntimelapse_generatethumbnail($dst, "$save_path/$contextid-$height-tn.jpg", $height);

		// Creating a copy of the latest image.
		copy($dst, "$save_path/$contextid.jpg");

		if (isset($retranslate_urls[$contextid])) {
			$ch = curl_init();
			$fp = fopen($dst, 'r');
			curl_setopt($ch, CURLOPT_URL, $retranslate_urls[$contextid] . $file_name);
			curl_setopt($ch, CURLOPT_USERPWD, $retranslate_users[$contextid] . ':' . $retranslate_passwords[$contextid]);
			curl_setopt($ch, CURLOPT_UPLOAD, 1);
			curl_setopt($ch, CURLOPT_INFILE, $fp);
			curl_setopt($ch, CURLOPT_INFILESIZE, filesize($dst));
			curl_setopt($ch, CURLOPT_TIMEOUT, 10);
		    curl_exec($ch);
		    fclose($fp);
		    curl_close($ch);
		}
	}

	echo 'ok';
?>
