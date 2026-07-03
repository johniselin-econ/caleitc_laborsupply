** Install all Stata packages required by the CalEITC pipeline
** Run once from the repo root: stata-mp -b do code/hpc/install_packages.do
** Packages land in the default PLUS directory (~/ado/plus), shared via NFS
** with compute nodes.

clear all
set more off

foreach pkg in ftools reghdfe ppmlhdfe fre coefplot estout gtools ///
    balancetable ivreghdfe ivreg2 ranktest _gwtmean rwolf2 wyoung ///
    psacalc blindschemes {
    capture which `pkg'
    di "Installing `pkg'..."
    capture noisily ssc install `pkg', replace
}

** parallel (not on SSC)
capture noisily net install parallel, ///
    from("https://raw.github.com/gvegayon/parallel/stable/") replace

** TAXSIM local
capture noisily net install taxsimlocal35, ///
    from("https://taxsim.nber.org/stata") replace

** Report what's installed
foreach cmd in reghdfe ppmlhdfe esttab coefplot rwolf2 parallel taxsimlocal35 {
    capture which `cmd'
    if _rc == 0 di "OK: `cmd'"
    else di "MISSING: `cmd'"
}
