*! editanything v2.0.2  09nov2026
*! Eric A. Booth, Sr Researcher, Texas 2036 (eric.a.booth@gmail.com)
*! Elizabeth Teas, Sr Research Scientist, Far Harbor, LLC (elizabeth@farharbor.com)
*! Open *any* text file (.ado, .sthlp, .hlp, .do, .mata, .md, .txt, .html,
*! .raw, .csv, .tsv, .R, .py, .json, .yaml, .toml, .xml, .css, .js, .sql,
*! .sh, .bat, .ini, .cfg, .log, .smcl, .tex, .bib, ...) from inside Stata.
*!
*! Default: opens in the Do-file Editor (like SSC's -adoedit-) but works on
*! any text-readable extension. Options let you preview in the Viewer, hand
*! the file to your OS default app, copy contents to the clipboard, create
*! a new empty file, or safely clone a base/updates ado into PERSONAL.
*
* Changelog
*   2.0.2  09nov2026  r(file) and the banner always carry an absolute path:
*                     files found in or relative to the working folder were
*                     returned relative, and replace returned an unexpanded
*                     ~ path from c(sysdir_personal). Only a leading ~/ is
*                     expanded (HOME, then USERPROFILE, then HOMEDRIVE and
*                     HOMEPATH). clipboard reports a failed or missing
*                     pbcopy/xclip instead of always printing success. The
*                     doedit failure message shows its return code, and the
*                     suggested follow-up commands quote the full path.
*                     Removed the 32 KB guard for Stata < 11, which could not
*                     run under version 14.
*   2.0.1  09nov2026  external: the opener now receives the real path. macOS
*                     and Linux call open/xdg-open through the shell with the
*                     path single-quoted and report a failure; Windows passes
*                     plain double quotes and backslashes to cmd /c start.
*                     (2.0.0 sent Stata compound quotes, so the opener got a
*                     path that does not exist and the command still reported
*                     success.) Leading ~ also expands from USERPROFILE.
*   2.0.0  26may2026  Previous release.

program define editanything, rclass
    version 14

    syntax anything(name=fname id="filename" everything) [, ///
        EXTension(string)   ///
        EDitor              ///
        View                ///
        EXTernal            ///
        SHOWpath            ///
        CLIPboard           ///
        PERSONAL            ///
        REPlace             ///
        Force               ///
        NEW                 ///
        Quietly             ///
    ]

    *------------------------------------------------------------------*
    * 1. Clean the filename token
    *------------------------------------------------------------------*
    local fname : list clean fname
    local fname = subinstr(`"`fname'"', `"""', "", .)
    if `"`fname'"' == "" {
        di as err "filename required"
        exit 198
    }

    * mutually-exclusive open modes
    local nmodes = 0
    foreach m in editor view external showpath clipboard {
        if "``m''" != "" local ++nmodes
    }
    if `nmodes' > 1 {
        di as err "only one of {opt editor}, {opt view}, {opt external}, " ///
            "{opt showpath}, {opt clipboard} may be specified"
        exit 198
    }

    * default extension to try when none supplied
    if "`extension'" == "" local extension "ado"
    local extension = subinstr("`extension'",".","",.)

    * does the filename already carry an extension?
    local has_ext = 0
    local ext_given ""
    if regexm(`"`fname'"', "\.([A-Za-z0-9]+)$") {
        local has_ext  = 1
        local ext_given = strlower(regexs(1))
    }

    *------------------------------------------------------------------*
    * 2. -new-: create a brand-new empty file, then open it
    *------------------------------------------------------------------*
    if "`new'" != "" {
        local target `"`fname'"'
        if !`has_ext' local target `"`target'.`extension'"'

        * make absolute if a bare name was given
        if !regexm(`"`target'"', "^(/|~|[A-Za-z]:)") {
            local target `"`c(pwd)'/`target'"'
        }

        capture confirm file `"`target'"'
        if !_rc {
            di as err `"file already exists: `target'"'
            di as err "omit {opt new} to open it, or pick a different name."
            exit 602
        }

        tempname fh
        file open  `fh' using `"`target'"', write text
        file close `fh'
        di as txt `"created new file: {browse "`target'":`target'}"'
        local file `"`target'"'
    }

    *------------------------------------------------------------------*
    * 3. Resolve an existing file by searching cwd, ado-path, PERSONAL
    *------------------------------------------------------------------*
    if "`new'" == "" {
        local file ""

        * if -personal- requested, look there first
        if "`personal'" != "" {
            local p1 `"`c(sysdir_personal)'`fname'"'
            capture confirm file `"`p1'"'
            if !_rc local file `"`p1'"'
            if "`file'" == "" & !`has_ext' {
                local p2 `"`c(sysdir_personal)'`fname'.`extension'"'
                capture confirm file `"`p2'"'
                if !_rc local file `"`p2'"'
            }
        }

        * direct / relative path as given
        if "`file'" == "" {
            capture confirm file `"`fname'"'
            if !_rc local file `"`fname'"'
        }

        * ado-path search exactly as typed
        if "`file'" == "" {
            capture findfile `"`fname'"'
            if !_rc local file `"`r(fn)'"'
        }

        * ado-path search with default extension appended
        if "`file'" == "" & !`has_ext' {
            capture findfile `"`fname'.`extension'"'
            if !_rc local file `"`r(fn)'"'
        }

        * if default ext was .ado and that failed, try .sthlp / .hlp / .do
        if "`file'" == "" & !`has_ext' & "`extension'" == "ado" {
            foreach try in sthlp hlp do {
                capture findfile `"`fname'.`try'"'
                if !_rc {
                    local file `"`r(fn)'"'
                    continue, break
                }
            }
        }

        * fall back to PERSONAL even if not requested
        if "`file'" == "" {
            local p1 `"`c(sysdir_personal)'`fname'"'
            capture confirm file `"`p1'"'
            if !_rc local file `"`p1'"'
        }

        if "`file'" == "" {
            di as err `"file not found: {bf:`fname'}"'
            di as err "searched: current directory, full ado-path, and PERSONAL"
            di as err "(tip: pass {opt new} to create a new empty file)"
            exit 601
        }
    }

    *------------------------------------------------------------------*
    * 4. Normalize path: backslash -> /, expand a leading ~/, make the
    *    path absolute (relative hits are resolved against c(pwd))
    *------------------------------------------------------------------*
    _editanything_abspath `"`file'"'
    local file `"`ea_path'"'

    *------------------------------------------------------------------*
    * 5. Capture metadata: extension, size, base-file flag
    *------------------------------------------------------------------*
    local fext ""
    if regexm(`"`file'"', "\.([A-Za-z0-9]+)$") local fext = strlower(regexs(1))

    local fsize = .
    tempname fh
    capture file open `fh' using `"`file'"', read binary
    if !_rc {
        capture file seek `fh' eof
        if !_rc {
            file seek `fh' query
            local fsize = r(loc)
        }
        capture file close `fh'
    }

    local fbasename = substr(`"`file'"', strrpos(`"`file'"', "/")+1, .)

    local is_basefile = 0
    if index(`"`file'"',"/ado/base") | index(`"`file'"',"/ado/updates") {
        local is_basefile = 1
    }

    *------------------------------------------------------------------*
    * 6. -replace-: clone a base/updates file into PERSONAL, then edit
    *------------------------------------------------------------------*
    if "`replace'" != "" {
        if !`is_basefile' & "`personal'" == "" {
            di as txt "{opt replace} only relocates base/updates files; nothing to do."
        }
        else {
            local dest `"`c(sysdir_personal)'`fbasename'"'
            capture confirm file `"`dest'"'
            if !_rc {
                di as err `"PERSONAL copy already exists: `dest'"'
                di as err "delete it first, or open it directly:"
                di as err `"   . editanything `fbasename', personal"'
                exit 602
            }
            capture mkdir `"`c(sysdir_personal)'"'
            copy `"`file'"' `"`dest'"'
            di as txt `"copied: {input:`file'}"'
            di as txt `"    to: {input:`dest'}"'
            _editanything_abspath `"`dest'"'
            local file `"`ea_path'"'
            local is_basefile = 0
        }
    }

    *------------------------------------------------------------------*
    * 7. Pretty banner (unless -quietly-)
    *------------------------------------------------------------------*
    if "`quietly'" == "" {
        di as txt _n "{hline 70}"
        di as txt `"  file: {browse "`file'":`file'}"'
        di as txt "  type: ." as res "`fext'" as txt "      " _c
        if !missing(`fsize') {
            di as txt "size: " as res %12.0fc `fsize' as txt " bytes" _c
        }
        if `is_basefile' di as txt "      " as err "[Stata-supplied]"
        else             di ""
        di as txt "{hline 70}"
    }

    return local file       `"`file'"'
    return local extension  `"`fext'"'
    return local basename   `"`fbasename'"'
    if !missing(`fsize')  return scalar size = `fsize'

    *------------------------------------------------------------------*
    * 8. Warn before editing Stata-supplied files
    *------------------------------------------------------------------*
    if `is_basefile' & "`force'" == "" & "`view'" == "" & "`showpath'" == "" ///
                    & "`external'" == "" & "`clipboard'" == "" {
        di as err _n "Refusing to edit a Stata-supplied file in place."
        di as txt    `"   . editanything "`file'", replace"'
        di as txt    `"       (copy to PERSONAL, then edit)"'
        di as txt    `"   . editanything "`file'", view"'
        di as txt    `"       (open read-only in the Viewer)"'
        di as txt    `"   . editanything "`file'", force"'
        di as txt    `"       (edit anyway; updates may overwrite)"'
        exit 0
    }

    *------------------------------------------------------------------*
    * 9. Dispatch by mode
    *------------------------------------------------------------------*

    * -- showpath: already printed the clickable link
    if "`showpath'" != "" exit 0

    * detect platform robustly (c(os) is "Unix" on modern macOS Stata)
    local _ismac     = ("`c(os)'" == "MacOSX") | regexm("`c(machine_type)'", "Mac")
    local _iswindows = ("`c(os)'" == "Windows")

    * -- clipboard: copy raw file contents to system clipboard
    if "`clipboard'" != "" {
        if `_iswindows' {
            local wfile : subinstr local file "/" "\", all
            shell type "`wfile'" | clip
        }
        else {
            * an external program is required; the path is single-quoted
            * for /bin/sh and a failure (including a missing tool) is caught
            local cbtool = cond(`_ismac', "pbcopy", "xclip")
            local cbargs = cond(`_ismac', "", "-selection clipboard")
            local qfile : subinstr local file "'" "'\''", all
            tempfile cblog
            quietly shell cat '`qfile'' | `cbtool' `cbargs' > "`cblog'" 2>&1 || echo "__editanything_shell_failed__" >> "`cblog'"
            _editanything_readlog `"`cblog'"'
            if `ea_fail' {
                di as err `"`cbtool' could not copy the file to the clipboard: `macval(ea_msg)'"'
                if !`_ismac' di as err "(install xclip, or use {opt view} or {opt external} instead)"
                exit 691
            }
        }
        di as txt "contents copied to system clipboard."
        exit 0
    }

    * -- external: hand off to the OS default application
    *    (an external program is required, so this is the one OS-branched
    *    shell call; the path is passed with plain quoting the OS understands)
    if "`external'" != "" {
        if `_iswindows' {
            local wfile : subinstr local file "/" "\", all
            capture winexec cmd /c start "" "`wfile'"
            if _rc {
                di as err `"could not hand the file to the OS default application (rc=`=_rc')"'
                exit _rc
            }
        }
        else {
            local opener = cond(`_ismac', "open", "xdg-open")
            * single-quote for /bin/sh: each ' becomes '\''
            local qfile : subinstr local file "'" "'\''", all
            if substr(`"`file'"', 1, 1) == "-" local qfile `"./`qfile'"'
            tempfile oplog
            quietly shell `opener' '`qfile'' > "`oplog'" 2>&1 || echo "__editanything_shell_failed__" >> "`oplog'"
            _editanything_readlog `"`oplog'"'
            if `ea_fail' {
                di as err `"`opener' could not open the file: `macval(ea_msg)'"'
                exit 691
            }
        }
        di as txt "opened in OS default application."
        exit 0
    }

    * -- view: read-only in Viewer (renders SMCL for .sthlp/.hlp/.smcl)
    if "`view'" != "" {
        local smclexts sthlp hlp smcl
        if `: list fext in smclexts' {
            view `"`file'"'
        }
        else {
            view `"`file'"', asis
        }
        exit 0
    }

    *------------------------------------------------------------------*
    * 10. Default: open in the Do-file Editor
    *------------------------------------------------------------------*
    capture noisily doedit `"`file'"'
    if _rc {
        local rc = _rc
        di as err _n "doedit failed (rc=`rc')."
        di as txt "alternatives:"
        di as txt `"   . editanything "`file'", view"'
        di as txt `"   . editanything "`file'", external"'
        exit `rc'
    }
end


* Normalize a path: backslashes to /, a leading ~/ (or a bare ~) expanded
* from HOME, USERPROFILE, or HOMEDRIVE+HOMEPATH, a leading ./ dropped, and a
* relative path resolved against c(pwd).  Result in local ea_path.
program define _editanything_abspath
    version 14
    args p
    local p : subinstr local p "\" "/", all
    if `"`p'"' == "~" | substr(`"`p'"', 1, 2) == "~/" {
        local home : environment HOME
        if `"`home'"' == "" local home : environment USERPROFILE
        if `"`home'"' == "" {
            local hd : environment HOMEDRIVE
            local hp : environment HOMEPATH
            local home `"`hd'`hp'"'
        }
        if `"`home'"' != "" {
            local home : subinstr local home "\" "/", all
            local p = `"`home'"' + substr(`"`p'"', 2, .)
        }
    }
    while substr(`"`p'"', 1, 2) == "./" {
        local p = substr(`"`p'"', 3, .)
    }
    if !regexm(`"`p'"', "^(/|~|[A-Za-z]:/)") {
        local pwd `"`c(pwd)'"'
        local pwd : subinstr local pwd "\" "/", all
        if substr(`"`pwd'"', -1, 1) != "/" local pwd `"`pwd'/"'
        local p `"`pwd'`p'"'
    }
    c_local ea_path `"`p'"'
end


* Read a shell log written as  cmd > log 2>&1 || echo marker >> log.
* Sets ea_fail (1 if the marker is present) and ea_msg (first other line).
program define _editanything_readlog
    version 14
    args logfile
    local fail = 0
    local msg ""
    tempname oh
    capture file open `oh' using `"`logfile'"', read text
    if !_rc {
        file read `oh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "__editanything_shell_failed__") local fail = 1
            else if `"`macval(msg)'"' == "" local msg `"`macval(line)'"'
            file read `oh' line
        }
        file close `oh'
    }
    c_local ea_fail `fail'
    c_local ea_msg `"`macval(msg)'"'
end
