# 
# Note: Public API for mysql connection helper,
# Cris Magalang - modified 2014
#

package provide MySqlDb 1.0

itcl::class MySqlDb {
    
    public variable user      "" 
    public variable password  "" 
    public variable server    "" 
    public variable db_name   "" 
    public variable port      "" 
    public variable table_list [list]
    public variable view_list  [list]

    variable db             ""
    variable rows_found     "0"
    
    constructor {_name _dbopts } {    
        set name $_name
        set dbargs $_dbopts
        dbset $dbargs
    }
    
    private method dbset { dbargs } {
        array set opts ${dbargs}
        # get user
        if { [info exists opts(user)] } {
            if { [expr {[string length ${opts(user)}] > 0}] } {
                uplevel 1 variable user ${opts(user)}
            }
        }
        # get password
        if { [info exists opts(pass)] } {
            if { [expr {[string length ${opts(pass)}] > 0}] } {
                uplevel 1 variable password ${opts(pass)}
            }
        }
        # get server
        if { [info exists opts(host)] } {
            if { [expr {[string length ${opts(host)}] > 0}] } {
                uplevel 1 variable server ${opts(host)}
            }
        }
        # get db_name
        if { [info exists opts(db)] } {
            if { [expr {[string length ${opts(db)}] > 0}] } {
                uplevel 1 variable db_name ${opts(db)}
            }
        }
        # get port
        if { [info exists opts(port)] } {
            if { [expr {[string length ${opts(port)}] > 0}] } {
                uplevel 1 variable port ${opts(port)}
            }
        }
    }

    private method Connect { } {
        if {[catch {set db [mysql::connect -host $server -user $user -password $password -port $port -db $db_name -encoding utf-8 -multistatement 1]} msg]} {
            puts "Warning: Trying to reconnect to the database... "
            after 6000
            if {[catch {set db [mysql::connect -host $server -user $user -password $password -port $port -db $db_name -encoding utf-8 -multistatement 1]} msg]} {
                puts "Warning: Trying to reconnect to the database... "
                after 12000
                if {[catch {set db [mysql::connect -host $server -user $user -password $password -port $port -db $db_name -encoding utf-8 -multistatement 1]} msg]} {
                    puts "Warning: Trying to reconnect to the database... "
                    after 18000
                    if {[catch {set db [mysql::connect -host $server -user $user -password $password -port $port -db $db_name -encoding utf-8 -multistatement 1]} msg]} {
                        puts stderr "Error: Tried 3 time but still unable to connect to MySQL Server\n $msg"
                    }
                }
            }
        }
    }
    
    private method Disconnect { } {
    	set closedb ""
        if {[catch {set closedb [mysql::close $db]} msg]} {
            puts "Warning: Closing DB Connection Failed... Retrying after 1000ms. Error($msg)"
            after 1000
            if {[catch {set closedb [mysql::close $db]} msg]} {
                puts "Warning: Closing DB Connection Failed... Retrying after 0.5 mins. Error($msg)"
                after 30000
                if {[catch {set closedb [mysql::close $db]} msg]} {
                    puts "Warning: Closing DB Connection Failed... Retrying after 1 mins. Error($msg)"
                    after 60000
                    if {[catch {set db [mysql::close $db]} msg]} {
                        puts stderr "Error: Failed to close connection to MySQL Server\n $msg"
                    }
                }
            }
        }
    }

    method Connect_noDC { } {
    	Connect
    }

    method DisconnectCN { } {
    	Disconnect
    }
    
    method SelfTest {} {
        if { [catch { set db [mysql::connect -host $server -user $user -password $password -port $port -db $db_name -encoding utf-8 -multistatement 1]} msg ] } {
            return "$msg"
        } else {
            Disconnect
            return "Info: DB Connect OK"
        }
    }
    method GetStatus {} {
        return [mysql::state $db]
    }
    
    method Select { sql {list_style -list} } {
        #puts "$sql"
        Connect
        set result [mysql::sel $db $sql $list_style]
        Disconnect
        return $result
    }

    method Select_noDC { sql {list_style -list} } {
        set result [mysql::sel $db $sql $list_style]
        return $result
    }
    
    method SelectAndCount { sql {list_style -list} } {
        #puts "$sql"
        Connect
        set explain [mysql::sel $db [concat EXPLAIN EXTENDED $sql] -list]
        set explain_extended [mysql::sel $db "SHOW WARNINGS" -list] 
        append msg "Query optimization details.\n" [join $explain \n] "\n--\n" [join $explain_extended \n]
        puts $msg
        set result      [mysql::sel $db $sql $list_style]
        mysql::sel $db "SELECT FOUND_ROWS() as mycount"
        set rows_found  [mysql::fetch $db]
        Disconnect
        return $result
    }

    method escape_value { value } {
        return [mysql::escape $value]
    }

    method Insert { sql } {
        Connect
        mysql::exec $db $sql
        set result [mysql::insertid $db]
        Disconnect
        return $result
    }

    method Insert_noDC { sql } {
        mysql::exec $db $sql
        set result [mysql::insertid $db]
        return $result
    }
    
    
    method BulkInsert { sql } {
        Connect
        set result_count [mysql::exec $db $sql]
        puts "Bulk Added to Database >> $result_count row(s)"
        set result [mysql::insertid $db]
        set result [expr $result + $result_count - 1]
        Disconnect
        return $result
    }
    
    method Update { sql } {
        Connect
        set result [mysql::exec $db $sql]
        Disconnect
        return $result
    }

    method Update_noDC { sql } {
        set result [mysql::exec $db $sql]
        return $result
    }
    
    method CreateTable { sql } {
        Connect
        set result [mysql::exec $db $sql]
        Disconnect
        return $result
    }

    method CreateTempTable_noDC { sql } {
        set result [mysql::exec $db $sql]
        return $result
    }
    
    method AlterTable { sql } {
        Connect
        set result [mysql::exec $db $sql]
        Disconnect
        return $result
    }
        
    method Exec { sql } {
        Connect
        set result [mysql::exec $db $sql]
        Disconnect
        return $result
    }

    method Exec_noDC { sql } {
        set result [mysql::exec $db $sql]
        return $result
    }
    
   
    method Escape { str } {
        set result [mysql::escape $str]
        return $result
    }
    
    method GetRowsFound {} {
        return $rows_found
    }
    
    method GetInfo { option } {
        # Make sure the specified option is valid, throw error if not
        set valid_options [list info databases dbname host tables serverversion serverversionid sqlstate state]
        if {[lsearch -exact $valid_options $option] == -1} {
            puts stderr "Error: Invalid option '$option' in call to MySqlDb::GetInfo"
        } 
        
        Connect
        set result [mysql::info $db $option]
        Disconnect
        return $result
    }
    
    method GetColInfo { table option } {
        # Make sure the specified option is valid, throw error if not
        set valid_options [list name type length non_null prim_key numeric decimals]
        if {[lsearch -exact $valid_options $option] == -1} {
            puts stderr "Error: Invalid option '$option' in call to MySqlDb::GetColInfo"
        } 
        
        Connect
        set result [mysql::col $db $table $option]
        Disconnect
        return $result
    }
    
    method GetTable { class {options [list]}} {
        foreach table $table_list {
            if {[namespace tail $class] == [$table cget -class]} {
                $table SetDb $this
                return $table
            }
        }
        return [list]
    }
    
    method GetView { class } {
        foreach view $view_list {
            if {[namespace tail $class] == [$view cget -class]} {
                $view SetDb $this
                return $view
            }
        }
        return [list]
    }
    
    method GetTableName { class } {
        foreach table $table_list {
            if {[namespace tail $class] == [$table cget -class]} {
                return [$table cget -name]
            }
        }
        return [list]
    }
    
    method DropTable { name } {
        puts "Will be removing tables from the database.... "
        foreach table $table_list {
            if  {[$table cget -name] == $name } { 
                puts "Removed $name from DB"
                $table SetDb $this
                $table DropAllTable
            }
        }
        puts "Done."
    }
    
    method DropAllTables {} {
        puts "Will be removing tables from the database.... "
        foreach table $table_list {
            $table SetDb $this
            $table DropAllTable
        }
        puts "Done."
    }
    
    method CreateAllTables {} {
        puts "Creating new tables in the database... "
        foreach table $table_list {
            $table SetDb $this
            $table CreateAllTable
        }
        puts "Done."
    }
    
    method GetAllObjects { } {
        set result [list]
        foreach table $table_list {
            set result [concat $result [$table GetAllObjects]]
        }
        return $result
    }
    
    method GetAllSubTableObjects { } {
        set result [list]
        foreach table $table_list {
            set result [concat $result [$table GetAllSubTableObjects]]
        }
        return $result
    }
       
    method Validate { } {
        foreach table $table_list {
            $table SetDb $this
        }
    }
    
    method UpdateTableSchema {} {
        puts "Will check the table schema to see if any updates are needed"
        foreach table $table_list {
            $table SetDb $this
            if {[$table CheckTableExists]} {
                $table UpdateAllTableSchema
            } else {
                $table CreateAllTable
            }
        }
        puts "Finish updating table schema... "
    }
    
}
