package provide configfile 1.0
# used with permission.

namespace eval configfile {
	variable varlist {}
	variable contents ""
	variable filepath ""
	variable writePending no

	proc addVar {args} {
		variable varlist
		lappend varlist {*}$args

		foreach v $args {
			trace add variable $v {write unset} \
				[list [namespace current]::autoRecord $v]
		}
	}

	proc delVar {args} {
		variable varlist
		set nvars {}
		foreach v $varlist {
			if {$v ni $args} {
				lappend nvars $v
			}
		}
		set varlist $nvars
	}

	proc setPath {fname} {
		variable filepath
		set path ""
		switch -glob $::tcl_platform(os) {
			Windows* {
				if {[info exists ::env(APPDATA)]} {
					set path $::env(APPDATA)
				} else {
					set path $::env(HOME)
				}
				# If no extenstion, add one. Otherwise use what was given
				if {[file extension $fname] eq ""} {
					set fname ${fname}.rc
				}
			}
			macintosh {
				set path [file join $::env(HOME) Library Preferences]
				if {[string range $fname end-1 end] ne "rc"} {
					set fname ${fname}rc
				}
			}
			default {
				# assume a Unix style prefernce file.
				if {[string index $fname 0] ne "."} {
					set fname .$fname
				}
				if {[string range $fname end-1 end] ne "rc"} {
					set fname ${fname}rc
				}
				set path $::env(HOME)
			}
		}
		set filepath [file join $path $fname]
	}

	proc clear {} {
		variable contents
		set contents ""
	}

	# trace add variable <var> {write unset} \
		[list ::configFileAuto::autoRecord <var>]
	proc autoRecord {name0 name1 name2 op} {
		variable contents
		if {$op eq "write"} {
			upvar 1 $name0 bob
			dict set contents $name0 $bob
		} elseif {$op eq "unset"} {
			dict unset contents $name0
		}
		delayedWrite
	}

	proc recordAll {} {
		variable varlist
		variable contents
		foreach v $varlist {
			dict set contents $v [set $v]
		}
	}

	proc replayAll {} {
		variable varlist
		variable contents
		foreach v $varlist {
			if {[dict exists $contents $v]} {
				set $v [dict get $contents $v]
			}
		}
	}

	proc writeFile {} {
		variable contents
		variable filepath
		variable writePending

		set fd [open $filepath w]
		puts $fd $contents
		close $fd
		set writePending no
	}

	proc delayedWrite {} {
		variable writePending
		if $writePending return
		set writePending yes
		after 1000 [namespace current]::writeFile 
	}

	proc readFile {} {
		variable contents
		variable filepath

		if [file exists $filepath] {
			set fd [open $filepath]
			set contents [read $fd]
			close $fd
		}
	}

	proc setup {confFile args} {
		setPath $confFile
		addVar {*}$args
		readFile
		replayAll
	}
}

