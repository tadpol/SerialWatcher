package provide tcmenubutton 1.0

# I cannot get the behavor and look I want from the menubutton. (tile or
# tk) So I'm just going to build one up from labels.
# I could probably get tile to do this, but holy-crappy documentation batman.
package require snit

snit::widget TCmenubutton {
	option -listvariable {}
	option -textvariable {}
	option -command {}

	delegate option * to ml except {-listvariable -textvariable -command}

	constructor {args} {
		install ml using label $win.l
		$self configurelist $args

		$win.l configure -textvariable $options(-textvariable)
		label $win.a -text \u25BC
		pack $win.a -side right
		pack $win.l -side right -expand yes -fill x

		menu $win.popup -tearoff no

		bind $win.l <Button-1> [mymethod popup]
		bind $win.a <Button-1> [mymethod popup]

		$self buildMenu
		upvar #0 $options(-listvariable) menuitems
		trace add variable menuitems write [mymethod buildMenu]
	}
	destructor {
		upvar #0 $options(-listvariable) menuitems
		trace remove variable menuitems write [mymethod buildMenu]
	}

	method doItemCommand {args} {
		if {$options(-command) eq ""} return
		uplevel #0 $options(-command)
	}

	method buildMenu {args} {
		upvar #0 $options(-listvariable) menuitems
		$win.popup delete 0 end
		foreach mi $menuitems {
			if {$mi eq "-"} {set li " - "} else {set li $mi}
			$win.popup add radiobutton -label $li -value $mi \
				-variable $options(-textvariable) \
				-command [mymethod doItemCommand]
		}
	}

	method popup {} {
		upvar #0 $options(-listvariable) menuitems
		upvar #0 $options(-textvariable) selected
		# tk_popup behaves quite different if index is specified or not.
		# If not there, X Y are the top-left of the menu.
		# If there, X Y are adjusted to locate the menuitem under the
		#   point. The assumption being that the point is the mouse.  So it
		#   looks damn funny when it isn't. So we need to counter that.
		if {[set idx [lsearch $menuitems $selected]] < 0} {
			tk_popup $win.popup [winfo rootx $win] [winfo rooty $win]
		} else {
			set X [expr [winfo rootx $win] + ([winfo width $win] / 2)]
			set Y [expr [winfo rooty $win] + ([winfo height $win] / 2)]
			tk_popup $win.popup $X $Y $idx
		}
	}
}

