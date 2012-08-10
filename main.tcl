package require starkit
starkit::startup

package require snit
#package require configfile
package require tcmenubutton
package require tablelist

::snit::widgetadaptor rotext {
	constructor {args} {
		# Turn off the insert cursor
		#installhull using text $self -insertwidth 0
		# DDG the $self gaves an error at least with 0.97 onwards
		installhull using text -insertwidth 0

		# Apply an options passed at creation time.
		$self configurelist $args
	}

	# Disable the insert and delete methods, to make this readonly.
	method insert {args} {}
	method delete {args} {}

	# Enable ins and del as synonyms, so the program can insert and
	# delete.
	delegate method ins to hull as insert
	delegate method del to hull as delete

	# Pass all other methods and options to the real text widget, so
	# that the remaining behavior is as expected.
	delegate method * to hull
	delegate option * to hull
}

snit::widget PortOptionsWindow {
	option -port ""
	option -baud 57600
	option -parity n
	option -databits 8
	option -stopbits 1
	option -ashex NO
	option -autonewline YES
	option -color black
	option -open NO
	option -sends NO
	option -colorchangedcmd {}
	option -appendcmd {}

	variable channel ""

	# some vars for popups.
	typevariable bauds {110 300 600 1200 2400 4800 9600 14400 19200 38400 57600 115200 230400 460800 921600}
	typevariable parities {n o e m s}
	typevariable databitss {5 6 7 8}
	typevariable stopbitss {1 2}
	typevariable portList {}

	typeconstructor {
		set portList [$type listPorts]
		# A little bit of a hack to let us get smaller buttons.
		image create bitmap ${type}::colorimage \
			-data "#define data_width 1\n#define data_height 1\nstatic unsigned char data_bits[] = { 0x00 };"
	}

	constructor {args} {
		$self configurelist $args

		set f [frame $win.port]
		label $f.cl -text Port:
		if {$options(-port) eq ""} {
			set options(-port) [lindex $portList 0]
		}
		TCmenubutton $f.cc -textvariable [myvar options](-port) \
			-listvariable [mytypevar portList] \
			-width 10 \
			-anchor e
		pack $f.cl $f.cc -side left
		pack $f -anchor w

		set f [frame $win.mode]
		label $f.ml -text Mode:
		TCmenubutton $f.baud -textvariable [myvar options](-baud) \
			-listvariable [mytypevar bauds] \
			-width 6 \
			-anchor e
		TCmenubutton $f.parity -textvariable [myvar options](-parity) \
			-listvariable [mytypevar parities] \
			-width 1 \
			-anchor e
		TCmenubutton $f.databits -textvariable [myvar options](-databits) \
			-listvariable [mytypevar databitss] \
			-width 1 \
			-anchor e
		TCmenubutton $f.stopbits -textvariable [myvar options](-stopbits) \
			-listvariable [mytypevar stopbitss] \
			-width 1 \
			-anchor e
		pack $f.baud $f.parity $f.databits $f.stopbits -side left
		pack $f -anchor w

		set f [frame $win.opts]
		checkbutton $f.ashex -text "As Hex" -variable [myvar options](-ashex)
		checkbutton $f.anl -text "Auto \\n" -variable [myvar options](-autonewline)
		button $f.color -height 10 -width 30 -image ${type}::colorimage -bg $options(-color) -command [mymethod changeColor]
		checkbutton $f.open -text Open -variable [myvar options](-open) -command [mymethod toggleOpen]
		checkbutton $f.sends -text Sends -variable [myvar options](-sends)
		grid $f.ashex -column 0 -row 0 -sticky nw
		grid $f.anl -column 1 -row 0 -sticky nw
		grid $f.open -column 0 -row 1 -sticky nw
		grid $f.sends -column 1 -row 1 -sticky nw
		grid $f.color -column 0 -row 2 -sticky nw
		pack $f -anchor w

		# make sure to call this atleast once.
		after idle "uplevel #0 $options(-colorchangedcmd) $self"
	}

	destructor {
		if {$channel ne ""} {
			catch {close $channel}
		}
	}

	method changeColor {} {
		set newcolor [tk_chooseColor -initialcolor $options(-color) -title "Pick Text Color:"]
		if {$newcolor ne ""} {
			set options(-color) $newcolor
			$win.color configure -bg $options(-color)
			if {$options(-colorchangedcmd) ne ""} {
				uplevel #0 $options(-colorchangedcmd) $self
			}
		}
	}

	method modeLine {} {
		return "$options(-baud),$options(-parity),$options(-databits),$options(-stopbits)"
	}

	typemethod listPorts {} {
		if {$::tcl_platform(platform) eq "windows"} {
			set serial_base "HKEY_LOCAL_MACHINE\\HARDWARE\\DEVICEMAP\\SERIALCOMM"
			set values [registry values $serial_base]
			foreach valueName $values {
				lappend result [registry get $serial_base $valueName]
			}
			return [lsort $result]
		} else {
			return [glob -nocomplain -path /dev/ttyS *]
		}
	}

	method toggleOpen {} {
		if {$channel ne ""} {
			catch {close $channel}
			set channel ""
		} else {
			if {$::tcl_platform(platform) eq "windows"} {
				set ucm "\\\\.\\$options(-port)"
			} else {
				set ucm $options(-port)
			}

			if {[catch {open $ucm r} res opt]} {
				puts ":: $res :: $opt ::"
				set options(-open) no
			} else {
				set channel $res
				fconfigure $res -translation binary -mode [$self modeLine]
				fconfigure $res -blocking 0 -buffering none
				fileevent $res readable [mymethod doRead]
			}
		}
	}

	method doRead {} {
		if {[eof $channel]} {
			set options(-open) no
			catch {close $channel}
			set channel ""
			return
		}

		set data [read $channel]

		# convert to hex dump
		if {$options(-ashex)} {
			binary scan $data H* data
			set data [regsub -all {(..)} $data {\1 }
		}

		uplevel #0 $options(-appendcmd) $data $options(-port)

		# if autonewline and last char in data is not newline, suffix newline
		if {$options(-autonewline] && [string index $data end] != "\n"} {
			uplevel #0 $options(-appendcmd) "\n"
		}
	}

	method send {args} {
		if {!$options(-sends)} return
		if {$channel eq ""} return
		if {$options(-ashex)} {
			set data [regsub -all {[[:xdigit:]]} [join $args] {}]
			set data [binary format H* $data]
		} else {
			set data [join $args]
		}
		puts -nonewline $channel $data
	}
}

snit::widget PortList {
	option -powoptions {}

	typevariable somecolors {black red blue green yellow orange violet}
	variable ports {}

	constructor {args} {
		$self configurelist $args

		tablelist::tablelist $win.t \
			-activestyle none \
			-background SystemButtonFace \
			-columntitles {ports} \
			-listvariable [myvar ports] \
			-selectbackground SystemButtonFace \
			-showlabels no \
			-yscrollcommand [list $win.y set] \
			-width 0
		$win.t columnconfigure 0 -formatcommand [mymethod emptyStr] -sortmode integer
		scrollbar $win.y -orient vertical -command [list $win.t yview]
		set f [frame $win.f]
		button $f.add -text + -command [mymethod add]
		button $f.del -text - -command [mymethod del]
		pack $f.add $f.del -side left

		grid $win.t -column 0 -row 0 -sticky news
		grid $win.y -column 1 -row 0 -sticky nes
		grid $win.f -column 0 -row 1 -sticky ws
		grid columnconfigure $win 0 -weight 1
		grid rowconfigure $win 0 -weight 1


		# always should have atleast one
		$self add
	}

	destructor {
	}

	method emptyStr {val} {return ""}
	method createPOW {tbl row col w} {
		set clr [lindex $somecolors [expr $row % [llength $somecolors]]]
		PortOptionsWindow $w -color $clr {*}$options(-powoptions)
	}

	method add {} {
		$win.t insert end {""}
		$win.t cellconfigure end,0 -window [mymethod createPOW] -stretchwindow yes
	}

	method del {} {
		if {[llength $ports] > 1} {
			$win.t delete end end
		}
	}

	method send {args} {
		set r [lindex [split [$win.t cellindex end] ,] 0]
		for {set i 0} {$i <= $r} {incr i} {
			[$win.t windowpath $i,0] send {*}$args
		}
	}
}

snit::widget TextView {
	component txt
	constructor {args} {
		set txt $win.t
		rotext $win.t -yscrollcommand [list $win.y set]
		scrollbar $win.y -orient vertical -command [list $win.t yview]

		$self configurelist $args

		grid $win.t -column 0 -row 0 -sticky news
		grid $win.y -column 1 -row 0 -sticky nes
		grid columnconfigure $win 0 -weight 1
		grid rowconfigure $win 0 -weight 1

	}

	method ins {args} {
		$win.t ins {*}$args
		if {[lindex [$win.y get] 1] == 1.0} {
			$win.t see end
		}
	}

	# Pass all other methods and options to the real text widget, so
	# that the remaining behavior is as expected.
	delegate method * to txt
	delegate option * to txt
}

snit::widgetadaptor cmdentry {
	option -command {}
	variable history {}
	variable history_index 0

	constructor {args} {
		installhull using entry
		$self configurelist $args

		bind $win <Key-Return> "[mymethod dosend]; break"
		bind $win <Key-Escape> {%W delete 0 end; break}
		bind $win <Alt-Up> "[mymethod hist prev]; break"
		bind $win <Alt-Down> "[mymethod hist next]; break"
	}

	method dosend {} {
		lappend history [$win get]
		set history_index 0
		uplevel #0 $options(-command) [$win get]
		$win delete 0 end
	}

	method {hist prev} {} {
		incr history_index -1
		if {$history_index < 0} {
			set history_index [llength $history]
			incr history_index -1
		}
		$win delete 0 end
		$win insert 0 [lindex $history $history_index]
	}

	method {hist next} {} {
		incr history_index 1
		if {$history_index >= [llength $history]} {
			set history_index 0
		}
		$win delete 0 end
		$win insert 0 [lindex $history $history_index]
	}

	delegate method * to hull
	delegate option * to hull
}

namespace eval gui {
	variable w_text

	proc go {} {
		wm client . "Serial Watcher"
		wm title .  "Serial Watcher"

		pack [buildRoot .r] -expand yes -fill both

		wm protocol . WM_DELETE_WINDOW { destroy . }

		bind . <Control-asciitilde> {console show; break}

		focus -force .
	}
	proc gone {} {
		destroy .r
	}

	proc buildRoot {name} {
		variable w_text
		# root is two panes, a list of ports and a read only text view.
		set n [panedwindow $name]

		set powopt [list -appendcmd ::gui::appendText -colorchangedcmd ::gui::colorchanged]

		$n add [PortList $n.pl -powoptions $powopt] -sticky news -minsize 150

		set f [frame $n.tv]
		set w_text $f.text
		TextView $w_text -wrap word
		cmdentry $f.en -command "$n.pl send"
		pack $f.text $f.en -side top -fill both -expand yes
		$n add $f -sticky news -stretch always

		return $name
	}

	proc colorchanged {pow} {
		variable w_text
		$w_text tag configure [$pow cget -port] -foreground [$pow cget -color] \
			-lmargin2 [font measure [$w_text cget -font] m] \
			-spacing3 [dict get [font metrics [$w_text cget -font]] -descent]
	}

	proc appendText {args} {
		variable w_text
		$w_text ins end {*}$args
	}
}

::gui::go
#console show

