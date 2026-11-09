*==============================================================================*
* test_editanything.do -- battery for editanything v2.0.2
* Run:  stata-mp -b do test_editanything.do ["/path/to/pkg"]
* Batch-safe: exercises showpath, returns, creation, and refusals only
* (opening the Do-file Editor is a GUI action and is not tested here).
* Judge the run by the log: no r(NNN) errors, no "assertion is false".
*==============================================================================*
clear all
set more off

if `"`1'"' != "" global pkgroot `"`1'"'
if `"$pkgroot"' == "" {
    capture findfile editanything.ado
    if !_rc {
        local fp `"`r(fn)'"'
        local s = max(strrpos(`"`fp'"', "/"), strrpos(`"`fp'"', "\"))
        if `s' > 1 global pkgroot = substr(`"`fp'"', 1, `s' - 1)
    }
}
if `"$pkgroot"' == "" {
    di as err "test_editanything: cannot locate editanything.ado."
    exit 601
}
confirm file "$pkgroot/editanything.ado"
adopath ++ "$pkgroot"
discard

*--- (1) showpath finds a file on the adopath and returns its pieces ----------*
editanything editanything.ado, showpath
local f  `"`r(file)'"'
local x  `"`r(extension)'"'
local b  `"`r(basename)'"'
assert `"`f'"' != ""
confirm file `"`f'"'
assert `"`x'"' == "ado"
assert `"`b'"' == "editanything.ado"
di as res "TEST 1 OK: showpath resolves editanything.ado on the adopath"

*--- (2) size is returned for a real file -------------------------------------*
editanything editanything.ado, showpath
assert r(size) > 0 & r(size) < .
di as res "TEST 2 OK: r(size) = " r(size) " bytes"

*--- (3) a nonexistent file fails loudly --------------------------------------*
capture noisily editanything zz_no_such_file_zz.ado, showpath
assert _rc != 0
di as res "TEST 3 OK: missing file errors (rc " _rc ")"

*--- (4) extension() steers resolution ----------------------------------------*
editanything editanything, extension(sthlp) showpath
assert `"`r(extension)'"' == "sthlp"
di as res "TEST 4 OK: extension(sthlp) resolves the help file"

*--- (5) files found in or relative to the working folder return absolute --*
local here `"`c(pwd)'"'
local wd `"`c(tmpdir)'/editanything test dir"'
mata: st_local("de", strofreal(direxists(st_local("wd"))))
if !`de' {
    mkdir `"`wd'"'
}
mata: st_local("de", strofreal(direxists(st_local("wd") + "/config")))
if !`de' {
    mkdir `"`wd'/config"'
}
quietly cd `"`wd'"'
local wd `"`c(pwd)'"'
tempname fh
file open `fh' using `"`wd'/project_notes.md"', write text replace
file close `fh'
file open `fh' using `"`wd'/config/settings.toml"', write text replace
file close `fh'
editanything project_notes.md, showpath
assert `"`r(file)'"' == `"`wd'/project_notes.md"'
editanything project_notes, ext(md) showpath
assert `"`r(file)'"' == `"`wd'/project_notes.md"'
editanything "config/settings.toml", showpath
assert `"`r(file)'"' == `"`wd'/config/settings.toml"'
erase `"`wd'/project_notes.md"'
erase `"`wd'/config/settings.toml"'
rmdir `"`wd'/config"'
quietly cd `"`here'"'
rmdir `"`wd'"'
di as res "TEST 5 OK: relative hits come back as absolute paths"

*--- (6) replace copies a base ado into PERSONAL and returns that path -------*
local oldp `"`c(sysdir_personal)'"'
local pd `"`c(tmpdir)'/editanything personal/"'
sysdir set PERSONAL `"`pd'"'
capture erase `"`pd'ttest.ado"'
editanything ttest, replace showpath
local got `"`r(file)'"'
local want `"`pd'ttest.ado"'
local want : subinstr local want "//" "/", all
local got2 : subinstr local got "//" "/", all
assert `"`got2'"' == `"`want'"'
confirm file `"`got'"'
erase `"`got'"'
capture rmdir `"`pd'"'
sysdir set PERSONAL `"`oldp'"'
di as res "TEST 6 OK: replace returns the PERSONAL copy"

*--- (7) a Stata-supplied file is refused without opening anything -----------*
editanything ttest
assert strpos(`"`r(file)'"', "/ado/base/") > 0
di as res "TEST 7 OK: Stata-supplied file refused"

di as res _n "ALL TESTS PASSED: editanything battery complete"
