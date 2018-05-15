#SingleInstance force

#Include %A_LineFile%\..\includes.ahk

/**
 * Search and replace string in files contents, file & folder names
 * Search is proceded down from current directory
 *
 * String is searched & replaced in following formats:
 *		"lower case"
 *		"Title Case"
 *		"kebab-case"
 *		"snake_case"
 *		"PascalCase"
 *		"camelCase"
 *
 * DEPENDENCY:
 *		https://github.com/hi5/TF#TF_RegExReplace
 */
Class ContentAndPathReplacer
{

	parent_dir	:= ""
	_mode	:= "" ; copy|replace
	_search	:= ""
	_replace	:= ""

	notations_search	:= {}
	notations_replace	:= {}

	search_regex_string	:= ""
	paths_replace_content	:= []
	paths_to_rename	:= {"files":[], "folders":[]}

	__New($parent_dir){
		this.parent_dir := $parent_dir
	}
	/** mode
	 */
	mode($mode){
		this._mode := $mode
		return this
	}
	/** searchAndRelace
	 */
	searchAndRelace($search, $replace)
	{

		this._search	:= this._sanitizeString($search)
		this._replace	:= this._sanitizeString($replace)

		this.notations_search	:= this._convertNotations(this._search)
		this.notations_replace	:= this._convertNotations(this._replace)

		this._setSearchRegExString()
		this._setFilesForReplaceContent()
		this._setPathsToRename("files")
		this._setPathsToRename("folders")

		if(this._confirmReplaceContent())
			this._replaceInFilesContents()

		if(this._confirmRenamePaths())
			this._processPaths()

		MsgBox,262144,, Success,1
	}

	/** convert any notation to lower case
	 */
	_sanitizeString($string)
	{
		$lowercase	:= RegExReplace($string, "([A-Z])", " $L1" )
		$sanitized	:= RegExReplace($lowercase, "(\s+|-|_)", " " )
		return %$sanitized%
	}
	/** _convertNotations
	 */
	_convertNotations($string)
	{
		$notations := {}
		StringLower, $lower_case, % $string
		StringLower, $title_case, % $string, T

		$notations["lower case"]	:= $lower_case
		$notations["Title Case"]	:= $title_case
		$notations["kebab-case"]	:= RegExReplace($lower_case,	"\s+", "-" )
		$notations["snake_case"]	:= RegExReplace($lower_case,	"\s+", "_" )
		$notations["PascalCase"]	:= RegExReplace($title_case,	"\s+", "" )
		$notations["camelCase"]	:= RegExReplace($notations.PascalCase, "^(.)", "$L1" )
		return %$notations%
	}
	/** setSearchRegExScript
	 */
	_setSearchRegExString()
	{
		$reg_ex := ""
		For $notation, $search_string in this.notations_search
			$reg_ex .= $search_string "|"

		this._search_regex_string := "("  SubStr($reg_ex, 1, StrLen($reg_ex)-1) ")"
	}
	/** set relative path with occurences of search string
	 */
	_setFilesForReplaceContent()
	{
		loop, % this.parent_dir "*.*", 0, 1
			if ( this._isSearchFind(A_LoopFileLongPath) && ! this._isExcluded(A_LoopFileLongPath) && ! this._isThisFile(A_LoopFileName) )
				this.paths_replace_content.push( this._getRelativePath(A_LoopFileLongPath) )
	}
	/** _isSearchFind
	 */
	_isSearchFind($path)
	{
		return % TF_Find($path, "", "", this._search_regex_string) ? 1 : 0
	}
	/** _isExcluded
	 */
	_isExcluded($path)
	{
		return % RegExMatch( $path, "\.(git|exe)$" ) ? 1 : 0
	}
	/** _isThisFile
	 */
	_isThisFile($filename)
	{
		return % RegExMatch( $filename, "ContentAndPathReplacer.(ahk|exe)" )
	}
	/** rename all file matching all notations
 	 */
	_setPathsToRename($files_or_folders){
		$mode := $files_or_folders=="files" ? 0 : 2
		For $notation, $search in this.notations_search
			loop, % this.parent_dir "*.*", %$mode%, 1
				if (RegExMatch( A_LoopFileName, $search ) && ! this._isExcluded(A_LoopFileLongPath))
					this.paths_to_rename[$files_or_folders].push( [this._getRelativePath(A_LoopFileLongPath), this._getRelativePath( A_LoopFileDir "\\" this._replaceInPath(A_LoopFileName, $search, this.notations_replace[$notation]) )] )
	}
	/** _replaceInPath
	 */
	_replaceInPath($file_or_folder_name, $search, $replace)
	{
		return % RegExReplace( $file_or_folder_name, $search, $replace )
	}
	/** _replaceInFilesContents
	 */
	_replaceInFilesContents()
	{
		For $i, $path_relative in this.paths_replace_content
			this._replaceInFile( this.parent_dir $path_relative)
	}
	/** replace In File content
	 */
	_replaceInFile($file_path)
	{
		;Dump($file_path, "file_path", 1)
		For $notation, $search in this.notations_search
			TF_RegExReplace( "!" $file_path, "m)" $search, this.notations_replace[$notation])
	}
	/** rename all file matching all notations
 	 */
	_processPaths()
	{
		For $type, $files_or_folders in this.paths_to_rename
			For $p, $paths in $files_or_folders
				if($type=="files"){
					if(this._mode =="COPY")
						this._copyFile($paths)
					else
						this._renameFile($paths)
				}else
					this._renameFolder($paths)
	}
	/**
 	 */
	_copyFile($paths)
	{
		FileCopy, % this.parent_dir $paths[1], % this.parent_dir $paths[2], 0
	}
	/**
 	 */
	_renameFile($paths)
	{
		FileMove, % this.parent_dir $paths[1], % this.parent_dir $paths[2], 1
	}
	/**
 	 */
	_renameFolder($paths)
	{
		FileMoveDir, % this.parent_dir $paths[1], % this.parent_dir $paths[2], R
	}
	/** _getRelativePath
	 */
	_getRelativePath($path)
	{
		return % SubStr($path, StrLen(this.parent_dir), StrLen($path))
	}
	/*
	   CONFIRMATION
	*/
	/** _confirmReplaceContent
	 */
	_confirmReplaceContent()
	{
		$message := "SEARCH:`t`t-> REPLACE:`n"  this._joinSearchAndReplace() "`n`nIN FILES:`n" this._joinPathsReplaceContent()
		MsgBox, 4, , %$message%
		IfMsgBox, Yes
			return 1
		return
	}
	/** _joinSearchAndReplace
	 */
	_joinSearchAndReplace()
	{
		For $key, $search in this.notations_search
			$string .= "`n" $search " `t-> " this.notations_replace[$key]
		return %$string%
	}
	/** _joinPathsReplaceContent
	 */
	_joinPathsReplaceContent()
	{
		For $k, $path in this.paths_replace_content
			$string .= "`n" $path
		return %$string%
	}

	/** _confirmRenamePaths
	 */
	_confirmRenamePaths()
	{
		$message := this._mode " THIS PATHS ?`n`nFOLDERS:" this._joinPathsToRename("folders") "`n`nFILES:" this._joinPathsToRename("files")
		MsgBox, 4, , %$message%
		IfMsgBox, Yes
			return 1
		return
	}
	/** _joinPathsToRename
	 */
	_joinPathsToRename($files_or_folders)
	{
		For $key, $paths in this.paths_to_rename[$files_or_folders]
			$string .= "`n" $paths[1] "  ->  " $paths[2] ""
		return %$string%
	}


}
/*---------------------------------------
	ON FILE EXECUTED
-----------------------------------------
*/
$selected_file	= %1% 

SplitPath, $selected_file,,,, $selected_file_noext

/*---------------------------------------
	GUI
-----------------------------------------
*/
$ContentAndPathReplacer := new ContentAndPathReplacer(A_WorkingDir "\\")

SplitPath, A_WorkingDir, $dir_name

Gui, Margin, 32, 32
Gui, font, s10

Gui, Add, Text,  h24 0x0200 section, % A_WorkingDir


Gui, Add, Text, w60  h24 xs section 0x0200, Search:
Gui, Add, Edit, w300 h24 vsearch ys, % $selected_file_noext

Gui, Add, Text, w60  h24 xs section 0x0200, Replace:
Gui, Add, Edit, w300 h24 ys vreplace, % $dir_name


Gui, Add, Button, w120 h30 xs section, Copy
Gui, Add, Button, w120 h30 ys, Replace
Gui, Add, Button, w120 h30 ys, Cancel

Gui, Show,, Search 	MsgBox,262144,mode, %$mode%,3and replace everything
GuiControl, Focus, replace

Return


buttonCopy:
gui, submit
$ContentAndPathReplacer.mode("COPY").searchAndRelace(search, replace)
reload

buttonReplace:
gui, submit
$ContentAndPathReplacer.mode("REPLACE").searchAndRelace(search, replace)
reload



buttonCancel:
GuiClose:
GuiEscape:
ExitApp

