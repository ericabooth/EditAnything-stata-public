*==============================================================================*
* test_editanything.do -- battery for editanything v2.0.1
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

di as res _n "ALL TESTS PASSED: editanything battery complete"
