# ---------------------------------------------------------------------------------------
# Description:
#  cadws 
# *** Stripped down version demo.
# ---------------------------------------------------------------------------------------
# Developer : Cris Magalang
# Date : 2014-03-02
# ---------------------------------------------------------------------------------------
# Revision History:
# 2014-04-DD   Cris Magalang   Alpha   Development Releases -- Untracked versions
# 2014-05-10   Cris Magalang   1.0     First dev release
# ---------------------------------------------------------------------------------------
#

source mysqltcl.setup
# set up required libraries
package provide cadws 1.0

package require tdom
package require Itcl
package require MySqlDb
package require WS::Client
package require base64
package require sqlite3
package require comm
package require wsmgr_helper
package require cadws_config_vars
package require tbcload 1.6

itcl::class cadws {
    variable mydb
    public variable environment ""
    public variable BASE_DIR ""
    public variable WORK_DIR ""
    public variable ARCHIVES ""
    public variable messageID_suffix ""
    public variable msg_mode 0 ; # Run mode is CAD=0/SIT=1/UAT=2/NODB=3
    variable ws_holiday_msgs ""
    variable error_msg 0
    variable test_mode 0
    variable verbose 0
    variable config_load_once 0
    variable ws_call_response [list]
    variable ws_get_parse ""
    variable hosts ""
    variable messageID ""
    variable wait_var 0
    constructor {_name {_opts {}}} {
        set name $_name
        set environment $_name
        set messageID ""
        set jobid ""
        set option_set $_opts
        ws_configure $_name $_opts
    }

    destructor {
    	# Deleted content
    	#
    }

    # ----------------------------------------------------
    # ws_configure
    # Description: Prepare Variables and DB connections
    # ----------------------------------------------------
    private method ws_configure { environment options} {
        variable config_load_once
        variable hosts
        variable test_mode
        variable msg_mode
        variable BASE_DIR
        variable WORK_DIR
        variable ARCHIVES

        array set CVARS [::cadws_config_vars::getvars $environment]
        if [catch { array set opts $options } msg] {
        	puts "Error: Configuration Options: $msg"
        }

        # Contents deleted for demo version....
        #
        #
        #
        #
        #
        #
        #
        #
        #
        #
        #
        #
        #

        set error 0
        if { [info exists opts(msg_mode)] && [string length $msg_mode]>0} {
        	set msg_mode $opts(msg_mode)
        } else {
            set msg_mode 0
            set opts(msg_mode) 0
		}
        if { [info exists opts(test_mode)] } {
            set test_mode $opts(test_mode)
        }
        if { $config_load_once != 1 } {
            set mydb ""
            set BASE_DIR [file normalize $CVARS(dir,base)]
            set WORK_DIR [file normalize $CVARS(dir,work)]
            set ARCHIVES [file normalize $CVARS(dir,base)/archive]
            if { [info exists opts(baseDirectory)] } {
                if { [string length $opts(baseDirectory)] > 0 } {
                    set BASE_DIR $opts(BASE_DIR)
                }
            }
            if { [info exists opts(WORK_DIR)] } {
                if { [string length $opts(WORK_DIR)] > 0 } {
                    set WORK_DIR $opts(WORK_DIR)
                }
            }
            if { [info exists opts(ARCHIVES)] } {
                if { [string length $opts(ARCHIVES)] > 0 } {
                    set ARCHIVES $opts(ARCHIVES)
                }
            }
            catch { file mkdir ${WORK_DIR} }
            catch { file mkdir ${ARCHIVES} }

            set dbargs [list]
            lappend dbargs user $CVARS(db,mysql,user)
            lappend dbargs pass $CVARS(db,mysql,pass)
            lappend dbargs host $CVARS(db,mysql,server)
            lappend dbargs port $CVARS(db,mysql,port)
            lappend dbargs db   $CVARS(db,mysql,db)
            catch { set mydb [ MySqlDb $environment MySqlDb $dbargs ] } error
            set hosts ""
            set config_load_once 1
        } else {
            puts "[getdate] Warning: ws_configure can be only run once. - ignored"
        }
        if { [string length $error ] > 0 } { return $error } else { return 0 }
    }

    # ----------------------------------------------------
    # ::wsmdb::cadws_main
    # Description:
    # ----------------------------------------------------
    method cadws_main {options args} {
        variable environment
        variable mydb
        variable error_msg
        variable msg_mode
        set goal ""
        set require_params 0
        array set params $options
        set paramlist [list \
           do data dontWaitFeedback jobid logName \
           logSetup messageID ptrfNumber serviceName \
           svcOperation wsdlURL headers nameID]
        set params(msg_mode)   $msg_mode
        foreach var $paramlist {
            if { [info exists params($var)] } {
            } else {
                set params($var) ""
            }
        }
        # SET REQUEST OPERATION:
        # Define Operation as one of the following
        #   submit         --- Submit as new service request
        #   submit_stored  --- Submit store_only jobs
        #   update         --- Resubmit on same ID with updated details
        #   set_done       --- Mark request as Done
        #   cancel  --- Mark request as Cancelled
        #   retry          --- Retry submit to web service with same jobid
        #   store_only     --- Save data only and run later
        #   dictsave_async --- DataStore Async -  Inserted data will be picked-up by cron watcher
        #   dictsave_sync  --- DataStore Sync  -  Inserted data will be picked-up by cron watcher
        #   get_response   --- get Stored Web Service Response.
        #   get_status     --- Check/Report status of web service request.
        #   remove         --- Remove job from record"
        if { ! [string length $params(do)] > 0 } {
            wsmgr_helper::post_fatal_error "Required option \"do <operation>\" is required. Aborting."
        } else {
            set goal $params(do)
            switch -- $params(do) {
                "submit_ws_sync" {
                    #set params(dontWaitFeedback) 0
                    set params(webservice_mode) synchronous
                    set goal "submit_ws_sync"
                    set require_params 1
                }
                "submit" {
                    set params(webservice_mode) async
                    set goal "submit"
                    set require_params 1
                    set params(dontWaitFeedback) 0
                }
                "submit_stored" {
                    set goal "submit_stored"
                    set params(webservice_mode) async
                }
                "update" {
                    set goal "update"
                }
                "retry" {
                    set goal "retry"
                    set params(webservice_mode) async
                    set params(dontWaitFeedback) 0
                }
                "retry2" {
                    set goal "retry"
                    set params(do) "retry"
                    set params(webservice_mode) async
                    set params(dontWaitFeedback) 1
                }
                "retry_sync_grp" {
                    #set params(dontWaitFeedback) 0
                    set params(webservice_mode) synchronous
                    set goal "retry_sync_grp"
                }
                "store_only" {
                    set params(webservice_mode) async
                    set goal "store_only"
                    set require_params 1
                }
                "dictsave_async" {
                    set goal "dictsave_async"
                    set require_params 1
                }
                "dictsave_sync" {
                    set goal "dictsave_sync"
                    set require_params 1
                }
                "get_response" {
                    set goal "get_response"
                }
                "get_status" {
                    set goal "get_status"
                }
                "set_done" {
                    set goal "set_done"
                }
                "cancel" {
                    set goal "cancel"
                }
                default {
                    wsmgr_helper::post_fatal_error "Option must be one of : submit_ws_sync | submit | set_done | cancel | retry_sync_grp |retry | get_status | remove | store_only"
                }
            }
        }
        if { $require_params } {
            # WSDL Service Name
            if { ! [string length $params(serviceName)] > 0 } {
                wsmgr_helper::post_fatal_error "WSDL Service Name (serviceName <WS Service Name>) required. Aborting."
            }
            # WSDL Operation
            if { ! [string length $params(svcOperation)] > 0 } {
                wsmgr_helper::post_fatal_error "WSDL Operation (svcOperation <svcOperation>) required. Aborting ."
            }
            ## WSDL DICT
            if { ! [string length $params(data)] > 0 } {
                wsmgr_helper::post_fatal_error "WSDL Dictionary (data <dictionary>) required. Aborting."
            }
            ## PTRF Identification
            if { ![string length $params(ptrfNumber)] > 0 } {
                set params(ptrfNumber) "NAN"
            }
            ## nameID Identification
            if { ![string length $params(nameID)] > 0 } {
                set params(nameID) $params(ptrfNumber)
            }
        }
        # PTRF JOBID (REQUEST ID NUMBER)
        if { ! [string length $params(jobid)] > 0 } {
            set params(jobid) ""
        }
        # NO FEEDBACK CHECK.
        if { $params(dontWaitFeedback) != 0 } {
            set params(dontWaitFeedback) 1
        } else {
            set params(dontWaitFeedback) 0
        }
        set params(curr_host) [info hostname]
        set wsargs [list]
        set fnargs [array get params]
        set web_service ""
        # determine action from goal
        switch -- ${goal} {
            submit_ws_sync {
                array set RETURN [dbJobRecord_sync $fnargs]
                set RETURN(wsdlMessage) [remote2dontdie_wscall web_service_main $RETURN(jobid) [array get RETURN]]
                if {[info exists RETURN(wsdlMessage)] && [string length $RETURN(wsdlMessage)] < 1  && $params(dontWaitFeedback) < 1} {
                	set RETURN(wsdlMessage) [getResponse_wait [array get RETURN]]
				}
                return [array get RETURN]
            }
            retry_sync_grp {
                array set RETURN [dbJobRecord_sync $fnargs]
                set RETURN(wsdlMessage) [remote2dontdie_wscall web_service_main $RETURN(jobid) [array get RETURN]]
                if {[info exists RETURN(wsdlMessage)] && [string length $RETURN(wsdlMessage)] < 1  && $params(dontWaitFeedback) < 1 } {
                	set RETURN(wsdlMessage) [getResponse_wait [array get RETURN]]
				}
                return [array get RETURN]
            }
            submit {
                # Record Job to DataBase
                array set RETURN [dbJobRecord $fnargs]
                #parray RETURN
                set params(dontWaitFeedback) $RETURN(dontWaitFeedback)
                set params(error)            $RETURN(error)
                set params(jobid)            $RETURN(jobid)
                set params(logName)          $RETURN(logName)
                set params(logSetup)         $RETURN(logSetup)
                set params(messageID)        $RETURN(messageID)
                set params(rcvDate)          $RETURN(rcvDate)
                set params(wsdlURL)          $RETURN(wsdlURL)
                set params(data)             $RETURN(data)
                set params(headers)          $RETURN(headers)
                set fnargs [array get params]
                set retargs [array get RETURN]

                if { [regexp -nocase "^(host1213123|host1213124|serv3509|serv3510)" $params(curr_host) ]} {
                	set RETURN(wsdlMessage) [web_service_main $fnargs]
                } else {
                	set RETURN(wsdlMessage) [remote2dontdie_wscall web_service_main $params(jobid) $fnargs]
                }
                if {[info exists RETURN(wsdlMessage)] && [string length $RETURN(wsdlMessage)] < 1 && $params(dontWaitFeedback) < 1 } {
                	set RETURN(wsdlMessage) [getResponse_wait [array get RETURN]]
				}
                #set RETURN(wsdlMessage) [remote2dontdie_wscall web_service_main $params(jobid) $retargs]
                return [array get RETURN]
            }
            submit_stored {
                # Do Web Service Call is its not yet done
                if {[string length [checkIfSaveOnly $params(jobid)]]>1 } {
                    array set RETURN [dbJobRecord $fnargs]
                    set fnargs [array get RETURN]
                    if { [regexp -nocase "^(host1213123|host1213124|serv3509|serv3510)" $params(curr_host) ]} {
                    	set RETURN(wsdlMessage) [web_service_main $fnargs]
                    } else {
                    	set RETURN(wsdlMessage) [remote2dontdie_wscall web_service_main $params(jobid) $fnargs]
                    }
                    if {[info exists RETURN(wsdlMessage)] && [string length $RETURN(wsdlMessage)] < 1 && $params(dontWaitFeedback) < 1 } {
                    	set RETURN(wsdlMessage) [getResponse_wait [array get RETURN]]
                    }
                    return [array get RETURN]
				} else {
					# If its is already submitted, simply return the status
					array set RETURN [getJobStatus $params(jobid)]
					set RETURN(wsdlMessage) "Not running $params(jobid) with $RETURN(transactionStatus) status."
					set RETURN(jobid) $params(jobid)
					set RETURN(messageID) [getJobLastMessageID $params(jobid)]
					set RETURN(error) "0"
					set RETURN(status) $RETURN(transactionStatus)
					unset RETURN(ChipStatus)
					unset RETURN(dictFile)
					unset RETURN(transactionErrorMessage)
					return [array get RETURN]
			    }
            }
            store_only {
                array set RETURN [dbJobRecord $fnargs]
                return [array get RETURN]
            }
            dictsave_async {
                array set RETURN [dbJobRecord $fnargs]
                return [array get RETURN]
            }
            dictsave_sync {
                array set RETURN [dbJobRecord_sync $fnargs]
                return [array get RETURN]
            }
            retry {
                ## Do Web Service Call
                array set RETURN [dbJobRecord $fnargs]
                set fnargs [array get RETURN]
                if { [regexp -nocase "^(host1213123|host1213124|serv3509|serv3510)" $params(curr_host) ]} {
                	set RETURN(wsdlMessage) [web_service_main $fnargs]
                } else {
                	set RETURN(wsdlMessage) [remote2dontdie_wscall web_service_main $params(jobid) $fnargs]
                }
                if {[info exists RETURN(wsdlMessage)] && [string length $RETURN(wsdlMessage)] < 1 && $params(dontWaitFeedback) < 1 } {
                  	set RETURN(wsdlMessage) [getResponse_wait [array get RETURN]]
                }
                #set RETURN(wsdlMessage) [remote2dontdie_wscall web_service_main $params(jobid) $fnargs]
                return [array get RETURN]
            }
            get_response {
                if { ! [string length $params(serviceName)] > 0 } {
                    wsmgr_helper::post_fatal_error "WSDL Service Name (serviceName <WS Service Name>) required. Aborting."
                }
                # WSDL Operation
                if { ! [string length $params(svcOperation)] > 0 } {
                    wsmgr_helper::post_fatal_error "WSDL Operation (svcOperation <svcOperation>) required. Aborting ."
                }
                return [getResponse [array get params]]
            }
            get_status {
                return [getJobStatus $params(jobid)]
            }
            set_done {
                updateJobStatus $params(jobid) "DONE" "Status Done - Manual Initiated" ""
                updateMessageIDStatus $params(jobid) "CANCEL" "Set status to cancel - Manual Initiated"
            }
            cancel {
                updateJobStatus $params(jobid) "CANCEL" "Set status to cancel - Manual/Cron Initiated" ""
                updateMessageIDStatus $params(jobid) "CANCEL" "Set status to cancel - Manual/Cron Initiated"
            }
            default {
                # enjoy!
            }
        }
    }

    method cadws_dswatcher {options args} {
        variable environment
        variable mydb
        global cadws_dswatcher_waitvar
        set cadws_dswatcher_waitvar 1

        array set opts $options
        set data_dict_dir [file normalize $opts(data_write_dir)]
        set run_dir       [file normalize $opts(run_dir)]

		catch { file mkdir ${data_dict_dir} } ermsg
		catch { file mkdir ${run_dir} } ermsg

		set tblmain TBL_WSM_SYNC_MAIN
		set tbljd TBL_WSM_SYNC_JOB_DATA
        set fields "$tblmain.JOB_ID,$tblmain.WS_SVC_NAME,$tblmain.WS_OPERATION,$tblmain.REQ_STATUS,$tbljd.CONFIG,$tbljd.DATA_PARAM"

        while 1 {
            puts "# --------------------------------------"
            puts "Date : [getdate]"
            set sql "SELECT JOB_ID FROM tbl_wsm_sync_update_actions WHERE ACTION='cron_pickup_sync' ORDER BY JOB_ID ASC LIMIT 100"
            set result [$mydb Select $sql]

            if {[llength $result] < 1} {
            	puts "Date : [getdate] , No pending submission."
            	after 10000
            	continue
			}

            set id_list [join $result ,]
            set filter "$tblmain.JOB_ID IN ($id_list) AND $tblmain.REQ_STATUS = 'dictsave'"
            set sql_query "SELECT $fields FROM $tblmain INNER JOIN $tbljd ON $tblmain.JOB_ID = $tbljd.JOB_ID WHERE $filter"
            set result2 [$mydb Select $sql_query]
            if {[llength $result2] < 1} {
            	puts "Date : [getdate] , No pending submission in $id_list"
            	after 10000
            	continue
			}
        	set ymd [clock format [clock seconds] -format {%y%m%d} ]
            foreach line $result2 {
            	lassign $line jobid svc op req_status config data_param
				regsub -all " " $svc {} svc
				regsub -all " " $op  {} op
				catch { file mkdir ${data_dict_dir}/$ymd/ } ermsg
				catch { file mkdir ${data_dict_dir}/$ymd/$svc/ } ermsg

				set wsdlURL [lindex [getWSURL $svc $op] 0]


            	set dictfile [file normalize ${data_dict_dir}/$ymd/$svc/$jobid.$op.dict]
            	if {[catch {set  FO [open $dictfile w]} errmsg]} {
            	    puts "ERROR: JOB_ID=$jobid, ($dictfile) $errmsg"
            	    continue
				} else {
					puts $FO $data_param
					close $FO
            	    set sqlu "UPDATE tbl_wsm_sync_update_actions SET STATUS = 2,ACTION = 'dictfs' WHERE JOB_ID = $jobid AND ACTION = 'cron_pickup_sync' AND STATUS = 1"
            	    catch { $mydb Update $sqlu } dbupdate
            	    puts "WRITE JOB_ID=$jobid, DICT_FILE= $dictfile, DB_UPDATE=$dbupdate"
			    }

            	if {[catch {set  FR [open $run_dir/sync_${jobid}.sh w]} errmsg]} {
            	    puts "ERROR: JOB_ID=$jobid, ($run_dir) $errmsg"
				} else {
					puts $FR "write_date='[getdate]'"
					puts $FR "run_env='$environment'"
					puts $FR "run_jobid='$jobid'"
					puts $FR "run_dict='$dictfile'"
					puts $FR "ws_svc='$svc'"
					puts $FR "ws_op='$op'"
					puts $FR "ws_url='$wsdlURL'"
					puts $FR "ws_mode='synchronous'"
					close $FR
            	    puts "WRITE JOB_ID=$jobid, ARG_FILE= $run_dir/sync_${jobid}.sh"
			    }
            }
            after 10000
        }
        vwait cadws_dswatcher_waitvar
    }

    # ----------------------------------------------------
    # Description: Display usage message
    # ----------------------------------------------------
    method get_usage { options } {
        puts "Usage:"
        # << Usage >>
    }
    # ----------------------------------------------------
    # Description: Wait to emulate sleep
    # ----------------------------------------------------
    method sleep {N} {
        after [expr {int(${N} * 1000)}]
    }
    # ----------------------------------------------------------------
    # Get Active Transactions
    # Returns:
    #    1. (default) All transactions wating for completed signal.
    #    2. Or if (use_status_filter=1) retruns all transactions from
    #       selection filter
    # ----------------------------------------------------------------
    method activeTransactions { options } {
        variable mydb
        set FILTER_LIST [list]

        set params(filter) ""
        set params(use_status_filter) "on"
        set params(webservice_mode) ""
        if { [expr {[string length [string trim $options]] > 0 }] } {
            if { [string match -nocase $options "all"] } {
                #Do nothing
            } else {
                array set params $options
                set filter \
                    [expr {[string length [string trim $params(filter)]] \
                        > 0 ? $params(filter) \
                        : "" }]
                if {[string length $filter]>0} {
                	lappend FILTER_LIST $filter
				}

            }
        }
		set use_status_filter [ expr { [info exists params(use_status_filter)] > 0 ? "$params(use_status_filter)" : "on" }]
        set webservice_mode [ expr { [info exists params(webservice_mode)] > 0 ? "$params(webservice_mode)" : "async" }]
        if {[string match $params(webservice_mode) "synchronous"]} {
           set COLUMNS "NAME_ID,REQ_RCV_DATE,REQ_STATUS,"
           append COLUMNS "WS_SVC_NAME,WS_OPERATION,SVC_RETRIES,JOB_ID"
           if {[string match $use_status_filter "on" ]} {
           	   set REGS "pending|retry|submit|error|ON_HOLD"
           	   lappend FILTER_LIST "REQ_STATUS REGEXP '$REGS'"
           	   unset REGS
		   }
           set t1 "TBL_WSM_SYNC_MAIN"
           set FILTER [join $FILTER_LIST " AND " ]
           set msg "#NameID,rcvdate,status,serviceName,svcOperation,retries,JOBID"
           #set sql "SELECT $COLUMNS FROM $t1 WHERE $FILTER ORDER BY JOB_ID"
           set sql "SELECT $COLUMNS FROM $t1 WHERE $FILTER ORDER BY JOB_ID LIMIT 1000"
           set dnl [$mydb Select $sql]
           set ct  [llength $dnl]
           foreach line [ lindex $dnl] {
               append msg "\n[ join $line "," ]"
           }
        } else {
           set COLUMNS "PTRF,REQ_RCV_DATE,REQ_STATUS,"
           append COLUMNS "WS_SVC_NAME,WS_OPERATION,SVC_RETRIES,JOB_ID,SVC_ERRORS"
           if {[string match $use_status_filter "on" ]} {
               set REGS "pending|retry|submit|wait4reply"
               append REGS "|ERROR:AIA|ERROR:SFDC|ERROR|ON_HOLD"
               lappend FILTER_LIST "REQ_STATUS REGEXP '$REGS'"
           	   unset REGS
		   }
           set t1 "TBL_WSM_MAIN"
           set msg "#ptrfNumber,rcvdate,status,serviceName,svcOperation,retries,JOBID,ERROR_MSG,MSGID"
           set FILTER [join $FILTER_LIST " AND " ]
           #set sql "SELECT $COLUMNS FROM $t1 WHERE $FILTER ORDER BY JOB_ID"
           set sql "SELECT $COLUMNS FROM $t1 WHERE $FILTER ORDER BY JOB_ID LIMIT 1000"
           set dnl [$mydb Select $sql]
           set ct  [llength $dnl]
           foreach line [ lindex $dnl] {
               append msg  "\n[ join $line "," ],[getJobLastMessageID [lindex $line 6 ]]"
           }
        }
        array unset params
        return $msg
        unset COLUMNS
        unset FILTER
        unset FILTER_LIST
        unset use_status_filter
        unset webservice_mode
    }

    # ----------------------------------------------------------------
    # Get wsm pending actions
    # Returns: All transactions wating for completed signal.
    # ----------------------------------------------------------------
    method getUpdateActions { options } {
        variable mydb
        set FILTER_LIST [list]
        set params(filter) ""
        array set params $options
        if { [expr {[string length [string trim $options]] > 0 }] } {
            if { [string match -nocase $options "all"] } {
                #Do nothing
            } else {
                set filter \
                    [ expr {[string length [string trim $params(filter)]] \
                        > 0 ? $params(filter) \
                        : "" } ]
                if { [string length $filter]>0} {
                	lappend FILTER_LIST $filter
				}

            }
        }
        set FILTER [join $FILTER_LIST " AND " ]
        #set sql "SELECT tbl_wsm_update_actions.JOB_ID FROM `tbl_wsm_update_actions`,`TBL_WSM_MAIN` WHERE $FILTER AND tbl_wsm_update_actions.JOB_ID=TBL_WSM_MAIN.JOB_ID "
        set sql "SELECT tbl_wsm_update_actions.JOB_ID FROM `tbl_wsm_update_actions`,`TBL_WSM_MAIN` WHERE $FILTER AND tbl_wsm_update_actions.JOB_ID=TBL_WSM_MAIN.JOB_ID LIMIT 1000 "
        return [$mydb Select $sql]
    }

	# Check if jobID is still on SaveOnly State or already submitted.
	method checkIfSaveOnly { jobID } {
        variable mydb
        set query "SELECT JOB_ID FROM TBL_WSM_MAIN WHERE REQ_STATUS='saveonly' AND JOB_ID=$jobID LIMIT 1"
        set found 0
        set results [lindex [$mydb Select $query] 0]
        return $results
    }

    # ----------------------------------------------------------------
    # getJobLastMessageID
    #         getJobLastMessageID development 12
    #         getJobLastMessageID test 4
    # Input:  jobid
    # Return: Current Message ID or return 0 if not exists
    # ----------------------------------------------------------------
    private method getJobLastMessageID {jobid args} {
        set TABLE TBL_MSG_ID
        set FILTER "JOB_ID=$jobid AND WS_KEY=(SELECT MAX(WS_KEY) FROM TBL_MSG_ID WHERE JOB_ID=$jobid)"
        set sql "SELECT WS_MSG_ID FROM $TABLE WHERE $FILTER"
        catch { set dbl [$mydb Select $sql] } error
        return [lindex [lsort $dbl] end]
    }
    # ----------------------------------------------------------------
    # getJobLastMessageIDStatus
    #   Report Current Message ID Status
    # Input:  jobid
    # Optional:
    #         Environment [test | development | production]
    # ----------------------------------------------------------------
    private method getJobLastMessageIDStatus {jobid args}  {
       set messageID [getJobLastMessageID $jobid ]
        set sql "SELECT WS_STATUS FROM TBL_MSG_ID WHERE WS_MSG_ID='$messageID'"
        if {[catch { set dbl [$mydb Select $sql] } error]} {
            return "No MessageID Found"
        }
        return $dbl
    }
    # ----------------------------------------------------------------
    # addJobMessageID
    #   Create or Update Message ID Number
    # Input:  jobid
    # Optional:
    #         Environment [test | development | production]
    # ----------------------------------------------------------------
    private method addJobMessageID {jobid args} {
        variable environment
        variable msg_mode
        variable messageID_suffix
        set ols [list environment serviceName operation prefix suffix ]
        set ct1 0
        array set opts [list]
        foreach arg $args { set opts([lindex $ols $ct1]) $arg ; incr ct1 }

        ##--Run mode is CAD=0/SIT=1/UAT=2/NODB=3
        array set mode_select { 1 SIT 2 UAT 3 OFF default CAD }
        array set etag { test T development D production P }

        set ncoded [clock seconds]
        #set dclk [clock format [clock seconds] -format {%y,%m,%d,%k,%M,%S} ]
        #set chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        #foreach v [split $dclk ","] {
        #	if { $v >0 } { regsub {^0} $v {} v }
        #	append ncoded [string index $chars $v]
        #}
        #unset dclk

        set msg_prefix [ expr { [info exists mode_select($msg_mode)] > 0 ? "$mode_select($msg_mode)" : "CAD" }]

        set newmessageID "${msg_prefix}$etag($environment)-${jobid}-${ncoded}"

        if {[string length $messageID_suffix] > 0} {
            append newmessageID "-" $messageID_suffix
        }
        while { 1 } {
            set COLUMNS "JOB_ID,WS_MSG_ID,WS_STATUS"
            set VALUES "'$jobid','$newmessageID','create'"
            set sqli "INSERT IGNORE INTO TBL_MSG_ID ($COLUMNS) VALUES ($VALUES)"
            if {[ catch { $mydb Insert $sqli } error ] } {
                #Expects: Dont know, Failed to insert maybe.
                wsmgr_helper::post_fatal_error "\[addMessageID\] $error";
            } else {
            	catch { updateMessageIDStatus $newmessageID "pending" "" } imsg
                set error 0 ; break
            }
        }
        #puts "[getdate] Info: \[JOB_ID $jobid\],\[messageID $newmessageID\]"
        return $newmessageID
    }
    # ----------------------------------------------------------------
    # dbSaveDictionary
    #  Save Data Dictionary to DB
    # ----------------------------------------------------------------
    method dbSaveDictionary { type jobid label args } {
        variable mydb
        variable WORK_DIR
        set data_dictionary_safe [safe_sql_value "$args"]
        switch -- $type {
          datadict_sync {
              set dictfile ""
              set SQL_TABLE_DICT "TBL_WSM_SYNC_JOB_DATA"
              set FIELDS "JOB_ID,DATA_PARAM"
              set VALUES "'${jobid}','${data_dictionary_safe}'"
              set sqli "INSERT INTO $SQL_TABLE_DICT ($FIELDS) VALUES ($VALUES)"
              set sqli "$sqli ON DUPLICATE KEY UPDATE DATA_PARAM='${data_dictionary_safe}'"
          }
          config_sync {
              set dictfile ""
              set SQL_TABLE_DICT "TBL_WSM_SYNC_JOB_DATA"
              set FIELDS "JOB_ID,CONFIG"
              set VALUES "'${jobid}','${data_dictionary_safe}'"
              set sqli "INSERT INTO $SQL_TABLE_DICT ($FIELDS) VALUES ($VALUES)"
              set sqli "$sqli ON DUPLICATE KEY UPDATE CONFIG='${data_dictionary_safe}'"
          }
          datadict {
              set dictfile "$WORK_DIR/ws_${label}.${jobid}.setup"
              set SQL_TABLE_DICT TBL_WSM_JOB_DATA
              set FIELDS "JOB_ID,DATA_PARAM,DATA_ONDISK"
              set VALUES "'${jobid}','${data_dictionary_safe}','$dictfile'"
              set sqli "INSERT INTO $SQL_TABLE_DICT ($FIELDS) VALUES ($VALUES)"
              set sqli "$sqli ON DUPLICATE KEY UPDATE DATA_PARAM='${data_dictionary_safe}', DATA_ONDISK='$dictfile'"
          }
          config {
              set dictfile "$WORK_DIR/ws_${label}.${jobid}.setup"
              set SQL_TABLE_DICT TBL_WSM_JOB_DATA
              set FIELDS "JOB_ID,CONFIG"
              set VALUES "'${jobid}','${data_dictionary_safe}'"
              set sqli "INSERT INTO $SQL_TABLE_DICT ($FIELDS) VALUES ($VALUES)"
              set sqli "$sqli ON DUPLICATE KEY UPDATE CONFIG='${data_dictionary_safe}'"
          }
          default {
              #do nothing
              set error "[getdate] Error: dbSaveDictionary Invalid type:$type."
              puts $error
              return [list "" $error ]
          }
        }
        if {[set rval [catch { $mydb Insert $sqli } error ]]} {
            puts "[getdate] Error: Unable to save dictionary information to DB."
            puts "[getdate] Error: \[dbSaveDictionary\] $error"
            return [list $dictfile $error]
        } else {
            return [list $dictfile "saved to db"]
        }
    }
    # ----------------------------------------------------------------
    # dbRestoreDictionary
    #  Restore/Get Data Dictionary from DB
    # ----------------------------------------------------------------
    method dbRestoreDictionary {jobid table} {
        variable mydb
        set TABLE $table
        set FIELDS "DATA_PARAM"
        set sql "SELECT $FIELDS FROM $TABLE WHERE JOB_ID=$jobid LIMIT 1"
        if {[catch { set dbl [$mydb Select $sql] } error ]} {
            puts "[getdate] Error: Unable to restore dictionary info from DB."
            puts "[getdate] Error: \[dbRestoreDictionary\] $error"
            catch { updateJobStatus $jobid "ERROR:CAD" $error "" }
            return -code error $error
        } else {
            set dbl [lindex [lindex [join $dbl] 0 ] 0 ]
            if { [string length $dbl] == 0 } {
            	catch { updateJobStatus $jobid "ERROR:CAD" "Data dictionary empty" "" }
            	return -code error "Error: Data length is 0"
			}
            return $dbl
        }
    }
    # ----------------------------------------------------------------
    # getJobStatus
    #    get job status of a particular jobID
    # Input:  jobid
    # ----------------------------------------------------------------
    method getJobStatus { jobid args} {
        variable mydb
        set messageID ""
        if {[regexp {^SYNC:(\d+)} $jobid match id]} {
            set TABLE TBL_WSM_SYNC_MAIN
            set FILTER "JOB_ID=$id"
            set ws_mode sync
        } else {
        	set messageID [getJobLastMessageID $jobid ]
            set TABLE TBL_WSM_MAIN
            set FILTER "JOB_ID=$jobid"
            set ws_mode async
        }

        set sql "SELECT REQ_RCV_DATE,REQ_STATUS,SVC_ERRORS FROM $TABLE WHERE $FILTER"
        catch { set dbl [$mydb Select $sql] } msg
        set response_date   [lindex [lindex $dbl 0 ] 0]
        set status [lindex [lindex $dbl 0 ] 1]
        set error  [lindex [lindex $dbl 0 ] 2]

        if { [string match -nocase $ws_mode]} {
            array set JobStatus [list REQ_STATUS $status error $error]
		} else {
            array set JobStatus [getResponseData $jobid]
            set JobStatus(transactionDate) $response_date
            set JobStatus(transactionStatus) $status
            set JobStatus(transactionErrorMessage) $error
            set JobStatus(jobid) $jobid
            set JobStatus(messageID) $messageID
            #puts "# JOB STATUS ----------------------"
            #parray JobStatus
            #puts "# ---------------------------------"
	    }

        return [array get JobStatus]
    }

    # ----------------------------------------------------------------
    # getResponse
    #    get Response of a particular web service call
    # Input:  jobid
    # ----------------------------------------------------------------
    method getResponse { options } {
        variable mydb
        set messageID ""
        array set opts $options
        if {![info exists opts(webservice_mode)]} {
			return [list ERROR "web_service_mode option not found."]
	    }

        set mode $opts(webservice_mode)
        switch -regexp -- $mode {
        	"^sync" {
                set TABLE     TBL_WSM_SYNC_MAIN
                set RESTBL    TBL_WSM_SYNC_RES_DATA
                set ws_mode   sync
                set messageID ""
                set FIELDS1   "${TABLE}.JOB_ID,${TABLE}.NAME_ID,${TABLE}.WS_SVC_NAME,${TABLE}.WS_OPERATION,${TABLE}.REQ_STATUS,${TABLE}.REQ_RCV_DATE"
                set FIELDS2   "${RESTBL}.RESPONSE"
                set FILTER    "${TABLE}.JOB_ID='$opts(jobid)' AND ${TABLE}.JOB_ID = ${RESTBL}.JOB_ID"
                set sql       "SELECT $FIELDS1,$FIELDS2 FROM ${TABLE},${RESTBL} WHERE ${FILTER} ORDER BY ${RESTBL}.time_updated DESC LIMIT 1"
                set sql2      "SELECT $FIELDS1 FROM ${TABLE} WHERE ${TABLE}.JOB_ID='$opts(jobid)' ORDER BY ${TABLE}.REQ_RCV_DATE DESC LIMIT 1"
                if {[catch { set dbl [$mydb Select $sql] } msg]} {
                	return [list ERROR $msg]
				} else {
					if {[llength [lindex $dbl 0]] < 6} {
						if {[catch { set dbl [$mydb Select $sql2] } msg]} {
							return [list ERROR $msg]
						}
				    }
					if {[llength [lindex $dbl 0]] < 6} {
						set Response(jobid)        $opts(jobid)
				    	set Response(status)       "ERROR: REQUESTED_JOB_ID_NOT_FOUND"
				    	set Response(ERROR)        "ERROR: REQUESTED_JOB_ID_NOT_FOUND"
				    	set Response(response_message) ""
				    	set Response(response_date)    ""
				    	set Response(serviceName)      ""
				    	set Response(svcOperation)     ""
				    	return [array get Response]

					}
					set Response(jobid)            [lindex [lindex $dbl 0] 0]
					set Response(nameID)           [lindex [lindex $dbl 0] 1]
					set Response(serviceName)      [lindex [lindex $dbl 0] 2]
					set Response(svcOperation)     [lindex [lindex $dbl 0] 3]
					set Response(status)           [lindex [lindex $dbl 0] 4]
					set Response(response_date)    [lindex [lindex $dbl 0] 5]
					set rmsg [lindex [lindex $dbl 0] 6]
					#regsub -all "^$opts(svcOperation)Result " $rmsg {} rmsg
					set Response(response_message) $rmsg
			    }
            }
            "^async" {
            	set jobid $opts(jobid)
                set messageID [getJobLastMessageID $jobid ]
                set TABLE     TBL_WSM_MAIN
                set RESTBL    TBL_RESPONSE_DATA
                set ws_mode   async
                set sql "SELECT REQ_RCV_DATE,REQ_STATUS,SVC_ERRORS FROM $TABLE WHERE JOB_ID=$opts(jobid)"
                catch { set dbl [$mydb Select $sql] } msg
                set response_date   [lindex [lindex $dbl 0 ] 0]
                set status [lindex [lindex $dbl 0 ] 1]
                set error  [lindex [lindex $dbl 0 ] 2]

                if { [string match -nocase $ws_mode]} {
                    array set Response [list REQ_STATUS $status error $error]
		        } else {
                    array set Response [getResponseData $jobid]
                    set Response(transactionDate) $response_date
                    set Response(transactionStatus) $status
                    set Response(transactionErrorMessage) $error
                    set Response(jobid) $jobid
                    set Response(messageID) $messageID
                    #puts "# JOB STATUS ----------------------"
                    #parray Response
                    #puts "# ---------------------------------"
	            }

            }
            default {
               	return ""
            }
        }
        #################

        return [array get Response]
    }

    # ----------------------------------------------------------------
    # getResponseData
    #    get Response Dictionary
    # Input:  jobid
    # ----------------------------------------------------------------
    method getResponseData { jobid args} {
        variable mydb
        set messageID [getJobLastMessageID $jobid ]
        set COLUMNS "jobid,messageID,transactionStatus,transactionErrorMessage,ChipStatus,dictFile"
        set sql "SELECT $COLUMNS FROM TBL_RESPONSE_DATA WHERE jobid='$jobid' AND messageID='$messageID'"
        if { [catch { set dbl [lindex [$mydb Select $sql] 0] } msg] } {
           return [list Error $msg]
        } else {
           set opts(jobid) [lindex $dbl 0]
           set opts(messageID) [lindex $dbl 1]
           set opts(transactionStatus) [lindex $dbl 2]
           set opts(transactionErrorMessage) [lindex $dbl 3]
           set opts(ChipStatus) [lindex $dbl 4]
           set opts(dictFile) [lindex $dbl 5]
           return [array get opts]
        }
    }
    # ----------------------------------------------------------------
    # getResponseData_NONCAD
    #    get Response Dictionary
    # Input:  messageID
    # ----------------------------------------------------------------
    method getResponseData_NONCAD { messageID } {
        variable mydb
        set sql "SELECT * FROM TBL_NONCAD_RESPONSE WHERE messageID='$messageID'"
        if { [catch { set dbl [lindex [$mydb Select $sql] 0] } msg] } {
           return [list Error $msg]
        } else {
           return $dbl
        }
    }

    # ----------------------------------------------------------------
    # getResponse_wait
    #    retrieve delayed web service response
    # Input:  previous data response array
    # ----------------------------------------------------------------
    method getResponse_wait {fnargs} {
    	variable mydb
    	variable verbose

    	array set opts $fnargs

    	dict set data serviceName      $opts(serviceName)
    	dict set data svcOperation     $opts(svcOperation)
    	dict set data jobid            $opts(jobid)
    	dict set data do               get_response
    	if {[string match $opts(webservice_mode) synchronous] } {
    		dict set data webservice_mode  synchronous
		} else {
    		dict set data webservice_mode  async
	    }

    	set msg ""
    	set startdate [getdate]

    	set ctr 0
    	set noresponse 1
        after 300
        while {$noresponse} {
        	array set res [getResponse $data]
            if {[info exists res(status)] && [string match $res(status) "DONE"]} {
            	set noresponse 0
	        	break
	        } else {
	        	if { $ctr > 20} {
	        		set enddate [getdate]
	        		set runtime [getRunTime $startdate $enddate]
	        		append msg "ERROR: No web service response recieved after waiting for $runtime seconds.\n"
	        		break
	    		}
	    		incr ctr
	        	after 1000
	        }
        }
        if {[info exists res(status)]} {
        	set __RES(status) $res(status)
        }
        if {[info exists res(response_date)]} {
        	set __RES(response_date) $res(response_date)
        }
        if {[info exists res(response_message)]} {
        	set __RES(response_message) $res(response_message)
        } else {
        	set __RES(response_message) ""
        }
        if {$verbose} {
        	puts "Response Details:"
        	if {[string length $msg]>0} { puts "[getdate] $msg"	}
        	parray __RES
        }
        return $__RES(response_message)
    }

    # ----------------------------------------------------------------
    # getjobid
    #    get jobID assigned based on MessageID
    # ----------------------------------------------------------------
    method getjobid { messageID args} {
        variable mydb
        set jobid ""
        set sql "SELECT JOB_ID FROM TBL_MSG_ID WHERE WS_MSG_ID='$messageID'"
        set jobid [$mydb Select $sql]
        return $jobid
    }
    # ----------------------------------------------------------------
    # getWSURL
    #    get URL of given serviceName and svcOperation from db
    # ----------------------------------------------------------------
    method getWSURL { serviceName svcOperation } {
        variable mydb
        variable environment
        variable msg_mode
        set url            ""
        set fldSvcName     "WS_SVC_NAME='$serviceName'"
        set fldOperation   "WS_OPERATION_LIST LIKE '%${svcOperation}%'"
        ##--Run mode is CAD=0/SIT=1/UAT=2/NODB=3
        set env         "WS_ENV='$environment'"
        if { $msg_mode == 1 } {
            #SIT
            set env         "WS_ENV='SIT'"
        } elseif { $msg_mode == 2 } {
            #UAT
            set env         "WS_ENV='test'"
        } elseif { $msg_mode == 3 } {
            #NODB
            set env         "WS_ENV='$environment'"
        } else {
            #DEFAULT
           set env         "WS_ENV='$environment'"
        }
        set tblName        TBL_WSDLS
        set fldSelect      WS_URL
        #set sql "SELECT WS_URL,WS_HEADERS FROM TBL_WSDLS WHERE $env AND $fldSvcName AND $fldOperation LIMIT 1"
        set sql "SELECT $fldSelect FROM $tblName WHERE $fldSvcName AND $fldOperation AND $env LIMIT 1"
        set sql2 "SELECT WS_HEADERS FROM $tblName WHERE $fldSvcName AND $fldOperation AND $env LIMIT 1"
        set url [$mydb Select $sql]
        set headers [ lindex [$mydb Select $sql2] 0]
        return "$url $headers"
    }
    # ----------------------------------------------------------------
    # updateJobStatus
    #   status :
    #   msg    : Message Returned by WSDL
    # ----------------------------------------------------------------
    method updateJobStatus { jobid status errmsg {noDC 0}} {
        variable mydb
        set date [getdate]
        set UPDATES "REQ_STATUS='$status',REQ_END_DATE='$date'"
        if {[regexp {^SYNC:(\d+)} $jobid match id]} {
            set TABLE TBL_WSM_SYNC_MAIN
            set FILTER "JOB_ID=$id"
        } else {
            set TABLE TBL_WSM_MAIN
            set FILTER "JOB_ID=$jobid"
            append UPDATES ",SVC_ERRORS='$errmsg'"
        }
        set sqlu "UPDATE $TABLE SET $UPDATES WHERE $FILTER;"
        if {$noDC==1} {
            set results [$mydb Update_noDC $sqlu]
		} else {
            set results [$mydb Update $sqlu]
	    }
        return $results
    }
    # ----------------------------------------------------------------
    # updateMessageIDStatus
    #   status :
    #   msg    : Message Returned by WSDL
    # ----------------------------------------------------------------
    method updateMessageIDStatus { messageID status errmsg {noDC 0}} {
        variable mydb
        set sqlu "UPDATE TBL_MSG_ID SET WS_STATUS='$status', WS_ERROR='$errmsg' WHERE WS_MSG_ID='$messageID';"
        if { $noDC==1 } {
        	set results [$mydb Update_noDC $sqlu]
		} else {
        	set results [$mydb Update $sqlu]
	    }
        return $results
    }
    # ----------------------------------------------------------------
    # wsResponseStatusUpdate
    #   Used by WSDL Response
    #   Inputs:
    #   options: Key Value pair list of messages from WSDL Cad Response
    # ----------------------------------------------------------------
    method wsResponseStatusUpdate { options {noDC 0}} {
        array set opts $options
        set status    $opts(transactionStatus)
        set count     $opts(todayTransactionCountNumber)
        set messageID $opts(messageID)
        set msg ""
        set errct 0
        catch  { set opts(jobid) [ getjobid $messageID ] } msg
        if {[string length $opts(jobid)] > 0} {
            if {[catch { updateMessageIDStatus $messageID $status $opts(transactionErrorMessage) } err1]} {
            	incr errct
            	lappend msg $err1
            	unset err1
            }
            if {[catch { updateJobStatus $opts(jobid) $status $opts(transactionErrorMessage) "" } err2]} {
            	incr errct
            	lappend msg $err2
            	unset err2
			}
			if {[catch { wsResponseSaveData [array get opts] } err3]} {
            	incr errct
            	lappend msg $err3
            	unset err3
		    }
		    if {$errct>0} {
		    	puts "JOBID=$opts(jobid) : $msg"
		    	unset msg
			}
        } else {
            set noncad_jobid [clock format [clock seconds] -format {%m%d%H%M%S} ]
            append noncad_jobid $count
            set opts(jobid) $noncad_jobid
            wsResponseSaveData_NONCAD [array get opts]
        }
        return $opts(jobid)
    }
    # ----------------------------------------------------------------
    # wsResponseSaveData
    #   Used by WSDL Response
    #
    # ----------------------------------------------------------------
    method wsResponseSaveData { options {noDC 0}} {
        variable mydb
        variable WORK_DIR
        array set opts $options
        set oplist [list jobid transactionErrorMessage ChipStatus]
        foreach var $oplist {
            if { [info exists opts($var)] } {
            # procs
            } else {
                set opts($var) ""
            }
        }
        #Store to SQLITE file
        #set dictFile "$WORK_DIR/ws_$opts(ptrfNumber).$opts(jobid).sqlite3.db"
        #wsqlite create "$dictFile"
        #wsqlite insert "$dictFile" [array get opts]
        #Store ot DB
        set TABLE "TBL_RESPONSE_DATA"
        set FIELDS "dictFile"
        set VALUES "'$dictFile'"
        set updcol "dictFile='$dictFile'"
        foreach key [lsort -dictionary [array names opts]] {
            if { [string match "todayTransactionCountNumber" $key]} {
                continue
            }
            set value [safe_sql_value $opts($key)]
            append FIELDS ",$key"
            append VALUES ",'$value'"
            if { [string match -nocase $key "ChipStatus"] } {
                if { [string length $value] > 0 } {
                    append updcol " , $key='$value'"
                }
            } else {
                append updcol " , $key='$value'"
            }
        }
        append updcol " , rstat='u'"
        set sqli "INSERT INTO TBL_RESPONSE_DATA ($FIELDS) VALUES ($VALUES)"
        append sqli " ON DUPLICATE KEY UPDATE $updcol"

        if {[set rval [catch {$mydb Insert $sqli } error ]]} {
            puts "[getdate] Error: \[wsResponseSaveData\] $error"
            return $error
        } else {
            return 0
        }
    }
    # ----------------------------------------------------------------
    # wsResponseSaveData_NONCAD
    #   Used by WSDL Response
    #
    # ----------------------------------------------------------------
    method wsResponseSaveData_NONCAD { options } {
        variable mydb
        variable WORK_DIR
        array set opts $options
        set oplist [list jobid transactionErrorMessage ChipStatus]
        foreach var $oplist {
            if { [info exists opts($var)] } {
            # procs
            } else {
                set opts($var) ""
            }
        }
        ##Store to SQLITE file
        set dictFile "$WORK_DIR/NONCAD.$opts(messageID).message.db"
        #wsqlite create "$dictFile"
        #wsqlite insert "$dictFile" [array get opts]
        #Store ot DB
        set TABLE "TBL_NONCAD_RESPONSE"
        set FIELDS "dictFile"
        set VALUES "'$dictFile'"
        set updcol "$dictFile='$dictFile'"
        foreach key [lsort -dictionary [array names opts]] {
            #puts "$key : $opts($key)"
            if { [string match -nocase "todayTransactionCountNumber" $key]} {
                continue
            }
            set value [safe_sql_value $opts($key)]
            append FIELDS ",$key"
            append VALUES ",'$value'"
            if { [string match -nocase $key "ChipStatus"] } {
                if { [string length $opts($key)] > 0 } {
                    append updcol " , $key='$value'"
                }
            } else {
                append updcol " , $key='$value'"
            }
        }
        set sqli "INSERT INTO ${TABLE} ($FIELDS) VALUES ($VALUES)"
        #append sqli " ON DUPLICATE KEY UPDATE $updcol"
        if {[set rval [catch {$mydb Insert $sqli } error ]]} {
            puts "[getdate] Error: \[wsResponseSaveData_NONCAD\] $error"
            return $error
        } else {
            return 0
        }
    }
    # ----------------------------------------------------------------
    # wsResponseSaveData_synchronous
    #  do_sync_call Save Data
    #
    # ----------------------------------------------------------------
    method wsResponseSaveData_synchronous { options } {
        variable mydb
        variable WORK_DIR
        array set opts $options
        set oplist [list JOB_ID REQ_STATUS RESPONSE]
        foreach var $oplist {
            if { [info exists opts($var)] } {
            # procs
            } else {
                set opts($var) ""
            }
        }
        set response [safe_sql_value $opts(RESPONSE)]
        #Store ot DB
        set TABLE "TBL_WSM_SYNC_RES_DATA"
        set FIELDS "JOB_ID,REQ_STATUS,RESPONSE"
        set VALUES "'$opts(JOB_ID)','$opts(REQ_STATUS)','$response'"
        set updcol "REQ_STATUS='$opts(REQ_STATUS)',RESPONSE='$response'"
        set sqli "INSERT INTO $TABLE ($FIELDS) VALUES ($VALUES)"
        append sqli " ON DUPLICATE KEY UPDATE $updcol"
        if {[set rval [catch {$mydb Insert $sqli } error ]]} {
            puts "[getdate] Error: \[wsResponseSaveData_synchronous\] $error"
            return $error
        } else {
            return 0
        }
    }
    # ----------------------------------------------------------------
    # dbJobRecord
    # Description: Stores job to MySQL database.
    # Inputs:
    #    ptrfNumber
    #    serviceName
    #    svcOperation
    #    logName (optional, automatically generated)
    #    jobid (optional, automatically generated)
    #
    # Sample Usage:
    #    set fnargs [list]
    #    lappend fnargs ptrfNumber "PTRF-12345-6789"
    #    lappend fnargs jobid ""
    #    lappend fnargs serviceName "wsSampleService"
    #    lappend fnargs svcOperation "cookSecretFormula"
    #    puts [$wsdb dbJobRecord $fnargs ]
    #
    # Returns:
    #    Dictionary of added values.
    #    e.g.
    #     messageID 10000012 serviceName wsSampleService jobid 10000024 ptrfNumber PTRF-12345-6789 \
    #     rcvDate {2002/02/02 12:34:56} svcOperation cookSecretFormula error 0 logName ws_10000024.log
    #
    # Error return:
    #   Database Table Insert error failure // Fail Immediately. No database entry created.
    #   e.g.
    #   serviceName wsSampleService jobid 10000020 ptrfNumber PTRF-12345-6789 \
    #   svcOperation cookSecretFormula \
    #   error {mysql::exec/db server: Duplicate entry '10000020' for key 'JOB_ID'} logName ws_10000020.log
    #
    # ----------------------------------------------------------------
    method dbJobRecord { options args } {
        variable mydb
        variable environment
        variable msg_mode
        variable WORK_DIR
        set rcvDate [getdate]
        set data ""
        set updateOrRetry 0
        array set opts $options
        set SQL_TABLE_MAIN TBL_WSM_MAIN
        set SQL_TABLE_DICT TBL_WSM_JOB_DATA
        set SQL_TABLE_RESP TBL_RESPONSE_DATA
        set SQL_TABLE_VIEW ""

    	if { [webservice_holiday] } {
    		set reqstat "ON_HOLD"
        } else {
        	set reqstat "pending"
        }

        #get wsdlURL
        if { [info exists opts(wsdlURL)] && [string length $opts(wsdlURL)] > 0 } {
            set wsdlURL $opts(wsdlURL)
        } else {
            set opts(wsdlURL) [lindex [getWSURL $opts(serviceName) $opts(svcOperation)] 0]
            set wsdlURL $opts(wsdlURL)
        }
        set SVC_RETRIES "SVC_RETRIES"
        set colupdate "SVC_RETRIES=$SVC_RETRIES"
        if { ([string length $opts(jobid)] > 0) && ([regexp {^retry$|^submit_stored$} $opts(do)]) } {
        	if { [string match -nocase "ON_HOLD" $reqstat ]} {
        		set SVC_RETRIES "SVC_RETRIES"
			} elseif {[string match "submit_stored" $opts(do)]} {
        		set SVC_RETRIES "SVC_RETRIES"
            	set reqstat "submit"
		    } else {
				set SVC_RETRIES "SVC_RETRIES+1"
            	set reqstat "$opts(do)"
		    }
            set updateOrRetry 1
            set colupdate "REQ_STATUS='$reqstat', REQ_RCV_DATE='$rcvDate', SVC_RETRIES=$SVC_RETRIES"
            if { [string length $opts(ptrfNumber)] > 0 } {
            	set opts(nameID) $opts(ptrfNumber)
                set colupdate "$colupdate, PTRF='$opts(ptrfNumber)'"
            }
            if { [string length $opts(serviceName)] > 0 } {
            set colupdate "$colupdate, WS_SVC_NAME='$opts(serviceName)'"
            }
            if { [string length $opts(svcOperation)] > 0 } {
                set colupdate "$colupdate, WS_OPERATION='$opts(svcOperation)'"
            }
        }
        while {1} {
            set COLUMNS "PTRF,WS_SVC_NAME,WS_OPERATION,REQ_STATUS,REQ_RCV_DATE"
            set VALUES  "'$opts(ptrfNumber)','$opts(serviceName)','$opts(svcOperation)','$reqstat','$rcvDate'"
            if { [llength $opts(jobid)] > 0 } {
                    append COLUMNS ",JOB_ID"
                    append VALUES  ",$opts(jobid)"
            }
            set sqli   "INSERT INTO $SQL_TABLE_MAIN ($COLUMNS) VALUES ($VALUES)"
            set cmd "$mydb Insert $sqli"
            if { $updateOrRetry == 1 } {
                append sqli "ON DUPLICATE KEY UPDATE $colupdate"
            } else {
                append sqli "; SELECT LAST_INSERT_ID()"
            }

            if {[ catch { set insertid [$mydb Insert $sqli] } error ] } {
                puts "[getdate] Error: \[dbJobRecord\] $error"
                break;
            } else {
                if { $updateOrRetry == 1 } {
                    set COLUMNS2 "PTRF,WS_SVC_NAME,WS_OPERATION,REQ_STATUS,REQ_RCV_DATE,SVC_RETRIES"
                    set sqlb "SELECT $COLUMNS2 FROM $SQL_TABLE_MAIN WHERE JOB_ID=$opts(jobid)"
                    set dbl [$mydb Select $sqlb]
                    set opts(ptrfNumber)      [lindex [lindex $dbl 0 ] 0]
                    set opts(serviceName)     [lindex [lindex $dbl 0 ] 1]
                    set opts(svcOperation)    [lindex [lindex $dbl 0 ] 2]
                    set opts(status)          [lindex [lindex $dbl 0 ] 3]
                    set opts(origRecieveDate) [lindex [lindex $dbl 0 ] 4]
                    set opts(submitRetries)   [lindex [lindex $dbl 0 ] 5]
                } else {
                    set opts(jobid) $insertid
                }
                set job_host_user_info [list userhost "${::tcl_platform(user)}@[info hostname]"]
                set sql4hostupdate  "UPDATE $SQL_TABLE_MAIN SET JOB_NFO=CONCAT(IF(LENGTH(`JOB_NFO`),`JOB_NFO`,''),'$job_host_user_info') "
                append sql4hostupdate "WHERE JOB_ID=$opts(jobid) AND ( JOB_NFO NOT LIKE '%userhost%' OR JOB_NFO IS NULL)"
                catch { $mydb Update $sql4hostupdate } error
                #puts "[getdate] JOB_ID==>$opts(jobid)"
                set error 0 ; break
            }
        }
        set opts(logName) ""

        if { [string length $opts(jobid)] > 0 } {
        	set messageID_suffix [string range $opts(svcOperation) 0 2]
        	set sqlu ""
        	set sqli ""
        	if {[string equal "store_only" $opts(do)]} {
        		set sqlu "UPDATE $SQL_TABLE_MAIN SET REQ_STATUS='saveonly' WHERE JOB_ID=$opts(jobid);"
        		set sqli "INSERT INTO tbl_wsm_update_actions (JOB_ID,ACTION,STATUS) VALUES ($opts(jobid),'do submit',1);"
        		$mydb Insert $sqli
        		#$mydb Update $sqlu        		
		    } elseif {[string equal "dictsave_async" $opts(do)]} {
        		set sqlu "UPDATE $SQL_TABLE_MAIN SET REQ_STATUS='dictsave' WHERE JOB_ID=$opts(jobid);"
        		set sqli "INSERT INTO tbl_wsm_update_actions (JOB_ID,ACTION,STATUS) VALUES ($opts(jobid),'do cron_pickup_async',1);"
        		$mydb Insert $sqli
        		$mydb Update $sqlu        		
        	} elseif {[string equal "submit_stored" $opts(do)]} {
        		set sqlu "UPDATE $SQL_TABLE_MAIN SET REQ_STATUS='pending' WHERE JOB_ID=$opts(jobid);"
        		set opts(messageID) [addJobMessageID $opts(jobid) $environment $opts(serviceName) $opts(svcOperation)]
        		set sqld "DELETE FROM `tbl_wsm_update_actions` WHERE (`JOB_ID`='$opts(jobid)') AND (`ACTION`='do submit') AND (`STATUS`='1') LIMIT 1"
        		$mydb Exec $sqld
        		$mydb Update $sqlu
        		set opts(do) submit
        	} elseif {[string equal "cron_pickup_async" $opts(do)]} {
        		set sqlu "UPDATE $SQL_TABLE_MAIN SET REQ_STATUS='pending' WHERE JOB_ID=$opts(jobid);"
        		set opts(messageID) [addJobMessageID $opts(jobid) $environment $opts(serviceName) $opts(svcOperation)]
        		set sqld "DELETE FROM `tbl_wsm_update_actions` WHERE (`JOB_ID`='$opts(jobid)') AND (`ACTION`='do cron_pickup_async') AND (`STATUS`='1')"
        		$mydb Exec $sqld
        		$mydb Update $sqlu
        		set opts(do) submit
        	} else {
        		set sqlu "UPDATE $SQL_TABLE_MAIN SET JOB_LOG='' WHERE JOB_ID=$opts(jobid);"
        		set opts(messageID) [addJobMessageID $opts(jobid) $environment $opts(serviceName) $opts(svcOperation)]
            }
        		unset sqlu
        		unset sqli
        }

        #save data
        if { [info exists opts(data)] } {
            if { [string length $opts(data)] > 0 } {
                set opts(dataDictSave) [dbSaveDictionary datadict $opts(jobid) $opts(ptrfNumber) $opts(data)]
            } elseif { $updateOrRetry == 1 } {
                set opts(data) [dbRestoreDictionary $opts(jobid) $SQL_TABLE_DICT]
                #puts $opts(data)
            } elseif {[string match -nocase "submit_stored" $opts(do)]} {

                set opts(data) [dbRestoreDictionary $opts(jobid) $SQL_TABLE_DICT]
            } else  {
            	puts "[getdate] Warning: Missing data to submit"
            	set opts(dataDictSave) 0
            }
        }

        set opts(error)   $error
        set opts(rcvDate) $rcvDate
        set opts(WORK_DIR) "$WORK_DIR"
        set opts(msg_mode) "$msg_mode"
        #set opts(logName) $jobLog
        #set opts(logSetup) "$WORK_DIR/ws_$opts(ptrfNumber).$opts(jobid).sqlite3.db"
        #wsqlite create $opts(logSetup)
        #wsqlite insert $opts(logSetup) [array get opts]
        set tmpcfgarr(msg_mode) $msg_mode
        set tmpcfgarr(error) $error
        set tmpcfgarr(do) $opts(do)
        dbSaveDictionary config $opts(jobid) $opts(ptrfNumber) [array get tmpcfgarr ]
        return [array get opts]
    }

    # ----------------------------------------------------------------
    # dbJobRecord_sync -- Synchronous. Non MRS Calls
    # Description: Stores job to MySQL database.
    # Inputs:
    #    nameID { or PTRF Number }
    #    serviceName
    #    svcOperation
    #    logName (optional, automatically generated)
    #    jobid (optional, automatically generated)
    #
    # Sample Usage:
    #    set fnargs [list]
    #    lappend fnargs nameID "PTRF-12345-6789"
    #    lappend fnargs serviceName "wsSampleService"
    #    lappend fnargs svcOperation "cookSecretFormula"
    #    puts [$wsdb dbJobRecord_sync $fnargs ]
    #
    # Returns:
    #    Dictionary of added values.
    #    e.g.
    #     serviceName wsSampleService jobid 10000024 nameID PTRF-12345-6789 \
    #     rcvDate {2002/02/02 12:34:56} svcOperation cookSecretFormula error 0
    #
    # Error return:
    #
    # ----------------------------------------------------------------
    method dbJobRecord_sync { options args } {
        variable mydb
        variable environment
        variable msg_mode
        variable WORK_DIR
        set SQL_TABLE_MAIN TBL_WSM_SYNC_MAIN
        set SQL_TABLE_DICT TBL_WSM_SYNC_JOB_DATA
        set SQL_TABLE_RESP TBL_WSM_SYNC_RES_DATA
        set SQL_TABLE_VIEW TBL_WSM_SYNC_flat_view
        array set opts $options

        set updateOrRetry 0
        set rcvDate [getdate]
        set data ""

        if {$opts(do) == "dictsave_sync"} {
        	set reqstat "dictsave"
		} else {
        	set reqstat "pending"
	    }
        unset opts(logName)
        unset opts(logSetup)
        #reinforce
        set opts(webservice_mode) synchronous
        if { [info exists opts(messageID)] && [string length $opts(messageID)] == 0 } {
            unset opts(messageID)
        }
        #get wsdlURL
        if { [info exists opts(wsdlURL)] && [string length $opts(wsdlURL)] > 0 } {
            set wsdlURL $opts(wsdlURL)
        } else {
            set opts(wsdlURL) [lindex [getWSURL $opts(serviceName) $opts(svcOperation)] 0]
            set wsdlURL $opts(wsdlURL)
        }
        set colupdate ""
        set nameID [select_searchName_or_ptrfNumber $opts(nameID) $opts(ptrfNumber)]
        if { ([string length $opts(jobid)] > 0) && [regexp "^retry" $opts(do)] } {
            set reqstat "retry"
            set colupdate "REQ_STATUS='$reqstat', REQ_RCV_DATE='$rcvDate', SVC_RETRIES=SVC_RETRIES+1"
            set colupdate "$colupdate, NAME_ID='$nameID'"
            set updateOrRetry 1
        }
        while {1} {
            set COLUMNS "NAME_ID,WS_SVC_NAME,WS_OPERATION,REQ_STATUS,REQ_RCV_DATE"
            set VALUES  "'$nameID','$opts(serviceName)','$opts(svcOperation)','$reqstat','$rcvDate'"
            if { [llength $opts(jobid)] > 0 } {
                    append COLUMNS ",JOB_ID"
                    append VALUES  ",$opts(jobid)"
            }
            set sqli   "INSERT INTO $SQL_TABLE_MAIN ($COLUMNS) VALUES ($VALUES)"
            set cmd "$mydb Insert $sqli"
            if { $updateOrRetry == 1 } {
                append sqli "ON DUPLICATE KEY UPDATE $colupdate"
            } else {
                append sqli "; SELECT LAST_INSERT_ID()"
            }
            if {[ catch { set insertid [$mydb Insert $sqli] } error ] } {
                puts "[getdate] Error: \[dbJobRecord_sync\] $error"
                break;
            } else {
                if { $updateOrRetry == 1 } {
                    set COLUMNS2 "NAME_ID,WS_SVC_NAME,WS_OPERATION,REQ_STATUS,REQ_RCV_DATE,SVC_RETRIES"
                    set sqlb "SELECT $COLUMNS2 FROM $SQL_TABLE_MAIN WHERE JOB_ID=$opts(jobid)"
                    set dbl [$mydb Select $sqlb]
                    set opts(ptrfNumber)      [lindex [lindex $dbl 0 ] 0]
                    set opts(serviceName)     [lindex [lindex $dbl 0 ] 1]
                    set opts(svcOperation)    [lindex [lindex $dbl 0 ] 2]
                    set opts(status)          [lindex [lindex $dbl 0 ] 3]
                    set opts(origRecieveDate) [lindex [lindex $dbl 0 ] 4]
                    set opts(submitRetries)   [lindex [lindex $dbl 0 ] 5]
                } else {
                    set opts(jobid) $insertid
                }
                set job_host_user_info [list userhost "[info hostname]@$::tcl_platform(user)"]
                set sql4hostupdate  "UPDATE $SQL_TABLE_MAIN SET JOB_NFO=CONCAT(IF(LENGTH(`JOB_NFO`),`JOB_NFO`,''),'$job_host_user_info') "
                append sql4hostupdate "WHERE JOB_ID=$opts(jobid) AND ( JOB_NFO NOT LIKE '%userhost%' OR JOB_NFO IS NULL)"
                catch { $mydb Update $sql4hostupdate } error
                #puts "[getdate] JOB_ID==>$opts(jobid)"
                set error 0 ; break
            }
        }

	    if {[string equal "dictsave_sync" $opts(do)]} {
        	set sqli "INSERT INTO tbl_wsm_sync_update_actions (JOB_ID,ACTION,STATUS) VALUES ($opts(jobid),'cron_pickup_sync',1);"
        	$mydb Insert $sqli
        } elseif {[string equal "cron_pickup_sync" $opts(do)]} {
        	set sqld "DELETE FROM `tbl_wsm_sync_update_actions` WHERE (`JOB_ID`='$opts(jobid)') AND (`ACTION`='cron_pickup_sync') AND (`STATUS`='1')"
        	$mydb Exec $sqld
        	set opts(do) submit
        }

        set tmpcfgarr(msg_mode) $msg_mode
        set tmpcfgarr(do) $opts(do)
        set tmpcfgarr(sn) $nameID
        #save data
        if { [info exists opts(data)] } {
            if { [string length $opts(data)] > 0 } {
                set opts(dataDictSave) [dbSaveDictionary datadict_sync $opts(jobid) $nameID $opts(data)]
                dbSaveDictionary config_sync $opts(jobid) $nameID [array get tmpcfgarr ]
            } elseif { $updateOrRetry == 1 } {
                set opts(data) [dbRestoreDictionary $opts(jobid) $SQL_TABLE_DICT]
            } else  {
                puts "[getdate] Warning: Missing data to submit"
                set opts(dataDictSave) 0
            }
        }
        return [array get opts]
    }
    # ----------------------------------------------------------------
    # wsqlite
    # Store Variable/s in local file - sqlite db.
    # wsqlite
    # Description:
    #    (KEY,VALUE) Storage in sqlite3 db.
    #
    # Usage:
    # 1. Create/Update Storage [SQL CREATE OR UPDATE TBL ...]
    #   wsqlite create <db_filename>
    # 2. Insert/Update to Storage [SQL INSERT OR UPDATE KEY ...]
    #   wsqlite insert <db_filename> { KEY1 VALUE1 .. KEYn VALUEn }
    # 3. Get Stored Value [SQL SELECT KEY ...]
    #   wsqlite get <db_filename> KEY
    # 4. Retrieve all stored value [SQL SELECT * ...]
    #   wsqlite allvars <db_filename>
    # ----------------------------------------------------------------
    method wsqlite { action dbfile args } {
        set db $dbfile
        set options [join $args]
        set tbl VARDATA
        switch -- ${action} {
            create {
                catch { fdb_create $db $tbl } msg
                return $msg
            }
            insert {
                #puts [list $options]
                catch { fdb_save $db $tbl $options } msg
                return $msg
            }
            save_response {
                set msgs ""
                set tbl RESPONSE
                catch { fdb_create $db $tbl } msg
                lappend msgs $msg
                catch { fdb_save $db $tbl $options } msg
                lappend msgs $msg
                return $msgs
            }
            save_var {
                set msgs ""
                catch { fdb_create $db $tbl } msg
                lappend msgs $msg
                catch { fdb_save $db $tbl $options } msg
                lappend msgs $msg
                return $msgs
            }
            get {
                return [fdb_get $db $tbl $options]
            }
            allvars {
                return [fdb_getallvars $db $tbl]
            }
            allresponsevars {
                set tbl RESPONSE
                return [fdb_getallvars $db $tbl]
            }
            default {
                #good luck
                return 0
            }
        }
    }
    #sqlite initialize datastorage
    method fdb_create { db tbl } {
        set date [getdate]
        sqlite3 bs $db
        bs eval {PRAGMA foreign_keys = ON;}
        set sql1 "
            CREATE TABLE IF NOT EXISTS $tbl (
            fldVAR VARCHAR(150) UNIQUE,
            fldDATA TEXT
            );
            INSERT OR REPLACE INTO $tbl VALUES ('_CreateDate','$date');
        "
        set sql2 {
            CREATE TABLE IF NOT EXISTS tbl_runinfo (
            fldVAR VARCHAR(50) UNIQUE,
            fldDATA TEXT
            );
        }
        set User $::tcl_platform(user)
        set sql3 "
                INSERT OR REPLACE INTO tbl_runinfo VALUES ('_CreateDate','$date');
                INSERT OR REPLACE INTO tbl_runinfo VALUES ('_user','$User');
                INSERT OR REPLACE INTO tbl_runinfo VALUES ('_script','[file normalize [info script]]');
                INSERT OR REPLACE INTO tbl_runinfo VALUES ('_script_args','$::argv');
                INSERT OR REPLACE INTO tbl_runinfo VALUES ('_proc_id','[pid]');
            "
        bs eval $sql1
        bs eval $sql2
        bs eval $sql3
        bs close
    }
    #sqlite insert/update variable records into dbfile
    method fdb_save { db tbl optionvars } {
        array set opts $optionvars
        sqlite3 bs $db
        bs eval {PRAGMA foreign_keys  = ON;}
        foreach var [array names opts ] {
            set sql "INSERT OR REPLACE INTO $tbl VALUES ('$var','$opts($var)')"
            bs eval $sql
        }
        set sql "INSERT OR REPLACE INTO $tbl VALUES ('_lastUpdate','[getdate]')"
        bs eval $sql
        bs close
    }
    #sqlite retrive key,value from db
    method fdb_get { db tbl var } {
        sqlite3 bs $db
        bs eval {PRAGMA foreign_keys  = ON;}
        set sql "SELECT ${tbl}.fldDATA FROM $tbl WHERE ${tbl}.fldVAR = '$var'"
        set results [bs eval $sql]
        bs close
        return $results
    }
    #retrieve all stored key,value from db.
    method fdb_getallvars { db tbl } {
        sqlite3 bs $db
        bs eval {PRAGMA foreign_keys  = ON;}
        set sql "SELECT * FROM $tbl"
        set results [bs eval $sql]
        bs close
        return $results
    }
    # ----------------------------------------------------------------
    # -- WEB SERVICE CALL PROCEDURES                             -----
    # --                                                         -----
    # ----------------------------------------------------------------
    # ----------------------------------------------------
    # Description: web_service_main
    # ----------------------------------------------------
    method web_service_main { options } {
        variable verbose
        variable error_msg
        variable ws_call_response
        variable ws_get_parse
        variable ws_holiday_msgs
        array set opts ${options}

    	if { [webservice_holiday] } {
    		return $ws_holiday_msgs
        }

        if { [string length $opts(wsdlURL)] > 0 } {
            set url $opts(wsdlURL)
        } else {
            set opts(wsdlURL) [lindex [getWSURL $opts(serviceName) $opts(svcOperation)] 0]
            set url $opts(wsdlURL)
        }

        set dontWaitFeedback $opts(dontWaitFeedback)

        if { [string length $opts(headers)] > 0 } {
            set headers $opts(headers)
        } else {
            set headers ""
            array set headlist [lindex [getWSURL $opts(serviceName) $opts(svcOperation)] 1]
            if { [info exists headlist(userpass)] && [string length $headlist(userpass)] > 0 } {
                set headers [list Authorization "Basic [ ::base64::encode $headlist(userpass)]"]
            } elseif { [info exists headlist(encryptedHeader)] && [string length $headlist(encryptedHeader)] > 0 } {
                set headers $headlist(encryptedHeader)
            }
            array unset headlist
        }
        unset opts(headers)
        set serviceAlias ""
        #parse wsdl
        set cmd [ get_parse_wsdl $url $headers $serviceAlias ]
        if { $cmd } { return -code error "ERROR: $error_msg" }
        switch -- $opts(webservice_mode) {
            synchronous {
                set query [getSaveCallQuery \
                    $opts(serviceName) $opts(svcOperation) \
                    $opts(wsdlURL) $opts(data) "" screen]
                catch { saveXMLCallQuery2DB \
                    "SYNC:$opts(jobid)" [list query $query serviceName $opts(serviceName) svcOperation  $opts(svcOperation)] } error_msg
                set scmd [do_sync_call [array get opts]]
                set cmd [lindex $scmd 0 ]
                set ws_call_response [lindex $scmd 1 ]
            }
            async {

            	#
            	# Special Handling this two service since WS developer put another hierarchy for its data
                # Service CADMRSLayerSyncService_client_ep dependent Data
                #  --- Web service wraps data under : "mrsData"
                #
                if { [string match -nocase $opts(serviceName) "CADMRSLayerSyncService_client_ep"] } {
                    set dataMRS "messageID $opts(messageID) $opts(data)"
                    dict set opts(data) mrsData [ list $dataMRS ]
                    unset dataMRS

                #
                # Service MDPMRSSyncService_client_ep dependent Data
                #  --- Web service wraps data into : { msg Data }
                #
                } elseif { [string match -nocase $opts(serviceName) "MDPMRSSyncService_client_ep"] } {
                    set dataMDP "messageID $opts(messageID) $opts(data)"
                    set opts(data) [list msg $dataMDP]
                    unset dataMDP

                #
                # Otherwise we proceeed with no data wrapping:
                #
                } else {
                    set opts(data) "messageID $opts(messageID) $opts(data)"

                }

                #set query [getSaveCallQuery \
                #    $opts(serviceName) $opts(svcOperation) \
                #    $opts(wsdlURL) $opts(data) \
                #    $opts(logSetup) sqlite3]

                set query [getSaveCallQuery \
                    $opts(serviceName) $opts(svcOperation) \
                    $opts(wsdlURL) $opts(data) "" screen]
                catch { saveXMLCallQuery2DB \
                    "ASYNC:$opts(jobid)" [list query $query serviceName $opts(serviceName) svcOperation  $opts(svcOperation) ] } error_msg
                if {$dontWaitFeedback} {
                    set cmd [do_async_call_no_wait [array get opts]]
                } else {
                    set cmd [do_async_call [array get opts]]
                }
            }
            default {
                puts "webservice_manager: web_service_mode must be \"synchronous\" or \"async\""
                return -error "ERROR Invalid web_service_mode. Aborted"
            }
        }
        if { $cmd } { return [list status 2 error $error_msg] }
        if { $verbose } {
            puts $ws_get_parse
            puts $ws_call_response
            puts $error_msg
        }

        #Do not delete this puts below. This is needed for remote invocation stdout message capture
        #puts $ws_call_response
        return $ws_call_response
    }
    # ----------------------------------------------------
    # Description: dump Query XML FILE transmitted from dictionary.
    # ----------------------------------------------------
    method getSaveCallQuery {serviceName operation wsdl data outfile type} {
        variable WORK_DIR
        set query [::WS::Client::buildDocLiteralCallquery \
            $serviceName $operation $wsdl $data ]
        set query_size [string length $query]
        set msg ""
        if { [string match -nocase $outfile ""] } {
            set type screen
        }
        switch -- $type {
            xml {
                set xmlfile [open $outfile w]
                puts $xmlfile $query
                close $xmlfile
            }
            sqlite3 {
                catch { wsqlite insert $outfile [list "ws_call_query" $query ] } msg
            }
            screen {
                return "$query"
            }
            default {
                catch { wsqlite insert $outfile [list "ws_call_query" $query ] } msg
            }
        }
        return "$query_size $msg"
    }

    method saveXMLCallQuery2DB { messageID options} {
        variable mydb
        set TABLE TBL_XML_QUERY
        set FIELDS "WS_MSG_ID,WS_SVC_NAME,WS_OPERATION,XML_QUERY"
        array set opts $options
        set query [safe_sql_value $opts(query)]
        set VALUES "'$messageID', '$opts(serviceName)', '$opts(svcOperation)'"
        append VALUES ",'$query'"
        set sqli "INSERT INTO $TABLE ($FIELDS) VALUES ($VALUES)"
        set sqli "$sqli ON DUPLICATE KEY UPDATE XML_QUERY='$query'"
        if {[ catch { $mydb Insert $sqli } msg ] } {
            puts "[getdate] Error: $msg"
            return 1
        } else {
            return 0
        }
    }

    method getXMLSavedQuery {messageID} {
        variable mydb
        set TABLE TBL_XML_QUERY
        set FIELDS "WS_MSG_ID,WS_SVC_NAME,WS_OPERATION,XML_QUERY"
        set FILTER "WS_MSG_ID='$messageID'"
        set sql "SELECT XML_QUERY FROM $TABLE WHERE $FILTER LIMIT 1"
        catch { $mydb Select $sql } msg
        return $msg
    }
    # ----------------------------------------------------
    # Description: WRAPPER TO Invoke Retry WS::Client::GetAndParseWsdl
    # ----------------------------------------------------
    method get_parse_wsdl { url headers serviceAlias } {
        variable test_mode ; # Retry interval is every second when test is 1, else 60s->120s.
        variable ws_get_parse
        variable error_msg
        set tmp 0
        set msg ""
        if { [catch {set ws_get_parse [WS::Client::GetAndParseWsdl $url $headers $serviceAlias]} msg]} {
            #puts "ERROR: [getdate] Failed to Connect/Parse $url : $msg"
            lappend error_msg "\[GetAndParseWsdl\] $msg"
            return 1
        }

        #if { [catch {set ws_get_parse [WS::Client::GetAndParseWsdl $url $headers $serviceAlias]} msg]} {
        #    #couldn't open socket: host is unreachable (Name or service not known)
        #    puts "[getdate] WARNING: Failed to Connect/Parse (1) $url : $msg"
        #    sleep [ expr { ($test_mode == 0) ? 30 : 1 } ]
        #    if {[catch {set ws_get_parse [WS::Client::GetAndParseWsdl $url $headers $serviceAlias]} msg]} {
        #        puts "[getdate] WARNING: Failed to Connect/Parse (2) $url : $msg"
        #        sleep [ expr { ($test_mode == 0) ? 60 : 1 } ]
        #        if { [catch {set ws_get_parse [WS::Client::GetAndParseWsdl $url $headers $serviceAlias]} msg]} {
        #            puts "[getdate] ERROR: Failed to Connect/Parse (3) $url : $msg"
        #            puts "[getdate] ERROR: \[GetAndParseWsdl\] Aborted..."
        #            lappend error_msg "\[GetAndParseWsdl\] $msg"
        #            return 1
        #        }
        #    }
        #}
        return 0
    }
    # ----------------------------------------------------
    # Description: WRAPPER FOR synchronous Method Invocation (DoCall)
    # ----------------------------------------------------
    # Arguments :
    #      serviceName     - The name of the Webservice
    #      svcOperation   - The name of the Operation to call
    #      data         - Dictionary
    #      headers         - Extra headers to add to the HTTP request.
    # Returns : Nothing.
    # Side-Effects : None
    # Exception Conditions :
    #      WSCLIENT HTTPERROR      - if an HTTP error occured
    #      others                  - as raised by called Operation
    method do_sync_call { options } {
        variable error_msg
        variable ws_call_response
        array set opts ${options}
        after 100 set state timeout
        set response 0
        set msg 0
        set serviceName  $opts(serviceName)
        set svcOperation $opts(svcOperation)
        set data $opts(data)
        set call_status 0
        set job_status pending

        if { [ catch { WS::Client::DoCall $serviceName $svcOperation $data } msg ] } {
            puts stdout "[getdate] Error: WSCALL==>$msg"
            lappend error_msg "\[Web Service Call\] $msg"
            set call_status 1
            set job_status ERROR:CAD
            set response_msg "$msg"
        } else {
            set call_status 0
            set response_msg "$msg"
            set job_status DONE
        }

        set wsmgr_helper::ws_call_response $msg
        set ws_call_response $msg

        set slist [list \
                   JOB_ID "$opts(jobid)" \
                   REQ_STATUS "$job_status" \
                   RESPONSE "$response_msg"]
        if {[catch { updateJobStatus "SYNC:$opts(jobid)" $job_status $response_msg "" } msg2]} {
            puts $msg2
        }
        if {[catch { wsResponseSaveData_synchronous $slist } msg3]} {
            puts $msg3
        }
        return [list $call_status $msg]

        ## Using Async Call instead of DoCall so we can have timeout.
        #if { [ catch { \
        #    set resp [ WS::Client::DoAsyncCall $serviceName $svcOperation $data \
        #       [list wsmgr_helper::success [after 10000 set wsmgr_helper::waitvar 1] ]\
        #       [list wsmgr_helper::hadError [after 10000 set wsmgr_helper::waitvar 9999]]] } msg ] } {
        #    puts stdout "[getdate] Error: WSCALL==>$msg"
        #    lappend error_msg "\[Web Service Call\] $msg"
        #    set call_status 1
        #    set job_status ERROR:CAD
        #} else {
        #    set call_status 0
        #    set job_status DONE
        #}

        ##Terminating Call
        #vwait wsmgr_helper::wait_var

        #if { [info exists wsmgr_helper::ws_call_response] } {
        #	set response_msg "$wsmgr_helper::ws_call_response"
        #    set job_status DONE
		#} else {
        #	set response_msg "CAD Aborted - No Response Recieved"
        #    set job_status ERROR:CAD
	    #}

        #set slist [list \
        #           JOB_ID "$opts(jobid)" \
        #           REQ_STATUS "$job_status" \
        #           RESPONSE "$response_msg"]
        #if {[catch { updateJobStatus "SYNC:$opts(jobid)" $job_status $response_msg "" } msg2]} {
        #    puts $msg2
        #}
        #if {[catch { wsResponseSaveData_synchronous $slist } msg3]} {
        #    puts $msg3
        #}
        #return $call_status
    }

    # ----------------------------------------------------
    # Description: WRAPPER FOR Asynchronous Method Invocation (DoAsyncCall)
    # ----------------------------------------------------
    #Arguments :
    #     serviceName     - The name of the Webservice
    #     svcOperation   - The name of the Operation to call
    #     data         - Dictionary
    #     succesCmd       - Return operation when successfull
    #     errorCmd        - Return operation when Error
    #     headers         - Extra headers to add to the HTTP request.
    #Returns : Nothing.
    #Side-Effects : None
    #Exception Conditions :
    #     WSCLIENT HTTPERROR      - if an HTTP error occured
    #     others                  - as raised by called Operation
    method do_async_call { options } {
        variable messageID
        variable error_msg
        array set opts ${options}
        set response 0
        set msg 0
        set serviceName  $opts(serviceName)
        set svcOperation $opts(svcOperation)
        set data $opts(data)
        if {[info exists opts(messageID)] && [string length $opts(messageID)]>2 } {
            set messageID $opts(messageID)
        } else {
            set messageID 0
        }
        set wsmgr_helper::wait_var 0
        catch { updateJobStatus $opts(jobid) "wait4reply" $msg "" } umsg
        catch { updateMessageIDStatus $messageID "wait4reply" $msg } imsg
        if { [ catch { \
            WS::Client::DoAsyncCall $opts(serviceName) $opts(svcOperation) $data \
               [list wsmgr_helper::success [after 10000 set wsmgr_helper::wait_var 1]]\
               [list wsmgr_helper::hadError [after 10000 set wsmgr_helper::wait_var 2]] } msg ] } {
            puts stdout "[getdate] Error: $messageID,doAsyncCall==>$msg"
            lappend error_msg "\[DoAsyncCall\] $msg"
            catch { updateJobStatus $opts(jobid) "ERROR:CAD" $msg "" }
            return 1
        }
        #Terminating Call
        vwait wsmgr_helper::wait_var
        return 0
    }
    method do_async_call_no_wait { options } {
        variable error_msg
        array set opts ${options}
        set response 0
        set msg 0
        set serviceName  $opts(serviceName)
        set svcOperation $opts(svcOperation)
        set data $opts(data)
        variable messageID
        if {[info exists opts(messageID)]} {
            set messageID $opts(messageID)
        } else {
            set messageID 0
        }
        #Were not expecting return unless it does not hit WSDL
        #No Success or failed response are exepected via this channel
        # except for failed connection syntax/data format compliance
        # Responses will be collected via wsdl response. Monitor separately
        #puts "[getdate] Info: WebService Submit $serviceName $svcOperation $opts(messageID)"
        catch { updateJobStatus $opts(jobid) "wait4reply" $msg "" } umsg
        catch { updateMessageIDStatus $messageID "wait4reply" $msg } imsg
        if { [ catch { \
            WS::Client::DoAsyncCall $opts(serviceName) $opts(svcOperation) $data \
               [list wsmgr_helper::success [after 3000 set wsmgr_helper::wait_var 1]]\
               [list wsmgr_helper::hadError [after 3000 set wsmgr_helper::wait_var 2]] } msg ] } {
            puts stdout "[getdate] Error: MSGID==>$messageID|doAsyncCall==>$msg"
            lappend error_msg "\[DoAsyncCall\] $msg"
            catch { updateJobStatus $opts(jobid) "ERROR:CAD" $msg "" }
            return 1
        }
        #Terminating Call
        after 3000 { set wsgmr_helper::wait_var 1 }
        vwait wsmgr_helper::wait_var
        return 0
    }

    # ----------------------------------------------------
    # Remote Web Service Call --
    # ----------------------------------------------------
    method remote2dontdie_wscall { method jobid options } {
        variable environment
        variable BASE_DIR
        variable WORK_DIR
        variable ARCHIVES
        variable messageID_suffix
        variable msg_mode
        variable error_msg
    	variable ws_holiday_msgs

    	if { [webservice_holiday] } {
    		return $ws_holiday_msgs
        }

        array set fnargs ${options}
        set objname "cadwsDDIEobj"
        set remote_host "dontdie.fab3.tapeout.cso"
        set current_user $::tcl_platform(user)
        set dtimestr [clock format [clock seconds] -format {%m%d%H%M}]
        set port_proc [list]
        set remote_port 8014
        set remote_proc callProc
        set rmode tst
        if { [string match -nocase $environment "production"] } {
            set remote_port 9018
            set rmode prd

        }

        if { [info exists fnargs(webservice_mode)] && [info exists fnargs(nameID)] } {
        	set webservice_mode $fnargs(webservice_mode)
            set outfile "$jobid.[string range $fnargs(serviceName) 0 6].$fnargs(svcOperation).$fnargs(nameID).tcl"
            set rtype s
        } else {
            set outfile "$jobid.[string range $fnargs(serviceName) 0 6].$fnargs(svcOperation).[wsmgr_helper::randomRangeString 3].tcl"
            set rtype a
        }
        #LOAD BALANCING : GET REMOTE SUBMITTER NEW PORT AND PROCS
        if { [catch { set port_proc [::comm::comm send "$remote_port $remote_host" port_allocator $rmode $rtype ] } msg ] } {
            puts "[getdate] \[remote2dontdie_wscall\] Error: Unable to reach remote_submitter $port_proc $msg"
        } else {
        	set remote_port [lindex $port_proc 0 ]
        	set remote_proc [lindex $port_proc 1 ]
        }

        #append objname cadwsDDIEobj [clock format [clock seconds] -format {%d%H%M}]
        set setup [ list \
                OBJ $objname \
                environment $environment \
                msg_mode $msg_mode \
                ConfigFile /csm/config/wsmgr/config.xml \
                method $method \
                outfile $outfile \
                ]

        #puts "# WSCALL via $remote_host : $fnargs(svcOperation)"

		# GENERIC
        if { [info exists fnargs(dontWaitFeedback)] } {

        	if { $fnargs(dontWaitFeedback) } {
                if { [catch { \
                      set result [::comm::comm send "$remote_port $remote_host" \
                        $remote_proc "wsmgr_rsub::submit_service" $::tcl_platform(user) [info hostname] [list $setup] [list $options] ] \
                      } msg ] } {
                    puts "[getdate] \[remote2dontdie_wscall\] Warning: $msg"
                } else {
                    #puts "[getdate] \[remote2dontdie_wscall\] Info: $msg"
                }
			} else {
        	# Synchronous DONTDIE CONNECTION: Results will be feedback
                if { [catch { \
                      set result [::comm::comm send "$remote_port $remote_host" \
                        $remote_proc "wsmgr_rsub::submit_service" $::tcl_platform(user) [info hostname] [list $setup] [list $options] ] \
                      } msg ] } {
                    puts "[getdate] \[remote2dontdie_wscall\] Warning: $msg"
                } else {
                    #puts "[getdate] \[remote2dontdie_wscall\] Info: $msg"
                }
		    }

		# MRS MRS CALL
		} else {
        	# Synchronous DONTDIE CONNECTION: Results will be feedback
            if { [catch { \
                  set result [::comm::comm send "$remote_port $remote_host" \
                    $remote_proc "wsmgr_rsub::submit_service" $::tcl_platform(user) [info hostname] [list $setup] [list $options] ] \
                  } msg ] } {
                puts "[getdate] \[remote2dontdie_wscall\] Warning: $msg"
            } else {
                #puts "[getdate] \[remote2dontdie_wscall\] Info: $msg"
            }
	    }
        return $msg
    }

    # ----------------------------------------------------
    # Description: Halt Service
    # ----------------------------------------------------
    method webservice_holiday {} {
    	variable mydb
    	variable ws_holiday_msgs
    	set TABLE tbl_service_start_stop
    	set FILTER "active=1 AND (CURRENT_TIMESTAMP() BETWEEN start AND stop)"
    	set sql "SELECT stop,start,comment FROM tbl_service_start_stop WHERE $FILTER"
        set query [$mydb Select $sql]
        set ws_holiday_msgs
        if { [llength $query]>=1 } {
        	foreach "line" $query {
        		foreach "start stop note" $line  {
        			append ws_holiday_msgs "INFO: DUE TO $note , WEBSERVICE MANAGER WILL NOT BE SUBMITTING CALLS FROM '$start' until '$stop'"
        			puts "INFO: DUE TO $note , WEBSERVICE MANAGER WILL NOT BE SUBMITTING CALLS FROM '$start' until '$stop'"
        		}
			}
        	puts "# ------------------------------------------------------"
			return 1
		} else {
			set ws_holiday_msgs ""
			return 0
		}
    }
    # ----------------------------------------------------
    # Description: Cleanup
    # ----------------------------------------------------
    method cleanupVars {} {
        variable environment
        variable BASE_DIR
        variable WORK_DIR
        variable ARCHIVES
        variable test_mode
        variable msg_mode
        variable verbose
        variable error_msg
        variable messageID
        variable jobid
        variable ws_call_response
        variable ws_get_parse
        variable messageID_suffix ""
        set environment ""
        set BASE_DIR ""
        set WORK_DIR ""
        set ARCHIVES ""
        set test_mode 0
        set msg_mode 0
        set verbose 0
        set error_msg  ""
        set messageID  ""
        set messageID_suffix ""
        set jobid  ""
        set ws_call_response [list]
        set ws_get_parse  ""
        set hosts  ""
        set mydb  ""
        set config_load_once  ""
    }

    #Helpers
    method get_BASE_DIR { args } {
        variable BASE_DIR
        return $BASE_DIR
    }
    method get_WORK_DIR { args } {
        variable WORK_DIR
        return $WORK_DIR
    }
    method get_test_mode { args } {
        variable test_mode
        return $test_mode
    }
    method set_test_mode { bool } {
        variable test_mode $bool
        return $test_mode
    }
    method get_msg_mode { args } {
        variable msg_mode
        return $msg_mode
    }
    method set_msg_mode { bool } {
        variable msg_mode $bool
        return $msg_mode
    }
    method get_holiday_msgs { args } {
        variable ws_holiday_msgs
        return $ws_holiday_msgs
    }
    method get_messageID_suffix { args } {
        variable messageID_suffix
        return $messageID_suffix
    }
    method set_messageID_suffix { str } {
        variable messageID_suffix $str
        return $messageID_suffix
    }
    method set_ws_call_response { args } {
        variable ws_call_response $args
        return $ws_call_response
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
        variable mydb
        return [$mydb escape_value $value]
    }

    method mrs_sql { op sql} {
    	variable mydb
    	return [$mydb $op $sql]
    }

    method select_searchName_or_ptrfNumber { nameID ptrfNumber } {
        regsub -all {\s+} $nameID {,} nameID
        regsub -all {\s+} $ptrfNumber {,} ptrfNumber
        if {![string match -nocase $nameID "NAN"] && [string length $nameID]>1 } {
            return $nameID
        } elseif {![string match -nocase $ptrfNumber "NAN"] && [string length $ptrfNumber]>1 } {
            return $ptrfNumber
        } else {
            return NAN
        }
    }

    method write_xml2file { jobid outfile} {
    	variable mydb
    	set sql "SELECT XML_QUERY FROM TBL_XML_QUERY WHERE WS_MSG_ID LIKE '%:$jobid'"
    	set result [$mydb Select $sql]
    	set xmlfh [open $outfile w ]
    	puts $xmlfh $result
    	close $xmlfh
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

#END OF CLASS cadws
}
