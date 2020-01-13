@echo off
SETLOCAL
goto :Start


	::	Purpose: Provides a convenient wrapper to complicated VBoxManage commands, in order to:
	::		- Change amount of RAM allocated to VM.
	::		- Attach/remove/reconfigure RAW disk vmdk mapping.
	::	Arguments: (See ":Syntax")
	::	Dependencies:
	::		OldChoice.exe
	::		sleep.exe
	::	Version history:
	::		- 20111107 JC: Copied from vm509a_zh6.cmd and enhanced/cleaned-up a bit.
	::		- 20160125 JC: Copied from vm710a...cmd fork, and lightly refactored / generalized.
	::		- 20160914 JC: Refactored and used TEMPLATE_Full_v20130325a.cmd as a base.
	::		- 20171030 JC:
	::			- Added vwRamMB (as first argument).
	::			- Updated license to GPLv3.
	::		- 20180808 JC: Added empty CD to end (for VBox extensions). Shouldn't matter if there's another one on a different controller already.
	::		- 20200113 JC: Fixed location of helper files for generic open-source distribution.

::----------------------------------------------------------------------------------------
:Description
	call :fEcho_Bare ""
	call :fEcho_Bare "%~n0 20180808"
	call :fEcho_Bare "Copyright 2011-2018 Jim Collier"
	call :fEcho_Bare "This program is free software: you can redistribute it and/or modify it under"
	call :fEcho_Bare "the terms of the GNU General Public License v3."
	call :fEcho_Bare "See https://www.gnu.org/licenses/quick-guide-gplv3.html for more info."
goto :EOF


::----------------------------------------------------------------------------------------
:Hook_PreStart
	:: set HOOK_SKIPTOEND=1
goto :EOF


::----------------------------------------------------------------------------------------
:Syntax
	set vbCancel=1
	call :fEcho_Bare ""
	call :fEcho_Bare "Command-line parameters:"
	call :fEcho_Bare ".    1          [REQUIRED]: Virtual machine name"
	call :fEcho_Bare ".    2          [optional]: RAM in MB to set the VM to, if you wish to change it."
	call :fEcho_Bare ".    3, 4       [optional]: {first physical drive}[:{first partition}[,{second partition}[,{etc}]]] {type}"
	call :fEcho_Bare ".    5...20     [optional]: {Nth physical drive}[:{first partition}[,{second partition}[,{etc}]]]   {type}"
	call :fEcho_Bare "Where:"
	call :fEcho_Bare ".    - Physical drive:"
	call :fEcho_Bare ".        - The 'N' at the end of Windows '\\.\PhysicalDriveN'."
	call :fEcho_Bare ".        - Integer"
	call :fEcho_Bare ".        - Example: 0"
	call :fEcho_Bare ".    - Partitions:"
	call :fEcho_Bare ".        - Typically in the range of 1 to about 7."
	call :fEcho_Bare ".        - Integer"
	call :fEcho_Bare ".        - Example: 0:5,6 (physical drive 0, with partitions 5 and 6)"
	call :fEcho_Bare ".    - Drive type [optional]:"
	call :fEcho_Bare ".        - HDD or SDD"
	call :fEcho_Bare ".        - Defaults to HDD."
	call :fEcho_Bare "Double quotes are required for all drive[:part[,part]] arguments."
	call :fEcho_Bare ""
	call :fListDevices
goto :EOF

::----------------------------------------------------------------------------------------
:Initialize

	::-----------------------------------
	:: Constants - OK to adjust
	::-----------------------------------
	::set csHostDiskIoCache=off
	set csHostDiskIoCache=on
	set csVBoxManage=C:\Program Files\Oracle\VirtualBox\VBoxManage.exe
::	set csVirtualBoxMachineRootPath=C:\custom\data\common\virtualization\VirtualBox
	set csVirtualBoxMachineRootPath=C:\0-0\common\exec\local\vm\virtualbox
	set csSataControllerName=SATA_PhysDevices
	set csRawVmdkFilenamePrefix=raw-mapping
	

	::-----------------------------------
	:: Script options [OK to change assigned vals but do not delete]
	::-----------------------------------
	set cbDebug=false
	set cbOpt_PromptUser_ToContinue=1
	set cbOpt_PromptUser_OnNormalExit=0
	set cbOpt_PromptUser_OnError=1
	set cbOpt_EnableBeep=0
	set cwOpt_WindowVisibility=0
		:: 0=normal; 1=minimized; 2=hidden


	::-----------------------------------
	:: Constants - do not change
	::-----------------------------------
	set csPhysPath_Base=\\.\PhysicalDrive


	:: -----------------------------------
	:: Macros
	:: -----------------------------------


	::-----------------------------------
	:: Arguments
	::-----------------------------------
	set vsVmMachineName=%~1& shift
	set vwRamMB=%~1& shift
	set vsDriveArg01_PhysArg=%~1& shift
	set vsDriveArg01_Type=%~1& shift
	set vsDriveArg02_PhysArg=%~1& shift
	set vsDriveArg02_Type=%~1& shift
	set vsDriveArg03_PhysArg=%~1& shift
	set vsDriveArg03_Type=%~1& shift
	set vsDriveArg04_PhysArg=%~1& shift
	set vsDriveArg04_Type=%~1& shift
	set vsDriveArg05_PhysArg=%~1& shift
	set vsDriveArg05_Type=%~1& shift
	set vsDriveArg06_PhysArg=%~1& shift
	set vsDriveArg06_Type=%~1& shift
	set vsDriveArg07_PhysArg=%~1& shift
	set vsDriveArg07_Type=%~1& shift
	set vsDriveArg08_PhysArg=%~1& shift
	set vsDriveArg08_Type=%~1& shift
	set vsDriveArg09_PhysArg=%~1& shift
	set vsDriveArg09_Type=%~1& shift
	set vsDriveArg10_PhysArg=%~1& shift
	set vsDriveArg10_Type=%~1& shift
	set vsDriveArg11_PhysArg=%~1& shift
	set vsDriveArg11_Type=%~1& shift
	set vsDriveArg12_PhysArg=%~1& shift
	set vsDriveArg12_Type=%~1& shift
	set vsDriveArg13_PhysArg=%~1& shift
	set vsDriveArg13_Type=%~1& shift
	set vsDriveArg14_PhysArg=%~1& shift
	set vsDriveArg14_Type=%~1& shift
	set vsDriveArg15_PhysArg=%~1& shift
	set vsDriveArg15_Type=%~1& shift
	set vsDriveArg16_PhysArg=%~1& shift
	set vsDriveArg16_Type=%~1& shift
	set vsDriveArg17_PhysArg=%~1& shift
	set vsDriveArg17_Type=%~1& shift
	set vsDriveArg18_PhysArg=%~1& shift
	set vsDriveArg18_Type=%~1& shift
	set vsDriveArg19_PhysArg=%~1& shift
	set vsDriveArg19_Type=%~1& shift
	set vsDriveArg20_PhysArg=%~1& shift
	set vsDriveArg20_Type=%~1& shift

	::-----------------------------------
	:: Variables (for doc purposes)
	::-----------------------------------
	set vwTotalPortCount=0
	set vwPortLoopCounter=0
	set vsVmFolder=
	set vsVirtualMachineFile=
	set vsRamInfo=
	set vbChangeRam=

goto :EOF


::----------------------------------------------------------------------------------------
:Prepare
if "%vbCancel%"=="1" goto :EOF

	if "%cbDebug%" == "true" echo :Prepare

	:: Calculate compound variables
	set vsVmFolder=%csVirtualBoxMachineRootPath%\%vsVmMachineName%
	set vsVirtualMachineFile=%vsVmFolder%\%vsVmMachineName%.vbox

	set vsRamInfo=(no change)
	set vbChangeRam=0
	if "%vwRamMB%"=="" goto :Prepare_XCXIMX
	if "%vwRamMB%"=="0" goto :Prepare_XCXIMX
		set vsRamInfo=%vwRamMB% MB
		set vbChangeRam=1
	:Prepare_XCXIMX

goto :EOF


::----------------------------------------------------------------------------------------
:Validate
if "%vbCancel%"=="1" goto :EOF

	if "%cbDebug%" == "true" echo :Validate

	call :Validate_CmdArgCannotBeNull "%vsVmMachineName%" & if "%vsVmMachineName%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "csVBoxManage" "%csVBoxManage%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "vsVmFolder" "%vsVmFolder%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "csPhysPath_Base" "%csPhysPath_Base%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "csSataControllerName" "%csSataControllerName%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "csHostDiskIoCache" "%csHostDiskIoCache%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "csVirtualBoxMachineRootPath" "%csVirtualBoxMachineRootPath%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "vsVirtualMachineFile" "%vsVirtualMachineFile%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "csRawVmdkFilenamePrefix" "%csRawVmdkFilenamePrefix%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "vwTotalPortCount" "%vwTotalPortCount%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "vwPortLoopCounter" "%vwPortLoopCounter%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_CheckInPath "wmic.exe" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_CheckInPath "sleep.exe" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_FolderMustExist "%csFolderPath_Helpers%" & if "%vbCancel%"=="1" goto :EOF
	call :MustBeValidFile "%csVBoxManage%" & if "%vbCancel%"=="1" goto :EOF
	call :MustBeValidFolder "%csVirtualBoxMachineRootPath%" & if "%vbCancel%"=="1" goto :EOF
	call :MustBeValidFolder "%vsVmFolder%" & if "%vbCancel%"=="1" goto :EOF
	call :MustBeValidFile "%vsVirtualMachineFile%" & if "%vbCancel%"=="1" goto :EOF

	:: Validate drive-related args and count ports
	call :ValidateArgsAndGetPortCount

goto :EOF


::----------------------------------------------------------------------------------------
:ValidateArgsAndGetPortCount
	:: Validates drive args and sets port count
	set vbValidateArgsAndGetPortCount_Stop=0
	call :ValidateArgsAndGetPortCount_Per  1 "%vsDriveArg01_PhysArg%" "%vsDriveArg01_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per  2 "%vsDriveArg02_PhysArg%" "%vsDriveArg02_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per  3 "%vsDriveArg03_PhysArg%" "%vsDriveArg03_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per  4 "%vsDriveArg04_PhysArg%" "%vsDriveArg04_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per  5 "%vsDriveArg05_PhysArg%" "%vsDriveArg05_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per  6 "%vsDriveArg06_PhysArg%" "%vsDriveArg06_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per  7 "%vsDriveArg07_PhysArg%" "%vsDriveArg07_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per  8 "%vsDriveArg08_PhysArg%" "%vsDriveArg08_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per  9 "%vsDriveArg09_PhysArg%" "%vsDriveArg09_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 10 "%vsDriveArg10_PhysArg%" "%vsDriveArg10_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 11 "%vsDriveArg11_PhysArg%" "%vsDriveArg11_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 12 "%vsDriveArg12_PhysArg%" "%vsDriveArg12_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 13 "%vsDriveArg13_PhysArg%" "%vsDriveArg13_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 14 "%vsDriveArg14_PhysArg%" "%vsDriveArg14_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 15 "%vsDriveArg15_PhysArg%" "%vsDriveArg15_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 16 "%vsDriveArg16_PhysArg%" "%vsDriveArg16_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 17 "%vsDriveArg17_PhysArg%" "%vsDriveArg17_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 18 "%vsDriveArg18_PhysArg%" "%vsDriveArg18_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 19 "%vsDriveArg19_PhysArg%" "%vsDriveArg19_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :ValidateArgsAndGetPortCount_Per 20 "%vsDriveArg20_PhysArg%" "%vsDriveArg20_Type%" & if "%vbValidateArgsAndGetPortCount_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	pause
goto :EOF


::----------------------------------------------------------------------------------------
:ValidateArgsAndGetPortCount_Per
	set vlsVld_ArgNum=%~1& shift
	set vlsVld_PhysArg=%~1& shift
	set vlsVld_Type=%~1& shift

	set vbValidateArgsAndGetPortCount_Stop=1
	if "%vlsVld_PhysArg%"=="" goto :ValidateArgsAndGetPortCount_Per_End

		:: Split out and drive and partition numbers
		set vlsVld_Drive=
		set vlsVld_Partitions=
		for /f "tokens=1,2 delims=:" %%i in ("%vlsVld_PhysArg%") do set vlsVld_Drive=%%i& set vlsVld_Partitions=%%j

		:: Debug
	::	echo vlsVld_PhysArg ......: "%vlsVld_PhysArg%"
	::	echo vlsVld_Drive ........: "%vlsVld_Drive%"
	::	echo vlsVld_Partitions ...: "%vlsVld_Partitions%"

		:: Validate drive number
		set vlsIsNumber=0
		echo("%vlsVld_Drive%"|findstr "^[\"][-][1-9][0-9]*[\"]$ ^[\"][1-9][0-9]*[\"]$ ^[\"]0[\"]$">nul&&set vlsIsNumber=1||set vlsIsNumber=0
		if "%vlsIsNumber%"=="1" goto :jmp_df987sdfm
			call :fEcho_Bare ""
			call :fEcho_Bare "Error: Invalid drive number; specified drive:[partition1[,partition2[,etc]]] = '%vlsVld_PhysArg%'."
			goto :Syntax
		:jmp_df987sdfm

		:: Validate parition numbers
		if "%vlsVld_Partitions%"=="" goto :ValidateArgsAndGetPortCount_Per_NoChkPrt
			set vlsIsNumber=0
		::	This is a good test for +/- integers, but also need to allow comma
		::	echo("%vlsVld_Partitions%"|findstr "^[\"][-][1-9][0-9]*[\"]$ ^[\"][1-9][0-9]*[\"]$ ^[\"]0[\"]$">nul&&set vlsIsNumber=1||set vlsIsNumber=0
			set vlsIsNumber=1
				if "%vlsIsNumber%"=="1" goto :jmp_oiuyawer7634j
					call :fEcho_Bare ""
					call :fEcho_Bare "Error: Invalid partition number[s]; specified drive:[partition1[,partition2[,etc]]] = '%vlsVld_PhysArg%'."
					goto :Syntax
				:jmp_oiuyawer7634j
		:ValidateArgsAndGetPortCount_Per_NoChkPrt

		:: Validate type
		if /i "%vlsVld_Type%"=="HDD" goto :ValidateArgsAndGetPortCount_Per_Type_OK
		if /i "%vlsVld_Type%"=="SSD" goto :ValidateArgsAndGetPortCount_Per_Type_OK
		if /i "%vlsVld_Type%"=="" goto :ValidateArgsAndGetPortCount_Per_Type_OK
			call :fEcho_Bare ""
			call :fEcho_Bare "Error: Invalid drive type for drive parameter %vlsVld_ArgNum%: '%vlsVld_Type%', should be 'HDD' or 'SSD'."
			goto :Syntax
		:ValidateArgsAndGetPortCount_Per_Type_OK

		:: Set port highest valid count so far
		set vwTotalPortCount=%vlsVld_ArgNum%

		:: OK to keep Checking
		set vbValidateArgsAndGetPortCount_Stop=0

	:ValidateArgsAndGetPortCount_Per_End
goto :EOF

::----------------------------------------------------------------------------------------
:PromptToExecute
if "%vbCancel%"=="1" goto :EOF

	if "%cbDebug%" == "true" echo :PromptToExecute

	:: Show information and prompt to continue
	if "%cbOpt_PromptUser_ToContinue%"=="0" goto :PromptToExecute_010
		call :fEcho_Bare ""
		call :fEcho_Bare "This script will:"
		call :fEcho_Bare "1. Soft-power-off existing instance of '%vsVmMachineName%'."
		call :fEcho_Bare "2. Hard-power-off existing instance of '%vsVmMachineName%' (in case it is stuck on)."
		call :fEcho_Bare "3. Clear read-only physical drive attributes if necesssary."
		call :fEcho_Bare ".      - [This isn't currently working; you must do this manually with DISKPART.]"
		call :fEcho_Bare "4. Remove or refresh the raw VMDK physical mappings that the VM '%vsVmMachineName%' uses."
		call :fEcho_Bare "5. Launch '%vsVmMachineName%'."
		call :fEcho_Bare ""
		call :fEcho_Bare "Virtual machine name ........................: '%vsVmMachineName%'"
		call :fEcho_Bare "vbox file ...................................: '%vsVirtualMachineFile%'"
		call :fEcho_Bare "VirtualBox exe ..............................: '%csVBoxManage%'"
		call :fEcho_Bare "RAM .........................................: %vsRamInfo%"
		set cmsDots=......
		call :ShowDriveArgs
		call :fEcho_Bare ""
::		call :fListDevices
		call :Sub_PromptToContinue
		if "%vbCancel%"=="1" goto :EOF
	:PromptToExecute_010

	call :Execute

	call :fEcho ""

if "%vbCancel%"=="1" (ENDLOCAL & set vbCancel=1) else (ENDLOCAL)
goto :EOF


::----------------------------------------------------------------------------------------
:ShowDriveArgs
if "%vbCancel%"=="1" goto :EOF
SETLOCAL

	if "%cbDebug%" == "true" echo :ShowDriveArgs

	set vbShowDriveArgs_Stop=0
	call :ShowDriveArgs_PerArg 01 "%vsDriveArg01_PhysArg%" "%vsDriveArg01_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 02 "%vsDriveArg02_PhysArg%" "%vsDriveArg02_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 03 "%vsDriveArg03_PhysArg%" "%vsDriveArg03_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 04 "%vsDriveArg04_PhysArg%" "%vsDriveArg04_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 05 "%vsDriveArg05_PhysArg%" "%vsDriveArg05_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 06 "%vsDriveArg06_PhysArg%" "%vsDriveArg06_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 07 "%vsDriveArg07_PhysArg%" "%vsDriveArg07_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 08 "%vsDriveArg08_PhysArg%" "%vsDriveArg08_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 09 "%vsDriveArg09_PhysArg%" "%vsDriveArg09_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 10 "%vsDriveArg10_PhysArg%" "%vsDriveArg10_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 11 "%vsDriveArg11_PhysArg%" "%vsDriveArg11_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 12 "%vsDriveArg12_PhysArg%" "%vsDriveArg12_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 13 "%vsDriveArg13_PhysArg%" "%vsDriveArg13_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 14 "%vsDriveArg14_PhysArg%" "%vsDriveArg14_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 15 "%vsDriveArg15_PhysArg%" "%vsDriveArg15_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 16 "%vsDriveArg16_PhysArg%" "%vsDriveArg16_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 17 "%vsDriveArg17_PhysArg%" "%vsDriveArg17_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 18 "%vsDriveArg18_PhysArg%" "%vsDriveArg18_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 19 "%vsDriveArg19_PhysArg%" "%vsDriveArg19_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF
	call :ShowDriveArgs_PerArg 20 "%vsDriveArg20_PhysArg%" "%vsDriveArg20_Type%" & if "%vbShowDriveArgs_Stop%"=="1" goto :EOF

goto :EOF


::----------------------------------------------------------------------------------------
:ShowDriveArgs_PerArg
if "%vbCancel%"=="1" goto :EOF
SETLOCAL

	if "%cbDebug%" == "true" echo :ShowDriveArgs_PerArg

	:: Args
	set vlsArgNum=%~1& shift
	set vlsPhysArg=%~1& shift
	set vlsType=%~1& shift

	set vlsContents=""

	:: Physical drive number
	set vbShowDriveArgs_Stop=1
	if "%vlsPhysArg%" == "" goto :ShowDriveArgs_PerArg_01

		:: Parse out drive and partitions
		set vlsShow_Drive=
		set vlsShow_Partitions=
		for /f "tokens=1,2 delims=:" %%i in ("%vlsPhysArg%") do set vlsShow_Drive=%%i& set vlsShow_Partitions=%%j

		:: Physical device argument
		set vlsContents=%csPhysPath_Base%%vlsShow_Drive%

		:: Partitions device argument
		if "%vlsShow_Partitions%" == "" goto :ShowDriveArgs_PerArg_jmp_opzgw5928
		set vlsContents=%vlsContents%; Partitions=%vlsShow_Partitions%

		:: Type
		:ShowDriveArgs_PerArg_jmp_opzgw5928
		if "%vlsType%" == "" set vlsType=HDD
		set vlsContents=%vlsContents%; Type=%vlsType%

		:: Show
		call :fEcho_Bare "Arg%vlsArgNum% physical drive[,partition]; type %cmsDots%: %vlsContents%"

		:: OK to go again
		set vbShowDriveArgs_Stop=0

	:ShowDriveArgs_PerArg_01

goto :EOF


::----------------------------------------------------------------------------------------
:Execute
if "%vbCancel%"=="1" goto :EOF

	if "%cbDebug%" == "true" echo :Execute

	:: Soft power off
	call :fEcho ""
	call :fEcho "Attempting to safely shutdown existing instance of '%vsVmMachineName%' (in case one is running) ..."
	call :fEcho "If you see error messages (e.g. no running VM to shutdown), don't worry it's OK."
	set vlsCommand="%csVBoxManage%" controlvm "%vsVmMachineName%" acpipowerbutton
	echo [ Executing: %vlsCommand% ]
	%vlsCommand% 2>nul

	:: Hard power off
	call :fEcho ""
	call :fEcho "Attempting to hard-power-off VM (in case one is already running and it's hung)."
	call :fEcho "If you see error messages (e.g. no running VM to power off), don't worry it's OK."
	set vlsCommand="%csVBoxManage%" controlvm "%vsVmMachineName%" poweroff
	echo [ Executing: %vlsCommand% ]
	%vlsCommand% 2>nul
	sleep 2

	:: Change RAM
	if "%vbChangeRam%"=="0" goto :Execute_XCXIMY
		call :fEcho ""
		call :fEcho "Setting virtual RAM to %vwRamMB% MB ..."
		set vlsCommand="%csVBoxManage%" modifyvm "%vsVmMachineName%" --memory %vwRamMB%
		echo [ Executing: %vlsCommand% ]
		%vlsCommand%
	:Execute_XCXIMY

	:: Remove controller (as workaround part 1/2 of inability to remove individual drives)
	call :fEcho ""
	call :fEcho "Removing virtual controller '%csSataControllerName%' (to release drives) ..."
	call :fEcho "If you see If you see error messages (e.g. no controller), don't worry it's OK."
	set vlsCommand="%csVBoxManage%" storagectl "%vsVmMachineName%" --name "%csSataControllerName%" --remove
	echo [ Executing: %vlsCommand% ]
	%vlsCommand% 2>nul

	:: Remove all physical-to-virtual drive and/or partition mappings
	:: from VirtualBox disk manager, as well as vmdk file from the filesystem.
	:: The previous step already insured they are not tied to adapters.
	call :fEcho ""
	call :fEcho "Removing existing physical-to-virtual drive mappings ..."
	call :fRemoveAllDriveAndOrPartitionMappings
	if "%vbCancel%"=="1" goto :EOF

	:: Add controller back in (as workaround part 2/2 of inability to remove individual drives)
	if "%vwTotalPortCount%" LEQ "0" goto :Execute_jmp_wupwg3273
		call :fEcho ""
		call :fEcho "Adding virtual controller '%csSataControllerName%' back in (without drives) ..."
		set vlsCommand="%csVBoxManage%" storagectl "%vsVmMachineName%" --add sata --controller IntelAhci --hostiocache %csHostDiskIoCache% --portcount %vwTotalPortCount% --name "%csSataControllerName%"
		echo [ Executing: %vlsCommand% ]
		%vlsCommand%
		if errorlevel=1 goto :ERROR
	:Execute_jmp_wupwg3273

	:: Add back in any drives and/or partitions specified
	call :fEcho ""
	call :fEcho "Adding new mappings back to virtual machine ..."
	call :fMapDriveAndOrPartitionIfArgsValid
	if "%vbCancel%"=="1" goto :EOF
	
	:: Add an empty DVD drive
	set vbMapDriveAndOrPartitionIfArgsValid_Stop=1
	set vlsCommand="%csVBoxManage%" storageattach "%vsVmMachineName%" --storagectl "%csSataControllerName%" --port %vwPortLoopCounter% --type dvddrive --medium emptydrive --hotpluggable on
	echo [ Executing: %vlsCommand% ]
	%vlsCommand%
	if errorlevel=1 goto :ERROR
	:: Increment port counter (0-based)
	set /a vwPortLoopCounter+=1
	if errorlevel=1 goto :ERROR
	:: Set flag OK to go again
	set vbMapDriveAndOrPartitionIfArgsValid_Stop=0

	:: Start the VM
	call :fEcho ""
	call :fEcho "Starting virtual machine ..."
	set vlsCommand="%csVBoxManage%" startvm "%vsVmMachineName%"
	echo [ Executing: %vlsCommand% ]
	%vlsCommand%
	if errorlevel 1 goto :ErrorMsg_ReadOnly

goto :EOF


::----------------------------------------------------------------------------------------
:fListDevices
SETLOCAL
	if "%cbDebug%" == "true" echo :fListDevices
	call :fEcho_Bare "Attached drives:"
	call :fEcho_Bare "(Note that partition count and numbers may be listed incorrectly. Use GParted for accurate partition numbers.)"
	call :fEcho_Bare ""
	wmic diskdrive list brief
::	call :fEcho_Bare "Partitions (numbers are probably not accurate - might = +2 or 3 higher):"
::	wmic partition list brief
goto :EOF


::----------------------------------------------------------------------------------------
:fRemoveAllDriveAndOrPartitionMappings
if "%vbCancel%"=="1" goto :EOF
SETLOCAL

	::	TODO:
	::		- This is painfully slow as should be obvious by the nested looping structure, and also too arbitrarily limiting (however realistic it may be).
	::			- Options for improvement:
	::				- Check for file prefix matches and loop over those, parsing out name parts if necessary.

	if "%cbDebug%" == "true" echo :fRemoveAllDriveAndOrPartitionMappings

	:: Remove drive/partition-only vmdk, if exists.
	for /L %%i in (0,1,20) do (
		:: Echo progress dots (does not advance newline)
		<NUL set /p EchoNoNewLine=.
		call :fRemoveAllDriveAndOrPartitionMappings_PerFile "%vsVmFolder%\%csRawVmdkFilenamePrefix%_drive%%i"
		for /L %%j in (0,1,6) do (
			call :fRemoveAllDriveAndOrPartitionMappings_PerFile "%vsVmFolder%\%csRawVmdkFilenamePrefix%_drive%%i_partitions%%j"
			for /L %%k in (1,1,7) do (
				call :fRemoveAllDriveAndOrPartitionMappings_PerFile "%vsVmFolder%\%csRawVmdkFilenamePrefix%_drive%%i_partitions%%j,%%k"
			)
		)
	)

	:: Break out of dots
	call :fEcho ""

goto :EOF
				for /L %%l in (2,1,8) do (
					call :fRemoveAllDriveAndOrPartitionMappings_PerFile "%vsVmFolder%\%csRawVmdkFilenamePrefix%_drive%%i_partitions%%j,%%k,%%l"
				)


::----------------------------------------------------------------------------------------
:fRemoveAllDriveAndOrPartitionMappings_PerFile
if "%vbCancel%"=="1" goto :EOF
SETLOCAL

	if "%cbDebug%" == "true" echo :fRemoveAllDriveAndOrPartitionMappings_PerFile

	set vlsArg=%~1

	set vlsVmdkFile=%vlsArg%.vmdk
	::echo "Checking for: '%vlsVmdkFile%'."
	if not exist "%vlsVmdkFile%" goto :EOF

		:: Echo to break out of dots
		call :fEcho ""

		:: Remove from virtualbox disk manager
		set vlsCommand="%csVBoxManage%" closemedium disk "%vlsVmdkFile%"
		echo [ Executing: %vlsCommand% ]
		%vlsCommand% 2>nul

		:: Remove from the filesystem
		set vlsCommand=del "%vlsVmdkFile%"
		echo [ Executing: %vlsCommand% ]
		%vlsCommand% 2>nul

		:: Also check for the "-pt" file that gets automatically created.
		set vlsVmdkFile=%vlsArg%-pt.vmdk
		if not exist "%vlsVmdkFile%" goto :EOF

			:: Remove from the filesystem
			set vlsCommand=del "%vlsVmdkFile%"
			echo [ Executing: %vlsCommand% ]
			%vlsCommand% 2>nul

goto :EOF


::----------------------------------------------------------------------------------------
:fMapDriveAndOrPartitionIfArgsValid
if "%vbCancel%"=="1" goto :EOF

	set vbMapDriveAndOrPartitionIfArgsValid_Stop=0
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg01_PhysArg%" "%vsDriveArg01_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg02_PhysArg%" "%vsDriveArg02_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg03_PhysArg%" "%vsDriveArg03_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg04_PhysArg%" "%vsDriveArg04_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg05_PhysArg%" "%vsDriveArg05_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg06_PhysArg%" "%vsDriveArg06_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg07_PhysArg%" "%vsDriveArg07_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg08_PhysArg%" "%vsDriveArg08_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg09_PhysArg%" "%vsDriveArg09_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg10_PhysArg%" "%vsDriveArg10_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg11_PhysArg%" "%vsDriveArg11_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg12_PhysArg%" "%vsDriveArg12_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg13_PhysArg%" "%vsDriveArg13_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg14_PhysArg%" "%vsDriveArg14_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg15_PhysArg%" "%vsDriveArg15_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg16_PhysArg%" "%vsDriveArg16_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg17_PhysArg%" "%vsDriveArg17_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg18_PhysArg%" "%vsDriveArg18_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg19_PhysArg%" "%vsDriveArg19_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF
	call :fMapDriveAndOrPartitionIfArgsValid_PerArg "%vsDriveArg20_PhysArg%" "%vsDriveArg20_Type%" & if "%vbMapDriveAndOrPartitionIfArgsValid_Stop%"=="1" goto :EOF & if "%vbCancel%"=="1" goto :EOF

goto :EOF

::----------------------------------------------------------------------------------------
:fMapDriveAndOrPartitionIfArgsValid_PerArg
if "%vbCancel%"=="1" goto :EOF

	if "%cbDebug%" == "true" echo :fMapDriveAndOrPartitionIfArgsValid_PerArg

	:: Arguments
	set vlsPhysDevice=%~1& shift
	set vlsType=%~1& shift

	set vbMapDriveAndOrPartitionIfArgsValid_Stop=1
	if "%vlsPhysDevice%" == "" goto :jmp_ajo4ed234rt

		:: HDD or SSD (default to HDD)
		if "%vlsType%" == "" set vlsType="HDD"
		set vlsFlags=--nonrotational=off
		if /i "%vlsType%" == "SSD" set vlsFlags=--nonrotational=on --discard=on

		:: Get command for either whole drive, or just partition
		set vlsMap_Drive=
		set vlsMap_Partitions=
		for /f "tokens=1,2 delims=:" %%i in ("%vlsPhysDevice%") do set vlsMap_Drive=%%i& set vlsMap_Partitions=%%j
		if "%vlsMap_Partitions%" NEQ "" goto :jmp_ajo4ed5f87_DriveAndPartition

		:: Drive only
		:jmp_ajo4ed5f87_DriveOnly

			set vlsFullVmdk=%vsVmFolder%\%csRawVmdkFilenamePrefix%_drive%vlsMap_Drive%.vmdk
			set vlsCommand="%csVBoxManage%" internalcommands createrawvmdk -filename "%vlsFullVmdk%" -rawdisk %csPhysPath_Base%%vlsPhysDevice%
			goto :jmp_ajo4ed5f87_end

		:: Drive+Partition
		:jmp_ajo4ed5f87_DriveAndPartition

			set vlsFullVmdk=%vsVmFolder%\%csRawVmdkFilenamePrefix%_drive%vlsMap_Drive%_partitions%vlsMap_Partitions%.vmdk
			set vlsCommand="%csVBoxManage%" internalcommands createrawvmdk -filename "%vlsFullVmdk%" -rawdisk %csPhysPath_Base%%vlsMap_Drive% -partitions %vlsMap_Partitions%
			goto :jmp_ajo4ed5f87_end

		:jmp_ajo4ed5f87_end

		:: Create new raw VMDK
		echo [ Executing: %vlsCommand% ]
		%vlsCommand%
		if errorlevel=1 goto :ErrorMsg_ReadOnly

		:: Attach the VMDK to the machine
		set vlsCommand="%csVBoxManage%" storageattach "%vsVmMachineName%" --storagectl "%csSataControllerName%" --port %vwPortLoopCounter% --type hdd %vlsFlags% --medium "%vlsFullVmdk%"
		echo [ Executing: %vlsCommand% ]
		%vlsCommand%
		if errorlevel=1 goto :ERROR

		:: Increment port counter (0-based)
		set /a vwPortLoopCounter+=1
		if errorlevel=1 goto :ERROR

		:: Set flag OK to go again
		set vbMapDriveAndOrPartitionIfArgsValid_Stop=0

	:jmp_ajo4ed234rt

goto :EOF


::----------------------------------------------------------------------------------------
:ErrorMsg_ReadOnly

	call :fEcho_Bare ""
	call :fEcho_Bare "If the error is 'VERR_ACCESS_DENIED', make sure you do the following:"
	call :fEcho_Bare "1: Always execute the script from a Command prompts or shortcut with Administrator rights."
	call :fEcho_Bare "2: Do via Command prompt with Administrator rights:"
	call :fEcho_Bare "2a:    DISKPART"
	call :fEcho_Bare "2a1:       LIST DISK"
	call :fEcho_Bare "2a2:       SELECT DISK [drive number]"
	call :fEcho_Bare "2a4:       ATTRIBUTES DISK"
	call :fEcho_Bare "2a3:       ATTRIBUTES DISK CLEAR READONLY"
	call :fEcho_Bare "2a4:       ATTRIBUTES DISK"
	call :fEcho_Bare "2a5:       OFFLINE DISK"
	call :fEcho_Bare "2b:    ctrl+c"

	goto :ERROR

goto

::----------------------------------------------------------------------------------------
:Cleanup
	call :Cleanup_Generic

goto :EOF
























































::----------------------------------------------------------------------------------------
:: Useful template functions that may be used
::----------------------------------------------------------------------------------------


::----------------------------------------------------------------------------------------
:FilesAndFolders_ForEach_File
if "%vbCancel%"=="1" goto :EOF
	:: This is a callback routine, invoked by :FilesAndFolders_Enumerate
	:: OK to delete if not used
	echo File: '%~1'
goto :EOF


::----------------------------------------------------------------------------------------
:FilesAndFolders_ForEach_Folder
if "%vbCancel%"=="1" goto :EOF
	:: This is a callback routine, invoked by :FilesAndFolders_Enumerate [OK to delete if not used]
	echo Folder: '%~1'
goto :EOF


::----------------------------------------------------------------------------------------
:List_ForEach
if "%vbCancel%"=="1" goto :EOF
	:: This is a callback routine, invoked by :List_Enumerate [OK to delete if not used]
	echo List item: '%~1'
goto :EOF


::----------------------------------------------------------------------------------------
:: GENERIC ROUTINES BELOW, DO NOT DELETE OR CHANGE!
::----------------------------------------------------------------------------------------




::----------------------------------------------------------------------------------------
:Start

	call :Description
	if "%~1"=="/?" goto :Syntax
	if "%~1"=="?" goto :Syntax
	if "%~2"=="/?" goto :Syntax
	if "%~2"=="?" goto :Syntax
	if "%~3"=="/?" goto :Syntax
	if "%~3"=="?" goto :Syntax
	if "%~4"=="/?" goto :Syntax
	if "%~4"=="?" goto :Syntax
	if "%~5"=="/?" goto :Syntax
	if "%~5"=="?" goto :Syntax
	if "%~6"=="/?" goto :Syntax
	if "%~6"=="?" goto :Syntax
	if "%~7"=="/?" goto :Syntax
	if "%~7"=="?" goto :Syntax
	if "%~8"=="/?" goto :Syntax
	if "%~8"=="?" goto :Syntax
	if "%~9"=="/?" goto :Syntax
	if "%~9"=="?" goto :Syntax

	:: Generic constants and variables [do not delete or change]
	set vbError=0
	set vbCancel=
	set USERABORT=0
	set HOOK_SKIPTOEND=
	set SERIAL=
	set PASSWORD=
	set TEMPSPEC=
	set CommandLine=%*
    set IsFileOrFolder=

	:: Helper scripts and constants
	set vsFilespec_ThisScript=%~f0
	set csFolderPath_Helpers=%~dp0
	if "%csFolderPath_Helpers:~-1%"=="\" set csFolderPath_Helpers=%csFolderPath_Helpers:~0,-1%
::	set csFolderPath_Helpers=%csFolderPath_Helpers%\0_library_v1
	set csPARAMETERS_ALL=%*
	call :Validate_VariableCannotBeNull "vsFilespec_ThisScript" "%vsFilespec_ThisScript%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_FilespecMustExist "%vsFilespec_ThisScript%" & if "%vbCancel%"=="1" goto :EOF

	:: Command-line variables for very long args
	set vsArgs=
	:GetArgs
		set vsTemp=%2
		if x%vsTemp%x==xx goto :GetArgs_Break
		set vsArgs=%vsArgs% %vsTemp%
		shift /2
		goto :GetArgs
	:GetArgs_Break	

	call :Hook_PreStart %*
	if "%HOOK_SKIPTOEND%"=="1" goto :Start_PostExecute
		call :Initialize %*
		call :Prepare %*
		call :Prepare_GetArchitecture %*
		call :Validate %*
		call :ExecVisibility %*
		call :PromptToExecute %*
	:Start_PostExecute
		call :End
		call :Cleanup

goto :EOF


::----------------------------------------------------------------------------------------
:TestIfObjectExistsThenJumpto
	if "%vbCancel%"=="1" goto :EOF

	::	Purpose:
	::		A cleaner way to control flow based on the existence of a file object (folder or file).
	::		Jumps to provided labels (without the ":") depending on the answer.
	::	Args: (See ":: Arguments" below.)
	::	Minimum usage:
	::		call :TestIfObjectExistsThenJumpto "FILE OR FOLDER" "LABEL_Y" "LABEL_N" & goto :EOF
	::			(Note that you must use "call" rather than "goto", and must end with " & goto :EOF".)
	::	Example usage:
	::		call :TestIfObjectExistsThenJumpto "C:\Windows" "Folder_Exists" "Folder_NoExist" "Sorry, but the folder" "doesn't exist." & goto :EOF

	:: Arguments
	set TIFE_vsFolder=%~1
	set TIFE_vsJumpLabel_IfExists=%~2
	set TIFE_vsJumpLabel_IfNot=%~3
	set TIFE_vsMessage_IfNot_Prefix=%~4
	set TIFE_vsMessage_IfNot_Suffix=%~5
	set TIFE_vsMessage_IfSo_Prefix=%~6
	set TIFE_vsMessage_IfSo_Suffix=%~7

	:: Validation
	call :Validate_VariableCannotBeNull "TIFE_vsFolder"                "%TIFE_vsFolder%"                 & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "TIFE_vsJumpLabel_IfExists"    "%TIFE_vsJumpLabel_IfExists%"     & if "%vbCancel%"=="1" goto :EOF
	call :Validate_VariableCannotBeNull "TIFE_vsJumpLabel_IfNot"       "%TIFE_vsJumpLabel_IfNot%"        & if "%vbCancel%"=="1" goto :EOF

	:: Execution
	if not exist "%TIFE_vsFolder%" goto :TestIfObjectExistsThenJumpto_N
	:TestIfObjectExistsThenJumpto_Y
		if "%TIFE_vsMessage_IfSo_Prefix%_%TIFE_vsMessage_IfSo_Suffix%" == "_" goto :TestIfObjectExistsThenJumpto_Y_s1
			call :fEcho_Bare "%TIFE_vsMessage_IfSo_Prefix% '%TIFE_vsFolder%' %TIFE_vsMessage_IfSo_Suffix%"
		:TestIfObjectExistsThenJumpto_Y_s1
		goto :%TIFE_vsJumpLabel_IfExists%
		goto :TestIfObjectExistsThenJumpto_X
	:TestIfObjectExistsThenJumpto_N
		if "%TIFE_vsMessage_IfNot_Prefix%_%TIFE_vsMessage_IfNot_Suffix%" == "_" goto :TestIfObjectExistsThenJumpto_N_s1
			call :fEcho_Bare "%TIFE_vsMessage_IfNot_Prefix% '%TIFE_vsFolder%' %TIFE_vsMessage_IfNot_Suffix%"
		:TestIfObjectExistsThenJumpto_N_s1
		goto :%TIFE_vsJumpLabel_IfNot%
		goto :TestIfObjectExistsThenJumpto_X
	:TestIfObjectExistsThenJumpto_X

goto :EOF


::----------------------------------------------------------------------------------------
:fEcho
	if "%~1" == "" goto :fEcho_sub_null
		call :fEcho_Bare "[ %~1 ]"
		goto :fEcho_sub_x
	:fEcho_sub_null
		call :fEcho_Bare ""
	:fEcho_sub_x
	goto :EOF
:fEcho_Bare
	if "%~1" == "" goto :fEcho_Bare_null
		echo %~1
		goto :fEcho_Bare_x
	:fEcho_Bare_null
		echo:
	:fEcho_Bare_x
	goto :EOF
:Description_License_ShareAlike
	if "%vbCancel%"=="1" goto :EOF
	call :fEcho_Bare "License: Attribution-Noncommercial-Share Alike 3.0 United States."
	call :fEcho_Bare "License details: http://creativecommons.org/licenses/by-nc-sa/3.0/us/"
	goto :EOF
:Cleanup_Generic
	if "%vbCancel%"=="1" goto :EOF
	:: Script-specific variables
	set vsThisScript=
	:: Generic settings, constants, and variables [do not delete or change]
	set cbOpt_PromptUser_ToContinue=
	set cbOpt_PromptUser_OnNormalExit=
	set cbOpt_PromptUser_OnError=
	set cbOpt_EnableBeep=
	set vbCancel=
	set USERABORT=
	set HOOK_SKIPTOEND=
	set SERIAL=
	set PASSWORD=
	set TEMPSPEC=
	set CommandLine=
	set IsFileOrFolder=
	set cwOpt_WindowVisibility=
	goto :EOF
:Prepare_GetArchitecture
	if "%vbCancel%"=="1" goto :EOF
	:: Options based on processor type
	goto :Prepare_010_%PROCESSOR_ARCHITECTURE%
	:Prepare_010_x86
		set csPROGRAM_FILES_32BIT=%ProgramFiles(x86)%
		set csPROGRAM_FILES_64BIT=
		set csPROGRAM_FILES_NATIVE=%csPROGRAM_FILES_32BIT%
		goto :Prepare_010_end
	:Prepare_010_AMD64
		set csPROGRAM_FILES_32BIT=%ProgramFiles(x86)%
		set csPROGRAM_FILES_64BIT=%ProgramW6432%
		set csPROGRAM_FILES_NATIVE=%csPROGRAM_FILES_64BIT%
		goto :Prepare_010_end
	:Prepare_010_end
	:: Validate
	call :Validate_VariableCannotBeNull "csPROGRAM_FILES_NATIVE" "%csPROGRAM_FILES_NATIVE%" & if "%vbCancel%"=="1" goto :EOF
	goto :EOF
:ExecVisibility
	if "%vbCancel%"=="1" goto :EOF
		:: Re-execute this script, minimized and/or hidden
		:: 	Note: in this context, "goto :EOF" effctively resumes execution rather than exits the script
		:: Check flag to see if this instance was called from the first (ExecutingHidden flag set)
			if /i "%~1"=="EXECUTE_MINIMIZED" goto :EOF
			if /i "%~2"=="EXECUTE_MINIMIZED" goto :EOF
			if /i "%~3"=="EXECUTE_MINIMIZED" goto :EOF
			if /i "%~4"=="EXECUTE_MINIMIZED" goto :EOF
			if /i "%~5"=="EXECUTE_MINIMIZED" goto :EOF
			if /i "%~6"=="EXECUTE_MINIMIZED" goto :EOF
			if /i "%~7"=="EXECUTE_MINIMIZED" goto :EOF
			if /i "%~8"=="EXECUTE_MINIMIZED" goto :EOF
			if /i "%~9"=="EXECUTE_MINIMIZED" goto :EOF
			if /i "%~1"=="EXECUTE_HIDDEN" goto :EOF
			if /i "%~2"=="EXECUTE_HIDDEN" goto :EOF
			if /i "%~3"=="EXECUTE_HIDDEN" goto :EOF
			if /i "%~4"=="EXECUTE_HIDDEN" goto :EOF
			if /i "%~5"=="EXECUTE_HIDDEN" goto :EOF
			if /i "%~6"=="EXECUTE_HIDDEN" goto :EOF
			if /i "%~7"=="EXECUTE_HIDDEN" goto :EOF
			if /i "%~8"=="EXECUTE_HIDDEN" goto :EOF
			if /i "%~9"=="EXECUTE_HIDDEN" goto :EOF
		:: Re-launch the script minimized and/or hidden (will pick back up at ":PromptToExecute")
			if /i "%cwOpt_WindowVisibility%"=="1" goto :ExecVisibility_Minimized
			if /i "%cwOpt_WindowVisibility%"=="2" goto :ExecVisibility_Hidden
				goto :EOF
			:ExecVisibility_Minimized
				call :Validate_VariableCannotBeNull "vsFilespec_ThisScript" "%vsFilespec_ThisScript%" & if "%vbCancel%"=="1" goto :EOF
				call :Validate_FilespecMustExist "%vsFilespec_ThisScript%" & if "%vbCancel%"=="1" goto :EOF
				START "%vsFilespec_ThisScript% (minimized)" /MIN ""%vsFilespec_ThisScript%" %1 %2 %3 %4 %5 %6 %7 %8 EXECUTE_MINIMIZED"
				exit
			:ExecVisibility_Hidden
				call :Validate_VariableCannotBeNull "vsFilespec_ThisScript" "%vsFilespec_ThisScript%" & if "%vbCancel%"=="1" goto :EOF
				call :Validate_VariableCannotBeNull "FRM_Session_Exe_RunHidden" "%FRM_Session_Exe_RunHidden%" & if "%vbCancel%"=="1" goto :EOF
				call :Validate_FilespecMustExist "%vsFilespec_ThisScript%"
				call :Validate_FilespecMustExist "%csFolderPath_Helpers%\hstart.exe"
				"%csFolderPath_Helpers%\hstart.exe" /NOCONSOLE /SILENT "%vsFilespec_ThisScript%" %1 %2 %3 %4 %5 %6 %7 %8 EXECUTE_HIDDEN
				exit
		goto :EOF
:Validate_CheckInPath
	if "%vbCancel%"=="1" goto :EOF
		:: Checks if a file is in the current directory or in the PATH system environment variable.
		:: Param 1: 
		:: 	Required
		:: 	Description:
		:: 		Filename (with no preceeding path).
		:: Param 2:
		:: 	Optional
		:: 	Description:
		:: 		Whether or not the file must exist somewhere in the executable path.
		:: 	Allowable values:
		:: 		Y (default)
		:: 		N
		:: Params 3-9:
		:: 	Optional
		:: 	Description:
		:: 		Command line to execute if param 1 is in the path.
		if not "%~$PATH:1"=="" goto :Validate_CheckInPath_010
			if /i "%~2"=="N" goto :EOF
				echo The file '%~1' is required to be in the executable path, but was not found.
				goto :ERROR
		:Validate_CheckInPath_010
		if "%~3"=="" goto :EOF
			%3 %4 %5 %6 %7 %8 %9
			goto :EOF
:Sub_PromptToContinue
	if "%vbCancel%"=="1" goto :EOF
		:: prompts user to continue
		:: sets vbCancel to 1 if no
		call :Validate_FilespecMustExist "%csFolderPath_Helpers%\OldChoice.exe"
		if "%vbCancel%"=="1" goto :EOF
			call :DoBeep
			"%csFolderPath_Helpers%\OldChoice.exe" /n /c:YN "Continue [Y,N]? "
			if not errorlevel=2 goto :EOF
				set USERABORT=1
				goto :CANCEL
:DoBeep
	if "%JSASS_vbCancel%"=="1" goto :EOF
		if "%JSASS_cbOpt_EnableBeep%" NEQ "1" goto :EOF
			if not exist "%JSASS_csFolderPath_Helpers%\WinBeep.exe" goto :EOF
				"%JSASS_csFolderPath_Helpers%\WinBeep.exe"
	:goto :EOF
:Sub_PromptForPassword
	if "%vbCancel%"=="1" goto :EOF
		call :Validate_FilespecMustExist "%csFolderPath_Helpers%\Password.cmd" "Y"
		if "%vbCancel%"=="1" goto :EOF
			set PASSWORD_USERABORT=
			set ERR_PWD=
			call :DoBeep
			echo:
			call "%csFolderPath_Helpers%\Password.cmd" PASSWORD "Enter password or 'X' to quit: " Y "re-enter                     : " Y "X"
			if "%ERR_PWD%"=="1" goto :ERROR
			if not "%PASSWORD_USERABORT%"=="1" goto :EOF
				set USERABORT=1
				goto :CANCEL
:Sub_GetSerializedTime
	if "%vbCancel%"=="1" goto :EOF
		call :Validate_FilespecMustExist "%csFolderPath_Helpers%\SerialTime2.cmd" "Y"
		if "%vbCancel%"=="1" goto :EOF
			set DTTEV_ERROR=1
			set SERIAL=NULL
			call "%csFolderPath_Helpers%\SerialTime2.cmd" SERIAL %1
			if "%DTTEV_ERROR%" NEQ "0" goto :ERROR
			if "%SERIAL%"=="NULL" goto :ERROR
			if "%SERIAL%" NEQ "" goto :EOF
				echo:
				echo [a serial number could not be generated using '"%csFolderPath_Helpers%\SerialTime2.cmd"']
				goto :ERROR
		goto :EOF
:Validate_CannotBeNull
	if "%vbCancel%"=="1" goto :EOF
		if /i "%~1" NEQ "" goto :EOF
			echo:
			echo A variable was expected to be non-null.
			goto :ERROR
:Validate_VariableCannotBeNull
	if "%vbCancel%"=="1" goto :EOF
		if /i "%~2" NEQ "" goto :EOF
			echo:
			echo The variable "%~1" cannot be null.
			goto :ERROR
:Validate_CmdArgCannotBeNull
	if /i "%vbCancel%"=="1" goto :EOF
		if "%~1"=="" goto :Syntax
		goto :EOF
:Validate_FolderMustExist
	if "%vbCancel%"=="1" goto :EOF
		if exist "%~1" goto :EOF
			echo:
			echo The following folder was not found, but must exist to continue: '%~1'
			goto :ERROR
		goto :EOF
:Validate_FolderCannotExist
	if "%vbCancel%"=="1" goto :EOF
		if not exist "%~1" goto :EOF
			echo:
			echo The following folder was found, but cannot exist to continue: '%~1'
			goto :ERROR
		goto :EOF
:Validate_FilespecMustExist
	if "%vbCancel%"=="1" goto :EOF
		if exist "%~1" goto :EOF
			echo:
			echo The following file specification was not found, but must exist to continue: '%~1'
			goto :ERROR
		goto :EOF
:Validate_FilespecCannotExist
	if "%vbCancel%"=="1" goto :EOF
		if not exist "%~1" goto :EOF
			echo The following file specification was found, but cannot exist to continue:
			echo '%~1'
			goto :ERROR
		goto :EOF
:IsFileOrFolder
	:: Returns 1=file, 2=folder, or 0=neither (file not found)
	if "%vbCancel%"=="1" goto :EOF
		set IsFileOrFolder=0
		if "%~1"=="" goto :EOF
			set Temp1=%~a1
			if "%Temp1%"=="" goto :IsFileOrFolder_Cleanup
				set Temp2=%Temp1:~0,1%
				if "%Temp2%"=="d" goto :IsFileOrFolder_Folder
					set IsFileOrFolder=1
					goto :IsFileOrFolder_Cleanup
				:IsFileOrFolder_Folder
					set IsFileOrFolder=2
					goto :IsFileOrFolder_Cleanup
			:IsFileOrFolder_Cleanup
				set Temp1=
				set Temp2=
			goto :EOF
:FilesAndFolders_Enumerate
	:: Enumerates individual files and folders from a string.
	:: Invokes :FilessAndFolders_ForEach_File and/or :FilessAndFolders_ForEach_Folder
	:: param 1 [required]: String to parse containing files and folders.
	:: Will be parsed based on spaces, so any files or folders with a space must be surrounded by quotes.
	if "%vbCancel%"=="1" goto :EOF
		call :Validate_CannotBeNull "%~1" & if "%vbCancel%"=="1" goto :EOF
		:FilesAndFolders_Enumerate_Items
			if "%vbCancel%"=="1" goto :EOF
				if "%~1"=="" goto :EOF
					call :IsFileOrFolder "%~1"
					if "%IsFileOrFolder%"=="1" call :FilesAndFolders_ForEach_File "%~1"
					if "%IsFileOrFolder%"=="2" call :FilesAndFolders_ForEach_Folder "%~1"
					SHIFT
					goto :FilesAndFolders_Enumerate_Items
		goto :EOF
:List_Enumerate
	:: Parses a string with the specified delimiter, and enumerates each one individually.
	:: Only 25 items can be parsed.
	:: param 1 [required]: String to parse (surrounded by quotes).
	:: pa:: 2 [required]: Delimiter.
	if "%vbCancel%"=="1" goto :EOF
		call :Validate_CannotBeNull "%~1" & if "%vbCancel%"=="1" goto :EOF
		call :Validate_CannotBeNull "%~2" & if "%vbCancel%"=="1" goto :EOF
		FOR /F "tokens=1-25 delims=%~2" %%a in ("%~1") DO call :List_Enumerate_Items "%%a" "%%b" "%%c" "%%d" "%%e" "%%f" "%%g" "%%h" "%%i" "%%j" "%%k" "%%l" "%%m" "%%n" "%%o" "%%p" "%%q" "%%r" "%%s" "%%t" "%%u" "%%v" "%%w" "%%x" "%%y"
		goto :EOF
		:List_Enumerate_Items
			if "%vbCancel%"=="1" goto :EOF
				if "%~1"=="" goto :EOF
					call :List_ForEach "%~1"
					SHIFT
					goto :List_Enumerate_Items
		goto :EOF
:MustBeValidFile
	:: Errors if the argument is not a file or doesn't exist or is null.
	:: param 1 [required]: Folder specification.
	:MustBeValidFile_010
		if not "%~1"=="" goto :MustBeValidFile_020
			echo Was expecting a valid file specification, but received nothing.
			goto :ERROR
	:MustBeValidFile_020
		if exist "%~1" goto :MustBeValidFile_030
			echo The file '%~1' does not exist.
			goto :ERROR
	:MustBeValidFile_030
		call :IsFileOrFolder "%~1"
		if "%IsFileOrFolder%"=="1" goto :MustBeValidFile_040
			echo '%~1' is not a file.
			goto :ERROR
	:MustBeValidFile_040
	goto :EOF
:MustBeValidFolder
	:: Errors if the argument is not a folder or doesn't exist or is null.
	:: param 1 [required]: Folder specification.
	:MustBeValidFolder_010
		if not "%~1"=="" goto :MustBeValidFolder_020
			echo Was expecting a valid folder specification, but received nothing.
			goto :ERROR
	:MustBeValidFolder_020
		if exist "%~1" goto :MustBeValidFolder_030
			echo The folder '%~1' does not exist.
			goto :ERROR
	:MustBeValidFolder_030
		call :IsFileOrFolder "%~1"
		if "%IsFileOrFolder%"=="2" goto :MustBeValidFolder_040
			echo '%~1' is not a folder.
			goto :ERROR
	:MustBeValidFolder_040
	goto :EOF
:Validate_MustBeNetworkPath
	set TEMPX=%~1
	if "%TEMPX:~0,2%"=="\\" goto :Validate_MustBeNetworkPath_X
		echo '%TEMPX%' is not a network path.
		goto :ERROR
	:Validate_MustBeNetworkPath_X
	set TEMPX=
	goto :EOF
:Validate_MustBeDriveLetter
	set TEMPX=%~1
	if "%TEMPX:~1,1%"==":" goto :Validate_MustBeDriveLetter_X
		echo '%TEMPX%' is not a drive letter.
		goto :ERROR
	:Validate_MustBeDriveLetter_X
	set TEMPX=
	goto :EOF
:MoveFolder
	:: Moves a folder from one place to another
	:: param 1 [required]: Source folder
	:: param 2 [required]: Destination folder
	set MOVEFOLDER_SOURCE=%~1
	set MOVEFOLDER_DEST=%~2
	set MOVEFOLDER_NAMEANDEXT=%~nx1
	if "%MOVEFOLDER_SOURCE:~-1%"=="\" set MOVEFOLDER_SOURCE=%MOVEFOLDER_SOURCE:~0,-1%
	if "%MOVEFOLDER_DEST:~-1%"=="\" set MOVEFOLDER_DEST=%MOVEFOLDER_DEST:~0,-1%
	call :MustBeValidFolder "%MOVEFOLDER_SOURCE%" & if "%vbCancel%"=="1" goto :EOF
	call :MustBeValidFolder "%MOVEFOLDER_DEST%" & if "%vbCancel%"=="1" goto :EOF
	MD "%MOVEFOLDER_DEST%\%MOVEFOLDER_NAMEANDEXT%"
	call :MustBeValidFolder "%MOVEFOLDER_DEST%\%MOVEFOLDER_NAMEANDEXT%" & if "%vbCancel%"=="1" goto :EOF
	XCOPY "%MOVEFOLDER_SOURCE%\*.*" "%MOVEFOLDER_DEST%\%MOVEFOLDER_NAMEANDEXT%" /E /F /Q /H /K
	if errorlevel=1 goto :ERROR
	RD "%MOVEFOLDER_SOURCE%" /S /Q
	set MOVEFOLDER_SOURCE=
	set MOVEFOLDER_DEST=
	set MOVEFOLDER_NAMEANDEXT=
	goto :EOF
:CANCEL
	set vbCancel=1
	goto :EOF
:ERROR
	set vbError=1
	set vbCancel=1
	goto :EOF
:End
	call :DoBeep
	if "%vbError%"=="1" (
		call :fEcho "An error occurred."
		if "%cbOpt_PromptUser_OnError%"=="1" pause
	) else (
		if "%USERABORT%"=="1" (
			call :fEcho "User aborted."
			if "%cbOpt_PromptUser_OnNormalExit%"=="1" pause
		) else (
			if "%vbCancel%"=="1" (
				call :fEcho "Script aborted."
				if "%cbOpt_PromptUser_OnError%"=="1" pause
			) else (
				call :fEcho "Finished successfully."
				if "%cbOpt_PromptUser_OnNormalExit%"=="1" pause
			)
		)
	)
	if "%vbCancel%"=="1" (ENDLOCAL & set vbCancel=1) else (ENDLOCAL)
	goto :EOF










::----------------------------------------------------------------------------------------
:: REFERENCE: USEFUL VALIDATIONS AND MODIFICATION
::----------------------------------------------------------------------------------------

	:: Conditionally set one variable based on another
	if "%SOMEVARIABLE1%"=="" set SOMEVARIABLE2=

	:: Extract just a drive letter and colon
	set SOMEVARIABLE=%SOMEVARIABLE:~0,2%

	:: Strip off ending "\"
	if "%SOMEVARIABLE:~-1%"=="\" set SOMEVARIABLE=%SOMEVARIABLE:~0,-1%

	:: Get just a drive letter and colon
	set SOMEVARIABLE=%SOMEVARIABLE:~0,2%

	:: Replace every occurence of "X" with "Y"
	set SOMEVARIABLE=%SOMEVARIABLE:X=Y%

	:: Determine if sourcepath is a local or network
	if "%SOMEVARIABLE1:~0,2%"=="\\" set SOMEVARIABLE2=NET
	if "%SOMEVARIABLE1:~1,1%"==":" set SOMEVARIABLE2=LOCAL

	:: Get serialized time [can be used for a unique number; return value placed in variable named 'SERIAL']
	call :Sub_GetSerializedTime "yyyyMMdd-HHmmss-fff" & if "%vbCancel%"=="1" goto :EOF

	:: Prompt for password [or enter for none; "x" = abort; password stored temporarily in PASSWORD]
	call :Sub_PromptForPassword & if "%vbCancel%"=="1" goto :EOF

	:: Validations
	call :Validate_VariableCannotBeNull "SOMEVARIABLE" "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_CmdArgCannotBeNull "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_CannotBeNull "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_FilespecMustExist "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :MustBeValidFile "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :MustBeValidFolder "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_CheckInPath "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_FilespecCannotExist "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_FolderCannotExist "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_MustBeNetworkPath "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF
	call :Validate_MustBeDriveLetter "%SOMEVARIABLE%" & if "%vbCancel%"=="1" goto :EOF

	:: Prompt user for input
	set /P SOMEVARIABLE=Input something here: 

	:: Substring operations
	echo The first two characters of '%vExample%' are '%vExample:~0,2%'
	echo The last character of '%vExample%' is '%vExample:~-1%'
	echo The string '%vExample%' with the last character removed is '%vExample:~0,-1%'
	echo Substituting 'Bob' with 'Jill' in the string '%vExample%' results in '%vExample:Bob=Jill%'

	:: Loop counter example
	set /A "SOMECOUNTER += 1"

	:: Math example using both environment variables and static 'magic numbers'
	set /A "SOMERESULT = (VARIABLEA + VARABLEB) / (5 * 4 - (3 - 1))"

	:: Logical grouping using bitwise AND (&), bitwise OR (|), and bitwise XOR (^)
	set /A "SOMERESULT = "(0|1) & (1&1) & (128^256)"

	:: Conditional comparison
	if %VARIABLEA% EQU %VARIABLEB% echo %VARIABLEA% is equal to %VARIABLEB%
	if %VARIABLEA% NEQ %VARIABLEB% echo %VARIABLEA% is not equal to %VARIABLEB%
	if %VARIABLEA% LSS %VARIABLEB% echo %VARIABLEA% is less than %VARIABLEB%
	if %VARIABLEA% LEQ %VARIABLEB% echo %VARIABLEA% is less than or equal to %VARIABLEB%
	if %VARIABLEA% GTR %VARIABLEB% echo %VARIABLEA% is greater than %VARIABLEB%
	if %VARIABLEA% GEQ %VARIABLEB% echo %VARIABLEA% is greater than or equal to %VARIABLEB%

	:: Move a folder from one place to another, even accross drives
	:: call :MoveFolder "FolderToMove" "NewContainingFoler"

	:: Process each file or folder on the command line
	call :FilesAndFolders_Enumerate %CommandLine%

	:: Enumerate arguments
	call :EnumerateArgs

	:: RAR operation (check RAR_ERROR if operating on one file, or RAR_EXITVALUE if multiple; but not both)
	if not "%PASSWORD%"=="" set PASSWORD=-p"%PASSWORD%"
	set RAR_ERROR=
	set RAR_EXITVALUE=
	call "%csFolderPath_Helpers%\Rar.cmd" a -ep1 -m3 -os -r0 -rr -ac %PASSWORD% "[target.rar]" "[sourcespec]"
	if "%RAR_ERROR%"=="1" goto :ERROR
	if not "%RAR_EXITVALUE%"=="0" goto :ERROR

	:: Branch logic without parentheses [which are vastly more convenient but fail if there are parentheses in a string or value of an environment variable].
	if exist "%vm210c_csFilespec_VerifyMountedFile%" goto :PromptToExecute_SomeCondition_Y
	goto :PromptToExecute_SomeCondition_N
	:PromptToExecute_SomeCondition_Y
		goto :PromptToExecute_SomeCondition_X
	:PromptToExecute_SomeCondition_N
		goto :PromptToExecute_SomeCondition_X
	:PromptToExecute_SomeCondition_X
