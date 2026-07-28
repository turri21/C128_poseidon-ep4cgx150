#!/usr/bin/tclsh

# Build ID generator for MiST cores
# Creates a unique build ID based on date and time

set outputFileName "build_id.v"
set outputFile [open $outputFileName "w"]

set buildDate [clock format [clock seconds] -format %y%m%d]
set buildTime [clock format [clock seconds] -format %H%M%S]

puts $outputFile "`define BUILD_DATE \"$buildDate\""
puts $outputFile "`define BUILD_VERSION \"1.0\""

close $outputFile
