<?php
	// These contexts and passwords should be specified to the upload script as
	// HTTP GET parameters. The format is: camera/soundcard name => password.
	// Rename this example file to upload-config.inc.php.
	$upload_passwords = array('name1' => 'password1',
		'name2' => 'password2');

	// The POST field name of the file.
	$upload_name = 'FILE1';

	// Path where uploaded files will be stored under their camera/soundcard
	// directories (these dirs will be auto created).
	$save_path = '/var/opt/ntimelapse';

	// Allowed file extensions
	$extension_whitelist = array('jpg', 'png', 'jpeg', 'mp3', 'wav');

	// This is the maximum file size which can be uploaded.
	$max_file_size_in_bytes = 2000000;

	// Thumbnail heights to generate.
	$thumbnail_heights = array(140);

	// Path where the image PNG overlays can be found.
	$overlays_path = "$save_path/overlays";

	// Current date will be written to these x & y coordinates with the given font size.
	$datetext_xpos = array('name1' => 5);
	$datetext_ypos = array('name1' => 678);
	$datetext_size = array('name1' => 8);

	// If there's temperature data then it can be added to the date text.
	$tempdata_mysql_hosts = array('name1' => 'localhost');
	$tempdata_mysql_users = array('name1' => 'user1');
	$tempdata_mysql_passwords = array('name1' => 'password1');
	$tempdata_mysql_dbs = array('name1' => 'db1');
	$tempdata_mysql_querys = array('name1' => 'select `temp-out` from `nweather` order by `date` desc limit 1');
	$tempdata_format = '    %.2f °C';

	// At the end, the uploaded image will be posted to the given URL with curl.
	$retranslate_users = array('name1' => 'user1');
	$retranslate_passwords = array('name1' => 'password1');
	$retranslate_urls = array('name1' => 'ftp://ftp.something.com/');
?>
