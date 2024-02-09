#!/bin/sh
#
# *** /APP1/Tcl/Linux-x86_64/ActiveTcl8.5.17.0/bin/base-tcl8.5-thread-linux-x86_64 ***
#
# the next line restarts using tclsh \
exec /APP1/Tcl/`uname -s`-`uname -m | sed 's/\/.*//'`/ActiveTcl8.6.4.0/bin/base-tk8.6-thread-linux-x86_64 "$0" "$@"
package require starkit
starkit::startup
package require app-main