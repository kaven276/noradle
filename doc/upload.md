upload file
=============

## oracle can specify where the upload file will be saved

* full path including directory and filename with ext.
`
	<input type="hidden" name="_file" value="test/filename.ext"/>
	<input type="file" name="file" />
	If upload file name is myfile.jpg
	The file will save at test/filename.ext
`

* only directory where the original named file will be saved
`
	<input type="hidden" name="_file" value="test/"/>
	<input type="file" name="file" />
	Note that the _file's value is "test/" where the last character is "/"
	If upload file name is myfile.jpg
	The file will save at test/myfile.jpg
`

* full path including directory and filename with ext the same as original file's ext.
`
	<input type="hidden" name="_file" value="test/filename."/>
	<input type="file" name="file" />
	Note that the _file's value is "test/filename." where the last character is "."
	If upload file name is myfile.jpg
	The file will save at test/filename.jpg
`