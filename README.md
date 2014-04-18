ntimelapse
==========

Scripts for processing webcam and sound uploads, generating and uploading
timelapse videos to YouTube.

#### Usage

There are two main components:

# upload.php

Receives and stores image and sound files in POST requests. It can put logo
overlays, dynamic date and weather texts onto images.

Copy *upload-config-example.inc.php* to *upload-config.inc.php*, then edit it.

# generateanduploadtimelapses.sh

As it's name says, this shell script can be used for generating timelapse
videos from image and sound files, and uploading them to YouTube.

Copy *generateanduploadconfig-example* to *generateanduploadconfig*, then edit
it. Make sure you have downloaded [nlogrotate](https://github.com/nonoo/nlogrotate).
