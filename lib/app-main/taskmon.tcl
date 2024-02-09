#!/bin/sh
# ---------------------------------------------------------------------------------------
# Description:
#  TMA Task Monitor for TO 4.0
# ---------------------------------------------------------------------------------------
# Developer : Cris Magalang
# Date : 2020-12-01
# ---------------------------------------------------------------------------------------
# Revision History:
# 2020-MM-DD   Cris Magalang   Alpha   Development Releases -- Untracked versions
# 2021-04-08   Cris Magalang   1.0     First Perforce Checkin - Rev 1.0
# 2021-04-12   Cris Magalang   1.0.0.1 Update task_status features - show,sel,limit options.
#                                      -show : added column sort features
#                                      -sel  : MySQL select options
#                                      -limit : limit number of records to return

# ---------------------------------------------------------------------------------------
# Application Release version
# the next line restarts using tclsh \
exec /APP1/Tcl/`uname -s`-`uname -m | sed 's/\/.*//'`/ActiveTcl8.5.17.0/bin/tclsh8.5 "$0" "$@"

package provide app-main 1.0

package require cmdline
package require base64
package require Itcl
package require TclCurl
package require tdom 0.9.2
package require json
package require tma_microsvcs
package require sqlite3

set appVersion 1.0.1

namespace eval app-main {
	set main(applist) {
        la
        activelist
        alert
        close
        create
        delete
        event
        rerun
        status
        help
        update
        tocb
        report_lr
        lr
    }

	namespace ensemble create -map {
		la         get_active_list
		activelist get_active_list
		close      event_close
		create     event_create
		delete     event_delete
		event      to40_event
		status     event_status
		update     event_update
		rerun      event_rerun
		report_lr  report_long_running_and_errors
		lr         report_long_running_and_errors
		tocb       tows_log_callback
		help       help

    }
}

# Sendout Alerts
proc app-main::help {args} {
	puts "OPTIONS:"
    #puts "  \[get active list\]    : <script> la"
    puts "  \[Long Running Tasks\] : <script> lr"
    puts "  \[Create event entry\] : <script> create"
    #puts "  \[Update event\]       : <script> update   -uuid [exec uuidgen] -name FORM001-TSF001 -group Submitted -status running"
    puts "  \[Update event\]       : <script> update   -tid 1000,1001 -status manualComplete -dis"
	puts "  \[Rerun event\]        : <script> rerun    -\[-tid <tid> | -uuid <uuid>  \] \[-test\]" 
    #puts "  \[Mark task as :"
    #puts "          close          : <script> uclose  \[-tid <tid> | -uuid <uuid>  \] \[-test\] -dis"
    #puts "          Cancelled      : <script> ucancel \[-tid <tid> | -uuid <uuid>  \] \[-test\] -dis"
    #puts "          done           : <script> udone   \[-tid <tid> | -uuid <uuid>  \] \[-test\] -dis"
	  #puts "          manualComplete : <script> umc     \[-tid <tid> | -uuid <uuid>  \] \[-test\] -dis"
    #puts "          Ignore         : <script> ignore  \[-tid <tid> | -uuid <uuid>  \] \[-test\] -dis"
    #puts "          Deleted        : <script> udel    \[-tid <tid> | -uuid <uuid>  \] \[-test\] -dis"
    #puts "          Deleted        : <script> delete  \[-tid <tid> | -uuid <uuid>  \] \[-test\] -dis"
    puts "  \[Get status\]         : <script> status ..."
    #puts "  \[Task Rerun\]         : <script> retry   \[-tid <tid> | -uuid <uuid>  \] \[-test\]"
    #puts "  \[Retry\] 	           : <script> rerun   \[-tid <tid> | -uuid <uuid>  \] \[-test\]"
    puts "  \[Event Tracker Add\]  : <script> event <action> <maskset> <FORM> <formiId> <json> \[-test\]"
    #puts "  \[Send Tasks\]         : <script> sendtask ... "
    puts "    <script> help     "
}

proc app-main::setenv {mode} {
	switch -nocase -exact -- $mode {
		development - dev -
		test - testing - uat {
			tma_microsvcs %RUNOBJ test
		}
		prod - production - prd  {
			tma_microsvcs %RUNOBJ production
		}
		default {
			tma_microsvcs %RUNOBJ $mode
	    }
    }
    return
}

# Update LR Task status to close.
proc app-main::event_close {args} {
	set options {
		{tid.arg     "" "Database stored ID, Optional" }
		{uuid.arg    "" "Assigned uuid if needed, Optional" }
		{test        "Set environment==test, default=prod" }
	}

	set usage "\\> event_close \[options\]"
	set cmdusage [::cmdline::usage $options $usage]
    if {[catch {array set params [::cmdline::getoptions args $options $usage]} error]} {
        puts "[info script] $cmdusage"
        puts "e.g. [file tail [info script]] close -test -uuid [exec uuidgen]"
        return 1
    }
    array set opts {}
    if {[string length $params(uuid)]>0} {set opts(uuid) $params(uuid)}
    if {[string length $params(tid)]>0} {set opts(tid) $params(tid)}
    if {$params(test)} {setenv test} else {setenv prod}
    if {[catch {%RUNOBJ task_close [array get opts]} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else {
    	puts LinesClosed=$retMsg
    	return -code ok 0
	}

}

# Insert create message record
proc app-main::event_create {args} {
	set options {
		{uuid.arg    "" "Assigned uuid if needed, Optional" }
		{name.arg    "" "Assigned name, {FORM/Formid/}, REQUIRED" }
		{group.arg   "" "Assigned job group, REQUIRED" }
		{status.arg  "started" "Set initial status, default=started" }
		{updated.arg "" "Specify date time %Y-%m-%d %T, default=CurrentTimestamp" }
		{dis         "Set job as disable, active=0" }
		{test        "Set environment==test, default=prod" }
	}

	set usage "\\> event_create \[options\]"
	set cmdusage [::cmdline::usage $options $usage]
    if {[catch {array set params [::cmdline::getoptions args $options $usage]} error]} {
        puts "[info script] $cmdusage"
        puts "e.g. [file tail [info script]] -uuid [exec uuidgen] -name FORM001-TSF001 -group Submitted -status started"
        return 1
    }

    array set opts {}
    set sklist {uuid dis test}
    set errmsg ""
    if {[string length $params(name)] < 1} {
		append errmsg "Error: -name <Name OR ptrfNumber OR ptrfNumber OR FORMNumber> required.\n"
	}
    if {[string length $params(group)] < 1} {
		append errmsg "Error: -group <Action Name OR TaskName OR GroupType> required."
	}
    foreach key [array names params] {
    	if {[lsearch $sklist $key] >=0} {continue}
    	if {[string length $params($key)]>0} {lappend opts(job_$key) $params($key)}
    }
    if {$params(dis)} {set opts(job_active) 0}
    if {[string length $params(uuid)]>0} {set opts(uuid) $params(uuid)}
    if {$params(test)} {setenv test} else {setenv prod}
    if {$errmsg ne ""} {
    	parray params
    	puts $errmsg
    	exit 1
	}

    if {[catch {%RUNOBJ task_insert [array get opts]} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else {
    	puts InsertID=$retMsg
    	return -code ok 0
	}
}

proc event_status_showlist_map_elem {elem} {

	switch -regexp [string tolower $elem] {
		"^name" - "^formid" - "^FORM" - "^job*" {
			set elem "jobName"
	    }
	    "^group" - "^grp" - "^g" {
			set elem "GROUP"
	    }
	    "^stat*" - "^s" {
			set elem "STATUS"
	    }
	    "^uuid" {
			set elem "UUID"
	    }
	    "^tid" - "^id" {
			set elem "TID"
	    }
	    "^active" - "^act*" {
			set elem "ACTIVE"
	    }
	    "^datec*" - "^created" - "^dc" {
			set elem "dateCreated"
	    }
	    "^dateu*" - "^updated" - "^du" {
			set elem "dateUpdated"
	    }
	    "^diffn*" - "^dnu" {
			set elem "diffNowUpdate"
	    }
	    ^default {
	    	###
	    }
	}
	return $elem
}

proc app-main::event_status {args} {
	set options {
		{tid.arg     "" "Database stored ID, Optional" }
		{uuid.arg    "" "Assigned uuid if needed, Optional" }
		{name.arg    "" "Assigned name, {FORM/Formid/}, Optional" }
		{group.arg   "" "Assigned job group, Optional" }
		{status.arg  "" "Get with assigned status" }
		{show.arg    "" "Specify list of fields to display" }
		{sel.arg     "" "Select query filter option. <WHERE {}>" }
		{limit.arg   "500" "Limit number of results count <DEFAULT : 500>" }
		{log            "Get run log information" }
		{v              "verbose" }
		{test        "Set environment==test, default=prod" }
	}

	set usage "\\> Get event status \[options\]"
	set cmdusage [::cmdline::usage $options $usage]
    if {[catch {array set params [::cmdline::getoptions args $options $usage]} error]} {
        puts "[info script] $cmdusage"
        puts "e.g. [file tail [info script]] status -uuid [exec uuidgen]"
        return 1
    }
    array set opts {}
    set sklist {tid uuid dis test} 
    foreach key [array names params] {
    	if {[lsearch $sklist $key] >=0} {continue}
    	if {[string length $params($key)]>0} {lappend opts(job_$key) $params($key)}
    }
    if {[string length $params(uuid)]>0} {set opts(uuid) $params(uuid)}
    if {[string length $params(tid)]>0} {set opts(tid) $params(tid)}
    if {[string length $params(sel)]>0} {set opts(sel) $params(sel)}
    if {[string length $params(limit)]>0} {set opts(limit) $params(limit)}
    if {$params(test)} {setenv test} else {setenv prod}
    if {[catch {%RUNOBJ task_get_status [array get opts]} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else {
		array set all_result $retMsg
		#set show_list {jobName GROUP STATUS UUID}
		set show_list {jobName GROUP STATUS active UUID DATE}
		if {$params(log)} {
			lappend show_list log
		}
		if {[string length $params(show)] > 0} {
			set show_list [split [regsub -all "," $params(show) " "] " "]
		}
		foreach key [lsort -dictionary [array names all_result]] {
			array set RESULT $all_result($key)
			if {$params(log)} {
				#1. some actions
				#2. embed to RESULT
				#3. Append log to show_list
				set RESULT(log) [app-main::getLogFile [array get params] [array get RESULT] ]
			}
			set printlist {}
			foreach elem $show_list {
				set elem [event_status_showlist_map_elem $elem]
				if {[info exists RESULT($elem)]} {
					lappend printlist $RESULT($elem)
				} else {
					lappend printlist ""
			    }
		    }
			if {$params(v)} {
				parray RESULT
				puts ""
			} else {
				#puts "$RESULT(jobName),$RESULT(GROUP),$RESULT(STATUS),$RESULT(UUID)"
				puts [join $printlist ,]
		    }
	    }
    	return -code ok 0
	}
}
proc app-main::getLogFile {fnargs result} {
	array set params $fnargs
	array set RESULT $result
	#set start [clock seconds]
	#set RESULT $result
	if {$params(test)} {
		set path "/csm/log/to40_test/"
		set GtoPath "/gtofilesystem/tws_test/"
		#puts "path is $path"
	} else {
		set path "/csm/log/to40/"
		set GtoPath "/gtofilesystem/tws/"
		#puts "path is $path"
	}
	set RegResult [regexp -inline -all -- {(^FORM\d{6})} $RESULT(jobName)]
	set FORM [lindex $GtoPath 0] ;# In the event the regexp return >1 result
	set neutral_file "${GtoPath}${FORM}/neutralfileXml_${FORM}"
	set cmd "xml_grep -root 'tsf_form/name' -text ${neutral_file} " ;# To filter out those active TSF_form
	catch {exec csh -c $cmd} FORM_form ;# Get the active TSF FORM
	set year [clock format [clock scan $RESULT(dateUpdated)] -format %Y]
	set month [clock format [clock scan $RESULT(dateUpdated)] -format %m]
	set directory "${path}${RESULT(GROUP)}/${year}/${month}/"
	#set cmd "ls $directory | grep $RESULT(jobName)"
	set cmd "glob $directory/$RESULT(GROUP)*$RESULT(jobName)*.log"
	#puts " Directory is : <$directory> while group is <$RESULT(GROUP)> \n"
	if {[ catch {exec csh -c $cmd} stdout] } {
		set log "No Logfile Available"
	} else {
		set log "" ;# initialise logfile variables
		foreach logfile $stdout {
			lappend log "${directory}/[file tail $logfile]"
		}
	}
	#set end [clock seconds]
	#puts "Time taken per result is [expr {$end - $start}] seconds \n"
	return $log
}
proc app-main::event_rerun {args} {
	set options {
		{tid.arg     "" "Database stored ID, Optional" }
		{uuid.arg    "" "Assigned uuid if needed, Optional" }
		{name.arg    "" "Assigned name, {FORM/Formid/}, Optional" }
		{group.arg   "" "Assigned job group, Optional" }
		{test  		 "Set environment==test, default=prod" }
	}
    set usage "\\ event_rerun \[options]"
	set cmdusage [::cmdline::usage $options $usage]
    if {[catch {array set params [::cmdline::getoptions args $options $usage]} error]} {
        puts "[info script] $cmdusage"
        puts "e.g. [file tail [info script]] -uuid [exec uuidgen]"
        return 1
    }
    array set opts {}
    set sklist {uuid test} 
    foreach key [array names params] {
    	if {[lsearch $sklist $key] >=0} {continue}
    	if {[string length $params($key)]>0} {lappend opts(job_$key) $params($key)}
    }
    if {[string length $params(uuid)]>0} {set opts(uuid) $params(uuid)}
    if {[string length $params(name)]>0} {set opts(uuid) $params(uuid)}
    if {[string length $params(tid)]>0} {set opts(tid) $params(tid)}
    if {$params(test)} {setenv test} else {setenv prod}
	if {[catch {%RUNOBJ task_get_status [array get opts]} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else { ;# go retrieve the relevant information for rerun 
		array set all_result $retMsg
		foreach key [lsort -dictionary [array names all_result]] {
			array set RESULT $all_result($key)
			if {$params(uuid) eq $RESULT(UUID) || $params(tid) eq $RESULT(TID)} {
				set op $RESULT(GROUP)
				set formid $RESULT(jobName)
				set uuid $RESULT(UUID)
				set date [clock format [clock scan "$RESULT(dateCreated)"] -format {%Y/%m/%d}]
			}
		}
	}
	if {$params(test)} {
		set rerunFile "/tool/sg_tool_sde/cadauto/bin/test/rerun_event.tcl"
	} else {
		set rerunFile "/tool/sg_tool_sde/cadauto/bin/prod/rerun_event.tcl"
	}
	set cmd " $rerunFile $op $formid $uuid $date"
	#puts "command is $cmd \n"
	if {[catch {exec csh -c $cmd} stderr] } {
		puts "Error is <$stderr> \n"
		puts "Please remember to use wtadmin account for rerun!"
	}
	#puts "op is $op, formid is $formid , uuid is $uuid date is $date \n"
   	return -code ok 0
}


proc app-main::event_update {args} {
	set options {
		{tid.arg     "" "Database stored ID, Optional" }
		{uuid.arg    "" "Assigned uuid if needed, Optional" }
		{name.arg    "" "Assigned name, {FORM/Formid/}, Optional" }
		{group.arg   "" "Assigned job group, Optional" }
		{status.arg  "" "Update new status, default=current status" }
		{dis         "Set job as disable, active=0" }
		{test        "Set environment==test, default=prod" }
	}

	set usage "\\> event_update \[options\]"
	set cmdusage [::cmdline::usage $options $usage]
    if {[catch {array set params [::cmdline::getoptions args $options $usage]} error]} {
        puts "[info script] $cmdusage"
        puts "e.g. [file tail [info script]] -uuid [exec uuidgen] -status manualComplete -dis"
        return 1
    }
    array set opts {}
    set sklist {tid uuid dis test} 
    foreach key [array names params] {
    	if {[lsearch $sklist $key] >=0} {continue}
    	if {[string length $params($key)]>0} {lappend opts(job_$key) $params($key)}
    }
    if {$params(dis)} {set opts(job_active) 0}
    if {[string tolower $params(status)] eq "done" || [string tolower $params(status)] eq "completed"} {
    	set opts(job_active) 0
	}
    if {[string length $params(uuid)]>0} {set opts(uuid) $params(uuid)}
    if {[string length $params(tid)]>0} {set opts(tid) $params(tid)}
    if {$params(test)} {setenv test} else {setenv prod}
    if {[catch {%RUNOBJ task_update [array get opts]} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else {
    	puts InsertID=$retMsg
    	return -code ok 0
	}
}

# Delete LR record.
proc app-main::event_delete {args} {
	set options {
		{tid.arg     "" "Database stored ID, Optional" }
		{uuid.arg    "" "Assigned uuid if needed, Optional" }
		{test        "Set environment==test, default=prod" }
	}

	set usage "\\> event_update \[options\]"
	set cmdusage [::cmdline::usage $options $usage]
    if {[catch {array set params [::cmdline::getoptions args $options $usage]} error]} {
        puts "[info script] $cmdusage"
        puts "e.g. [file tail [info script]] delete -test -uuid [exec uuidgen]"
        return 1
    }
    array set opts {}
    if {[string length $params(uuid)]>0} {set opts(uuid) $params(uuid)}
    if {[string length $params(tid)]>0} {set opts(tid) $params(tid)}
    if {$params(test)} {setenv test} else {setenv prod}
    if {[catch {%RUNOBJ task_delete [array get opts]} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else {
    	puts LinesDeleted=$retMsg
    	return -code ok 0
	}

}

proc app-main::to40_event {mode do json args} {
	puts "DEBUG event action  for to40_event..."
	puts "DEBUG args: $mode $do $json $args"
	setenv $mode
	if {![file exists $json]} {
		puts "Error: Specified json '$json' file not found."
		exit 1
	}
    set opts [list json [file normalize $json] do event_$do]
    puts "cmd: to40_event $opts"
    if {[catch {%RUNOBJ tma_microsvcs_main $opts} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else {
    	puts $retMsg
    	return -code ok 0
	}
	

}

# Get ActiveList.
proc app-main::get_active_list {args} {
	set options {
		{tid.arg     "" "Assigned tid if needed, Optional" }
		{uuid.arg    "" "Assigned uuid if needed, Optional" }
		{name.arg    "" "Assigned name, {FORM/Formid/}, Optional " }
		{group.arg   "" "Assigned job group, Optional" }
		{status.arg  "" "Set initial status, default=started" }
		{max_age.arg "" "Max time to check. e.g. 1h, 30m, 1d . \n\tSearch only by seconds,minutes,hours or days." }
		{min_age.arg "" "Minimum time to check. e.g. 1h, 30m, 1d . \n\tSearch only by seconds,minutes,hours or days." }
		{raw          "OUPUT OPTION: Return mysql raw output."}
		{arr          "OUPUT OPTION: Return array dump"}
		{test        "Set environment==test, default=prod" }
	}
	set usage "\\> event_create \[options\]"
	set cmdusage [::cmdline::usage $options $usage]
    if {[catch {array set params [::cmdline::getoptions args $options $usage]} error]} {
        puts "[info script] $cmdusage"
        puts "e.g. [file tail [info script]] -uuid [exec uuidgen] -name FORM001-TSF001 -group Submitted -status started"
        return 1
    }
    array set opts {}
    set sklist {tid uuid dis test min_age} 
    foreach key [array names params] {
    	if {[lsearch $sklist $key] >=0} {continue}
    	if {[string length $params($key)]>0} {lappend opts(job_$key) $params($key)}
    }
    if {[string length $params(uuid)]>0} {set opts(uuid) $params(uuid)}
    if {[string length $params(tid)]>0} {set opts(tid) $params(tid)}
    if {[string length $params(min_age)]>0} {set opts(min_age) $params(min_age)}
    if {[string length $params(max_age)]>0} {set opts(max_age) $params(max_age)}
    set opts(raw) $params(raw)
    set opts(arr) $params(arr)
    if {$params(test)} {setenv test} else {setenv prod}
    if {[catch {%RUNOBJ task_get_active_list [array get opts]} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else {
		set dxclk [clock format [clock seconds] -format {%Y%m%d.%H%M%S}]
		set ftmp /tmp/LR_results.${::env(USER)}.$dxclk.[exec uuidgen].htm
		set FOUT [open $ftmp w]
		puts $FOUT $retMsg
		close $FOUT
		if {[file exists $ftmp]} {
			if {[catch {exec /usr/bin/elinks -dump 1 -dump-color-mode 0 $ftmp} formattedMsg]} {
				puts $retMsg
			} else {
				puts $formattedMsg
		    }
		} else {
			puts $retMsg
	    }
	    catch {file delete $ftmp} errmsg
    	return -code ok 0
	}

}

# Sendout Alerts
proc app-main::report_long_running_and_errors {args} {
	set options {
		{group.arg    "" "Assigned job group, Optional" }
		{status.arg   "" "Set initial status, default=started" }
		{exclude.arg  "" "Exclude listed status types: e.g \"'On Hold','In progress','Cancelled'\"" }
		{max_age.arg  "" "Max time to check. e.g. 1h, 30m, 1d . \n\tSearch only by seconds,minutes,hours or days." }
		{min_age.arg  "" "Minimum time to check. e.g. 1h, 30m, 1d . \n\tSearch only by seconds,minutes,hours or days." }
		{html         "OUTPUT OPTION: Dump html tbl"}
		{raw          "OUPUT OPTION: Return mysql raw output."}
		{arr          "OUPUT OPTION: Return array dump"}
		{test         "Set environment==test, default=prod" }
	}
	set usage "\\> event_create \[options\]"
	set cmdusage [::cmdline::usage $options $usage]
    if {[catch {array set params [::cmdline::getoptions args $options $usage]} error]} {
        puts "[info script] $cmdusage"
        puts "e.g. [file tail [info script]] -uuid [exec uuidgen] -name FORM001-TSF001 -group Submitted -status started"
        return 1
    }
    array set opts {}
    set sklist {tid uuid dis test min_age} 
    foreach key [array names params] {
    	if {[lsearch $sklist $key] >=0} {continue}
    	if {[string length $params($key)]>0} {lappend opts(job_$key) $params($key)}
    }
    if {[string length $params(min_age)]>0} {set opts(min_age) $params(min_age)}
    if {[string length $params(max_age)]>0} {set opts(max_age) $params(max_age)}
    if {[string length $params(exclude)]>0} {set opts(exclude) $params(exclude)}
    set opts(raw) $params(raw)
    set opts(arr) $params(arr)
    set opts(group_by_job_name) 1
    set opts(use_template_file) /tool/sg_tool_sde/cadauto/config/email_templates/
    if {$params(test)} {setenv test} else {setenv prod}
    if {[catch {%RUNOBJ task_get_active_list [array get opts]} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else {
		if {$params(raw)} {
			puts $retMsg
			return -code ok 0
		}

		if {$params(html)} {
			puts $retMsg
			return -code ok 0
		}
		set dxclk [clock format [clock seconds] -format {%Y%m%d.%H%M%S}]
		set ftmp /tmp/LR_results.${::env(USER)}.$dxclk.[exec uuidgen].htm
		set FOUT [open $ftmp w]
		puts $FOUT $retMsg
		close $FOUT
		if {[file exists $ftmp]} {
			if {[catch {exec /usr/bin/elinks -dump 1 -dump-color-mode 0 $ftmp} formattedMsg]} {
				puts $retMsg
			} else {
				puts $formattedMsg
		    }
		} else {
			puts $retMsg
	    }
	    catch {file delete $ftmp} errmsg
    	return -code ok 0
	}
}

proc app-main::tows_log_callback {args} {
	puts tows_log_callback
	set options {
		{uuid.arg     "" "uuid" }
		{status.arg   "" "Status (0=Success,1=Ignorable error,2=Error response,3=Invalid response)" }
		{cof.arg      "" "Callback tracking reference" }
		{cin.arg      "" "Callback input file" }
		{test         "Set environment==test, default=prod" }
	}
	set usage "\\> event_create \[options\]"
	set cmdusage [::cmdline::usage $options $usage]
    if {[catch {array set params [::cmdline::getoptions args $options $usage]} error]} {
        puts "[info script] $cmdusage"
        puts "e.g. [file tail [info script]] -uuid [exec uuidgen] -status 0 -cof [clock format [clock seconds] -format {%Y/%m/%d-%dd}].SUCCESS.txt -cin <path_2_xml>"
        return 1
    }

    array set opts {}
    if {[string length $params(uuid)]   == 0 } { puts "Parameter uuid is required." ; return 1}
    if {[string length $params(status)] == 0 } { puts "Parameter status is required." ; return 1}
    if {[string length $params(cin)]    == 0 } { puts "Parameter cin is required." ; return 1}
    if {[string length $params(cof)]    == 0 } { puts "Parameter cof is required." ; return 1}
    if {$params(test)} {setenv test} else {setenv prod}
    if {[catch {%RUNOBJ task_track_towscb [array get params]} retMsg]} {
    	puts "Error:$retMsg"
    	exit 1
	} else {
    	return -code ok 0
	}
}


proc app-main::main {} {
	global argv
	variable main

	switch -nocase -exact -- [lindex $argv 0] {
		"" - -h - -help - --help - -usage -
		--usage {
			[namespace current]::help
	    }
	    default {
	    	if {[string length [lsearch -nocase -inline $main(applist) [lindex $argv 0]]]>0} {
	    		if {[catch {::app-main {*}$argv} result]} {
	    			return -code error $result
	    		}
	    		return
			} else {
	    		[namespace current]::help
	    		return
	    	}

	    }
    }

    #----------------------------------------------------------
}

app-main::main
