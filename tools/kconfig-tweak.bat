@echo off

rem Manipulate options in a .config file from the command line
setlocal EnableExtensions
setlocal EnableDelayedExpansion
set myname=%~n0

REM echo %0 %1 %2 %3 %4 %5 %6 %7

set configfilename=%~2
if "%1"=="--file" (
   rem echo configfilename=%configfilename%
   if "%configfilename%"=="" (
      call :Usage
      exit 2
   )
) else set configfilename=.config

if "%1"=="" (
   call :Usage
   exit 1
)

set "munge_case=y"

:StartArgLoop
   if "%1"=="" goto :EndArgLoop
   set thiscmd=%1
   set thiscmdargone=%2
   set thiscmdargtwo=%3
   shift
   
   for %%i in (--keep-case -k) do if %thiscmd%==%%i (
      set "munge_case="
   )
   
   for %%i in (--disable -d) do if %thiscmd%==%%i (
      rem echo Disable!
      call :SetVar %thiscmdargone% "# %thiscmdargone% is not set"
   )
   
   for %%i in (--enable -e) do if %thiscmd%==%%i (
      rem echo Enable!
      call :SetVar %thiscmdargone% "%thiscmdargone%=y"
   )
   
   for %%i in (--module -m) do if %thiscmd%==%%i (
      rem echo Module!
      call :SetVar %thiscmdargone% "%thiscmdargone%=m"
   )
   
   if %thiscmd%==--set-str (
      rem echo Set-str!
      call :SetVar %thiscmdargone% "%thiscmdargone%=\"%thiscmdargtwo%\""
   )
   
   if %thiscmd%==--set-val (
      rem echo Set-val!
      call :SetVar %thiscmdargone% "%thiscmdargone%=%thiscmdargtwo%"
   )

   for %%i in (--undefine -u) do if %thiscmd%==%%i (
      rem echo Undefine!
      call :UndefVar %thiscmdargone%
   )
   
   for %%i in (--state -s) do if %thiscmd%==%%i (
      rem echo State!
      call :PrintVarState %thiscmdargone%
   )
   
   for %%i in (--enable-after -E) do if %thiscmd%==%%i (
      rem echo Enable-after!
      call :SetVar %thiscmdargone% "%thiscmdargone%=y" %thiscmdargtwo%
   )
   
   for %%i in (--disable-after -D) do if %thiscmd%==%%i (
      rem echo Disable-after!
      call :SetVar %thiscmdargone% "# %thiscmdargone% is not set" %thiscmdargtwo%
   )
   
   for %%i in (--module-after -M) do if %thiscmd%==%%i (
      rem echo Module-after!
      call :SetVar %thiscmdargone% "%thiscmdargone%=m" %thiscmdargtwo%
   )

   rem echo Processed arg: %thiscmd%
   
goto :StartArgLoop
:EndArgLoop

exit


:SetVar
   set varname=%1
   set newline=%~2
   set beforevar=%3
   set "foundname="
   set "foundbefore="

   rem echo SetVar: varname=%varname%; newline=%newline%; beforevar=%beforevar%
   
   set name_re="^(%varname%=|# %varname% is not set)"
   rem echo name_re=%name_re%

   grep -Eq %name_re% %configfilename% && set "foundname=y"
   
   if not "%beforevar%"=="" (
      rem echo %beforevar%
      grep -Eq "^(%beforevar%=|# %beforevar% is not set)" %configfilename% && set "foundbefore=y"
      if defined foundbefore (
         rem echo foundbefore
         call :TxtAppend "^%beforevar%=" "%newline%" "%configfilename%"
         call :TxtAppend "^# %beforevar% is not set" "%newline%" "%configfilename%"
      )
   )
   
   if not defined foundbefore (
      if defined foundname (
         call :TxtSubst "^%varname%=.*" "%newline%" "%configfilename%"
         call :TxtSubst "^# %varname% is not set" "%newline%" "%configfilename%"
      ) else (
         echo %newline%>>"%configfilename%"
      )
   )
exit /B 0


:UndefVar
   set varname=%1

   call :TxtDelete "^%varname%=" "%configfilename%"
   call :TxtDelete "^# %varname% is not set" "%configfilename%"
exit /B 0


:PrintVarState
   set varname=%1
:PrintVarStateN
   grep -q "# %varname% is not set" "%configfilename%"
   if errorlevel 1 goto :PrintVarStatePresent
   echo n
   goto :EndPrintVarState
:PrintVarStatePresent
   grep -q "^%varname%=" "%configfilename%"
   if errorlevel 1 goto :PrintVarStateAbsent
   grep "^%varname%=" "%configfilename%" | sed -r "s/^%varname%=//"
   goto :EndPrintVarState
:PrintVarStateAbsent
  echo undef
:EndPrintVarState
exit /B 0


:TxtAppend
   set anchor=%~1
   set insert=%~2
   set infile=%~3
   set tmpfile=%infile%.swp
   
   rem echo TxtAppend %1 %2 %3
   sed "/%anchor%/ s/$/\n%insert%/" "%infile%" > "%tmpfile%"
   mv "%tmpfile%" "%infile%"
exit /B 0


:TxtDelete
   set texttodelete=%~1
   set infile=%~2
   set tmpfile=%infile%.swp
   
   rem sed -e "/$text/d" "$infile" >"$tmpfile"
   sed -e "/%texttodelete%/d" "%infile%" >"%tmpfile%"
   mv "%tmpfile%" "%infile%"
exit /B 0


:TxtSubst
   set before=%~1
   set after=%~2
   set infile=%~3
   set tmpfile=%infile%.swp
   
   rem echo sed -e "s/%before%/%after%/" "%infile%"
   sed -e "s/%before%/%after%/" "%infile%" >"%tmpfile%"
   mv "%tmpfile%" "%infile%"
exit /B 0


:Usage
   echo %myname%: Manipulate options in a .config file from the command line.
   echo.
   echo Usage:
   echo    %myname% options command ...
   echo.
   echo commands:
   echo    --enable,-e option   Enable option
   echo    --disable,-d option  Disable option
   echo    --module,-m option   Turn option into a module
   echo    --set-str option string
   echo       Set option to "string"
   echo    --set-val option value
   echo       Set option to value
   echo    --undefine,-u option Undefine option
   echo    --state,-s option    Print state of option (n,y,m,undef)
   echo.
   echo    --enable-after,-E beforeopt option
   echo       Enable option directly after other option
   echo    --disable-after,-D beforeopt option
   echo       Disable option directly after other option
   echo    --module-after,-M beforeopt option
   echo       Turn option into module directly after other option
   echo.
   echo    Commands can be repeated multiple times.
   echo.
   echo options:
   echo    --file config-file   .config file to change (default .config)
   echo    --keep-case,-k       Keep next symbols' case (dont' upper-case it)
   echo.
   echo %myname% doesn't check the validity of the .config file. This is done at next
   echo make time.
   echo.
   echo By default, %myname% will upper-case the given symbol. Use --keep-case to keep
   echo the case of all following symbols unchanged.
   echo.
exit /B 1
