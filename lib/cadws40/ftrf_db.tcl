# ---------------------------------------------------------------------------------------
# Description:
#  tma_microsvcs connector api.
#  Provides task insertion, retrieval and monitoring 
# *** Stripped down version for demo ***
# ---------------------------------------------------------------------------------------
# Developer : Cris Magalang
# Date :
# ---------------------------------------------------------------------------------------


source mysqltcl.setup
# set up required libraries
package provide tma_microsvcs 1.0

package require tdom
package require Itcl
package require MySqlDb
package require WS::Client
package require base64
package require sqlite3
package require comm
package require wsmgr_helper
package require cadws_config_vars
package require json
package require cadws

itcl::class tma_microsvcs {
    variable environment
    variable mydb
    variable CVAR
    variable MSVC

    constructor {_name {_opts {}}} {
        set name $_name
        set environment $_name
        ws_configure $_name $_opts
    }

    # ----------------------------------------------------
    # ws_configure
    # Description: Prepare Variables and DB connections
    # ----------------------------------------------------
    private method ws_configure { env options} {
    	# CONTENTS REMOVED.
    	# CONTENTS REMOVED.
    	# CONTENTS REMOVED.
    	# CONTENTS REMOVED.
    	# CONTENTS REMOVED.
    	# CONTENTS REMOVED.
    }

    # ----------------------------------------------------
    # ::wsmdb::tma_microsvcs_main
    # Description:
    # ----------------------------------------------------
    method tma_microsvcs_main {options args} {
        variable environment
        variable mydb
        array set params $options
        # SET REQUEST OPERATION:
        # -do
        #   event_add    --- Insert event message 
        switch -- $params(do) {
           "event_add" {
                  tma_event_message_add $options
           }
           default {
                  puts "DEFAULT EVENT."
           }
        }
    }

    method tma_event_message_add {options args} {
        variable environment
        variable mydb
        array set opts $options
        array set data {}
        if {[info exists opts(json)] && [file exists $opts(json)]} {
            array set data  [get_json2dict $opts(json)]
        } else {
            error "json file required. Error finding <$opts(json)>"
        }
        set FIELD ""
        set VALUE ""
        foreach field {
            accountShortName
            bumpRequest
            consolidatedLayerStatus
            ddrRequest
            drcRequest
            eventTimeStamp
            eventTriggeredBy
            eventType
            executionServiceAction
            formId
            formStatus
            formType
            maskSetTitle
            primeRequest
            productName
            productRevision
            prototypeFormId
            stepPlanRequest
            transactionId
        } {
            if {[info exists data($field)]} {
                lappend FIELD "$field"
                set value [safe_sql_value $data($field)]
                lappend VALUE "'$value'"
            }
        }
        set tbl TBL_FTRF_EVENT_QUEUE
        set FIELD [join $FIELD ,]
        set VALUE [join $VALUE ,]
        set sqli "INSERT INTO $tbl ($FIELD) VALUES ($VALUE)"
        append sqli "; SELECT LAST_INSERT_ID()"
        puts $sqli

        if {[ catch { $mydb Insert $sqli } error ] } {
            wsmgr_helper::post_fatal_error "tma_event_message_add $error";
        } else {
            puts "$error"
        }
    } 

	method task_track_towscb {options args} {
        variable environment
        variable mydb
        array set opts $options
        array set data {}
        set FIELD ""
        set VALUE ""
        foreach field {
        	uuid status cin cof
        } {
            if {[info exists opts($field)]} {
                lappend FIELD "$field"
                set value [safe_sql_value $opts($field)]
                lappend VALUE "'$value'"
            }
        }
        set tbl TBL_TOWSCB_TRACK
        set FIELD [join $FIELD ,]
        set VALUE [join $VALUE ,]
        set sqli "INSERT INTO $tbl ($FIELD) VALUES ($VALUE)"
        append sqli "; SELECT LAST_INSERT_ID()"

        if {[ catch { $mydb Insert $sqli } error ] } {
            wsmgr_helper::post_fatal_error "tma_event_message_add $error";
        } else {
            puts "$error"
        }
    } 


    method get_json2dict {json_file {validate 0}} {
        set FIN [open $json_file r]
        set jsondata [read $FIN]
        close $FIN
        set json $jsondata
        if {[catch {::json::json2dict $json} ddata error_detail]} {
            puts Error:$error_detail
            error "$ddata"
        }
        if {!$validate == 1} {
            return $ddata
        } else {
            if {![dict exists $ddata accountShortName]} { lappend err_msg "Missing event parameter 'accountShortName'"}
            if {![dict exists $ddata eventTimeStamp]} { lappend err_msg "Missing event parameter 'eventTimeStamp'"}
            if {![dict exists $ddata eventType]} { lappend err_msg "Missing event parameter 'eventType'"}
            if {![dict exists $ddata formId]} { lappend err_msg "Missing event parameter 'formId'"}
            if {![dict exists $ddata formStatus]} { lappend err_msg "Missing event parameter 'formStatus'"}
            if {![dict exists $ddata formType]} { lappend err_msg "Missing event parameter 'formType'"}
            if {![dict exists $ddata maskSetTitle]} { lappend err_msg "Missing event parameter 'maskSetTitle'"}
            if {![dict exists $ddata prototypeFormId]} { lappend err_msg "Missing event parameter 'prototypeFormId'"}
            #if {![dict exists $ddata bumpRequest]} { lappend err_msg "Missing event parameter 'bumpRequest'"}
            #if {![dict exists $ddata ddrRequest]} { lappend err_msg "Missing event parameter 'ddrRequest'"}
            #if {![dict exists $ddata drcRequest]} { lappend err_msg "Missing event parameter 'drcRequest'"}
            #if {![dict exists $ddata eventTriggeredBy]} { lappend err_msg "Missing event parameter 'eventTriggeredBy'"}
            #if {![dict exists $ddata executionServiceAction]} { lappend err_msg "Missing event parameter 'executionServiceAction'"}
            #if {![dict exists $ddata primeRequest]} { lappend err_msg "Missing event parameter 'primeRequest'"}
            #if {![dict exists $ddata productName]} { lappend err_msg "Missing event parameter 'productName'"}
            #if {![dict exists $ddata productRevision]} { lappend err_msg "Missing event parameter 'productRevision'"}
            #if {![dict exists $ddata remark]} { lappend err_msg "Missing event parameter 'remark'"}
            #if {![dict exists $ddata stepPlanRequest]} { lappend err_msg "Missing event parameter 'stepPlanRequest'"}
            #if {![dict exists $ddata transactionId]} { lappend err_msg "Missing event parameter 'transactionId'"}
            foreach err $err_msg {
                puts "\tEvent content ERROR: $err"
            }

            if {[llength $err_msg]>1} {
                exit 1
            } else {
                return $ddata
            }
        }
    }


    method get_common_formStatus {} {

        array set known_status_list {
            "Cancelled"                      1
            "Completed"                      1
            "Copy DB"                        1
            "Deleted"                        1
            "Draft"                          0
            "Error Rectification"            0
            "Extract & Build Execution"      1
            "In Progress"                    0
            "Mask Layer Check"               0
            "Request vs DB Check"            0
            "Step Plan/Frame Approved"       0
            "Step Plan/Frame Review"         0
            "Submitted"                      1
        }
        
    }

    # ----------------------------------------------------
    # Description: Display usage message
    # ----------------------------------------------------
    method get_usage { options } {
        puts "Usage:"
        # Contents removed.
        # Contents removed.
        # Contents removed.
        # Contents removed.
        # Contents removed.
        # Contents removed.
        # << Usage >>
    }
    # ----------------------------------------------------
    # Description: Wait to emulate sleep
    # ----------------------------------------------------
    method sleep {N} {
        after [expr {int(${N} * 1000)}]
    }

    # ----------------------------------------------------------------
    # getRunTime
    # ----------------------------------------------------------------
    method getRunTime { start end } {
        return [expr \
            { [clock scan $end -format {%Y-%m-%dT%T}] - \
              [clock scan $start -format {%Y-%m-%dT%T}] } ]
    }

    method getdate {} {
        return [clock format [clock seconds] -format {%Y-%m-%dT%T} ]
    }

    method safe_sql_value { value } {
        return [mysql::escape $value]
    }

    method mrs_sql { op sql} {
        variable mydb
        return [$mydb $op $sql]
    }

    method getsite {} {
        set cm1 "/tool/pandora/bin/sitename"
        set cm2 "/csm/bin/whereami"
        set sitename "NOT_FOUND"
        if {[file exists $cm1]} {
            if {[catch {exec $cm1} sitename]} {
                if {[file exists $cm2]} {
                    if {[catch {exec $cm2} sitename]} {
                        set sitename "NOT_FOUND"
                    }
                }
            }
            return $sitename
        } else {
            return
        }
    }

    # Save new task to database.
    method task_insert {options} {
        variable environment
        variable mydb
        array set opts $options
        if {[info exists opts(uuid)]} {set uuid $opts(uuid)} else {set uuid ""}
        if {[info exists opts(job_name)]} {set job_name $opts(job_name)} else {set job_name ""}
        if {[info exists opts(job_group)]} {set job_group $opts(job_group)} else {set job_group ""}
        if {[info exists opts(job_active)]} {set job_active $opts(job_active)} else {set job_active 1}
        if {[info exists opts(job_status)]} {set job_status $opts(job_status)} else {set job_status "started"}
        if {[info exists opts(job_updated)]} {set job_updated $opts(job_updated)} else {
            set job_updated [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]}

        set tbl TBL_SERVICEMON
        set field [list uuid job_name job_group job_active job_status job_updated source_user source_host]
        set value [list "'$uuid'" "'$job_name'" "'$job_group'" "'$job_active'" "'$job_status'" "'$job_updated'" \
                    "'$::env(USER)'" "'[exec hostname -s]'"]
        set FIELD [join $field ,]
        set VALUE [join $value ,]
        set sqli "INSERT INTO $tbl ($FIELD) VALUES ($VALUE)"
        append sqli "; SELECT LAST_INSERT_ID()"
        puts "Inserting: $value"
        if {[ catch { $mydb Insert $sqli } insert_id ] } {
            wsmgr_helper::post_fatal_error "tma_event_message_add $insert_id";
        } else {
            return $insert_id
        }
    }

    # update stored task
    method task_update {options} {
        variable environment
        variable mydb
        array set opts $options
        set filter ""
        set setlist ""
        parray opts
        if {[info exists opts(tid)]} {lappend filter "tid IN ($opts(tid))"}
        if {[info exists opts(uuid)]} {lappend filter uuid='$opts(uuid)'}
        if {[info exists opts(job_name)]} {lappend setlist job_name='$opts(job_name)'}
        if {[info exists opts(job_active)]} {lappend setlist job_active=$opts(job_active)}
        if {[info exists opts(job_status)]} {lappend setlist job_status='$opts(job_status)'}
        set job_updated [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
        lappend setlist job_updated='$job_updated'

        set tbl TBL_SERVICEMON
        set field [list uuid job_name job_group job_active job_status job_updated source_user source_host]
        set jfilter [join $filter " AND "] 
        set sqlu "UPDATE $tbl SET [join  $setlist ,] WHERE $jfilter"
        puts $sqlu

        if {[ catch { $mydb Insert $sqlu } update_id ] } {
            wsmgr_helper::post_fatal_error "tma_event_message_update $update_id";
        } else {
            return $update_id
        }
    }

    # delete stored task
    method task_delete {options} {
        variable environment
        variable mydb
        array set opts $options
        set filter ""
        set setlist ""
        if {[info exists opts(tid)]} {
            lappend filter "tid IN ($opts(tid))"
        }
        if {[info exists opts(uuid)]} {lappend filter uuid='$opts(uuid)'}
        if {[string length $filter]==0} {
            puts "Error: Task delete requires record 'tid' or 'uuid' reference."
            exit 1
        }
        set job_updated [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
        lappend setlist job_updated='$job_updated'

        set tbl TBL_SERVICEMON
        set field [list uuid job_name job_group job_active job_status job_updated source_user source_host]
        set jfilter [join $filter " AND "] 
        set sqlu "UPDATE $tbl SET [join  $setlist ,],job_status='deleted',job_active=0 WHERE $jfilter"
        puts $sqlu

        if {[ catch { $mydb Update $sqlu } update_id ] } {
            wsmgr_helper::post_fatal_error "tma_event_message_delete $update_id";
        } else {
            return $update_id
        }
    }

    # mark task as closed.
    method task_close {options} {
        variable environment
        variable mydb
        array set opts $options
        set filter ""
        set setlist ""
        if {[info exists opts(tid)]} {lappend filter "tid IN ($opts(tid))"}
        if {[info exists opts(uuid)]} {lappend filter uuid='$opts(uuid)'}
        if {[string length $filter]==0} {
            puts "Error: Task close requires record 'tid' or 'uuid' reference."
            exit 1
        }
        set job_updated [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
        lappend setlist job_updated='$job_updated'

        set tbl TBL_SERVICEMON
        set field [list uuid job_name job_group job_active job_status job_updated source_user source_host]
        set jfilter [join $filter " AND "] 
        set sqlu "UPDATE $tbl SET [join  $setlist ,],job_status='closed',job_active=0 WHERE $jfilter"
        if {[ catch { $mydb Update $sqlu } update_id ] } {
            wsmgr_helper::post_fatal_error "task_close $update_id";
        } else {
            return $update_id
        }
    }

    # get task_status
    method task_get_status {options} {
        variable environment
        variable mydb
        array set opts $options
        
        set filter {}
        if {[info exists opts(tid)]} {lappend filter "tid IN ($opts(tid))"}
        if {[info exists opts(uuid)]} {lappend filter uuid='$opts(uuid)'}
        if {[info exists opts(job_name)]} {
            if {[regexp {%} $opts(job_name)]} {
                lappend filter "job_name LIKE '$opts(job_name)'"
            } else {
                lappend filter "job_name='$opts(job_name)'"
            }
        }
        if {[info exists opts(job_group)]} {lappend filter "job_group LIKE '$opts(job_group)'"}
        if {[info exists opts(job_status)]} {lappend filter job_status='$opts(job_status)'}
        if {[info exists opts(sel)]} {lappend filter $opts(sel)}
        if {[info exists opts(limit)]} {set limit $opts(limit)} else {set limit 500}
        set tbl TBL_SERVICEMON
        set field [list \
            tid \
            job_group \
            job_create_date \
            job_updated \
            TIMEDIFF(NOW(),job_create_date) \
            TIMEDIFF(job_updated,job_create_date) \
            TIMEDIFF(NOW(),job_updated) \
            job_name \
            uuid \
            job_status \
            job_active]

        if {[string length $filter] == 0 } {
			set wheref ""
		} else {
        	set filter [join $filter " AND "]
        	set wheref "WHERE $filter"
	    }
	    set sql1 "SELECT [join $field ,] FROM $tbl $wheref ORDER BY tid DESC LIMIT $limit"
		set sqls "SELECT * FROM ($sql1)sub ORDER BY tid ASC"

        if {[ catch { $mydb Select $sqls } results ] } {wsmgr_helper::post_fatal_error "$sqls \n$results"}
        array set result {}
        set ctr 0
        array set all_results {}
        foreach line $results {
            lassign $line result(TID) result(GROUP) result(dateCreated) result(dateUpdated) \
                result(diffNowCreate) result(diffCreateUpdate) result(diffNowUpdate) \
                result(jobName) result(UUID) result(STATUS) result(ACTIVE)
            incr ctr
            set all_results($ctr) [array get result]
        }
        return -code ok [array get all_results]
    }


    # get task_active_list
    method task_get_active_list {options} {
        variable environment
        variable mydb
        array set opts $options
        
        set filter {}
        if {[info exists opts(tid)]} {lappend filter "tid IN ($opts(tid))"}
        if {[info exists opts(uuid)]} {lappend filter uuid='$opts(uuid)'}
        if {[info exists opts(job_name)]} {
            if {[regexp {%} $opts(job_name)]} {
                lappend filter "job_name LIKE '$opts(job_name)'"
            } else {
                lappend filter "job_name='$opts(job_name)'"
            }
        }
        if {[info exists opts(job_group)]} {lappend filter "job_group LIKE '$opts(job_group)'"}
        if {[info exists opts(job_status)]} {lappend filter job_status='$opts(job_status)'}
        if {[info exists opts(min_age)]} {
            if {[regexp -nocase {^([0-9]+)$} $opts(min_age) -> ctime]} {
                set tformat MINUTE
                puts selected=$ctime\t$tformat
            } elseif {[regexp -nocase {^([0-9]+)([A-Za-z]*)$} $opts(min_age) -> ctime tform]} {
                puts tform=$tform
                switch -nocase -regexp -- [string tolower $tform] {
                    ^M - ^m - ^min* {
                        set tformat MINUTE
                    }
                    ^s - ^sec* {
                        set tformat SECOND
                    }
                    ^h - ^hour* - ^hr* {
                        set tformat HOUR
                    }
                    ^d - ^day* {
                        set tformat DAY
                    }
                    default {
                        puts "Error: Unexpected time option, Search only by seconds,minutes,hours or days."
                        exit 1
                    }
                }
            }
        } else {
            set ctime 1
            set tformat HOUR
        }
        if {[info exists opts(max_age)]} {
            if {[regexp -nocase {^([0-9]+)$} $opts(max_age) -> ctime_max]} {
                set tformat_max MINUTE
                puts selected=$ctime_max\t$tformat_max
            } elseif {[regexp -nocase {^([0-9]+)([A-Za-z]*)$} $opts(max_age) -> ctime_max tform_max]} {
                puts tform_max=$tform_max
                switch -nocase -regexp -- [string tolower $tform_max] {
                    ^M - ^m - ^min* {
                        set tformat_max MINUTE
                    }
                    ^s - ^sec* {
                        set tformat_max SECOND
                    }
                    ^h - ^hour* - ^hr* {
                        set tformat_max HOUR
                    }
                    ^d - ^day* {
                        set tformat_max DAY
                    }
                    default {
                        puts "Error: Unexpected time option, Search only by seconds,minutes,hours or days."
                        exit 1
                    }
                }
            }
        } else {
        	# Number of days we keep into record. (was 30 days but we want forever<virtually>)
        	# 10years you havent recieved.
            set ctime_max 3650
            set tformat_max day
        }
        lappend filter "job_create_date < (NOW()- INTERVAL $ctime $tformat)"
        lappend filter "job_create_date > (NOW()- INTERVAL $ctime_max $tformat_max)"
        lappend filter job_active=1
        set tbl TBL_SERVICEMON
        set field [list \
            tid \
            job_group \
            job_create_date \
            job_updated \
            TIMEDIFF(NOW(),job_create_date) \
            TIMEDIFF(job_updated,job_create_date) \
            TIMEDIFF(NOW(),job_updated) \
            job_name \
            uuid \
            job_status]
        set jfilter [join $filter " AND "] 
        set sqls "SELECT [join $field ,] FROM $tbl  WHERE $jfilter ORDER BY job_create_date"
        if {[ catch { $mydb Select $sqls } results ] } {wsmgr_helper::post_fatal_error "$sqls \n$results"}
        if {$opts(raw)} {
        	return $results
        }
        if {$opts(arr)} {
        	array set RES {}
            foreach line $results {
                lassign $line tid grp dateCreated dateUpdated diffNowCreate diffCreateUpdate diffNowUpdate jobName uuid status
        	    #set RES($tid) [list $grp $dateCreated $dateUpdated $diffNowCreate $diffCreateUpdate $diffNowUpdate $jobName $uuid $status]
        	    set RES($tid) [list $grp $dateCreated $dateUpdated $jobName $uuid $status]
			}
			parray RES
			exit 0
		}
		set trtd ""
        foreach line $results {
            lassign $line tid grp dateCreated dateUpdated diffNowCreate diffCreateUpdate diffNowUpdate jobName uuid status
			append trtd "\n<tr>\n\t<td>$tid</td><td>$grp</td><td>$jobName</td><td>$dateUpdated</td>"
			append trtd "<td>$uuid</td><td>$status</td>\n</tr>"
        }
        if {[string length $trtd]>0} {
        append mailmsg {<table style="width:100%;border-color:#9cbdcc;" border="1">}
        append mailmsg "<tr>"
        append mailmsg "\n\t<th>#</th>"
        append mailmsg "\n\t<th>App Grp</th>"
        append mailmsg "\n\t<th>Name</th>"
        append mailmsg "\n\t<th>Last Update</th>"
        append mailmsg "\n\t<th>Run ID</th>"
        append mailmsg "\n\t<th>Status</th>"
        append mailmsg "</tr>"
        append mailmsg $trtd
        append mailmsg "\n</table>"
        return $mailmsg
		} else {
			return -code ok
	    }
    }

#END OF CLASS tma_microsvcs
}

# -------------------------------------
# TEST DEBUG LINES :
# -------------------------------------
#
#tma_microsvcs %TEST test
#
#array set mytask [list \
#    uuid [string trim [exec /usr/bin/uuidgen]]\
#    job_name "FTRF[string range [clock clicks] end-7 end]-TSF[string range [clock clicks] end-2 end]" \
#    job_group DesignDb \
#    job_active 0 \
#    job_status "submitted" \
#]

# TEST LINES
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
## Contents Removed....
