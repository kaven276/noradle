upload file
=============

## oracle can specify where the upload file will be saved

* full path including directory and filename with ext.
`
	<input type="hidden" name="_file" value="test/filename.ext"/>
	<input type="file" name="file" />
	If upload file name is "myfile.jpg"
	The file will save at test/filename.ext
`

* only directory where the original named file will be saved
`
	<input type="hidden" name="_file" value="test/"/>
	<input type="file" name="file" />
	Note that the _file's value is "test/" where the last character is "/"
	If upload file name is "myfile.jpg"
	The file will save at test/myfile.jpg
`

* full path including directory and filename with ext the same as original file's ext.
`
	<input type="hidden" name="_file" value="test/filename."/>
	<input type="file" name="file" />
	Note that the _file's value is "test/filename." where the last character is "."
	If upload file name is "myfile.jpg"
	The file will save at test/filename.jpg
`

## if not specify saving path, node will use random path

  Node will generate a 32-bytes hex string for the saving filename, 
By default, node will split the hex string to two 16-bytes hex string and join them using "/",
This way, if too many file are uploaded, the upload file saving root directory will not be filled with too much file,
that will cause finding in the big directory very slow.

  You can specify in cfg.js to set upload_depth to 1,2,3,4 for deeper directory, that is

* 1: auto/32.ext
*	2: auto/16/16.ext
* 3: auto/10/10/12.ext
* 4: auto/8/8/8/8.ext

## anti script infection mechanism 

  If upload file's content-type is "text/html" or the upload file's extension is .html or .htm, PSP.WEB will stripe all `<script>` tags, that will prevent the html file from loading or executing harmful javascript code, such as to stolen other user's identity cookie value.