quietly set BreakOnAssertion 2
quietly onfinish final

quietly lassign [context du] workpath tbname

set broken 0
onbreak {
  lassign [runStatus -full] status fullstat morestat
  if {$status eq "error"} {
    # Unexpected error, report info and force an error exit
    echo "Error: $fullstat"
    set broken 1
    resume
  } elseif {$status eq "break"} {
    if {[string match "user_*" $fullstat]} {
      pause
    } else {
      # if {$fullstat ne {step_builtin}} {
      #   cont
      # } else {
      #   resume
      # }
      resume
    }
  } else {
    resume
  }
}

run -all

coverage save -testname "$tbname" "coveragedbs/$tbname.ucdb"

if {$broken == 1} {
  # Unexpected condition.  Exit with bad status.
  echo "failure"
  quit -f -code 3
}

if { [coverage attribute -name TESTSTATUS -concise] != 0} {
  echo "TESTSTATUS nonzero; errors!"
  quit -f -code 1
}

quit -f