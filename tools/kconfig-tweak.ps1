#!/usr/bin/env pswd
############################################################################
#
# SPDX-License-Identifier: Apache-2.0
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.  The
# ASF licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.
#
############################################################################

# Manipulate options in a .config file from the command line

$myname=$($MyInvocation.MyCommand.Name)

function usage {
  Write-Host ""
  Write-Host "Manipulate options in a .config file from the command line." -ForegroundColor Cyan
  Write-Host "Usage:"
  Write-Host "$myname options command ..." -ForegroundColor Yellow
  Write-Host "commands:"
  Write-Host "    --enable|-e option   Enable option"
  Write-Host "    --disable|-d option  Disable option"
  Write-Host "    --module|-m option   Turn option into a module"
  Write-Host "    --set-str option string"
  Write-Host "                         Set option to "string""
  Write-Host "    --set-val option value"
  Write-Host "                         Set option to value"
  Write-Host "    --undefine|-u option Undefine option"
  Write-Host "    --state|-s option    Print state of option (n,y,m,undef)"
  Write-Host ""
  Write-Host "    --enable-after|-E beforeopt option"
  Write-Host "                         Enable option directly after other option"
  Write-Host "    --disable-after|-D beforeopt option"
  Write-Host "                         Disable option directly after other option"
  Write-Host "    --module-after|-M beforeopt option"
  Write-Host "                         Turn option into module directly after other option"
  Write-Host ""
  Write-Host "commands can be repeated multiple times"
  Write-Host ""
  Write-Host "options:"
  Write-Host "    --file config-file   .config file to change (default .config)"
  Write-Host "    --keep-case|-k       Keep next symbols' case (dont' upper-case it)"
  Write-Host ""
  Write-Host "$myname doesn't check the validity of the .config file. This is done at next"
  Write-Host "make time."
  Write-Host ""
  Write-Host "By default, $myname will upper-case the given symbol. Use --keep-case to keep"
  Write-Host "the case of all following symbols unchanged."
  Write-Host ""
  Write-Host "$myname uses 'CONFIG_' as the default symbol prefix. Set the environment"
  Write-Host "variable CONFIG_ to the prefix to use. Eg.: CONFIG_="FOO_" $myname ..."

  exit 1
}

function status_var {
  param (
         [string]$name
  )
  Write-Debug " status_var: name= $name"

  $tmpcontent = Get-Content "$FN"
  
  $pattern_no="^# $name is not set"
  $pattern_val="^$name=.*"
  
  $findval_no = $tmpcontent | Select-String $pattern_no -AllMatches
  $findval_val = $tmpcontent | Select-String $pattern_val -AllMatches
  
  if ($findval_no) {
      Write-Host "Status: $findval_no" -ForegroundColor Yellow
   } elseif ($findval_val) {
      Write-Host "Status: $findval_val" -ForegroundColor Yellow
   } else {
      Write-Host "Status: undef" -ForegroundColor Yellow
   }
 
}

function txt_append {
  param (
        [string]$anchor,
        [string]$insert,
        [string]$infile,
        [string]$tmpfile = "$infile.swp"
    )
  Write-Debug "txt_append: anchor= $anchor insert= $insert infile= $infile tmpfile= $tmpfile"
  $tmpcontent = Get-Content -Raw "$infile"
  $tmpcontent = $tmpcontent -replace "$anchor" , "$anchor`n$insert"

  Set-Content -NoNewLine -Path "$tmpfile" -Value "$tmpcontent"
  # replace original file with the edited one
  Move-Item -Path "$tmpfile" -Destination "$infile" -Force -ErrorAction Stop
}

function txt_subst {
  param (
        [string]$before,
        [string]$after,
        [string]$infile,
        [string]$tmpfile = "$infile.swp"
    )
  Write-Debug "txt_subst:  before= $before after= $after infile= $infile tmpfile= $tmpfile"

  $tmpcontent = Get-Content -Raw "$infile"
  $tmpcontent = $tmpcontent -replace "$before" , "$after"

  Set-Content -NoNewLine -Path "$tmpfile" -Value "$tmpcontent"
  # replace original file with the edited one
  Move-Item -Path "$tmpfile" -Destination "$infile" -Force -ErrorAction Stop
}

function txt_delete {
  param (
        [string]$text,
        [string]$infile,
        [string]$tmpfile = "$infile.swp"
    )
  Write-Debug "txt_delete:  text= $text infile= $infile tmpfile= $tmpfile"

  $tmpcontent = Get-Content -Raw "$infile"
  $tmpcontent = $tmpcontent -replace "$text" , ""

  Set-Content -NoNewLine -Path "$tmpfile" -Value "$tmpcontent"
  # replace original file with the edited one
  Move-Item -Path "$tmpfile" -Destination "$infile" -Force -ErrorAction Stop
}

function set_var {
   param (
        [string]$name,
        [string]$new,
        [string]$before
    )

  Write-Debug "set_var:  name= $name new= $new before= $before"

  $name_re="^($name=|# $name is not set)"
  $before_re="^($before=|# $before is not set)"

  # Check if the .config file exists
  if (-Not (Test-Path "$FN")) {
      Write-Host "Error: .config file not found at $FN" -ForegroundColor Red
      exit 1
  }

  $content = Get-Content "$FN"
   Write-Debug "Find val ..."

  if (($before) -and ($content | Select-String $before_re -AllMatches)){
      Write-Debug "set_var:  before= $before"
      $before = $content | Select-String $before_re -AllMatches
      Write-Debug "set_var:  before = $before"
      txt_append "$before" "$new" "$FN"
      txt_append "# $before is not set" "$new" "$FN"
  } elseif ($content | Select-String $name_re -AllMatches) {
      $listfull= $content | Select-String $name_re -AllMatches
      Write-Debug "set_var:  listfull = $listfull"
      txt_subst "$name=.*" "$new" "$FN"
      txt_subst "# $name is not set" "$new" "$FN"
  } else {
      Add-Content -Path "$FN" -Value "$new"
  }
}

function undef_var {
  param (
        [string]$name
    )
  Write-Debug " undef_var  name= $name"

  # Check if the .config file exists
  if (-Not (Test-Path "$FN")) {
      Write-Host "Error: .config file not found at $FN" -ForegroundColor Red
      exit 1
  }

  txt_delete "$name=.*" "$FN"
  txt_delete "# $name is not set" "$FN"
}

if (!$args[0]) {
   usage
}


function checkarg{
  param (
         [string]$ARG
  )
  Write-Debug " ARG: ARG= $ARG"

  if (!$ARG) {
     usage
  }
  $substring = 'CONFIG_'
  if (!$ARG.contains($substring)) {
    $ARG="CONFIG_$ARG"
  }
  if ($MUNGE_CASE -eq "yes") {
     $ARG="$ARG".ToUpper()
  }
  return $ARG
}


$FN=".config"
$MUNGE_CASE="yes"
for ( $i = 0; $i -lt $args.count; $i++ ) {
    switch -regex -casesensitive($($args[$i])) {
        '--keep-case|-k' {
            $MUNGE_CASE = "no"
            continue
        }
        '--file' {
            if (!$args[1]) {
               usage
            } else {
               $FN=$($args[1])
               $i += 1
            }
            continue
        }
        '--*(-after)|-E|-D|-M' {
            $CMD=$($args[$i])
            $A = checkarg $($args[$i+1])
            $B = checkarg $($args[$i+2])
            $i += 2
            Break
        }
        '--set-*' {
            $CMD = $($args[$i])
            $ARG = checkarg $($args[$i+1])
            $VALUE = checkarg $($args[$i+2])
            $i += 2
            Break
        }
        '-*' {
            $CMD = $($args[$i])
            $ARG = checkarg $($args[$i+1])
            $i += 1
            Break
        }
        default {
            Write-Debug "Default $($args[$i])"
            usage
        }
    }
}

switch -regex -casesensitive ($CMD) {
        '--enable|-e' {
            set_var "$ARG" "$ARG=y"
            Break
        }
        '--disable|-d' {
            set_var "$ARG" "# $ARG is not set"
            Break
        }
        '--undefine|-u' {
            undef_var "$ARG"
            Break
        }
        '--set-val' {
            set_var "$ARG" "$ARG=$VALUE"
            Break
        }
        '--set-str' {
            set_var "$ARG" "$ARG=""$VALUE"""
            Break
        }
        '--state|-s' {
            status_var "$ARG"
            Break
        }
        '--enable-after|-E' {
            set_var "$B" "$B=y" "$A"
            Break
        }
        '--disable-after|-D' {
            set_var "$B" "# $B is not set" "$A"
            Break
        }
        '--module-after|-M' {
            set_var "$B" "$B=m" "$A"
            Break
        }
        default {
            Write-Debug "Default $CMD"
            usage
        }
}
