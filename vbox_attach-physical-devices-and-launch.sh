#!/bin/bash

#########################################################################################
##	Purpose:
##		- [See fDescriptionAndCopyright below.]
##	TODO:
##		- Clean up template code [prune unused functions which is most of them].
##		- Make more generic, appropriate for an open-source standalone script.
##		- Include device listing code in this script.
##	History:
##		- 20181002 JC: Created based on TEMPLATE_simple_v20160925.
##		- 20190701 JC: Fixed a bug that was preventing raw vmdks from being deleted.
##			- 'find' command needed a "/" at end of folder to search. (Edit XZPZhwYKPUykvoDy9L_AUw)
##		- 20190910 JC: Added script name to examples in fSyntax().
##		- 20191014 JC: Renamed from j.* to x9*
##		- 20200112 JC: Included code from 0_library_v2 so that it's a one-file solution (clean up later).
#########################################################################################


## Script constants; change to match your system
declare -r cmsVirtualboxBaseFolder="$HOME/VirtualBox VMs/"
declare -r cmsHostIOCache="off"  ## on|off


## Template settings
function fDescriptionAndCopyright() {
	fEcho_Clean "Configures and launches a named VirtualBox VM."
}

function fSyntax() { :; 
	fEcho_Clean "Parameters:"
	fEcho_Clean "    1 [REQUIRED]: Name of VirtualBox VM."
	fEcho_Clean "    2 [optional]: Space-delimited string of 'sdxx' devices to attach as raw."
	fEcho_Clean ""
	fEcho_Clean "Examples:"
	fEcho_Clean "    $(basename "${0}") MyVM"
	fEcho_Clean "    $(basename "${0}") MyVM \"sdh sdi\""
#	fEcho_Clean ""
#	JCDRIVEINFO_LESSVERBOSE=true x9driveinfo
#	fEcho_ResetBlankCounter
}

declare cmwNumberOfRequiredArgs=1
declare cmbAlwaysShowDescriptionAndCopyright="true"
declare cmbEchoAndDo_EchoOnly="false"
declare cmbDebug="false"
declare vmbLessVerbose="${TEMPLATE_LESSVERBOSE}"; if [ "${vmbLessVerbose}" != "true" ]; then vmbLessVerbose="false"; fi


function fMain() { :;
	fEcho_IfDebug "fMain()"
	[ "${vmbLessVerbose}" != "true" ] && fEcho ""

	## Get packed args
	local packedArgs="$1"; shift || true
	local -a argsArray; fUnpackArgs_ToArrayPtr "${packedArgs}" argsArray  ##..... Unpack args to array
	local -r arg1="$(fArray_GetItemBy_1ndex argsArray 1)"  ##....................... Get item 1 using array function (error-resistant)
	local -r arg2="$(fArray_GetItemBy_1ndex argsArray 2)"  ##....................... Get item 1 using array function (error-resistant)

	## Constants
	local -r clsVmName="${arg1}"
	local -r clsRawDevices="${arg2}"
	local -r clsVmFolder="${cmsVirtualboxBaseFolder}/${clsVmName}"
	local -r clsType="gui"  ## gui, sdl, headless
	local -r clsAttachType="writethrough"  ## immutible, normal, writethrough
	local -r clsDrivePrefix="raw"
	local -r clsStorageControllerName="sata_raw"
	local -r clsOwner="${USER}:vboxusers"

	## Variables
	local vlsDevPath=""
	local vlsFilename=""
	local vlsRawFilespec=""
	local vlwCounter=0
	local rawFilespec=""

	## Validate
	if [ -z "${clsVmName}" ]; then fThrowError "You must specify a VirtualBox VM name to run."; fi

	## Prompt
	if [ "${vmbLessVerbose}" != "true" ]; then :;
		fEcho "You may be prompted for sudo rights."
		fPromptToRunScript
	fi

	fEcho ""
	fGetSudo

	## Validate
	fEcho "Validating script configuration ..."
	vlwCounter=0
	for vlsRawDevice in $clsRawDevices; do
		if [ -z "${vlsRawDevice}" ]; then fThrowError "No drive specified."; fi
		vlsDevPath="/dev/${vlsRawDevice}"
		if [ ! -e "${vlsDevPath}" ]; then fThrowError "Device '${vlsDevPath}' does not exist."; fi
		vlwCounter=$[vlwCounter + 1]
	done

	## Remove the controller, if it exists (necessary to do this before close/delete the drives)
	fEcho "Removing SATA controller '${clsStorageControllerName}' if necessary ..."
	VBoxManage storagectl "${clsVmName}" --name "${clsStorageControllerName}" --remove 2> /dev/null || true

	## Close and delete existing VMDKs
	local -r rawFiles="$(find "${clsVmFolder}/" -maxdepth 1 -type f -iregex ".*/${clsDrivePrefix}_.*\.vmdk" 2> /dev/null || true)"  ## Edit XZPZhwYKPUykvoDy9L_AUw
	if [ -n "${rawFiles}" ]; then
		IFS=$'\n'
		for rawFilespec in $rawFiles; do
			if [ -n "${rawFilespec}" ]; then
				if [ -f "${rawFilespec}" ]; then
					fEcho "Closing and removing existing raw mapping: '${rawFilespec}' ..."
					sudo chown ${clsOwner} "${rawFilespec}"
					sudo chmod 664 "${rawFilespec}"
					VBoxManage closemedium disk "${rawFilespec}" 2> /dev/null || true  ## Errors are OK, as it may not be loaded.
					rm "${rawFilespec}"
				fi
			fi
		done
	fi

	if [ ${vlwCounter} -gt 0 ]; then

		## [Remove] and [re-]add the controller (necessary to do this before close/delete the drives)
		fEcho "Re-adding SATA controller '${clsStorageControllerName}' ..."
		VBoxManage storagectl "${clsVmName}" --name "${clsStorageControllerName}" --add SATA --controller IntelAHCI --portcount $vlwCounter --hostiocache ${cmsHostIOCache}

		## Unmount devices
		for vlsRawDevice in $clsRawDevices; do
			if [ -n "${vlsRawDevice}" ]; then
				vlsDevPath="/dev/${vlsRawDevice}"
				if [ -e "${vlsDevPath}" ]; then

					fEcho "Unmounting '${vlsDevPath}' ..."

					## Try to unmount it without error, and without forcing (will fail if something is actually using it)
					sudo umount "${vlsDevPath}" &> /dev/null || true

					## Try to mount it to a dummy location as a test, but don't error (should fail if didn't unmount cleanly above).
					tmpMount="$(sudo mktemp -d)"
					sudo mount "${vlsDevPath}" "${tmpMount}" 2> /dev/null || true  ## OK to fail here

					## Now unmount it, while not swallowing errors. This should be a final test of 1) can it be cleanly mounted [e.g. not still mounted], and 2) can it be cleanly unmounted
					if [ -n "$(mount | grep "${tmpMount}" 2> /dev/null || true)" ]; then
						sudo umount "${tmpMount}"
					fi

				fi
			fi
		done

		### Debug
		#fEcho_VariableAndValue arg1
		#fEcho_VariableAndValue arg2
		#fEcho_VariableAndValue clsVmName
		#fEcho_VariableAndValue clsRawDevices
		#fEcho_VariableAndValue clsVmFolder
		#fEcho_VariableAndValue vlwCounter
		#fEcho_VariableAndValue rawFiles
		#exit

		## Create VMDKs
		vlwCounter=0
		for vlsRawDevice in $clsRawDevices; do
			if [ -n "${vlsRawDevice}" ]; then
				vlsDevPath="/dev/${vlsRawDevice}"
				if [ -e "${vlsDevPath}" ]; then
					vlsFilename="${clsDrivePrefix}_${vlsRawDevice}.vmdk"
					vlsRawFilespec="${clsVmFolder}/${vlsFilename}"
					fEcho "Creating VMDK '${vlsRawFilespec}' for '${vlsDevPath}' ..."
					sudo chown $clsOwner "${vlsDevPath}"; sudo chmod 664 "${vlsDevPath}"
					VBoxManage internalcommands createrawvmdk -filename "${vlsRawFilespec}" -rawdisk $vlsDevPath 1> /dev/null
					sudo chown $clsOwner "${vlsRawFilespec}"; sudo chmod 664 "${vlsRawFilespec}"
					VBoxManage storageattach "${clsVmName}" --storagectl "${clsStorageControllerName}" --port $vlwCounter --type hdd --medium "${vlsRawFilespec}" --mtype $clsAttachType
					vlwCounter=$[vlwCounter + 1]
				fi
			fi
		done

	fi

	## Start the VM
	#VBoxManage controlvm
	fEcho ""
	fEcho "Starting '${clsVmName}' ..."
	VBoxManage startvm "${clsVmName}" --type $clsType

	if [ "${vmbLessVerbose}" != "true" ]; then fEcho ""; fEcho "Done"; fi
}


function fCleanup() { :;
	if [ "${vmbInSudoSection}" == "true" ]; then :;
		## Exiting while running under ExecutionEngine’s sudo loop (not guaranteed to be called - e.g. if already sudo when script invoked).
		fEcho_IfDebug "fCleanup() [in sudo loop]"
	else
		## Exiting script under normal execution
		fEcho_IfDebug "fCleanup()"
		if [ "${vmbLessVerbose}" != "true" ]; then fEcho ""; fi
	fi
}

































































#########################################################################################
## Generic code - do not modify
#########################################################################################

function _fMustBeInPath() { :;
	if [ -z "$1" ]; then :;
		echo "_fMustBeInPath(): Nothing to check."; exit 1
	elif [ "$(_fIsInPath "$1")" != "true" ]; then :;
		echo "The command “$1” must be in path, but isn’t."; exit 1
	fi; }
function _fIsInPath() { :;
	local vlsReturn="false"
	if [ -z "$1" ]; then :;
		echo "_fIsInPath(): Nothing to check."; exit 1
	else
		if [ -n "$(_fSafeWhich "$1")" ]; then vlsReturn="true"; fi
	fi
	echo "${vlsReturn}"; }
function _fGetrawFilespecOfMe(){ :;
	echo "$0" ; :; }
function _fSafeWhich() { :;
	which "$@" 2> /dev/null || true; :; }
function _fErrHandling_Get(){ :;
	##	Arguments: (None)
	##	Returns via echo: A string with zero, one, or more of "e" or "E" in any order. Where:
	##		"e": Break on errors. If not included, errors are ignored
	##		"E": Include called files. If not included, ignored.
	local returnStr=""
	if [[ "$-" == *"e"* ]]; then returnStr="${returnStr}e"; fi
	if [[ "$-" == *"E"* ]]; then returnStr="${returnStr}E"; fi
	echo "${returnStr}" ; }
function _fErrHandling_Set(){ :;
	##	Argument: A string with zero, one, or more of "e" or "E" in any order. Where:
	##		"e": Break on errors. If not included, errors are ignored
	##		"E": Include called files. If not included, ignored.
	##	Returns via echo: String of previous state.
	local prevVal="$(_fErrHandling_Get)"
	if [[ "$1" == *"e"* ]]; then set -e; else set +e; fi
	if [[ "$1" == *"E"* ]]; then set -E; else set +E; fi
	echo "${prevVal}" ; }
function _fErrHandling_Set_Ignore(){ :;
	##	Arguments: (None)
	##	Returns via echo: String of previous state.
	local prevVal="$(_fErrHandling_Get)"
	_fErrHandling_Set ""
	echo "${prevVal}" ; }
function _fErrHandling_Set_Fatal(){ :;
	##	Arguments: (None)
	##	Returns via echo: String of previous state.
	local prevVal="$(_fErrHandling_Get)"
	_fErrHandling_Set "eE"
	echo "${prevVal}" ; }


#########################################################################################
## Initial settings and execution control
#########################################################################################

## Error handling
_fErrHandling_Set_Fatal 1>/dev/null

## Validate
_fMustBeInPath "basename"

## Me references
declare vmsMe_Pathspec="$(_fGetrawFilespecOfMe)"
declare vmsMe_Name="$(basename "${vmsMe_Pathspec}")"
declare vmsMeName="${0}"  ## Legacy; use vmsMe_Pathspec instead









































#########################################################################################
## Toolbox code that used to be included with `source 0_library_v2`
#########################################################################################

function fTemplate(){ :;
	local -r functionName="fTemplate"
	#@	Purpose:
	#@	Arguments:
	#@		1 [REQUIRED]: 
	#@		2 [optional]: 
	#@	Depends on global or parent-scope variable[s] or constant[s]:
	#@		
	#@	Modifies global or parent-scope variable[s]:
	#@		
	#@	Other side-effects:
	#@		
	#@	Returns via echo:
	#@		
	#@	Note[s]:
	#@		- 
	#@	Example[s]:
	#@		1: 
	##	History:
	##		- 20YYMMDD JC: Created.
	fEcho_IfDebug "${functionName}()"

	## Constants

	## Args
	local arg1="$1"

	## Variables

	## Init

	## Validate

	## Execute

}


function fIndent(){
	#@	Purpose: Indents all lines of piped input, to an absolute number of spaces (regardless of starting indentation).
	#@	Arguments: None (use on right side of pipe).
	#@	Example[s]:
	#@		1: ls -1 | fIndent 4
	#@			Shows a directory listing, indented 4 spaces.
	##	History:
	##		- 20190903 JC: Created.
	sed -e 's/^[ \t]*//' | sed "s/^/$(printf "%${1}s")/"
#	sed -e 's/^[ \t]*//' | sed 's/^/    /'
#	sed -e 's/^[ \t]*//' | awk '{printf "%\${1}s", " "}'
}


function fInit_Integer(){ :;
	local -r functionName="fInit_Integer"
	#@	Purpose:
	#@		Initializes a variable with a valid integer, if it isn't already.
	#@	Arguments:
	#@		1 [REQUIRED]: Variable name that contains initial value, and gets overwritten with valid integer if necessary.
	#@		2 [optional]: Default value used if not integer. Default to 0.
	#@		3 [optional]: Minimum value to constrain to.
	#@		3 [optional]: Maximum value to constrain to.
	#@	Modifies:
	#@		The value stored in the variable named in arg 1.
	#@	Example[s]:
	#@		1: fInit_Integer myVariable 0 0
	#@			myVariable before: 1     ; myVariable after: 1
	#@			myVariable before: 10000 ; myVariable after: 10000
	#@			myVariable before: -1    ; myVariable after: 0
	#@			myVariable before: ""    ; myVariable after: 0
	#@			myVariable before: "Tom" ; myVariable after: 0
	##	History:
	##		- 20190525 JC: Created.
	fEcho_IfDebug "${functionName}()"

	## Constants

	## Args
	local variableName="$1"
	local defaultValue=$2
	local minVal=$3
	local maxVal=$4

	## Variables
	local variableValue=""

	## Init
	variableValue="${!variableName}"

	## Debug
	#fEcho_VariableAndValue variableName
	#fEcho_VariableAndValue variableValue
	#fEcho_VariableAndValue defaultValue
	#fEcho_VariableAndValue minVal
	#fEcho_VariableAndValue maxVal

	## Init
	if [ -z "${defaultValue}" ]; then
		defaultValue=0
	fi

	## Validate
	fFunctionArgumentCannotBeEmpty "${functionName}()" 1 "$1"
	if [ "$(fIsInteger "${defaultValue}")" == "false" ]; then
		fThrowError "${functionName}(): Specified default value is not an integer: '${defaultValue}'."
	fi
	if [ -n "${minVal}" ]; then
		if [ "$(fIsInteger "${minVal}")" == "false" ]; then
			fThrowError "${functionName}(): Specified min value is not an integer: '${minVal}'."
		fi
	fi
	if [ -n "${maxVal}" ]; then
		if [ "$(fIsInteger "${maxVal}")" == "false" ]; then
			fThrowError "${functionName}(): Specified max value is not an integer: '${maxVal}'."
		fi
	fi

	## Execute
	if [ -z "${variableValue}" ]; then
		## Empty string
		variableValue=$defaultValue
	elif [ "$(fIsInteger "${variableValue}")" == "false" ]; then
		## Not an integer
		variableValue=$defaultValue
	else
		## Check min/max
		if [ -n "${minVal}" ]; then
			if [ $variableValue -lt $minVal ]; then
				variableValue=$minVal
			fi
		fi
		if [ -n "${maxVal}" ]; then
			if [ $variableValue -gt $maxVal ]; then
				variableValue=$maxVal
			fi
		fi
	fi

	## Stuff the validated integer back into the specified variable
	eval "${variableName}=${variableValue}"

	## Debug
	#fEcho_VariableAndValue variableName
	#fEcho_VariableAndValue variableValue
	#fEcho_VariableAndValue defaultValue

}


function fIsProcessRunning(){ :;
	local -r functionName="fIsProcessRunning"
	#@	Purpose: Returns "true" if partial process match is running.
	#@	Arguments:
	#@		1 [REQUIRED]: Partial process name.
	#@	Returns via echo: "true" or "false"
	#@	Modifies:
	#@	Warnings:
	#@		- Be sure to give it a complete enough name to avoid false matches.
	##	History:
	##		- 20190525 JC: Created.
	fEcho_IfDebug "${functionName}()"

	## Constants

	## Args
	local -r procName="$1"

	## Variables
	local returnVal="false"

	## Validate
	fFunctionArgumentCannotBeEmpty "${functionName}()" 1 "$1"
	fMustBeInPath ps

	## Execute
	if [ -n "$(ps ax 2> /dev/null | grep -i "${procName}" 2> /dev/null | grep -iv "grep" 2> /dev/null || true)" ]; then
		returnVal="true"
	fi

	echo "${returnVal}"

}


function fWaitForProcessToEnd(){
	local -r functionName="fWaitForProcessToEnd"
	#@	Purpose:
	#@		- Waits in a loop until a partial process name disappears.
	#@	Arguments:
	#@		1 [REQUIRED]: Process name (partial regex match) to watch for.
	#@		2 [optional]: Seconds to wait before watching, to give it time to start.
	#@		3 [optional]: Seconds to wait before timing out and returning whether closed or not (without error).
	#@	Warnings:
	#@		- Be sure to give it a complete enough name to avoid false matches.
	#@	Example[s]:
	#@		1: fCloseKillProcess "nemo" 30
	##	History:
	##		- 20190128 JC: Created.
	##		- 20190525 JC: Moved into 0_library_v2.
	##		- 20190525 JC: Added timeout optional argument.
	fEcho_IfDebug "${functionName}()"

	## Constants
	local -r defaultWaitBeforeChecking=0
	local -r defaultTimeout=0  ## 0 means never timeout

	## Args
	local -r procName="$1"
	local waitBeforeChecking="$2"
	local timeout=$3

	## Variables
	local doExitLoop="false"
	local elapsedTime=0
	local wasEverRunning="false"

	## Validate
	fFunctionArgumentCannotBeEmpty "${functionName}()" 1 "$1"
	fMustBeInPath ps

	## Init ...... VariableName ...... DefaultValue ................ MinValue
	fInit_Integer  waitBeforeChecking  $defaultWaitBeforeChecking    0
	fInit_Integer  timeout             $defaultTimeout               0

	## See if it's running now, for later information:
	if [ "$(fIsProcessRunning "${procName}")" == "true" ]; then 
		wasEverRunning="true"
	fi

	## Wait for launch before checking
	if [ ${waitBeforeChecking} -gt 0 ]; then
		#fEcho "Waiting ${waitBeforeChecking} seconds before checking for process '${procName}' ..."
		sleep ${waitBeforeChecking}
	fi

	## Watch process and exit when it disappears
	doExitLoop="false"
	elapsedTime=0
	while [ "${doExitLoop}" == "false" ]; do
		if [ "$(fIsProcessRunning "${procName}")" == "false" ]; then 
			doExitLoop="true"
			if [ "${wasEverRunning}" == "true" ]; then
				fEcho "Process '${procName}' ended ..."
			fi
		else
			if [ $timeout -gt 0 ]; then
				if [ $elapsedTime -gt $timeout ]; then
					doExitLoop="true"
					fEcho "Timed-out waiting for process '${procName}' to end ..."
				fi
			fi
			if [ "${doExitLoop}" == "false" ]; then
				sleep 1  ## Has to be one for timeout seconds to work accurately
				elapsedTime=$((elapsedTime+1))  ## Increment ET
			fi
		fi
	done

}


function fCloseKillProcess(){
	local -r functionName="fCloseKillProcess"
	#@	Purpose:
	#@		- Tries to close a process, waiting for a specified timeout.
	#@		- If process doesn't close cleanly by then, it is killed with -9.
	#@		- If it still won't close, an error is thrown.
	#@	Arguments:
	#@		1 [REQUIRED]: Partial process name match to kill.
	#@		2 [optional]: Seconds to wait for clean close before killing with -9. Defaults to 0 (never).
	#@	Warnings:
	#@		- Be sure to give it a complete enough name to avoid false matches.
	#@	Example[s]:
	#@		1: fCloseKillProcess "nemo" 30
	##	History:
	##		- 20190525 JC: Created
	fEcho_IfDebug "${functionName}()"

	## Constants
	local -r defaultTimeout=0

	## Args
	local -r procName="$1"
	local timeout=$2

	## Validate
	fFunctionArgumentCannotBeEmpty "${functionName}()" 1 "$1"
	fMustBeInPath killall

	## Init ...... VariableName ...... DefaultValue ................ MinValue
	fInit_Integer  timeout             $defaultTimeout               0

	## Execute ##

	## Initial close attempt
	if [ "$(fIsProcessRunning "${procName}")" == "false" ]; then 
		fEcho "Process '${procName}' isn't running."
	else
		fEcho "Closing '${procName}' cleanly ..."
		killall "${procName}" 2> /dev/null || true
		fWaitForProcessToEnd "${procName}" 0 $timeout
	fi

	## Kill -9 if still running (allow to error)
	if [ "$(fIsProcessRunning "${procName}")" == "true" ]; then 
		if [ $timeout -gt 0 ]; then
			fEcho "Force-closing '${procName}' ..."
			killall -9 "${procName}" 2> /dev/null || true
			sleep 1
		fi
	fi

	if [ "$(fIsProcessRunning "${procName}")" == "true" ]; then
		fThrowError "${functionName}(): Process[es] '${procName}' could not all be closed."
	fi

}


function fAutoDocument(){ :;
	local -r functionName="fAutoDocument"
	#@	Purpose: Generate a list of functions, descriptions, etc.
	#@	Arguments:
	#@		1 [REQUIRED]: Shell script to document.
	#@	Returns via echo: List of functions and their descriptions.
	##	History:
	##		- 20190201 JC: Created.
	##		- 20190201 JC: Passed unit tests.
	fEcho_IfDebug "${functionName}()"

	## Constants
	spaces="  "

	## Args
	local -r shellScriptToDocument="$1"

	## Variables
	local functionList=""
	local newFunctionList=""
	local thisLineIsAutodoc=""
	local previousLineWasAutodoc="false"

	## Init

	## Validate
	fFileMustExist "${shellScriptToDocument}"

	## Execute
	functionList="$(cat "${shellScriptToDocument}")"  ## Yes I know grep can do this in one fewer pass. But I want to keep grep stuff together. It's not cat abuse.

	## Whittle down
	functionList="$(echo "${functionList}" | grep -iEv "[^a-z0-9]#[^@]"                2> /dev/null || true)"  ## Exclude comments
	functionList="$(echo "${functionList}" | grep -iEo "function [^\(\)]+\(\)|#@.*\$"  2> /dev/null || true)"  ## Extract function and autodoc lines

	newFunctionList=""
	thisLineIsAutodoc="false"
	while read -r line; do
		if [ -n "$(echo "${line}" | awk '{$1=$1};1' 2> /dev/null || true)" ]; then

			## Per-line type processing
			if [ -n "$(echo "${line}" | grep -iEo "#@.*" 2> /dev/null || true)" ]; then :;

				## Autodoc line
				thisLineIsAutodoc="true"
				line="$(echo "${line}" | sed -E $'s/\t/  /g' 2> /dev/null || true)"

			else :;

				## Function line
				thisLineIsAutodoc="false"
				line="$(echo "${line}" | grep -iEo " [^ ]*"          2> /dev/null || true)"  ## Only the part after 'function '
				line="$(echo "${line}" | grep -iEo "[^\ \(\)]*"      2> /dev/null || true)"  ## Only the function name
				line="${line}()"

			fi

			## Prepend newline (if function list isn't empty).
			if [ -n "${newFunctionList}" ]; then
				line="\n${line}"
				## Prepend an EXTRA newline if last line was an autodoc line (and not empty)
				if [ "${previousLineWasAutodoc}" == "true" ] && [ "${thisLineIsAutodoc}" == "false" ]; then :;
			    	line="\n${line}"
			    fi
			fi

		    ## Bottom of loop init
		    previousLineWasAutodoc="${thisLineIsAutodoc}"
	    	newFunctionList="${newFunctionList}${line}"
	    fi
	done <<< "$functionList"

	## Output final string
	echo -e "${newFunctionList}"
}


## ----------------------------------------------------------------------------------------
function fStrNormalize() {
	##	Purpose:
	##		- Strips leading and trailing spaces from string.
	##		- Changes all whitespace inside a string to single spaces.
	##	References:
	##		- https://unix.stackexchange.com/a/205854
	##	History
	##		- 20190701 JC: Created
	local argStr="$@"
	argStr="$(echo "${argStr}" | awk '{$1=$1};1' 2> /dev/null || true)"
	echo "${argStr}"
}

function fStrPtr_Trim() {
	##	History:
	##		- 20180228 JC: Created.
	if [ -n "$1" ]; then

		## Get variable name and contents
		local variableName="$1"
		local variableVal="${!variableName}"
		local toGrep=" $(printf '\t')$(printf '\n')"

		## Trim; works
		variableVal="$(echo -e "${variableVal}" | sed 's/ *$//')"
		#variableVal="$(echo -n "$(echo -e "${variableVal}")")"

		## Stuff restuls back into variable
		eval "${variableName}=\"\${variableVal}\""

	fi
}


##----------------------------------------------------------------------------------------------------
function fStrAppend2(){ :;
	local -r functionName="fStrAppend2"
	#@	Purpose:
	#@		Same as fStrAppend(), but:
	#@			- A different order of arguments
	#@			- Added two new optional arguments.
	#@			- Eval changed from:
	#@				eval "${variableName}=\"${returnStr}\""
	#@			  To:
	#@				eval "${variableName}=\"\${returnStr}\""
	#@			  Because it was discovered in j.hdd-torture-test that it didn't work otherwise.
	#@		In almost all cases, you only need to specify the first three arguments and it will work exactly as expected.
	#@	Arguments:
	#@		1 [REQUIRED]: Name of variable this function can see and modify.
	#@		2 [optional]: Delimiter to prepend or append [default: prepend only if existing string is not empty, and whether or not append string is empty].
	#@		3 [optional]: New string to append.
	#@		4 [optional]: Prepend delimiter even if existing string is empty? (true or false; default=false).
	#@		5 [optional]: Add delimiter even if new string is empty? (true or false; default=true).
	##	Modifies:
	##		- The variable with the name passed as arg 1.
	##	History:
	##		- 20190113 JC: Created fStrAppend().
	##		- 20190131 JC: Copied to fStrAppend2()and modified.
	fEcho_IfDebug "${functionName}()"

	## Args
	local -r variableName="$1"
	local -r delimiter="$2"
	local -r appendStr="$3"
	local doPrependDelimiterEvenIfOrigStrIsEmpty="$4"
	local doAddDelimiterEvenIfAppendStrIsEmpty="$5"

	## Constants
	local -r origStr="${!variableName}"

	## Variables
	local bitmappedOptions=""
	local returnStr=""

	## Default return
	eval "${variableName}=\"\""

	## Init
	doPrependDelimiterEvenIfOrigStrIsEmpty="${doPrependDelimiterEvenIfOrigStrIsEmpty,,}"
	doAddDelimiterEvenIfAppendStrIsEmpty="${doAddDelimiterEvenIfAppendStrIsEmpty,,}"
	if [ "${doPrependDelimiterEvenIfOrigStrIsEmpty}" != "true" ];  then doPrependDelimiterEvenIfOrigStrIsEmpty="false";  fi
	if [ "${doAddDelimiterEvenIfAppendStrIsEmpty}" != "false" ];   then doAddDelimiterEvenIfAppendStrIsEmpty="true";     fi


	##
	## Determine whether or not to include delimiter
	##

	## Calc bitmapped flags
	local bit_isPopulated_OrigStr="0";              if [ -n "${origStr}" ];                                        then bit_isPopulated_OrigStr="1";              fi
	local bit_PrependDelimEvenIf_OrigStrEmpty="0";  if [ "${doPrependDelimiterEvenIfOrigStrIsEmpty}" == "true" ];  then bit_PrependDelimEvenIf_OrigStrEmpty="1";  fi
	local bit_isPopulated_appendStr="0";            if [ -n "${appendStr}" ];                                      then bit_isPopulated_appendStr="1";            fi
	local bit_AddDelimEvenIf_appendStrEmpty="0";    if [ "${doAddDelimiterEvenIfAppendStrIsEmpty}" == "true" ];    then bit_AddDelimEvenIf_appendStrEmpty="1";    fi
	local -r bitmappedOptions="${bit_isPopulated_OrigStr}${bit_PrependDelimEvenIf_OrigStrEmpty}${bit_isPopulated_appendStr}${bit_AddDelimEvenIf_appendStrEmpty}"

	## Decision matrix
	##	1: origStr is populated.
	##	2: Add delimiter even if OrigStr is empty [but not if appendStr is also empty, unless #4 is also true].
	##	3: appendStr is populated.
	##	4: Add delimiter even if appendStr is empty [but not if origStr is also empty, unless #2 is also true.]
	local doAddDelimiter="false"  ## Probably faster to set default, and only check for override conditions.
	if [ -n "${delimiter}" ]; then
		case "${bitmappedOptions}" in
		#	"0000") doAddDelimiter="false"  ;;  ## Obvious (empty string)
		#	"0001") doAddDelimiter="false"  ;;
		#	"0010") doAddDelimiter="false"  ;;
		#	"0011") doAddDelimiter="false"  ;;
		#	"0100") doAddDelimiter="false"  ;;
			"0101") doAddDelimiter="true"   ;;
			"0110") doAddDelimiter="true"   ;;
			"0111") doAddDelimiter="true"   ;;
		#	"1000") doAddDelimiter="false"  ;;
			"1001") doAddDelimiter="true"   ;;
			"1010") doAddDelimiter="true"   ;;  ## Obvious (orig and append are populated)
			"1011") doAddDelimiter="true"   ;;  ## Obvious (orig and append are populated)
		#	"1100") doAddDelimiter="false"  ;;
			"1101") doAddDelimiter="true"   ;;
			"1110") doAddDelimiter="true"   ;;
			"1111") doAddDelimiter="true"   ;;  ## Obvious
		esac
	fi

	## Debug
	#fEcho_VariableAndValue bitmappedOptions
	#fEcho_VariableAndValue doAddDelimiter

	##
	## Calculate return string
	##

	returnStr="${origStr}"
	if [ "${doAddDelimiter}" == "true" ]; then
		returnStr="${returnStr}${delimiter}"
	fi
	returnStr="${returnStr}${appendStr}"

	## Return
	eval "${variableName}=\"${returnStr}\""

}


##----------------------------------------------------------------------------------------------------
function fStrAppend(){ :;
	local -r functionName="fStrAppend"
	##	Purpose:
	##		Given a name of a variable, appends a string to it.
	##	Arguments:
	##		1 [REQUIRED]: Name of variable this function can see and modify.
	##		2 [optional]: New string to append.
	##		3 [optional]: Delimiter to prepend, if existing string is not empty.
	##		4 [optional]: Prepend delimiter even if new string is empty? (true or false; default=true).
	##	Modifies:
	##		- The variable with the name passed as arg 1.
	##	Example[s]:
	##			fStrAppend myVariable "Adam" ", "; echo "myVariable='${myVariable}'."
	##				myVariable='Adam'.
	##			fStrAppend myVariable "Bob" ", "; echo "myVariable='${myVariable}'."
	##				myVariable='Adam, Bob'.
	##			fStrAppend myVariable "" ", "; echo "myVariable='${myVariable}'."
	##				myVariable='Adam, Bob, '.
	##			fStrAppend myVariable "Cole" ", "; echo "myVariable='${myVariable}'."
	##				myVariable='Adam, Bob, , Cole'.
	##			fStrAppend myVariable "" ", " false; echo "myVariable='${myVariable}'."
	##				myVariable='Adam, Bob, , Cole'.
	##	History:
	##		- 20190113 JC: Created.
	fEcho_IfDebug "${functionName}()"

	## Args
	local -r variableName="$1"
	local -r strToAppend="$2"
	local -r delimiterToPrepend="$3"
	local doAddDelimiterEvenIfAppendStrIsEmpty="$4"

	## Constants
	local -r variableVal="${!variableName}"

	## Variables
	local returnStr=""

	## Default return
	eval "${variableName}=\"${returnStr}\""

	## Init
	doAddDelimiterEvenIfAppendStrIsEmpty="${doAddDelimiterEvenIfAppendStrIsEmpty,,}"
	if [ "${doAddDelimiterEvenIfAppendStrIsEmpty}" != "false" ]; then doAddDelimiterEvenIfAppendStrIsEmpty="true"; fi

	##
	## Calc
	##

	## Prepend delimiter
	if [ -n "${variableVal}" ]; then
		if [ -n "${strToAppend}" ] || [ "${doAddDelimiterEvenIfAppendStrIsEmpty}" == "true" ]; then
			returnStr="${delimiterToPrepend}"
		fi
	fi

	## Append string to [maybe delimiter]
	returnStr="${returnStr}${strToAppend}"

	## Append [maybe delimiter][maybe new sring] to existing string
	returnStr="${variableVal}${returnStr}"

	## Return
	eval "${variableName}=\"${returnStr}\""

}


##----------------------------------------------------------------------------------------------------
function fStr_GetRegexMatchOnly_EchoReturn(){ :;
	##	Purpose:
	##		Calls fStr_GetRegexMatchOnly and echoes the return.
	##		Saves the user from having to use a temp variable, but also comes with increased brittleness; use with caution.
	##	History:
	##		- 20190113 JC: Created.

	## Args
	local -r stringToInspect2="$1"
	local -r regexOnly2="$2"

	## Variables	
	local retVal_98gbxq=""

	local errHandling_Prev="$(_fprivateErrHandling_ByStr_Set_Ignore)"
		fStr_GetRegexMatchOnly retVal_98gbxq "${stringToInspect2}" "${regexOnly2}"
	_fprivateErrHandling_ByStr_Set "${errHandling_Prev}" 1> /dev/null

	echo "${retVal_98gbxq}"
}

##----------------------------------------------------------------------------------------------------
function fStr_GetRegexMatchOnly(){ :;
	local -r functionName="fStr_GetRegexMatchOnly"
	##	Purpose:
	##		Returns a string of ONLY the matching portion of a regex, or empty if nothing matched.
	##	Arguments:
	##		1 [REQUIRED]: Variable name to set with return value.
	##		2 [REQUIRED]: String to test.
	##		2 [REQUIRED]: Regex to test against (only matching portion will be returned).
	##	Modifies:
	##		Variable with name that is passed as first argument.
	##	Example[s]:
	##		1: fStr_GetRegexMatchOnly myVariable "My dog has 37 FLEAS on his ear!" "[0-9]+ fleas"
	##			$myVariable will be set to "37 FLEAS".
	##		2: fStr_GetRegexMatchOnly myVariable "123-45-Yohoo-6789" "^[0-9]{3}-[0-9]{2}-[0-9]{4}\$"
	##			$myVariable will be set to "".
	##	History:
	##		- 20190113 JC: Created.
	fEcho_IfDebug "${functionName}()"

	## Arguments
	local -r returnVariableName="$1"
	local -r stringToInspect="$2"
	local -r regexOnly="$3"

	## Variables
	retval_fStr_GetRegexMatchOnly=""

	## Set default return value
	eval "${returnVariableName}=\"${retval_fStr_GetRegexMatchOnly}\""

	## Execute
	retval_fStr_GetRegexMatchOnly="$(echo "${stringToInspect}" | grep -iEo "${regexOnly}" 2> /dev/null || true)"

	### Debug
	#fEcho_VariableAndValue returnVariableName
	#fEcho_VariableAndValue stringToInspect
	#fEcho_VariableAndValue regexOnly
	#fEcho_VariableAndValue retval_fStr_GetRegexMatchOnly

	## Set return value
	eval "${returnVariableName}=\"\${retval_fStr_GetRegexMatchOnly}\""
}


##----------------------------------------------------------------------------------------------------
function fErrBehavior_Set(){
	##	Purpose ...............: Restores error handling to a previous state.
	##	Input..................: String previously returned by fErrBehavior_Get() - "fatal", "ignore", or "warn".
	##	Console output ........: May echo warnings.
	##  Other side-effects ....: May change error handling.
	##	History:
	##		- 20180107 JC: Created.

	## Test if input valid
	case "${1,,}" in

		## Standard valid inputs
		"fatal")  fErrBehavior_Set_Fatal  ;;
		"ignore") fErrBehavior_Set_Ignore ;;
		"warn")   fErrBehavior_Set_Ignore ;;  ## Don't yet have warn, so just use ignore for now. TODO: make

		## Avoid throwing an error on bad input, here since we're already dealing with error-related stuff. Just set to default.
		*)
			echo "Warning: ${__qualifiedNameOfThisLibrary}.fErrBehavior_Set(): Resetting error handling to 'fatal', since the function input value is not valid: '${1}'."
			fErrBehavior_Set_Fatal
			;;

	esac
}


##----------------------------------------------------------------------------------------------------
function fErrBehavior_Get(){
	##	Purpose ...............: Retrieves the current error-handling state.
	##	Echos to caller .......: "fatal", "ignore", "warn", or "error".
	##  Other side-effects ....: May reset error handling to fatal, if it determines something got messed up.
	##	History:
	##		- 20180107 JC: Created.

	## Test if current value for $__errBehavior_Current is even valid
	case "${__errBehavior_Current,,}" in

		## Standard valid inputs
		"fatal"|"ignore"|"warn") : ;;

		## Value either got munged, or never set somehow. Either way just set to default.
		*) fErrBehavior_Set_Fatal ;;

	esac

	## Return the value
	echo "${__errBehavior_Current}"
}


##----------------------------------------------------------------------------------------------------
function fErrHandling_Get(){ :;
	##	Purpose:
	##		Gets error handling in the form of a string with zero, one, or more of "e" or "E" in any order.
	##	Arguments:
	##		(none)
	##	Returns via echo:
	##		Zero, one, or more of "e" or "E" in any order
	##	Modifies:
	##		(nothing)
	##	History:
	##		- 20180819 JC: Created.
	local returnStr=""
	if [[ "$-" == *"e"* ]]; then returnStr="${returnStr}e"; fi
	if [[ "$-" == *"E"* ]]; then returnStr="${returnStr}E"; fi
	echo "${returnStr}"
}


##----------------------------------------------------------------------------------------------------
function fErrHandling_Set(){ :;
	##	Purpose:
	##		Sets error handling with a string containing zero, one, or more of "e" or "E" in any order.
	##	Arguments:
	##		A string with zero, one, or more of "e" or "E" in any order. Where:
	##			"e": Break on errors. If not included, errors are ignored
	##			"E": Include called files. If not included, ignored.
	##	Returns via echo:
	##		String of previous state.
	##	Modifies:
	##		(nothing)
	##	History:
	##		- 20180819 JC: Created.
	local prevVal="$(fErrHandling_Get)"
	if [[ "$1" == *"e"* ]]; then set -e; else set +e; fi
	if [[ "$1" == *"E"* ]]; then set -E; else set +E; fi
	echo "${prevVal}"
}

##----------------------------------------------------------------------------------------------------
function fErrHandling_Set_Ignore(){ :;
	##	Purpose:
	##		Sets error handling to ignore errors.
	##	Arguments:
	##		(none)
	##	Returns via echo:
	##		String of previous state.
	##	Modifies:
	##		(nothing)
	##	History:
	##		- 20180819 JC: Created.
	local prevVal="$(fErrHandling_Get)"
	fErrHandling_Set ""
	echo "${prevVal}"
}


##----------------------------------------------------------------------------------------------------
function fErrHandling_Set_Fatal(){ :;
	##	Purpose:
	##		Gets error handling in the form of a string with zero, one, or more of "e" or "E" in any order.
	##	Arguments:
	##		(none)
	##	Returns via echo:
	##		String of previous state.
	##	Modifies:
	##		(nothing)
	##	History:
	##		- 20180819 JC: Created.
	local prevVal="$(fErrHandling_Get)"
	fErrHandling_Set "eE"
	echo "${prevVal}"
}


##----------------------------------------------------------------------------------------------------
function fArray_IsSet_1ndex(){ :;
	##	Purpose:
	##		- Given an array (by reference), determines if specified index exists.
	##		- Presents array index starting at 1 (rather than native 0).
	##	Arguments:
	##		1 [REQUIRED]: The name of an array variable. Must be visible in scope to this function.
	##		2 [REQUIRED]: An integer >=1.
	##	Returns via echo:
	##		"true" or "false"
	##	Modifies:
	##		(nothing)
	##	Example[s]:
	##		1: 
	##	History:
	##		- 20180611 JC: Created.

	## Arguments
	local arrayName="$1"
	local index="$2"

	## Variables
	local -a tmpArray
	local returnBool="false"
	local itemCount=-1

	## Validate
	fFunctionArgumentCannotBeEmpty "fArray_IsSet_1ndex()" 1 "$1" "Name of an array variable visible to this scope."
	fFunctionArgumentCannotBeEmpty "fArray_IsSet_1ndex()" 2 "$2" "1-based integer index."
	fVariableCannotBeEmpty arrayName
	fVariableCannotBeEmpty index
	[ "$(fIsNum_Integer "${index}")" == "false" ] && fThrowError "fArray_IsSet_1ndex(): Second argument must be an 1-based integer index." 

	## Init
	index=$(( ${index} - 1 ))

	set +e

		## Copy the array so we can access it directly
		tmpArray=()
		eval "tmpArray=( \"\${$arrayName[@]}\" )"
		itemCount=${#tmpArray[@]}

		if [ ${itemCount} -gt 0 ]; then :;
			if [ ${index} -ge 0 ]; then :;
				if [ ${itemCount} -gt ${index} ]; then :;
					if [ "${tmpArray[${index}]+isset}" ]; then :;
				        returnBool="true"
					fi
				fi
			fi
		fi
	true; set -e

	echo "${returnBool}"

}


##----------------------------------------------------------------------------------------------------
function fArray_GetItemBy_1ndex(){ :;
	##	Purpose:
	##		- Given a 1-based index, returns the value.
	##		- Presents array index starting at 1 (rather than native 0).
	##	Arguments:
	##		1 [REQUIRED]: The name of an array variable. Must be visible in scope to this function.
	##		2 [REQUIRED]: An integer >=1.
	##	Returns via echo:
	##		The value, if avalialable, of the index item.
	##	Modifies:
	##		(nothing)
	##	Example[s]:
	##		1: 
	##	History:
	##		- 20180611 JC: Created.

	## Arguments
	local arrayName="$1"
	local index="$2"

	## Variables
	local returnVal=""

	## Proceed only if there is anything to get
	if [ "$(fArray_IsSet_1ndex ${arrayName} ${index})" == "true" ]; then :;

		## Copy the array so we can access it directly
		local -a tmpArray
		tmpArray=()
		eval "tmpArray=( \"\${$arrayName[@]}\" )"

		## Init
		index=$(( ${index} - 1 ))

		## Get the element
		set +e
			returnVal="${tmpArray[${index}]}"
		true; set -e

	fi

	echo "${returnVal}"
}


##----------------------------------------------------------------------------------------------------
function fLog_Init(){ :;
	##	Purpose: Initializes log file.
	##	Modifies:
	##		Log file specified by vmsLog_Filespec
	##	Notes:
	##		- You don't have to call this. If logfile doesn't exist, fLog_WriteLine() will call this.
	##	History:
	##		- 20171217 JC: Created.

	## Validate global values
	fVariableCannotBeEmpty vmsLog_Folder  ## Set at top (bottom) of this script
	fVariableCannotBeEmpty vmsMe_Name

	if [ -n "${vmsLog_Filespec}" ]; then :;
		fLog_WriteLine "Another call to fLog_Init() was made, even though it's already been started."
	else :;

		## Init
		vmsSerial="$(fGetTimeStamp)"
		vmsLog_Filespec="${vmsLog_Folder}/${vmsMe_Name}_${vmsSerial}.log"

		## Validate
		fVariableCannotBeEmpty vmsSerial
		fVariableCannotBeEmpty vmsLog_Filespec

		if [ -z "${vmsLog_Filespec}" ]; then :;
			fThrowError "No log file specified by variable 'vmsLog_Filespec'."
		elif [ -f "${vmsLog_Filespec}" ]; then :;
			fThrowError "Log file '${vmsLog_Filespec}' already exists."
		else :;

			## Make directory and set ownership if necessary
			if [ ! -d "${vmsLog_Folder}" ]; then :;
				mkdir -p "${vmsLog_Folder}"
				fDefineTrap_Error_Ignore
					chown ${USER} "${vmsLog_Folder}"
				fDefineTrap_Error_Fatal
			fi

			## Create the file and set ownership
			touch "${vmsLog_Filespec}"
			fDefineTrap_Error_Ignore
				chown ${USER} "${vmsLog_Filespec}"
			fDefineTrap_Error_Fatal

			## Write a line
		#	fLog_WriteLine "Logging started."

		fi
	fi
}


##----------------------------------------------------------------------------------------------------
function fLog_GetFilespec(){ :;
	##	History:
	##		- 20171217 JC: Created.
	echo "${vmsLog_Filespec}"
}


##----------------------------------------------------------------------------------------------------
function fLog_WriteLine(){ :;
	##	Purpose: Writes something to the log file.
	##	Modifies:
	##		Log file specified by vmsLog_Filespec.
	##	Notes:
	##		- Linefeeds are replaced with " [linefeed] "
	##	History:
	##		- 20171217 JC: Created.
	##		- 20180107 JC: Fixed bug: vmsLog_Filespec="" if fLog_Init() not called first. Ideally this function should never error.

	local vlsLine="$@"

	## Check to see if we need to initialize the log
	if [ -z "${vmsLog_Filespec}" ]; then fLog_Init; fi
	if [ ! -f "${vmsLog_Filespec}" ]; then fLog_Init; fi

	## Generate the line to write
	local vlsTimestamp="$(fGetTimeStamp)"  #........................ Get timestamp.
	vlsLine="${vlsLine//$'\n'/'--[newline]--'}"  #................... Replace newline with " [newline] ".

	## Write the line
	echo "${vlsTimestamp}: ${vlsLine}" >> "${vmsLog_Filespec}"  #... Write the line to the log.

}


##----------------------------------------------------------------------------------------------------
function fEchoAndLog(){ :;
	##	History:
	##		- 20171217 JC: Created.
	fEcho "$@"
	fLog_WriteLine "$@"
}


##----------------------------------------------------------------------------------------------------
function fDoAndLog(){ :;
	##	History:
	##		- 20171217 JC: Created.
	fEchoAndLog "Executing: $@"
	fDefineTrap_Error_Ignore
		local vlsResult="$(eval "$@ 2>&1")"
	fDefineTrap_Error_Fatal
	echo -e "${vlsResult}"
	fLog_WriteLine "${vlsResult}"
}


##----------------------------------------------------------------------------------------------------
function fDoAndLog_PackedArgs(){ :;
	##	TODO:
	##		- Like fDoAndLog(), but ingest and handle packed args
	##		- Future edit ID: 9df8d781-e592-42b7-8edc-c2800bb575d6
}


##----------------------------------------------------------------------------------------------------
function fDoSilentlyAndLog(){ :;
	##	History:
	##		- 20171217 JC: Created.
	fLog_WriteLine "Executing: $@"
	fDefineTrap_Error_Ignore
		fLog_WriteLine "$(eval "$@ 2>&1")"
	fDefineTrap_Error_Fatal
}


##----------------------------------------------------------------------------------------------------
function fDoSilentlyAndLog_PackedArgs(){ :;
	##	TODO:
	##		- Like fDoSilentlyAndLog(), but ingest and handle packed args
	##		- Future edit ID: 9df8d781-e592-42b7-8edc-c2800bb575d6
}


##----------------------------------------------------------------------------------------------------
function fThrowErrorAndLog(){ :;
	##	History:
	##		- 20171217 JC: Created.
	fLog_WriteLine "$@"
	fThrowError "$@"
}

##----------------------------------------------------------------------------------------------------
function fLog_Close(){ :;

	## Check if log is specified and exists
	if [ -n "${vmsLog_Filespec}" ]; then :;
		if [ -f "${vmsLog_Filespec}" ]; then :;

			## Write last line
		#	fLog_WriteLine "Logging stopped."

			## Set ownership
			fDefineTrap_Error_Ignore
				chown ${USER} "${vmsLog_Filespec}"
			fDefineTrap_Error_Fatal

			## Clear variables
		#	vmsSerial=""
		#	vmsLog_Filespec=""

		fi
	fi
}

##----------------------------------------------------------------------------------------------------
function fAssert_AreEqual_EvalFirstArg(){ :;
	## 20180611 JC: Created.

	## Args
	local vlsEval="$1"
	local vlsExpectedResult="$2"
	local vlsDescription="$3"

	## Variables
	local vlsEvalResult=""
	local vlsOutput=""

	## Eval
	fDefineTrap_Error_Ignore
		vlsEvalResult="$(eval "$1")"
	fDefineTrap_Error_Fatal

	## Build output string, part 1 of 2
	vlsOutput="Expression: '${vlsEval}'; Expected: '${vlsExpectedResult}'; Actual result: '${vlsEvalResult}'"
	[ -n "${vlsDescription}" ] && vlsOutput="${vlsOutput}; Description: ${vlsDescription}"

	## Output
	if [ "${vlsEvalResult}" == "${vlsExpectedResult}" ]; then :;
		fAssertResult_Msg_Passed "${vlsOutput}"
	else :;
		fAssertResult_Msg_Failed "${vlsOutput}"
	fi
}


##----------------------------------------------------------------------------------------------------
function fAssert_AreEqual(){ :;
	## 20171217 JC: Created.
	local vlsString1="$1"
	local vlsString2="$2"
	local vlsDescription="$3"
	if [ "${vlsString1}" == "${vlsString2}" ]; then :;
		fAssertResult_Msg_Passed "${vlsDescription}"
	else :;
		fAssertResult_Msg_Failed "${vlsDescription}"
	fi
}
function fAssertResult_Msg_Passed()     { echo "pass .......: $@"; }
function fAssertResult_Msg_Failed()     { echo "FAILURE ****: $@"; }
function fUnitTest_StartSection(){ echo; echo "-------- $@"; }


##----------------------------------------------------------------------------------------------------
function fIsString_PackedArgs(){ :;
	##	Purpose:
	##		Returns "true" if the string is some result of fPackArgs().
	##	Input:
	##		Anything or nothing.
	##	History:
	##		- 20171217 JC: Created.

	## Variables.
	local vlsInput="$@"
	local vlbReturn="false"

	if [[ "${vlsInput}" =~ ^⦃packedargs-begin⦄.*⦃packedargs-end⦄$ ]]; then :;
		local vlbReturn="true"
	fi

	echo "${vlbReturn}"

}


##----------------------------------------------------------------------------------------------------
function fPackedArgs_GetCount(){ :;
	##	Purpose:
	##		Given a packedargs string, returns the number of arguments.
	##	Input:
	##		Some result of fPackArgs()
	##	History:
	##		- 20171217 JC: Created.

	## Variables.
	local vlsInput="$@"
	local vlwReturnCount=0
	local vlsItem_Unpacked=""

	if [[ "${vlsInput}" =~ ^⦃packedargs-begin⦄.*⦃packedargs-end⦄$ ]]; then :;

		## Strip wrapper off
		vlsInput="$(echo "${vlsInput}" | sed "s/⦃packedargs-begin⦄//g")"
		vlsInput="$(echo "${vlsInput}" | sed "s/⦃packedargs-end⦄//g")"

		## Parse into array on "_"
		local vlsPrev=$IFS
		#IFS="_"
		IFS="☊"  ## 20190615 JC: Changed from _ to ☊ because _ was turning up in unpacked strings somehow. Not sure if this will fix it.
			local -a vlsArray=($vlsInput)
		IFS="${vlsPrev}"

		## Return array length, which is the count of arguments
		vlwReturnCount=${#vlsArray[@]}
		if [ "$(fIsInteger $vlwReturnCount)" != "true" ]; then :;
			vlwReturnCount=0
		fi

		## Check for empty array
		if [ $vlwReturnCount -eq 1 ]; then :;
			if [ "${vlsArray[0]}" == "" ]; then :;
				vlwReturnCount=0
			fi
		fi

		## We should never have a single element of "⦃empty⦄", unless explicitly passed to fPackArgs().
		#if [ vlwReturnCount -eq 1 ]; then :;
		#	if [ "${vlsArray[0]}" == "⦃empty⦄" ]; then :;
		#		vlwReturnCount=0
		#	fi
		#fi

	fi

	echo $vlwReturnCount

}


##----------------------------------------------------------------------------------------------------
function fUnpackArg_Number(){ :;
	##	Purpose:
	##		Given a packedargs string, and an argument number, returns a value.
	##		withouting getting fubar'ed by spaces and quotes.
	##	Input:
	##		1 [REQUIRED]: A packed arg string.
	##		2 [REQUIRED]: Integer >0 and < fPackedArgs_GetCount()
	##	History:
	##		- 20171217 JC: Created.

	## Input
	local vlsInput="$1"
	local vlwArgNum=$2

	## Variables
	local vlsReturn=""
	local vlsItem_Packed=""
	local vlsItem_Unpacked=""
	local vlwArgCount=0
	local vlwGetArrayIndex=0

	## Validation variables
	local vlbIsValid_PackedArg="false"
	local vlbIsValid_ArgNum="false"

	## Validate part 1/2
	if [ -n "${vlsInput}" ]; then :;
		if [[ "${vlsInput}" =~ ^⦃packedargs-begin⦄.*⦃packedargs-end⦄$ ]]; then :;
			vlbIsValid_PackedArg="true"
			vlwArgCount=$(fPackedArgs_GetCount "${vlsInput}")
			if [ "$(fIsInteger "${vlwArgNum}")" == "true" ]; then :;
				if [ $vlwArgNum -gt 0 ]; then :;
					if [ $vlwArgNum -le $vlwArgCount ]; then :;
						vlbIsValid_ArgNum="true"
					fi
				fi
			fi
		fi
	fi

	## Validate part 2/2
	if [ "${vlbIsValid_PackedArg}" != "true" ]; then :;
		vlsReturn=""
		#fThrowError "Input is not a packed args string."
	elif [ "${vlbIsValid_ArgNum}" != "true" ]; then :;
		vlsReturn=""
		#fThrowError "Argument number (second input) must be >0 and <[argument count]."
	else :;

		## Strip wrapper off
		vlsInput="$(echo "${vlsInput}" | sed "s/⦃packedargs-begin⦄//g")"
		vlsInput="$(echo "${vlsInput}" | sed "s/⦃packedargs-end⦄//g")"

		## Parse into array on "_"
		local vlsPrev=$IFS
		#IFS="_"
		IFS="☊"  ## 20190615 JC: Changed from _ to ☊ because _ was turning up in unpacked strings somehow. Not sure if this will fix it.
			local -a vlsArray=($vlsInput)
		IFS="${vlsPrev}"

		## Calculate the array index, from arg num
		vlwGetArrayIndex=$(( $vlwArgNum - 1 ))

		## Get the value stored in the specified array index
		vlsItem_Packed="${vlsArray[$vlwGetArrayIndex]}"

		## Unpack
		vlsItem_Unpacked="$(fUnpackString "${vlsItem_Packed}")"

		## Set return value
		vlsReturn="${vlsItem_Unpacked}"

	fi

	echo "${vlsReturn}"

}


##----------------------------------------------------------------------------------------------------
function fPackArgs(){ :;
	##	Purpose:
	##		Packs up arguments to allow passing around to functions and scripts,
	##		withouting getting fubar'ed by spaces and quotes.
	##	Input:
	##		Arguments. Can contain spaces, single quotes, double quotes, etc.
	##	Returns via echo:
	##		A packed string that can be safely passed around without getting munged.
	##	History:
	##		- 20161003 JC (0_library): Created.
	##		- 20161003 JC (0_library_v1):
	##			- Renamed from fArgs_Pack() to fPackString().
	##			- Updated "created" date from probably erroneous 2006, to 2016.
	##			- Updated comments.
	##			- Added outer "if" statement to catch null input.
	##		- 20171217 JC (0_library_v2):
	##			- Refactored.
	##			- Add packing header during packing process.
	##			- Check for packing header before packing, to avoid packing more than once.
	##			- Allow for $clwMaxEmptyArgsBeforeBail successive empty values before breaking

	## Constants
	local clwMaxEmptyArgsBeforeBail=8

	## Variables
	local vlsInput="$@"
	local vlsReturn=""
	local vlsCurrentArg=""
	local vlsCurrentArg_Encoded=""
	local vlsEncoded_Final=""
	local vlsEncoded_Provisional=""
	local vlwCount_EmptyArgs=0

	## Debug
	#fEcho_VariableAndValue clwMaxEmptyArgsBeforeBail
	#fEcho_VariableAndValue vlsInput
	#fEcho_VariableAndValue vlsReturn
	#fEcho_VariableAndValue vlsCurrentArg
	#fEcho_VariableAndValue vlsCurrentArg_Encoded
	#fEcho_VariableAndValue vlsEncoded_Final
	#fEcho_VariableAndValue vlsEncoded_Provisional
	#fEcho_VariableAndValue vlwCount_EmptyArgs

	if [[ "${vlsInput}" =~ ^⦃packedargs-begin⦄.*⦃packedargs-end⦄$ ]]; then :;

		## Return already packed input
		vlsReturn="${vlsInput}"

	else :;

		if [ -z "${vlsInput}" ]; then :;
			#vlsReturn="⦃empty⦄"  ## Caused a bug. An actual empty set works.
			vlsReturn=""
		else :;
			while [ $vlwCount_EmptyArgs -lt $clwMaxEmptyArgsBeforeBail ]; do

				## Get the first or next value off the args stack
				fDefineTrap_Error_Ignore
					vlsCurrentArg="$1"; shift; true
				fDefineTrap_Error_Fatal

				## Debug
				#fEcho_VariableAndValue vlsCurrentArg

				## Encode
				vlsCurrentArg_Encoded="$(fPackString "${vlsCurrentArg}")"

				## Debug
				#fEcho_VariableAndValue vlsCurrentArg_Encoded

				## Build provisional result
				if [ -n "${vlsEncoded_Provisional}" ]; then vlsEncoded_Provisional="${vlsEncoded_Provisional}☊"; fi  ## 20190615 JC: Changed from _ to ☊ because _ was turning up in unpacked strings somehow. Not sure if this will fix it.
				vlsEncoded_Provisional="${vlsEncoded_Provisional}${vlsCurrentArg_Encoded}"

				## Debug
				#fEcho_VariableAndValue vlsEncoded_Provisional

				## Handle if current arg is or isn't empty
				if [ -z "${vlsCurrentArg}" ]; then :;
					## Increment sucessive empty counter.
					vlwCount_EmptyArgs=$((vlwCount_EmptyArgs+1))
				else :;
					## Not empty: Set permanent return string (which may make previous empty args part of permanent return).
					vlsEncoded_Final="${vlsEncoded_Provisional}"
					vlwCount_EmptyArgs=0
				fi

				## Debug
				#fEcho_VariableAndValue vlwCount_EmptyArgs

			done

			vlsReturn="${vlsEncoded_Final}"
		fi

		## Wrap
		vlsReturn="⦃packedargs-begin⦄${vlsReturn}⦃packedargs-end⦄"

	fi

	echo "${vlsReturn}"

}


##----------------------------------------------------------------------------------------------------
function fUnpackArgs(){ :;
	##	Purpose:
	##		Unpacks args previously packed with fPackArg(), into its original string.
	##	Arguments:
	##		- 1 [optional]: Packed arguments string originally generated by fPackArgs().
	##	Returns via echo:
	##		- Original string, which due to the original reason for packing and unpacking, may not 
	##		  result in full fidelity. [Better to use something like fUnpackArgs_ToArrayPtr().]
	##	History:
	##		- 20161003 JC (0_library): Created.
	##		- 20161003 JC (0_library_v1):
	##			- Renamed from fArgs_Unpack() to fUnpackString().
	##			- Updated "created" date from probably erroneous 2006, to 2016.
	##			- Updated comments.
	##			- Added outer "if" statement to catch null input.
	##		- 20171217 JC (0_library_v2):
	##			- Refactored.
	##			- Check for packing header before unpacking, to avoid unpacking a non-packed args.
	##			- Remove packing header.

	## Variables.
	local vlsInput="$@"
	local vlsReturn=""
	local vlsItem_Unpacked=""

	if [[ "${vlsInput}" =~ ^⦃packedargs-begin⦄.*⦃packedargs-end⦄$ ]]; then :;

		## Strip wrapper off
		vlsInput="$(echo "${vlsInput}" | sed "s/⦃packedargs-begin⦄//g")"
		vlsInput="$(echo "${vlsInput}" | sed "s/⦃packedargs-end⦄//g")"

		## Parse into array on "_"
		local vlsPrev=$IFS
		#IFS="_"
		IFS="☊"  ## 20190615 JC: Changed from _ to ☊ because _ was turning up in unpacked strings somehow. Not sure if this will fix it.
			local -a vlsArray=($vlsInput)
		IFS="${vlsPrev}"

		## Loop through array
		for vlsItem in "${vlsArray[@]}"; do

			## Debug
			#fEcho_VariableAndValue vlsItem

			## Unpack item
			vlsItem_Unpacked="$(fUnpackString "${vlsItem}")"

			## Add item to return string
			if [ -n "${vlsReturn}" ]; then vlsReturn="${vlsReturn} "; fi
			vlsReturn="${vlsReturn}'${vlsItem_Unpacked}'"

		done

	else :;

		## Return already unpacked input
		vlsReturn="${vlsInput}"

	fi

	echo $vlsReturn

}


##----------------------------------------------------------------------------------------------------
function fUnpackArgs_ToArrayPtr(){ :;
	##	Purpose:
	##		Unpacks args previously packed with fPackString(), into the named array.
	##	Arguments:
	##		- 1 [REQUIRED]: Packed args string.
	##		- 2 [REQUIRED]: The name of an array variable. Must be visible in scope to this function.
	##	Modifies:
	##		- Overwrites the named array.
	##	History:
	##		- 20180306 JC (0_library_v2): Created.

	## Arguments
	local packedArgs="$1"
	local arrayName="$2"

	## Variables
	#local -a tmpArray
	local packedArgsCount=0
	local arrayIndex=0
	local packedargsIndex=0
	local unpackedArg=""

	## Validate
	fFunctionArgumentCannotBeEmpty "fUnpackArgs_ToArrayPtr()" 1 "$1" "packed args"
	fFunctionArgumentCannotBeEmpty "fUnpackArgs_ToArrayPtr()" 2 "$2" "target array variable name"
	fVariableCannotBeEmpty packedArgs
	fVariableCannotBeEmpty arrayName

	## Initialize
	eval "${arrayName}=()"    ## Clear out the specified array.

	## Unpack and fill array
	packedArgsCount=$(fPackedArgs_GetCount "${packedArgs}")
	if [ $packedArgsCount -gt 0 ]; then :;
		for ((arrayIndex = 0; arrayIndex < $packedArgsCount; arrayIndex++)); do
			packedargsIndex=$(( arrayIndex+1 ))
			unpackedArg="$(fUnpackArg_Number "${packedArgs}" ${packedargsIndex})"
			eval "${arrayName}+=(\"${unpackedArg}\")"
		done
	fi
	
}


##----------------------------------------------------------------------------------------------------
function fPackArgs_FromArrayPtr(){ :;
	##	Purpose:
	##		Packs args from a named array.
	##	Arguments:
	##		- 1 [REQUIRED]: The name of an array variable. Must be visible in scope to this function.
	##		- 2 [REQUIRED]: The name of a packed-args variable. Must be visible in scope to this function.
	##	Modifies:
	##		- Overwrites value of specified packed args string.
	##	History:
	##		- 20180306 JC (0_library_v2): Created.

	## Arguments
	local arrayName="$1"
	local packedArgsVarName="$2"

	## Variables
	local -a tmpArray
	local tmpPackedArgs=""

	## Validate
	fFunctionArgumentCannotBeEmpty "fUnpackArgs_ToArrayPtr()" 1 "$1" "target array variable name"
	fFunctionArgumentCannotBeEmpty "fUnpackArgs_ToArrayPtr()" 2 "$2" "target packed args variable name"
	fVariableCannotBeEmpty arrayName
	fVariableCannotBeEmpty packedArgsVarName

	## Copy the array so we can access it directly
	tmpArray=()
	eval "tmpArray=( \"\${$arrayName[@]}\" )"

	## Misc init
	eval "${packedArgsVarName}=\"\""

	### Debug
	#fEcho_Clean ""
	#fEcho_Clean	"tmpArray[] count ...: ${#tmpArray[@]}"
	#fEcho_Clean	"tmpArray[0] ........: '${tmpArray[0]}'"

	## Loop through the array
	local currentArg=""
	local currentArg_PackStrd=""
	local encodedPackStrs=""
	for currentArg in "${tmpArray[@]}"; do

		## Encode current item
		currentArg_PackStrd="$(fPackString "${currentArg}")"

		## Bundle packed strings together
		## if [ -n "${encodedPackStrs}" ]; then encodedPackStrs="${encodedPackStrs}_"; fi  ## 20190615 JC: Changed from _ to ☊ because _ was turning up in unpacked strings somehow. Not sure if this will fix it.
		if [ -n "${encodedPackStrs}" ]; then encodedPackStrs="${encodedPackStrs}☊"; fi
		encodedPackStrs="${encodedPackStrs}${currentArg_PackStrd}"

	done

	## Package them up in single packed args wrapper
	tmpPackedArgs="⦃packedargs-begin⦄${encodedPackStrs}⦃packedargs-end⦄"

	## Copy the value to the defined variable pointer
	eval "${packedArgsVarName}=\"${tmpPackedArgs}\""

}


##----------------------------------------------------------------------------------------------------
function fPackString(){ :;
	##	Purpose:
	##		Packs a string up to allow passing around to functions and scripts,
	##		withouting getting fubar'ed by spaces and quotes.
	##	Input:
	##		A string. Can contain spaces, single quotes, double quotes, etc.
	##	Note:
	##		Outer quotes will always be ignored. If you must get quotes preserved in a string,
	##		use single quotes with outer double quotes (e.g. "'first name' 'last name'"),
	##		double quotes with outer single quotes (e.g. '"first name" "last name"'),
	##		or escaped quotes if all the same (e.g. "\"first name\" \"last name\"").
	##	Returns via echo:
	##		A packed string that can be safely passed around without getting munged.
	##	History:
	##		- 20161003 JC (0_library_v1): Created.
	##		- 20161003 JC (0_library_v1):
	##			- Removed looping. Now explicitly just operates on the command argument as one big string.
	##			- Renamed from fArgs_Pack() to fPackString().
	##			- Updated "created" date from probably erroneous 2006, to 2016.
	##			- Updated comments.
	##			- Added outer "if" statement to catch null input.
	##		- 20171217 JC (0_library_v2):
	##			- Add packing header during packing process.
	##			- Check for packing header before packing, to avoid packing more than once.

	## Variables
	local vlsInput="$@"
	local vlsReturn=""

	if [[ "${vlsInput}" =~ ^⦃packedstring-begin⦄.*⦃packedstring-end⦄$ ]]; then  ##⦃⦄

		## Return already packed input
		vlsReturn="${vlsInput}"

	else :;
		if [ -z "${vlsInput}" ]; then :;

			## Explicitly empty
			vlsReturn="⦃empty⦄"

		else :;

			## Works
			vlsReturn="${vlsInput}"
			vlsReturn="$(echo "${vlsReturn}" | sed "s/\"/⦃dquote⦄/g" )"                               ## "    [double quote]
			vlsReturn="$(echo "${vlsReturn}" | sed "s/'/⦃squote⦄/g" )"                                ## '    [single quote]
			vlsReturn="${vlsReturn//$/⦃dollar⦄}"                                                      ## $    [dollar]
			vlsReturn="${vlsReturn//\%/⦃percent⦄}"                                                    ## %    [percent]
			vlsReturn="${vlsReturn//$'\n'/⦃newline⦄}"                                                 ## \n   [newline]
			vlsReturn="$(echo "${vlsReturn}" | sed 's#\t#⦃tab⦄#g' )"                                  ## \t   [tab]
			vlsReturn="$(echo "${vlsReturn}" | sed 's/ /⦃space⦄/g' )"                                 ## ' '  [space]
			vlsReturn="$(echo "${vlsReturn}" | sed 's#\\#⦃whack⦄#g' )"                                ## \    [whack]
			vlsReturn="$(echo "${vlsReturn}" | sed 's#\/#⦃slash⦄#g' )"                                ## /    [slash]
			vlsReturn="${vlsReturn//_/⦃underscore⦄}"                                                   ## _    [underscore]

			## Doesn't work
			#vlsReturn="$(echo "${vlsReturn}" | sed -e ":a" -e "N" -e "$!ba" -e "s/\n/⦃newline⦄/g" )"  ## \n   [newline]

		fi

		## Wrap with start and end wrappers
		vlsReturn="⦃packedstring-begin⦄${vlsReturn}⦃packedstring-end⦄"

	fi

	echo "${vlsReturn}"

}


##----------------------------------------------------------------------------------------------------
function fUnpackString(){ :;
	##	Purpose:
	##		Unpacks a string previously packed with fPackString(), into its original
	##		special characters.
	##	Arguments:
	##		- 1 [optional]: Packed arguments string originally generated by fPackString().
	##	Returns via echo:
	##		- Original string.
	##	History:
	##		- 20161003 JC (0_library_v1): Created.
	##		- 20161003 JC (0_library_v1):
	##			- Removed looping. Now explicitly just operates on the command argument as one big string.
	##			- Renamed from fArgs_Unpack() to fUnpackString().
	##			- Updated "created" date from probably erroneous 2006, to 2016.
	##			- Updated comments.
	##			- Added outer "if" statement to catch null input.
	##		- 20171217 JC (0_library_v2):
	##			- Check for packing header before unpacking, to avoid unpacking a non-packed args.
	##			- Remove packing header.

	## Variables.
	local vlsInput="$@"
	local vlsReturn=""

	if [ -n "${vlsInput}" ]; then :;

		if [[ "${vlsInput}" =~ ^⦃packedstring-begin⦄.*⦃packedstring-end⦄$ ]]; then :;

			## Strip off wrapper
			#vlsReturn="${vlsReturn/⦃packedstring-begin⦄/}"
			#vlsReturn="${vlsReturn/⦃packedstring-end⦄/}"
			vlsReturn="${vlsInput}"
			vlsReturn="$(echo "${vlsReturn}" | sed "s/⦃packedstring-begin⦄//g")"
			vlsReturn="$(echo "${vlsReturn}" | sed "s/⦃packedstring-end⦄//g")"

			## Check for empty
			if [ "${vlsReturn}" == "⦃empty⦄" ]; then :;
				vlsReturn=""
			else :;

				## Works
				vlsReturn="${vlsReturn//⦃underscore⦄/_}"                                                  ## _    [underscore]
				vlsReturn="${vlsReturn//⦃percent⦄/\%}"                                                    ## %    [percent]
				vlsReturn="${vlsReturn//⦃dollar⦄/$}"                                                      ## $    [dollar]
				vlsReturn="$(echo "${vlsReturn}" | sed 's/⦃space⦄/ /g' )"                                 ## ' '  [space]
				vlsReturn="$(echo "${vlsReturn}" | sed 's#⦃whack⦄#\\#g' )"                                ## \    [whack]
				vlsReturn="$(echo "${vlsReturn}" | sed 's#⦃slash⦄#\/#g' )"                                ## /    [slash]
				vlsReturn="$(echo "${vlsReturn}" | sed 's#⦃tab⦄#\t#g' )"                                  ## \t   [tab]
				vlsReturn="${vlsReturn/⦃newline⦄/$'\n'}"                                                  ## \n   [newline]
				vlsReturn="$(echo "${vlsReturn}" | sed "s/⦃squote⦄/'/g" )"                                ## '    [single quote]
				vlsReturn="$(echo "${vlsReturn}" | sed "s/⦃dquote⦄/\"/g" )"                               ## "    [double quote]

				## Doesn't work
				#vlsReturn="$(echo "${vlsReturn}" | sed -e ":a" -e "N" -e "$!ba" -e "s#⦃newline⦄#\n#g" )"  ## \n   [newline]

				## Ignore
				#vlsReturn="${vlsReturn/_27DKGA6-Underscore_/_}"                                                   ## _    [underscore]

			fi
		else :;

			## It is not packed, so return unchanged
			vlsReturn="${vlsInput}"

		fi
	fi

	echo "${vlsReturn}"
}


##-------------------------------------------------------------------------------------------------------------------
function fGetFolderOf_v2(){ :;
	##	History:
	## 		- 20150925 JC: Created.
	##		- 20170313 JC: New guts to fix bug that returns the wrong path in some cases.

	local vlsFilespec="$@"
	local vlsReturn=""

	## Validate
	fMustBeInPath "realpath"

	if [ -n "${vlsFilespec}" ]; then :;
		fDefineTrap_Error_Ignore
			vlsReturn="$(dirname "$(realpath "${vlsFilespec}")")"
		fDefineTrap_Error_Fatal
	fi

	## Suddenly quit working, returns path of executing script
	#fDefineTrap_Error_Ignore
	#	if [ -n "${vlsFilespec}" ]; then :;
	#		vlsFilespec="$(fGetFilespecOf "${vlsFilespec}")"
	#		vlsFilespec="$(cd -P "$(dirname "${vlsFilespec}")" && pwd)"  ## As found on interwebs.
	#		vlsReturn="${vlsFilespec}"
	#	fi
	#fDefineTrap_Error_Fatal

	echo "${vlsReturn}"
}


##----------------------------------------------------------------------------------------------------
function fGetFileExtention(){ :;
	##	Purpose:
	##		Returns the extention of a file, if any.
	##	Arguments:
	##		1 [REQUIRED]: Filename or complete filespec.
	##	Returns via echo:
	##		Extention
	##	Example[s]:
	##		1:
	##			Command: fGetFileExtention("my.tar.gz")
	##			Result: "tar.gz".
	##	History:
	##		- 20170313 JC: Created.
	local vlsArg="$@"
	local vlsReturn=""
	if [ -n "${vlsArg}" ]; then :;
		vlsArg="$(basename "${vlsArg}")"
		if [ -n "${vlsArg}" ]; then :;
			vlsReturn="${vlsArg#*.}"
		fi
	fi
	echo "${vlsReturn}"
}


##----------------------------------------------------------------------------------------------------
function fGetFilePrefix(){ :;
	##	Purpose:
	##		Returns the prefix of a filename, if any.
	##	Arguments:
	##		1 [REQUIRED]: Filename or complete filespec.
	##	Returns via echo:
	##		File prefix
	##	Requirements:
	##		- In path:
	##			- basename
	##	Example[s]:
	##		1:
	##			Command: fGetFilePrefix("my.tar.gz")
	##			Result: "my".
	##	History:
	##		- 20170313 JC: Created.
	local vlsArg="$@"
	local vlsReturn=""
	if [ -n "${vlsArg}" ]; then :;
		vlsArg="$(basename "${vlsArg}")"
		if [ -n "${vlsArg}" ]; then :;
			vlsReturn="${vlsArg%%.*}"
		fi
	fi
	echo "${vlsReturn}"
}


##-------------------------------------------------------------------------------------------------------------------
function fConvert_DecToHex_Real(){ :;
	##	Input:
	##		- 1 [REQUIRED]: Decimal number to hexadecimal.
	##		- 2 [optional]: Length to zero-pad to.
	##	Notes:
	##		- OK:
	##			- Zero-padded values.
	##		- Not OK (at least yet):
	##			- Negative values.
	##			- Decimal values.
	##	History:
	##		- 20170307 JC: Created.

	## Arguments
	local vlsInput="$1"
	local vlsZeroPadTo="$2"

	## Variables
	local vlsFormat=""
	local vlsOutput=""

	## Calculate the format string
	if [ -n "${vlsZeroPadTo}" ]; then :;
		if [ "$(fIsNum_Natural "${vlsZeroPadTo}")" == "false" ]; then :;
			fThrowError "fConvert_DecToHex(): vlsZeroPadTo is not a natural number: '${vlsZeroPadTo}'."
		else :;
			vlsFormat="%0${vlsZeroPadTo}x"
		fi
	fi
	if [ -z "${vlsFormat}" ]; then :;
		vlsFormat="%0x"
	fi


	if [ "$(fIsNum_Natural "${vlsInput}")" == "false" ]; then :;
		fThrowError "fConvert_DecToHex(): Input is not a natural number: '${vlsInput}'."
	else :;

		## Init
		vlsOutput="${vlsInput}"

		## Strip off leading zeros (only works with naturals).
		vlsOutput="$(fConvert_ToDec_Natural "${vlsOutput}")"

		## Convert to hex and pad
		vlsOutput="$(printf "${vlsFormat}" $vlsOutput)"

		## Other possible computations/transformations
		#awk '{printf "%04x", strtonum("0x"$1)}'
		#local clsPrintfFormat="%0${clwZeroPadTo}X\n"
		#vlwResultHex="$(printf "${clsPrintfFormat}" $vlwResultDec)"

	fi

	## Output return value
	echo "${vlsOutput}"

}


##-------------------------------------------------------------------------------------------------------------------
function fConvert_ToDec_Natural(){ :;
	##	History:
	##		- 20170307 JC: Created.
	local vlsInput="$1"
	local vlsOutput=""

	## Use math, forced to base-10 (only works with naturals).
	if [ -n "${vlsInput}" ]; then :;
		fDefineTrap_Error_Ignore
			vlsOutput="$((10#${vlsInput}))" 2> /dev/null
		fDefineTrap_Error_Fatal
	fi

	echo "${vlsOutput}"

}


##-------------------------------------------------------------------------------------------------------------------
function fIsHex_Natural(){ :;
	##	Notes:
	##		- Hexadecimal.
	##	History:
	##		- 20170307 JC: Created.
	echo "$(fIsMatch_Regex "${1}" "^([0-9]|[a-f]|[A-F])+$")"
}


##-------------------------------------------------------------------------------------------------------------------
function fIsNum_Natural(){ :;
	##	Notes:
	##		- Implicitly decimal.
	##	History:
	##		- 20170307 JC: Created.
	echo "$(fIsMatch_Regex "${1}" "^[0-9]+$")"
}


##-------------------------------------------------------------------------------------------------------------------
function fIsNum_Integer(){ :;
	##	Notes:
	##		- Implicitly decimal.
	##	History:
	##		- 20141117 JC: Created.
	##		- 20170307 JC:
	##			- Copied fIsNumber(), as fIsNum_Integer().
	##			- Uses fIsMatch_Regex() instead of duplicate logic.
	echo "$(fIsMatch_Regex "${1}" "^-?[0-9]+$")"
}


##-------------------------------------------------------------------------------------------------------------------
function fIsNum_Real(){ :;
	##	Notes:
	##		- Implicitly decimal.
	##	History:
	##		- 20141117 JC: Created.
	##		- 20170307 JC:
	##			- Copied fIsNumber(), as fIsNum_Real().
	##			- Uses fIsMatch_Regex() instead of duplicate logic.
	echo "$(fIsMatch_Regex "${1}" "^-?[0-9]+([.][0-9]+)?$")"
}


##-----------------------------------------------------------------------------------------------------
function fIsMatch_Regex(){ :;
	##	Purpose:
	##		- Calculates regex match in a way that doesn't crash your script on malformed input.
	##	History:
	##		- 20170307 JC: Created.

	local vlsString="$1"
	local vlsRegex="$2"
	local vlsRestul="false"

	if [ -n "${vlsRegex}" ]; then :;
		fDefineTrap_Error_Ignore
			if [[ "${vlsString}" =~ $vlsRegex ]] 2>/dev/null; then
				vlsRestul="true"
			fi
		fDefineTrap_Error_Fatal
	fi

	echo "${vlsRestul}"

}


##-------------------------------------------------------------------------------------------------------------------
function fGetSudo(){ :;
	## 20170306 JC: Copied and updated fGetSudo() to always be quiet unless prompt needed.
	if [ "$(fIsSudoValid)" == "false" ]; then :;
		if [ "${vmbLessVerbose}" == "true" ]; then :;
			sudo echo -n
		else :;
			if [ "${vmbLessVerbose}" != "true" ]; then fEcho_Clean ""; fi
			echo "[ Verifying sudo rights ... ]"
			sudo echo "[ Sudo rights verified. ]"
			fEcho_ResetBlankCounter
			#if [ "${vmbLessVerbose}" != "true" ]; then fEcho_Clean ""; fi
		fi
		fEcho_ResetBlankCounter
	fi
}
#function fGetSudo_v2(){ fGetSudo; }
function fGetSudo_Deprecated(){ :;
	## 20160904 JC: Updated to fully respect vmbLessVerbose
	## 20171217 JC: Deprecated.
	if [ "$(fIsSudoValid)" == "false" ] || [ "${vmbLessVerbose}" != "true" ]; then :;
		fEcho "You may be prompted to enter password to verify sudo role ..."
	fi
	if [ "${vmbLessVerbose}" == "true" ]; then :;
		sudo echo -n
	else :;
		sudo echo "[ Sudo role verified. ]"
		fEcho_ResetBlankCounter
	fi
}


##-------------------------------------------------------------------------------------------------------------------
function fForceUmount(){ :;
	local vlsMountPoint="$@"

	if [ "$(fIsMounted "${vlsMountPoint}")" == "false" ]; then :;
		fEcho "FYI - '${vlsMountPoint}' wasn't mounted."
	else :;

		sync; sleep 0.5

		## Try every trick in the book
		fEchoAndDo_IgnoreError "fusermount -u '${vlsFolder}'"
		if [ "$(fIsMounted "${vlsMountPoint}")" == "true" ]; then :;
			fEchoAndDo_IgnoreError "umount '${vlsMountPoint}'"
			if [ "$(fIsMounted "${vlsMountPoint}")" == "true" ]; then :;
				fGetSudo
				fEchoAndDo_IgnoreError "sudo fusermount -u '${vlsFolder}'"
				if [ "$(fIsMounted "${vlsMountPoint}")" == "true" ]; then :;
					fEchoAndDo_IgnoreError "sudo umount '${vlsMountPoint}'"
					if [ "$(fIsMounted "${vlsMountPoint}")" == "true" ]; then :;
						fEchoAndDo_IgnoreError "sudo umount -f '${vlsMountPoint}'"
						if [ "$(fIsMounted "${vlsMountPoint}")" == "true" ]; then :;
							fEchoAndDo_IgnoreError "sudo fusermount -uz '${vlsFolder}'"
							if [ "$(fIsMounted "${vlsMountPoint}")" == "true" ]; then :;
								fEchoAndDo_IgnoreError "sudo umount -fi '${vlsMountPoint}'"
								if [ "$(fIsMounted "${vlsMountPoint}")" == "true" ]; then :;
									fEchoAndDo_IgnoreError "sudo umount -fl '${vlsMountPoint}'"
									if [ "$(fIsMounted "${vlsMountPoint}")" == "true" ]; then :;
										fEchoAndDo_IgnoreError "sudo umount -fli '${vlsMountPoint}'"
									fi
								fi
							fi
						fi
					fi
				fi
			fi
		fi

		## Final test and error
		if [ "$(fIsMounted "${vlsMountPoint}")" == "false" ]; then :;
			sync; sleep 0.5
		else :;
			fThrowError "fForceUmount(): Could not unmount '${vlsMountPoint}'."
		fi

	fi
}


##-----------------------------------------------------------------------------------------------------
function fIsMounted(){ :;
	##	Purpose
	##		- Returns "true" if a file specification exists.
	##	Input:
	##		1 [REQUIRED]: Mount point, e.g. "/home/user/mnt/sdcard1"
	##		2 [optional]: Type of mount point to further narrow down, e.g. "vfat"
	##	History:
	##		- 20170302 JC: Created
	fEcho_IfDebug "fIsMounted()"

	local vlsMountPoint="$1"
	local vlsMountType="$2"
	local vlsTest=""
	local vlsReturn="false"

	## Get test ls output
	fDefineTrap_Error_Ignore
		if [ -n "${vlsMountPoint}" ] && [ -n "${vlsMountType}" ]; then :;
			vlsTest="$(mount | grep -i "${vlsMountPoint}" | grep -i "${vlsMountType}" 2> /dev/null)"
		elif [ -n "${vlsMountPoint}" ]; then :;
			vlsTest="$(mount | grep -i "${vlsMountPoint}" 2> /dev/null)"
		fi
	fDefineTrap_Error_Fatal

	if [ -n "${vlsTest}" ]; then :;
		vlsReturn="true"
	fi

	echo "${vlsReturn}"

}


##-----------------------------------------------------------------------------------------------------
function fDo_IgnoreError(){ :;
	## 20140520 JC: Created.
	## 20170302 JC: Updated for better output.
	fDefineTrap_Error_Ignore
		eval "$@" 2> /dev/null
	fDefineTrap_Error_Fatal
}


##-----------------------------------------------------------------------------------------------------
function fDo_IgnoreError_PackedArgs(){ :;
	##	TODO:
	##		- Like fDo_IgnoreError(), but ingest and handle packed args.
	##		- Future edit ID: 9df8d781-e592-42b7-8edc-c2800bb575d6
}


##-------------------------------------------------------------------------------------------------------------------
function fEchoAndDo_IgnoreError(){ :;
	## 20140520 JC: Created.
	## 20170302 JC: Updated for better output.
	fEcho "Executing: $@"
	fDo_IgnoreError "$@"
}


##-----------------------------------------------------------------------------------------------------
function fEchoAndDo_IgnoreError_PackedArgs(){ :;
	##	TODO:
	##		- Like fEchoAndDo_IgnoreError(), but ingest and handle packed args.
	##		- Future edit ID: 9df8d781-e592-42b7-8edc-c2800bb575d6
}


##-------------------------------------------------------------------------------------------------------------------
function fDoesFilespecExist(){ :;
	##	Purpose
	##		- Returns "true" if a file specification exists (without looking in subdirectories).
	##		- Wildcards are OK.
	##	Input (only #1 OR (#2 AND/OR #3)):
	##		- 1 [REQUIRED]: Folder to search in, no ending "/".
	##		- 2 [REQUIRED]: Match parameter, matches any part of result with grep regex.
	##	Notes:
	##		- To check for the existince of a folder, leave second argument blank.
	##		- To check for the existence of anything inside a folder, pass ".*" as second argument.
	##	History:
	##		- 20170301 JC: Created
	fEcho_IfDebug "fDoesFilespecExist()"

	## Input
	local vlsFolder="$1"
	local vlsFind="$2"
	local vlsTest=""
	local vlsReturn="false"

	## Calculate
	if [ -n "${vlsFind}" ]; then :;
		vlsFind="${vlsFolder}/${vlsFind}"
	fi

	## Debug
	#echo "vlsFolder ......: '${vlsFolder}'"
	#echo "vlsFind ........: '${vlsFind}'"

	if [ -z "${vlsFolder}" ]; then :;
		fThrowError "fDoesFilespecExist(): You must specify a folder to find in."
	else :;

		## Get 'find' output
		if [ -d "${vlsFolder}" ]; then :;
			fDefineTrap_Error_Ignore
				vlsTest="$(${vlsCommandPrefix} find "${vlsFolder}" -maxdepth 1  2> /dev/null | grep "${vlsFind}")"
			fDefineTrap_Error_Fatal
		fi

		## Debug
		#echo "vlsTest='${vlsTest}'"
		#exit 0

		## Did we find anything?
		if [ -n "${vlsTest}" ]; then :;
			vlsReturn="true"
		fi

		## Return value
		echo "${vlsReturn}"

	fi

}


##----------------------------------------------------------------------------------------------------
function fGetPassword(){ :;
	##	Purpose:
	##		Prompts for a password without echoing the input.
	##	Arguments:
	##		1 [REQUIRED]: Name of variable.
	##		2 [optional]: String to prompt user with.
	##		3 [optional]: Prompt twice? (true|false); defaults to false.
	##	Modifies:
	##		Whatever variable specified by name in argument 1.
	##	Example[s]:
	##		1: fGetPassword vlsPassword
	##	History:
	##		- 20161003 JC: Created.

	fThrowError "Work in progress."
	read -s -p "Remote password for user ${vlsHost} on server ${vlsHost} (none to quit): " vlsRemotePassword

}


##-------------------------------------------------------------------------------------------------------------------
function fGetDesktopEnvironment(){ :;
	##	Purpose: Returns a string indicating the currently running desktop environment.
	##	Returns:
	##		One of: cinnamon, kde5, gnome2, gnome3, mate, unity, xfce
	##	Notes:
	##		Limitations:
	##			- "What is a desktop environment?"
	##			- User may be running a mix and match of display manager, window manager, desktop renderer, and panels.
	##		Telltale running processes:
	##			- Xfce4:
	##				- Environment...: /etc/xdg/xfce4/xinitrc, xfce4/xfconf/xfconfd, xfce4-volumed
	##				- Panel ........: xfce4-panel
	##	History:
	##		- 20160922 JC: Created.
	local vlsReturn=""

	if [ "$(fIsRunning "xdg/xfce4")" == "true" ]; then :;
		vlsReturn="xfce4"
	fi

	echo "${vlsReturn}"
}


##-----------------------------------------------------------------------------------------------------
function fGet_VideoDriver(){ :;
	##	Purpose:
	##		Returns something like "nouveau", "nvidia", etc.
	##	Notes:
	##		- dmesg is not reliable, especially for long-running systems, as messages can scroll out of buffer.
	##	History:
	##		- 20160921 JC: Created.
	local vlsReturn=""
	local vlsTest=""
	fDefineTrap_Error_Ignore


		##-------------------------------------------------------------------------------
		## lshw
		##-------------------------------------------------------------------------------

		## TODO: Intel
		if [ -z "${vlsReturn}" ]; then :;
			vlsTest="$(fakeroot lshw -c video  2> /dev/null | grep -i 'vendor:' | grep -i 'Intel')"
			if [ -n "${vlsTest}" ]; then vlsReturn="intel"; fi
		fi

		## Virtualbox
		if [ -z "${vlsReturn}" ]; then :;
			vlsTest="$(fakeroot lshw -c video | grep -i 'virtualbox' 2> /dev/null)"
			if [ -n "${vlsTest}" ]; then vlsReturn="virtualbox"; fi
		fi

		## TODO: ATI Radeon proprietary ("radeon")

		## TODO: ATI Radeon open-source ("flgrx")


		##-------------------------------------------------------------------------------
		## lsmod (unreliable, use only as last resort)
		##-------------------------------------------------------------------------------

		### 
		#if [ -z "${vlsReturn}" ]; then :;
		#	vlsTest="$(lsmod | grep -i 'drm_kms_helper ' | awk '{ print $4 }')"
		#	if [ -n "${vlsTest}" ]; then vlsReturn="${vlsTest}"; fi
		#fi


		##-------------------------------------------------------------------------------
		## Dmesg (unreliable as early entries truncate; use only as a last resort)
		##-------------------------------------------------------------------------------

		## Nvidia open-source ("nouveau")
		if [ -z "${vlsReturn}" ]; then :;
			#vlsTest="$(lsmod | grep -i 'drm_kms_helper ' | awk '{ print $4 }')"
			#vlsTest="$(dmesg | grep -i 'nouveau' 2> /dev/null)"  ## This doesn't work.
			vlsTest="$(lsmod | grep -i 'nouveau' | grep -i 'drm')"
			if [ -n "${vlsTest}" ]; then vlsReturn="nouveau"; fi
		fi

		## Nvidia proprietary ("nvidia")
		if [ -z "${vlsReturn}" ]; then :;
			vlsTest="$(dmesg | grep -i 'nvidia' 2> /dev/null)"  ## This is true even for nouveau
			if [ -n "${vlsTest}" ]; then vlsReturn="nvidia"; fi
		fi

		## Virtualbox ("vboxvideo")
		if [ -z "${vlsReturn}" ]; then :;
			vlsTest="$(dmesg | grep -i 'vboxvideo' 2> /dev/null)"
			if [ -n "${vlsTest}" ]; then vlsReturn="virtualbox"; fi
		fi

		## TODO: Intel
		if [ -z "${vlsReturn}" ]; then :;
			vlsTest="$(dmesg | grep -i 'intel' | grep -i 'drm' 2> /dev/null)"
			if [ -n "${vlsTest}" ]; then vlsReturn="intel"; fi
		fi


	fDefineTrap_Error_Fatal

	## Clean up
	if [ -n "${vlsReturn}" ]; then :;
		vlsReturn="$(fStrToLower "${vlsReturn}")"
	fi
	echo "${vlsReturn}"
}


##-------------------------------------------------------------------------------------------------------------------
function fAreWeVirtual(){ :;
	##	Purpose:
	##		Detect virtualization
	##	Input: Nothing
	##	Output: "true" if virtual, "false" if not, otherwise "unknown" 
	##	History:
	##		- 201609?? JC: Created.
	if [ -n "$(fGet_VirtualizationProduct)" ]; then :;
		echo "true"
	else :;
		echo "false"
	fi
}


##-------------------------------------------------------------------------------------------------------------------
function fAreWeReal(){ :;
	##	Purpose:
	##		Detect virtualization.
	##		Counterpart to (and relies on) fAreWeVirtual
	##	Input: Nothing
	##	Output: "true" if real, "false" if virtual, otherwise "unknown".
	##	History:
	##		- 201609?? JC: Created.
	if [ -n "$(fGet_VirtualizationProduct)" ]; then :;
		echo "false"
	else :;
		echo "true"
	fi
}


##-------------------------------------------------------------------------------------------------------------------
declare vmsPrivate_VirtualizationProduct=""
function fGet_VirtualizationProduct(){ :;
	##	Purpose: Return virtualization hypervisor product, or empty string if not virtual.
	##	Input: Nothing
	##	Output:
	##		- Simple product name, such as "virtualbox", "vmware", "hyperv".
	##		- "unknown" if virtual but can't tell by who.
	##		- "" if not virtual.
	##	History:
	##		- 20160926 JC: Created.

	if [ -z "${vmsPrivate_VirtualizationProduct}" ]; then :;

		## systemd-detect-virt return values:
		##		Virtualization
		##			qemu .............: QEMU software virtualization
		##			kvm ..............: Linux KVM kernel virtual machine
		##			zvm ..............: s390 z/VM
		##			vmware ...........: VMware Workstation or Server, and related products
		##			microsoft ........: Hyper-V, also known as Viridian or Windows Server Virtualization
		##			oracle ...........: Oracle VM VirtualBox (historically marketed by innotek and Sun Microsystems)
		##			xen ..............: Xen hypervisor (only domU, not dom0)
		##			bochs ............: Bochs Emulator
		##			uml ..............: User-mode Linux
		##			parallels ........: Parallels Desktop, Parallels Server
		##		Containers
		##			openvz ...........: OpenVZ/Virtuozzo
		##			docker ...........: Docker container manager
		##			lxc ..............: Linux container implementation by LXC
		##			lxc-libvirt ......: Linux container implementation by libvirt
		##			systemd-nspawn ...: systemd's minimal container implementation, see systemd-nspawn(1)
		##			rkt ..............: rkt app container runtime
		local vlsSystemdDetectVirt=""
		if [ "$(fIsInPath systemd-detect-virt)" == "true" ]; then :;
			fDefineTrap_Error_Ignore
				vlsSystemdDetectVirt="$(systemd-detect-virt 2> /dev/null)"
			fDefineTrap_Error_Fatal
		fi
		vlsSystemdDetectVirt="$(fStrToLower "${vlsSystemdDetectVirt}")"

		## Debug
		#fEcho_VariableAndValue vlsSystemdDetectVirt

		## Get more specific
		local vlbProbeFurther="false"
		case "${vlsSystemdDetectVirt}" in

			## Map answers that are company names, to product names
			"oracle")      vmsPrivate_VirtualizationProduct="virtualbox" ;;
			"microsoft")   vmsPrivate_VirtualizationProduct="hyperv" ;;

			## Running on metal
			"none")        vmsPrivate_VirtualizationProduct="" ;;

			## Probe further, next code block below
			"unknown"|"")  vlbProbeFurther="true" ;;

			## Pass some other string straight through - e.g. "vmware", "kvm", "qemu", "xen", "parallels", "bochs"
			*)             vmsPrivate_VirtualizationProduct="${vlsSystemdDetectVirt}" ;;

		esac

		## Probe further; Method 1 - 
		if [ "${vlbProbeFurther}" == "true" ]; then :;
			:
		fi

		## Probe further; Method 2 - drive names
		if [ "${vlbProbeFurther}" == "true" ]; then :;
			:
		fi


		## Finally
		if [ "${vlbProbeFurther}" == "true" ]; then :;
			vmsPrivate_VirtualizationProduct="unkown"
		fi
	fi

	## Return
	echo "${vmsPrivate_VirtualizationProduct}"

}


##-------------------------------------------------------------------------------------------------------------------
function fpErrMsg(){ :;
	## 20160905 JC: Updated to output to CLI and/or GUI.
	## 20170308 JC: Updated for better blank line after console error message.
	## 20170313 JC: Include script name in error output.
	local vlsErrMsg=""
	if [ -n "$@" ]; then :;
		vlsErrMsg="Error in '$(basename "$0")': $@"
	else :;
		vlsErrMsg="An error occurred in '$(basename "$0")'."
	fi
	if [ -t 0 ]; then :;
		## Show the message in CLI
		fEcho ""
		fEcho "${vlsErrMsg}"
		if [ -n "${DISPLAY}" ]; then :;
			## Also show non-blocking message in GUI
			notify-send "${vlsErrMsg}"
		fi
	elif [ -n "${DISPLAY}" ]; then :;
		## Show blocking message in GUI
		zenity --error --text="${vlsErrMsg}" --ellipsize
	fi
}


## ----------------------------------------------------------------------------------------
function fpTrap_Error_Fatal(){ :;
	## Generic: Visually indicates that an error happened.
	## 20140519 JC: Updated with additional info.

	local lineNumber="$1"
	local errorDescription="$2"
	local errorCode="${3:-1}"

	fEcho_Clean ""
	fEcho_Clean "Error information:"

	## Script
	fEcho_Clean "    In script .....: $(fGetFileName_OfMe)"

	## Line number
	if [ -n "${lineNumber}" ]; then :;
		fEcho_Clean "    Near line# ....: ${lineNumber}"
	fi

	## Error code
	if [ -n "${errorCode}" ]; then :;
		fEcho_Clean "    Error code ....: ${errorCode}"
	fi

	## Description
	if [ -n "${errorDescription}" ]; then :;
		fEcho_Clean "    Description ...: ${errorDescription}"
	fi

}

##---------------------------------------------------------------------------------------
function fEcho_Clean(){ :;
	## 20140206-07 JC: Updated with "fold" to wrap at words.
	## 20170313    JC: Don't wrap at less than terminal width.
	## 20180306    JC: Use -e.
	if [ -n "$1" ]; then :;
		local -i vliActualCols=$(tput cols)
		#local -i vliMaxIdealCols=200
		local -i vliMaxIdealCols=$vliActualCols  ## Don't wrap at less than terminal width
		local -i vliColumns=$(fMath_Int_Min $vliActualCols $vliMaxIdealCols)
		echo -e "$@" | fold -s -w $vliColumns
		vmbLastEchoWasBlank="false"
	else :;
		if [ "${vmbLastEchoWasBlank}" != "true" ]; then :;
			echo
		fi
		vmbLastEchoWasBlank="true"
	fi
}
declare vmbLastEchoWasBlank="false"

##---------------------------------------------------------------------------------------
function fStrSearchAndReplace(){ :;
	##	Purpose: For every match in a string, substitutes a replacement.
	##	Input:
	##		- Source string.
	##		- Search substring.
	##		- Replacement substring.
	##	Notes:
	##		- Case-sensitve
	##		- Performons only ONE pass - can't get stuck in a loop.
	##		- Uses sed and tr for more robustness.
	##	Returns:
	##		Modified string via echo. Capture with: MyVariable="$(fStrSearchAndReplace "${MyVariable}")"
	##	TODO:
	##		Make sure can handle random strings with double quotes in them (as opposed to singular double quotes).
	##	History:
	##		- 20160906 JC: Rewrote from scratch to:
	##			- Only make one pass.
	##			- Use 'sed' instead of bash variable expansion, for more robust handling of:
	##				- Double quotes.
	##				- Escaped characters such as \n.
	##		- 20170308 JC:
	##			- Use bash variable expansion to bypass frustrating sed time-sink / bug.

	## Input
	local vlsString="$1"
	local vlsFind="$2"
	local vlsReplace="$3"

	## Temp replacements to avoid problems and trades speed for robustness
	vlsStrOp="forward"
	vlsString="$(fpStrOps_TempReplacements "${vlsString}")"
	vlsFind="$(fpStrOps_TempReplacements "${vlsFind}")"
	vlsReplace="$(fpStrOps_TempReplacements "${vlsReplace}")"

	## Debug
	#fEcho_VariableAndValue vlsString
	#fEcho_VariableAndValue vlsFind
	#fEcho_VariableAndValue vlsReplace
	#echo "Replace:"
	##echo "${vlsString}"| sed 's/${vlsFind}/${vlsReplace}/'
	#echo "${vlsString//${vlsFind}/${vlsReplace}}"
	#exit 0

	## Do the replacing
	#vlsString="$(echo "${vlsString}"| sed 's#${vlsFind}#${vlsReplace}#g')"
	vlsString="$(echo "${vlsString//${vlsFind}/${vlsReplace}}")"

	## Reverse temp replacements
	vlsStrOp="reverse"
	vlsString="$(fpStrOps_TempReplacements "${vlsString}")"

	echo -e "${vlsString}"
	exit

}

##-----------------------------------------------------------------------------------------------------
function fpStrOps_TempReplacements(){ :;
	##	History:
	##		- 20170308 JC:
	##			- Fixed error handling.
	##			- Added replacing "*", "?", "#", and brackets.
	local vlsString="$@"
	if [ "${vlsStrOp}" == "forward" ]; then :;
		#vlsString="$( echo -e "${vlsString}" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/_PLACEHOLDER_19544526_NEWILNE_/g' )"
		vlsString="$( echo -e "${vlsString}" | sed ':a;N;$!ba;s/\n/_PLACEHOLDER_19544526_NEWILNE_/g' )"
		vlsString="$( echo -e "${vlsString}" | sed 's*\"*_PLACEHOLDER_44757925_DQUOTE_*g' )"
		vlsString="$( echo -e "${vlsString}" | sed "s/'/_PLACEHOLDER_66824699_SQUOTE_/g" )"
		vlsString="$( echo -e "${vlsString}" | sed 's*\t*_PLACEHOLDER_54743014_TAB_*g' )"
		vlsString="$( echo -e "${vlsString}" | sed 's*\.*_PLACEHOLDER_24165191_DOT_*g' )"
		vlsString="$( echo -e "${vlsString}" | sed 's*\\*_PLACEHOLDER_99358465_BACKSLASH_*g' )"
		vlsString="$( echo -e "${vlsString}" | sed 's*/*_PLACEHOLDER_66037559_FWDSLASH_*g' )"  ## Can substitute any character for "/" delimiter in sed.
		vlsString="$( echo -e "${vlsString}" | sed "s/\*/_PLACEHOLDER_62469349_ASTERISK_/g" )"
		vlsString="$( echo -e "${vlsString}" | sed "s/\?/_PLACEHOLDER_83569350_QUESTION_/g" )"
		vlsString="$( echo -e "${vlsString}" | sed "s/#/_PLACEHOLDER_8344569350_POUND_/g" )"
		vlsString="$( echo -e "${vlsString}" | sed "s/\[/_PLACEHOLDER_8344350_LBRACKET_/g" )"
		vlsString="$( echo -e "${vlsString}" | sed "s/\]/_PLACEHOLDER_8344350_RBRACKET_/g" )"
	elif [ "${vlsStrOp}" == "reverse" ]; then :;
		vlsString="$( echo -e "${vlsString}" | sed 's*_PLACEHOLDER_19544526_NEWILNE_*\n*g' )"
		vlsString="$( echo -e "${vlsString}" | sed 's*_PLACEHOLDER_44757925_DQUOTE_*\"*g' )"
		vlsString="$( echo -e "${vlsString}" | sed "s/_PLACEHOLDER_66824699_SQUOTE_/'/g" )"
		vlsString="$( echo -e "${vlsString}" | sed 's*_PLACEHOLDER_54743014_TAB_*\t*g' )"
		vlsString="$( echo -e "${vlsString}" | sed 's*_PLACEHOLDER_24165191_DOT_*\.*g' )"
		vlsString="$( echo -e "${vlsString}" | sed 's*_PLACEHOLDER_99358465_BACKSLASH_*\\*g' )"
		vlsString="$( echo -e "${vlsString}" | sed 's*_PLACEHOLDER_66037559_FWDSLASH_*/*g' )"  ## Can substitute any character for "/" delimiter in sed.
		vlsString="$( echo -e "${vlsString}" | sed "s/_PLACEHOLDER_62469349_ASTERISK_/\*/g" )"
		vlsString="$( echo -e "${vlsString}" | sed "s/_PLACEHOLDER_83569350_QUESTION_/\?/g" )"
		vlsString="$( echo -e "${vlsString}" | sed "s/_PLACEHOLDER_8344569350_POUND_/#/g" )"
		vlsString="$( echo -e "${vlsString}" | sed "s/_PLACEHOLDER_8344350_LBRACKET_/\[/g" )"
		vlsString="$( echo -e "${vlsString}" | sed "s/_PLACEHOLDER_8344350_RBRACKET_/\]/g" )"
	else :;
		fThrowError "fpStrOps_TempReplacements(): vlsStrOp must be specified as 'forward' or 'reverse'."
	fi
	echo "${vlsString}"
}

##-------------------------------------------------------------------------------------------------------------------
function fIsInPath(){ :;
	## 20160912 JC: Recreated because accidentally deleted at some point.
	local vlsReturn="false"
	if [ -n "$1" ]; then
		if [ -n "$(which "$@")" ]; then
			vlsReturn="true"
		fi
	fi
	echo "${vlsReturn}"
}

##---------------------------------------------------------------------------------------
function fMustBeInPath() {
	## 20140206-07 JC: Created.
	## 20190609 JC: Fixed not showing name of file that must be in path.
	if [ -z "$1" ]; then
		fThrowError "fMustBeInPath(): Nothing to check."
	elif [ -z "$(which "$1" 2> /dev/null || true)" ]; then
		fThrowError "The command ${cmsDoubleQuote_Open}$1${cmsDoubleQuote_Close} must be in path, but isn’t."
	fi
}

##-----------------------------------------------------------------------------------------------------
function fStrSearchAndReplace_Iterative(){ :;
	##	Purpose: For every match in a string, substitutes a replacement.
	##	Notes:
	##		- Case-sensitve
	##		- Iterative - will keep looping until all matches are replaced.
	##		- SLOW. But robust.
	##	Returns:
	##		Modified string via echo. Capture with: MyVariable="$(fStrSearchAndReplace "${MyVariable}")"
	##	Notes:
	##		- Be careful of unintended recursion. E.g. Replacing "man" with "woman" will result in an endless loop.
	##	History:
	##		- 20160906 JC: Created.

	## Input
	local vlsString="$1"
	local vlsFind="$2"
	local vlsReplace="$3"

	## Replace all occurrences
	if [ -n "${vlsString}" ]; then :;
		local vlsPrevious=""
		while [ "${vlsString}" != "${vlsPrevious}" ]; do
			vlsPrevious="${vlsString}"
			vlsString="$(fStrSearchAndReplace "${vlsString}" "${vlsFind}" "${vlsReplace}")"
		done
	fi
	echo "${vlsString}"
}

##-------------------------------------------------------------------------------------------------------------------
function fStrGetFirstN(){ :;
	##	Purpose: Returns the first N characters from a string.
	##	Arguments:
	##		1 [optional]: The string in question.
	##		2 [optional]: An integer >0
	##			- If <=0 or empty, "" is returned.
	##			- If > input length, input is returned unchanged.
	##	History:
	##		- 20160906 JC: Created.
	local vlsInput="$1"
	local vlwFirstN="$2"
	local vlsReturn=""
	if [ -n "${vlsInput}" ] && [ -n "${vlwFirstN}" ]; then :;
		if [ "${vlwFirstN}" -lt 0 ]; then vlwFirstN="0"; fi
		vlsReturn="${vlsInput:0:$vlwFirstN}"
	fi
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fStrGetLastN(){ :;
	##	Purpose: Returns the last N characters from a string.
	##	Arguments:
	##		1 [optional]: The string in question.
	##		2 [optional]: An integer >0
	##			- If <=0 or empty, "" is returned.
	##			- If > input length, input is returned unchanged.
	##	History:
	##		- 20160906 JC: Created.
	local vlsInput="$1"
	local vlwLastN="$2"
	local vlsReturn=""
	if [ -n "${vlsInput}" ]; then :;
		if [ -n "${vlwLastN}" ]; then :;
			if [ "${vlwLastN}" -lt 0 ]; then vlwLastN="0"; fi
			if [ "${#vlsInput}" -lt "${vlwLastN}" ]; then :;
				vlsReturn="${vlsInput}"  ## The form below would return empty string in this case.
			else :;
				vlsReturn="${vlsInput: -${vlwLastN}}"
			fi
		fi
	fi
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fStrRemoveFirstN(){ :;
	##	Purpose: Removes the first N characters from a string.
	##	Arguments:
	##		1 [optional]: The string in question.
	##		2 [optional]: An integer >0
	##			- If <=0 or empty, input is returned unchanged.
	##			- If > input length, "" is returned.
	##	History:
	##		- 20160906 JC: Created.
	local vlsInput="$1"
	local vlwFirstN="$2"
	local vlsReturn=""
	if [ -n "${vlsInput}" ]; then :;
		if [ -z "${vlwFirstN}" ]; then :;
			vlsReturn="${vlsInput}"  ## Return unchanged
		else :;
			if [ "${vlwFirstN}" -lt 0 ]; then vlwFirstN="0"; fi
			vlsReturn="${vlsInput:$vlwFirstN}"
		fi
	fi
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fStrRemoveLastN(){ :;
	##	Purpose: Removes the first N characters from a string.
	##	Arguments:
	##		1 [optional]: The string in question.
	##		2 [optional]: An integer >0
	##			- If <=0 or empty, input is returned unchanged.
	##			- If > input length, "" is returned.
	##	History:
	##		- 20160906 JC: Created.
	local vlsInput="$1"
	local vlwLastN="$2"
	local vlsReturn=""
	if [ -n "${vlsInput}" ]; then :;
		if [ -z "${vlwLastN}" ]; then :;
			## LastN is empty, return input unchanged
			vlsReturn="${vlsInput}"
		elif [ "${vlwLastN}" -le "0" ]; then :;
			## LastN <=0, return input unchanged
			vlsReturn="${vlsInput}"
		elif [ "${vlwLastN}" -ge "${#vlsInput}" ]; then :;
			## LastN >= len; return ""
			vlsReturn=""
		else :;
			## Remove the leftmost N characters
			vlsReturn="${vlsInput::-$vlwLastN}"
		fi
	fi
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fStrGetMiddle(){ :;
	##	Purpose: Returns some middle portion of a string.
	##	Arguments:
	##		1 [optional]: The string in question.
	##		2 [optional]: 1-based starting position.
	##			- If <=0 or empty, assumes 1.
	##			- If > input length, "" is returned.
	##		3 [optional]: Length to return from starting position, in # of characters.
	##			- If <1 or empty, "" is returned.
	##			- If starting position + length -1 > input length, assumes to the end of the string.
	##	History:
	##		- 20160906 JC: Created.
	local vlsInput="$1"
	local vlwStartPos="$2"
	local vlwLen="$3"
	local vlsReturn=""
	if [ -n "${vlsInput}" ]; then :;
		if [ -n "${vlwLen}" ]; then :;
			if [ "${vlwLen}" -gt "0" ]; then :;
				if [ "${vlwStartPos}" -le "${#vlsInput}" ]; then :;
					if [ "${vlwStartPos}" -le "0" ]; then vlwStartPos="1"; fi
					vlwStartPos=$(( ${vlwStartPos} - 1 ))  ## Bash uses 0 as start
					vlsReturn="${vlsInput:${vlwStartPos}:${vlwLen}}"
				fi
			fi
		fi
	fi
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fStrGetMatchPos(){ :;
	##	Purpose: Returns the 1-based starting location of a substring match within a larger string.
	##	Arguments:
	##		1 [optional]: The main string in question.
	##			- If empty, return=0.
	##		2 [optional]: The substring. Regular expression OK.
	##			- If empty, return=0.
	##	Returns: An integer:
	##			- =0 if no match.
	##			- >0 if a match found.
	##	History:
	##		- 20160906 JC: Created.
	local vlsInput="$1"
	local vlsSubstring="$2"
	local vlwReturn="0"
	if [ -n "${vlsInput}" ]; then :;
		if [ -n "${vlsSubstring}" ]; then :;
			vlwReturn="$( echo "${vlsInput}" | grep -Ebo "${vlsSubstring}" | cut -d: -f1 )"
			if [ -n "${vlwReturn}" ]; then :;
				vlwReturn=$(( $vlwReturn + 1 ))  ## Change to 1-based index.
			else :;
				vlwReturn="0"
			fi
		fi
	fi
	echo "${vlwReturn}"
}

##-----------------------------------------------------------------------------------------------------
function fStrSanitize(){ :;
	##	Purpose: Sanitizes a string in a way that result can be used as variable contents, file name, and/or folder name
	##	TODO: Offer an argument to sanitize for different purposes.
	##	History:
	##		- 20160906 JC: Created.
	local vlsString="$@"

	local vlsPrevious=""
	while [ "${vlsString}" != "${vlsPrevious}" ]; do
		vlsPrevious="${vlsString}"

		## Basic stuff
		vlsString="$(echo "${vlsString}" | sed "s/\"//g" )"               ## double quotes with nothing
		vlsString="$(echo "${vlsString}" | sed "s/'//g" )"                ## single quotes with nothing
		vlsString="$(echo -e "${vlsString}" | tr '\n' '_' )"              ## newline with underscore
		vlsString="$(echo "${vlsString}" | sed 's/\\/~/g' )"              ## backslash with tilde
		vlsString="$(echo "${vlsString}" | sed 's/\//~/g' )"              ## forwardslash with tilde
		vlsString="${vlsString//$/_}"                                      ## dollar with underscore 
		vlsString="${vlsString//“/}"                                       ## Replace curly double open quotes with nothing
		vlsString="${vlsString//”/}"                                       ## Replace curly double close quotes with nothing
		vlsString="${vlsString//‘/}"                                       ## Replace curly double single quotes with nothing
		vlsString="${vlsString//’/}"                                       ## Replace curly single close quotes with nothing
		vlsString="${vlsString//\%/_}"                                     ## percent with underscore
		vlsString="${vlsString//./_}"                                      ## Dot with underscore
		vlsString="$(echo "${vlsString}" | sed 's*\t* *g' )"              ## Tab with space
		vlsString="$(echo "${vlsString}" | sed 's/ /-/g' )"               ## One space with dash
		vlsString="${vlsString//_-/-}"                                     ## Underscore dash, with dash
		vlsString="${vlsString//-_/-}"                                     ## Dash underscore, with dash
		vlsString="${vlsString//~-/~}"                                     ## tilde + dash -> tilde
		vlsString="${vlsString//-~/~}"                                     ## dash + tilde+ -> tilde
		vlsString="${vlsString//~_/~}"                                     ## tilde + underscore -> tilde
		vlsString="${vlsString//_~/~}"                                     ## underscore + tilde -> tilde
		vlsString="${vlsString//__/_}"                                     ## Double underscore with single underscore
		vlsString="${vlsString//--/-}"                                     ## Double dash with single dash
		vlsString="${vlsString//~~/~}"                                     ## Double tilde with single tilde

		## Remove trailing stuff
		local vlbCheckAgain="true"
		while [ "${vlbCheckAgain}" == "true" ]; do
			## Remove stuf from ends
			case "${vlsString}" in
				*" "|*"-"|*"_"|*"~"|*","|*".") vlsString="$(fStrRemoveLastN "${vlsString}" 1)" ;;
				" "*|"-"*|"_"*|"~"*|","*|"."*) vlsString="$(fStrRemoveFirstN "${vlsString}" 1)" ;;
			esac

			## Check if we need to loop again
			vlbCheckAgain="false"
			case "${vlsString}" in
				*" "|*"-"|*"_"|*"~"|*","|*".") vlbCheckAgain="true" ;;
				" "*|"-"*|"_"*|"~"*|","*|"."*) vlbCheckAgain="true" ;;
			esac
		done

	done

	echo "${vlsString}"
}

##-------------------------------------------------------------------------------------------------------------------
function fStrAdd_WithSpace_SkipIfEmpty(){ :;
	##	Purpose: Adds a substring with a space to an existing string.
	##	Input:
	##		1: The variable name whose contents you wish to Add the new string to.
	##		2: The contents to Add.
	##	History:
	##		- 20140927 JC: Created.
	##		- 20160940 JC: Fixed curly-quote bug.
	fEcho_IfDebug "fStrAdd_WithSpace_SkipIfEmpty()"

	## Input
	local vlsVariableName="$1"
	local vlsAddStr="$2"

	## Validation
	if [ -z "${vlsVariableName}" ]; then fThrowError "fStrAdd_WithSpace_SkipIfEmpty(): No variable name was specified"; fi

	## Logic
	if [ -n "${vlsAddStr}" ]; then :;

		## Init
		local vlsContent="${!vlsVariableName}"

		## Add a space to the content if it isn’t empty
		if [ -n "${vlsContent}" ]; then :;
			vlsContent="${vlsContent} "
		fi

		## Add string to content
		vlsContent="${vlsContent}${vlsAddStr}"

		## Store new content to named variable
		eval "${vlsVariableName}=\"${vlsContent}\""

	fi

}

##-------------------------------------------------------------------------------------------------------------------
function fFolderCannotHaveContents(){ :;
	## 20140206-07 JC: Created.
	## 20160940 JC: Fixed curly-quote bug.
	## 20180818 JC: Updated message.
	fEcho_IfDebug "fFolderCannotHaveContents()"
	local vlsFolder="$@"
	if [ "$(fDoesFolderHaveContents "${vlsFolder}")" == "true" ]; then :;
		fThrowError "Folder cannot have contents: ${cmsDoubleQuote_Open}${vlsFolder}${cmsDoubleQuote_Close}"
	fi
}

##-------------------------------------------------------------------------------------------------------------------
function fFolderMustHaveContents(){ :;
	## 20180818 JC: Created.
	fEcho_IfDebug "fFolderCannotHaveContents()"
	local vlsFolder="$@"
	if [ "$(fDoesFolderHaveContents "${vlsFolder}")" == "false" ]; then :;
		fThrowError "Folder must have contents: ${cmsDoubleQuote_Open}${vlsFolder}${cmsDoubleQuote_Close}"
	fi
}

##-----------------------------------------------------------------------------------------------------
function fDoesFolderHaveContents(){ :;
	## 20140206-07 JC: Created.
	## 20160940 JC: Fixed curly-quote bug.
	local vlsFolder="$@"
	local vlsReturn="false"
	if [ -d "${vlsFolder}" ]; then :;
		if [ -n "$(ls -A "${vlsFolder}")" ]; then :;
			vlsReturn="true"
		fi
	fi
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fIsRunning(){ :;
	local vlsProcName="$1"
	local vlsReturn=""
	if [ -n "${vlsProcName}" ]; then :;
		local vlsGrepVal=""
		vlsMeName="$(fGetFileName_OfMe)"
		local vlsTempCmd="ps auxw |  grep -v 'grep' | grep -v '${vlsMeName}' | grep -i '${vlsProcName}'"
		#local vlsTempCmd="pgrep -fc '${vlsProcName}'"
		#local vlsTempCmd="ps -ef | awk '$NF~"${vlsProcName}" {print $2}'"
		#local vlsTempCmd="ps -eux | awk '$NF~"${vlsProcName}" {print $2}'"
		fDefineTrap_Error_Ignore
			vlsGrepVal="$(eval "${vlsTempCmd}")"
		fDefineTrap_Error_Fatal
		#fEcho_VariableAndValue "vlsMeName"; fEcho_VariableAndValue "vlsTempCmd"; fEcho_VariableAndValue "vlsProcName"; fEcho_VariableAndValue "vlsGrepVal"
		if [ -n "${vlsGrepVal}" ]; then :;
			vlsReturn="true"
		fi
	fi
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fKill(){ :;
	local vlsProcName="$1"
	if [ -n "${vlsProcName}" ]; then :;
		fDefineTrap_Error_Ignore
			#fEchoAndDo "killall -I -w '$@' 2> /dev/null"
			fEchoAndDo "pkill -f $@ &> /dev/null & disown"
		fDefineTrap_Error_Fatal
		sleep $cmwSleepSeconds
	fi
}

##-------------------------------------------------------------------------------------------------------------------
function fGetFilespecOf(){ :;
	local vlsFilespec="$@"
	local vlsReturn=""
	fDefineTrap_Error_Ignore
		if [ -n "${vlsFilespec}" ]; then :;
			vlsFilespec="$(fGetWhich "${vlsFilespec}")"
			if [ -n "${vlsFilespec}" ]; then :;
				vlsFilespec="$(cd -P "$(dirname "${vlsFilespec}")" && pwd)/$(basename ${vlsFilespec})"  ## As found on interwebs.
				if [ -n "${vlsFilespec}" ]; then :;
					vlsReturn="${vlsFilespec}"
				fi
			fi
		fi
	fDefineTrap_Error_Fatal
	echo "${vlsFilespec}"
}

##-----------------------------------------------------------------------------------------------------
fRunForked (){ :;
	## 20150504 JC: Created.
	# detach stdout, stderr, stdin, run in background and disown handles
	local vlsPid=""
	echo "Disowned background execution:"
	echo "Command ......: $@"
	eval "$@" > /dev/null 2>&1 < /dev/null &
	vlsPid=$!
	disown $vlsPid
	echo "PID ..........: ${vlsPid}"
}

##-----------------------------------------------------------------------------------------------------
fRunForked_AndLog (){ :;
	## 20150504 JC: Created.
	# detach stdin, redirect stdout and stderr to log file, run in background and disown handles
	#local vlsTimestamp=$(date "+%Y%m%d-%H%M%S")
	local vlsPid=""
	local vlsTempFile="/tmp/$(fGetFileName_OfMe).fRunForked_AndLog_$(fGetTimeStamp).log"
	echo "Disowned background execution:"
	echo "Command ......: $@"
	echo "Output log ...: ${vlsTempFile}"
	eval "$@" > "${vlsTempFile}" 2>&1 < /dev/null &
	vlsPid=$!
	disown $vlsPid
	echo "PID ..........: ${vlsPid}"
}

##-----------------------------------------------------------------------------------------------------
function fIsInteger(){ :;
	## 20141117 JC: Created.
	if [[ "$1" =~ ^-?[0-9]+$ ]]; then :;
		echo "true"
	else :;
		echo "false"
   	fi
}

##-----------------------------------------------------------------------------------------------------
function fIsNumber(){ :;
	## 20141117 JC: Created.
	if [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then :;
		echo "true"
	else :;
		echo "false"
   	fi
}

##---------------------------------------------------------------------------------------
function fStrIndentAllLines(){ :;
	##	Purpose:
	##		- For a multiline string, indent all lines.
	##	History
	##		- 20141003 JC: Created.
	local clsFunctionName="fStrIndentAllLines"
	fEcho_IfDebug "${clsFunctionName}()"

	local vlsInput="$@"
	local vlsReturn=""

	if [ -n "${vlsInput}" ]; then :;
		while read -r vlsLine; do
			if [ -n "${vlsReturn}" ]; then :;
				vlsReturn="${vlsReturn}\n"
			fi
			vlsReturn="${vlsReturn}    ${vlsLine}"
		done <<< "${vlsInput}"
	fi

	echo -e "${vlsReturn}"

}

##-----------------------------------------------------------------------------------------------------
function fEchoOrEchoAndDo_IgnoreError(){ :;
	##	Purpose:
	##		- Echos what will be done, or echos it and does it.
	##	Input:
	##		1 [REQUIRED]: The command to echo [and possibly execute].
	##		2 [optional]: "listonly" to just list and not execute.
	##	History:
	##		- 20141103 JC: Created.
	local clsFunctionName="fEchoOrEchoAndDo_IgnoreError"
	fEcho_IfDebug "${clsFunctionName}()"

	local vlsListOnly="$(fStrToLower "$2")"

	if [ "${vlsListOnly}" == "listonly" ]; then :;
		echo "    $1"
	else :;
		fEchoAndDo_IgnoreError "$1"
	fi

}

##-----------------------------------------------------------------------------------------------------
function fEchoOrEchoAndDo(){ :;
	##	Purpose:
	##		- Echos what will be done, or echos it and does it.
	##	Input:
	##		1 [REQUIRED]: The command to echo [and possibly execute].
	##		2 [optional]: "listonly" to just list and not execute.
	##	History:
	##		- 20141103 JC: Created.
	local clsFunctionName="fEchoOrEchoAndDo"
	fEcho_IfDebug "${clsFunctionName}()"

	local vlsListOnly="$(fStrToLower "$2")"

	if [ "${vlsListOnly}" == "listonly" ]; then :;
		echo "    $1"
	else :;
		fEchoAndDo "$1"
	fi

}

##-----------------------------------------------------------------------------------------------------
function fNormalizePath(){ :;
	local clsFunctionName="fNormalizePath"
	##	Purpose:
	##		- Strips leading and trailing spaces from string.
	##		- Strips ending slash from string
	##			- So your code knows exactly the status of ending slash and can go from there.
	##		- Converts multiple instances of path separators, to only one.
	##	History
	##		- 20141011 JC: Created
	##		- 20190701 JC:
	##			- Refactored to use fStrTrim().
	##			- Also now uses read-only input for safety.
	##			- The old code also erroneously causes color formatting problems with Sublime.
	##		- 20190702 JC: Refactored to just wrap fNormalizePath_byref(). Had to use that one to debug.

	## 20190702 JC: New code
	local pathToNormalize="$1"
	fNormalizePath_byref pathToNormalize
	echo "${pathToNormalize}"

	## 20190702 JC: New code
	#local -r inputStr="$@"
	#echo "$(realpath -ms "${inputStr}" 2> /dev/null || true)"

	## 20190701 JC: Old code from 20141011
	#local vlsPath="$@"
	#if [ -n "${vlsPath}" ]; then vlsPath="${vlsPath#"${vlsPath%%[![:space:]]*}"}"; fi   ## Remove leading whitespace characters.
	#if [ -n "${vlsPath}" ]; then vlsPath="${vlsPath%"${vlsPath##*[![:space:]]}"}"; fi   ## Remove trailing whitespace characters.
	#if [ -n "${vlsPath}" ]; then vlsPath="${vlsPath%/}"; fi                             ## Remove trailing slash if exists
	#echo "$vlsPath"
}

##-----------------------------------------------------------------------------------------------------
function fNormalizePath_byref(){ :;
	local clsFunctionName="fNormalizePath_byref"
	##	Purpose:
	##		- Given a variable name, strips leading and trailing spaces from its contents.
	##		- Strips ending slash from string.
	##			- So your code knows exactly the status of ending slash and can go from there.
	##		- Converts multiple instances of path separators, to only one.
	##	History
	##		- 20141011 JC: Created fNormalizePath().
	##		- 20190701 JC:
	##			- Refactored to use fStrTrim().
	##			- Also now uses read-only input for safety.
	##			- The old code also erroneously causes color formatting problems with Sublime.
	##		- 20190702 JC:
	##			- Copyied fNormalizePath() and refactored. This version can show debugging messages, the other can't.
	##			- Note for converting multiple slaces:
	##				- Realpath -ms does all of this, PLUS convert multiple instances of slashes.
	##					- With -m, path doesn't need to exist (desired behavior).
	##					- With -s, does NOT canonicalize existing paths to their true physical locations (desired behavior).
	##				- HOWEVER: If it's a partial path, it tries to squeeze it onto current directory, which is definitely NOT desire behavior.
	##				- tr -s is actually perfect for this.
	##			- Also 

	## Args
	local -r varName="$1"

	## Variables
	local returnStr=""

	## Validate
	if [ -z "${varName}" ]; then
		fThrowError "fNormalizePath_byref(): No variable name specified."
	else

		## Get the value contained in the specified variable name
		local -r varVal="${!varName}"

		## Loop until the string stops changing (this will also skip empty input)
		returnStr="${varVal}"
		local loop_PreviousStr=""
		while [ "${returnStr}" != "${loop_PreviousStr}" ]; do
			
			## Get now, so we know next loop if the next code changed it.
			loop_PreviousStr="${returnStr}"
		#	echo "returnStr = '${returnStr}' [at top of loop]"  ## Debug

			## Replace newlines and tabs with spaces
			#returnStr="$(echo -e "${returnStr}")"  ## Don't do this as it prevents accurately converting Windows backslashes to forward slashes, which is more important.
			returnStr=${returnStr//$'\n'/ }
			returnStr=${returnStr//$'\t'/ }
		#	echo "returnStr = '${returnStr}' [after converting newlines and tabs to spaces]"  ## Debug

			## Convert backslashes to forward slashes
			returnStr="$(echo "${returnStr}" | sed 's#\\#/#g' 2> /dev/null || true)"
		#	echo "returnStr = '${returnStr}' [after using sed to convert backslashes to forward slashes]"  ## Debug

			## Remove space before and after slashes
			returnStr="$(echo "${returnStr}" | sed 's#/ #/#g' | sed 's# /#/#g' 2> /dev/null || true)"
		#	echo "returnStr = '${returnStr}' [after removing spaces between slashes]"  ## Debug

			## Convert multiple slashes into one
			returnStr="$(echo "${returnStr}" | tr -s "/" 2> /dev/null || true)"
		#	echo "returnStr = '${returnStr}' [after 'tr -s /']"  ## Debug

			## Trim trailing slash
			returnStr="${returnStr%/}"
		#	echo "returnStr = '${returnStr}' [After end slash removal]"  ## Debug

			## Trim leading and trailing whitespace
			returnStr="$(fStrTrim "${returnStr}")"
		#	echo "returnStr = '${returnStr}' [after fStrTrim()]"  ## Debug

		done

		## Assign new value to specified variable name
		eval "${varName}=\"${returnStr}\""
	fi
}

##-----------------------------------------------------------------------------------------------------
function fpStrAppend_WithNewLine(){ :;
	local clsFunctionName="fpStrAppend_WithNewLine"
	##	Purpose:
	##		- Core function for fStrAppend_WithNewLine_*()
	##		- If existing value is not empty, prepends a newline to the new string to add.
	##	Input:
	##		1: The variable name to append new contents to.
	##		2: The contents to Add. If empty, then a new line is created anyway.
	##	History:
	##		- 20140911 JC: Created.
	##		- 20140927 JC: Updated.

	## Arguments
	local vlsVariableName="$1"
	local vlsAddStr="$2"
	local vlsFunctionNameOverride="$3"

	## Init1
	if [ -z "${vlsFunctionNameOverride}" ]; then vlsFunctionNameOverride="${clsFunctionName}"; fi
	fEcho_IfDebug "${vlsFunctionNameOverride}()"

	## Validate
	if [ -z "${vlsVariableName}" ]; then fThrowError "${vlsFunctionNameOverride}(): No variable name was specified"; fi

	## Init2
	local vlsContent="${!vlsVariableName}"

#	## 20190609 JC: I'm not sure what this was meant to do, why, or what's with vlsFunctionNameOverride. But fpNewLine() doesn't exist.
#	## Add a new line to the end of the existing content if it isn’t empty, before the new content
#	if [ -n "${vlsContent}" ]; then :;
#		vlsContent="${vlsContent}$(fpNewLine "${vlsFunctionNameOverride}")"
#	fi

	## Prepend newline if existing string is not empty
	if [ -n "${vlsContent}" ]; then
		vlsContent="${vlsContent}\n"
	fi

	## Add the new string to old content (even if it is empty)
	vlsContent="${vlsContent}${vlsAddStr}"

	## Store new content to named variable
	eval "${vlsVariableName}=\"${vlsContent}\""

}

##-----------------------------------------------------------------------------------------------------
function fStrAppend_WithNewLine_EvenIfArgEmpty(){ :;
	local clsFunctionName="fStrAppend_WithNewLine_EvenIfArgEmpty"
	##	Purpose:
	##		- 
	##	Input:
	##		1: The variable name to Add the contents of.
	##		2: The contents to Add. If empty, then a new line is created anyway.
	##	History:
	##		- 20140911 JC: Created.
	##		- 20140927 JC: Updated.
	##		- 20140929 JC: Updated.
	fEcho_IfDebug "${clsFunctionName}()"
	## Arguments
	local vlsVariableName="$1"
	local vlsAddStr="$2"
	## Logic
	fpStrAppend_WithNewLine "$1" "$2" "${clsFunctionName}"
}

##-----------------------------------------------------------------------------------------------------
function fStrAppend_WithNewLine_ErrorIfArgEmpty(){ :;
	local clsFunctionName="fStrAppend_WithNewLine_ErrorIfArgEmpty"
	##	Purpose:
	##		- Passes through to fpStrAppend_WithNewLine(), after validating that the new string to add is not empty (if it is, it throws an error).
	##	Input:
	##		1: The variable name to Add the contents of.
	##		2: The contents to Add.
	##	History:
	##		- 20140911 JC: Created.
	##		- 20140929 JC: Updated.
	fEcho_IfDebug "${clsFunctionName}()"

	## Input
	local vlsAddStr="$2"

	## Logic
	if [ -z "${vlsAddStr}" ]; then :;
		fThrowError "fStrAppend_WithNewLine_ErrorIfArgEmpty(): No content was specified to Add to variable ${cmsDoubleQuote_Open}${vlsVariableName}${cmsDoubleQuote_Close}."
	else :;
		fpStrAppend_WithNewLine "$1" "${vlsAddStr}" "${clsFunctionName}"
	fi
}

##-----------------------------------------------------------------------------------------------------
function fStrAppend_WithNewLine_SkipIfArgEmpty(){ :;
	local clsFunctionName="fStrAppend_WithNewLine_SkipIfArgEmpty"
	##	Purpose:
	##		- If the new string to add is not empty, this passes through to fpStrAppend_WithNewLine().
	##	Input:
	##		1: The variable name to Add the contents of.
	##		2: The contents to Add.
	##	History:
	##		- 20140911 JC: Created.
	##		- 20140929 JC: Updated.
	fEcho_IfDebug "${clsFunctionName}()"

	## Input
	local vlsAddStr="$2"

	## Logic
	if [ -n "${vlsAddStr}" ]; then :;
		fpStrAppend_WithNewLine "$1" "${vlsAddStr}" "${clsFunctionName}"
	fi
}

##-----------------------------------------------------------------------------------------------------
function fIsStringInFile(){ :;
	## 20140311 JC: Created
	## Arg 1: String
	## Arg 2: File

	local vlsString="$1"
	local vlsFile="$2"

	local vlsReturn="false"

	if [ -f "${vlsFile}" ]; then :;
		fDefineTrap_Error_Ignore
			local vlsContents="$(cat ${vlsFile} | grep ${vlsString})"
		#	echo "vlsContents = ${cmsDoubleQuote_Open}${vlsContents}${cmsDoubleQuote_Close}"; exit 0
		fDefineTrap_Error_Fatal
		if [ -n "${vlsContents}" ]; then :;
			vlsReturn="true"
		fi
	fi

	echo "${vlsReturn}"

}

##-----------------------------------------------------------------------------------------------------
function fStrRemoveWhitespace(){
	local vlsArgs="$@"
	echo "${vlsArgs//[[:blank:]]/}"
}

##-----------------------------------------------------------------------------------------------------
function fStrToUpper(){
	##	History:
	##		- 20190702 JC: Refactored to be simpler.
	local -r inputStr="$@"
	echo "${inputStr^^}"
}

##-----------------------------------------------------------------------------------------------------
function fStrToLower(){
	##	History:
	##		- 20190702 JC: Refactored to be simpler.
	local -r inputStr="$@"
	echo "${inputStr,,}"
	#echo "$@" | tr "[:upper:]" "[:lower:]"
}

##-----------------------------------------------------------------------------------------------------
function fStrReplaceWithCaseInsensitive(){ :;
	##	Purpose: For every a-z or A-Z character (let’s say "x"), replaces them with "[Xx]".
	##	Uses:    For case-insensitive matching in tools such as rsync, tar - with not-quite-regex matching.
	##	Returns: Modified string via echo. Capture with: MyVariable="$(fStrReplaceWithCaseInsensitive "${MyVariable}")"
	##	History:
	##		- 20140615 JC: Created.
	local vlsInput="$@"
	local vlsReturn=""
	local vlsChar=""
	## Character subs
	for (( vliCount=0; vliCount<${#vlsInput}; vliCount++ )); do
		vlsChar="${vlsInput:$vliCount:1}"
		case "${vlsChar}" in
			[a-zA-Z])
				vlsReturn="${vlsReturn}[$(fStrToUpper "${vlsChar}")$(fStrToLower "${vlsChar}")]"
				;;
			*)
				vlsReturn="${vlsReturn}${vlsChar}"
				;;
		esac
	done
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fStrSearchAndReplace_DEPRECATED(){ :;
	##	Purpose: For every match in a string, substitutes a replacement.
	##	Input:
	##		- Source string.
	##		- Search substring (searches recursively).
	##		- Replacement substring.
	##	Notes:
	##		- Case-sensitve
	##		- Can get stuck in an endless loop if the replacement has the same subword as the find.
	##		- Deprecated because there was no alternative to potentially getting stuck in a loop.
	##	Returns: Modified string via echo. Capture with: MyVariable="$(fStrSearchAndReplace_DEPRECATED "${MyVariable}")"
	##	History:
	##		- 20140615 JC: Created.
	##		- 20141002 JC: Replaces all occurrences in multiple passes.
	##		- 20160906 JC: Deprecated.

	## Input
	local vlsString="$1"
	local vlsFind="$2"
	local vlsReplace="$3"

	## Variables
	local vlsPrevious=""

	## Replace all occurrences
	while [ "${vlsString}" != "${vlsPrevious}" ]; do
		vlsPrevious="${vlsString}"
		vlsString="${vlsString//${vlsFind}/${vlsReplace}}"
		if [ "${vlsString}" == "${vlsPrevious}" ]; then :;
			break
		fi
	done

	echo "${vlsString}"
}

##-------------------------------------------------------------------------------------------------------------------
function fStrReplaceWithMultilinePermutations(){ :;
	##	Purpose: For every match in a string, substitutes a replacement..
	##	Returns: Modified string via echo. Capture with: MyVariable="$(fStrReplaceWithMultilinePermutations "${MyVariable}")"
	##	History:
	##		- 20140615 JC: Created.

	local vlsInput="$1"
	local vlsFind="$2"
	local -a vlsReplacements=("${@:3}")
	local vlsCurrentReplacement=""
	local vlsLastReplacement=""
	local -a vlsReturnArray=""
	local -i vliReturnArrayAddCount=0
	local vlsTempReturnWithReplacements=""
	local vlbAtLeastOneReplacementMade="false"
	local vlsReturn=""

	## The first return element is free
	readarray -t vlsReturnArray <<<"$vlsInput"
	#echo -e "DEBUG: vlsReturnArray[@]:\n$(printf -- '%s\n' "${vlsReturnArray[@]}")"; exit

	if [ ${#vlsReturnArray[@]} -gt 0 ] && [ ${#vlsReplacements[@]} -gt 0 ]; then :;
		while true; do
			#echo; echo "DEBUG: Top of Main loop"

			## Return array loop
			local -a vlsTempArray=""
			local -i vliTempArrayIndex=0
			vlbAtLeastOneReplacementMade="false"
			for vlsCurrentReturn in "${vlsReturnArray[@]}"; do
				#echo "DEBUG: Top of Return array loop"
				#echo "DEBUG: vlsCurrentReturn=${cmsDoubleQuote_Open}${vlsCurrentReturn}${cmsDoubleQuote_Close}"

				## Replacement array loop
				vlsLastReplacement="ThisWontMatchAnythingUseful_LKJDFKLjsdflkjsdflkjdfqoiuweyrlkjvliuyqwer"
				for vlsCurrentReplacement in "${vlsReplacements[@]}"; do
					#echo "DEBUG: Top of Replacement array loop"
					#echo "DEBUG: vlsLastReplacement   =${cmsDoubleQuote_Open}${vlsLastReplacement}${cmsDoubleQuote_Close}"
					#echo "DEBUG: vlsCurrentReplacement=${cmsDoubleQuote_Open}${vlsCurrentReplacement}${cmsDoubleQuote_Close}"; sleep 1

					if [ "${vlsCurrentReplacement}" == "${vlsLastReplacement}" ]; then :;
						#echo "DEBUG: Replacement array loop break; current replacement same as last"; echo
						break
					else :;

						## Replace only the first match 
						vlsTempReturnWithReplacements="${vlsCurrentReturn/${vlsFind}/${vlsCurrentReplacement}}"
						#echo "DEBUG: vlsTempReturnWithReplacements=${cmsDoubleQuote_Open}${vlsTempReturnWithReplacements}${cmsDoubleQuote_Close}"

						if [ "${vlsTempReturnWithReplacements}" != "${vlsCurrentReturn}" ]; then :;

							## Append replacement to temp array
							#echo "DEBUG: vliTempArrayIndex=${cmsDoubleQuote_Open}${vliTempArrayIndex}${cmsDoubleQuote_Close}"
							if [ $vliTempArrayIndex -le 0 ]; then :;
								local -a vlsTempArray=("${vlsTempReturnWithReplacements}")
							else :;
								local -a vlsTempArray=("${vlsTempArray[@]}" "${vlsTempReturnWithReplacements}")
							fi
							#echo -e "DEBUG: vlsTempArray[@]:\n$(printf -- '%s\n' "${vlsTempArray[@]}")"
							#echo "DEBUG: new size of vlsTempArray = ${cmsDoubleQuote_Open}${#vlsTempArray[@]}${cmsDoubleQuote_Close}"; echo
							vliTempArrayIndex=($vliTempArrayIndex+1)
							vlbAtLeastOneReplacementMade="true"

						fi
					fi
					vlsLastReplacement="${vlsCurrentReplacement}"
				done
				#echo "DEBUG: Replacement array loop end; no more replacement items"; echo

			done
			#echo "DEBUG: Return array loop end; no more return array items"; echo

			## Replace the return array with temp
			if [ "${vlbAtLeastOneReplacementMade}" == "true" ]; then :;
				#echo "DEBUG: vliReturnArrayAddCount=${cmsDoubleQuote_Open}${vliReturnArrayAddCount}${cmsDoubleQuote_Close}"
				local -a vlsReturnArray=("${vlsTempArray[@]}")
				#echo -e "DEBUG: vlsReturnArray[@]:\n$(printf -- '%s\n' "${vlsReturnArray[@]}")"
				#echo "DEBUG: new size of vlsReturnArray = ${cmsDoubleQuote_Open}${#vlsReturnArray[@]}${cmsDoubleQuote_Close}"; echo
				vliReturnArrayAddCount=($vliReturnArrayAddCount+1)
			else :;
				#echo "DEBUG: Return array loop break; no more replacements to make"; echo
				break
			fi

			#echo -e "\nDEBUG: Bottom of main loop.\nvlsReturnArray[@]:\n$(printf -- '%s\n' "${vlsReturnArray[@]}")"
		done
		#echo "DEBUG: Recursive array loop end; no more matches"; echo
	fi
	## Build output string
	vlsReturn="$(printf -- '%s\n' "${vlsReturnArray[@]}")"

	## Return value
	echo -e "${vlsReturn}"
}
## Test
#	clear; echo "$(fStrReplaceWithMultilinePermutations "OK□to□delete" "□" "" "[X]" "[Y]")"; exit 0

##---------------------------------------------------------------------------------------
function fEchoExpandedMatchV2(){ :;
	##	Returns many permutations of a match, expanded to multiple lines with line breaks - for --exclude-from and --include-from with RSync, Tar, etc.
	##	Special input characters:
	##		"A"		         = "[Aa]"							All alphabetic characters are case-insensitive 
	##		"₴"		(U+20B4) = "[a-zA-Z]"						Exactly one alpha match
	##		"₦"		(U+20A6) = "[0-9]"							Exactly one numeric match
	##		"✻"		(U+25CB) = Null, and "[a-zA-Z]"				Zero or exactly one alpha match
	##		"△"		(U+25B3) = Null, and "[0-9]"				Zero or exactly one numeric match
	##		"□"	(U+25A1) = Null, and "[^0-9a-zA-Z]"			Zero or exactly one non-alphanum match
	##		"▶"		(U+25B6) = "**/", "**[^0-9a-zA-Z]", and ""	Beginning of directory or non alphanumeric character
	##		"◀"		(U+25C0) = "/**", "[^0-9a-zA-Z]**", and ""	End of directory or non alphanumeric character

	local vlsReturn="$@"
	if [ -n "${vlsReturn}" ]; then :;
		vlsReturn="$(fStrReplaceWithCaseInsensitive "${vlsReturn}")"
		vlsReturn="$(fStrSearchAndReplace_DEPRECATED "${vlsReturn}" "₴" "[a-zA-Z]")"
		vlsReturn="$(fStrSearchAndReplace_DEPRECATED "${vlsReturn}" "₦" "[0-9]")"
		vlsReturn="$(fStrReplaceWithMultilinePermutations "${vlsReturn}" "✻" "" "[a-zA-Z]")"
		vlsReturn="$(fStrReplaceWithMultilinePermutations "${vlsReturn}" "△" "" "[0-9]")"
		vlsReturn="$(fStrReplaceWithMultilinePermutations "${vlsReturn}" "□" "" "[^0-9a-zA-Z]")"
		vlsReturn="$(fStrReplaceWithMultilinePermutations "${vlsReturn}" "▶" "" "**[^0-9a-zA-Z]")"
		vlsReturn="$(fStrReplaceWithMultilinePermutations "${vlsReturn}" "◀" "" "/" "[^0-9a-zA-Z]**")"
	fi

	echo "${vlsReturn}"
}
## Test
#	clear; fEchoExpandedMatchV2 "▶1a2₴3₦4✻5△6□7◀"; exit 0
#	clear; fEchoExpandedMatchV2 "▶1"; exit 0
#	clear; fEchoExpandedMatchV2 "▶1◀"; exit 0
#	clear; cmsExcludeList_Folder="${HOME}/tmp"; cmsExcludeList_Filespec="${HOME}/tmp/debug_$(basename $0)_fInit_ExcludesFile.txt"; fInit_ExcludesFile; gedit "${cmsExcludeList_Filespec}" &> /dev/null & disown; sleep 5; rm "${cmsExcludeList_Filespec}"; exit 0

## ----------------------------------------------------------------------------------------
function fStrNormalize() {
	##	Purpose:
	##		- Strips leading and trailing spaces from string.
	##		- Changes all whitespace inside a string to single spaces.
	##	References:
	##		- https://unix.stackexchange.com/a/205854
	##	History
	##		- 20190701 JC: Created
	##		- 20190724 JC: Didn't work on newlines. Fixed.
	local argStr="$@"
	argStr="${argStr//$'\n'/ }"  ## Convert newlines to spaces
	argStr="${argStr//$'\t'/ }"  ## Convert tabs to spaces
	argStr="$(echo "${argStr}" | awk '{$1=$1};1' 2> /dev/null || true)"  ## Collapse multiple spaces to one and trim
	echo "${argStr}"
}

## ----------------------------------------------------------------------------------------
function fStrTrim(){
	##	Purpose:
	##		Trims leading and trailing whitespace characters from a string
	##		To use this function: MyString="$(fStrTrim_DEPRECATED "${MyString}")"
	##	History:
	##		- 20140519 JC: Created
	##		- 20141002 JC: Updated
	##		- 20160827 JC: Ignores error i.
	##		- 20190702 JC:
	##			- Deprecated previous function to fStrTrim_DEPRECATED(), this is a rewrite with the same interface.
	##			- Use a cleaner method.
	##		- 20190926 JC: Echo outputStr, rather than inputStr (oops!).

	local inputStr="$@"
	if [ -n "${inputStr}" ]; then
		outputStr="$(echo -e "${inputStr}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' 2> /dev/null || true)"  ## Strip of leading and trailing spaces or tabs.
	fi
	echo -n "${outputStr}"
}

## ----------------------------------------------------------------------------------------
function fStrTrim_DEPRECATED(){ :;
	##	Purpose:
	##		Trims leading and trailing whitespace characters from a string
	##		To use this function: MyString="$(fStrTrim_DEPRECATED "${MyString}")"
	##	History:
	##		- 20140519 JC: Created
	##		- 20141002 JC: Updated
	##		- 20160827 JC: Ignores error i.
	##		- 20190702 JC: Refactored with better code

	## Input
	local vlsInput="$@"
	local vlsOutput=""

	if [ -n "${vlsInput}" ]; then :;
		## Constants
		local clsPattern="[[:space:]]*([^[:space:]]|[^[:space:]].*[^[:space:]])[[:space:]]*"

		## General-purpose method for removal
		fDefineTrap_Error_Ignore
		    [[ \"${vlsInput}\" =~ \"${clsPattern}\" ]]
		    vlsOutput="${BASH_REMATCH[1]}"
		fDefineTrap_Error_Fatal
	fi
	echo -n "${vlsOutput}"
}


##---------------------------------------------------------------------------------------
function fDoFunctionAs_SpecifiedUser(){ :;
	##	TODO:
	##		- Ingest and handle packed args.
	##		- Future edit ID: 9df8d781-e592-42b7-8edc-c2800bb575d6
	##	History:
	##		- 20140311 JC: Created
	fEcho_IfDebug "fDoFunctionAs_SpecifiedUser()"
	local vlsFunctionName="$1"
	local vlsUserName="$2"
	local vlsArgs="${@:3}"
	if [ -n "${vlsFunctionName}" ]; then :;
		if [ -n "${vlsUserName}" ]; then :;
			if [ "${USER}" == "${vlsUserName}" ]; then :;
				## Already running as sudo, so just do invoke the function directly.
				## 20140224 JC: Fixed bug by removing quotes.
				$vlsFunctionName ${vlsArgs}
			else :;
				## Need to call self re-entrantly as sudo. The execution control section at bottom will handle reentrancy and function calling.
				local vlsPath_Me="$(fGetFileSpec_OfMe)"
				sudo -H -u $cmsRunAsUser bash -c "${vlsPath_Me} reentrant_do_function ${vlsFunctionName} ${vlsArgs}"
			fi
		else :;
			fThrowError "fDoFunctionAs_SpecifiedUser(): Programmer error - no username specified as an argument."
		fi
	else :;
		fThrowError "fDoFunctionAs_SpecifiedUser(): Programmer error - no function name specified as an argument."
	fi
}

##-----------------------------------------------------------------------------------------------------
function fGetWhich(){
	##	Echos:
	##		Results "which" but without erroring.
	##	History:
	##		- 20140304 JC: Created.
	which "$@" 2> /dev/null || true
}
##-----------------------------------------------------------------------------------------------------
function fGetUname(){ :;
	##	Echos:
	##		Results of uname -s or uname -o
	##	History:
	##		- 20140304 JC: Created.

	local vlsReturn=""

	## Get major name
	fDefineTrap_Error_Ignore
		vlsReturn="$(uname -s 2> /dev/null)"
		if [ -z "${vlsReturn}" ]; then :;
			vlsReturn="$(uname -o 2> /dev/null)"
		fi
	fDefineTrap_Error_Fatal

	## Sanitize
	if [ -z "${vlsReturn}" ]; then :;
		vlsReturn="unknown"
	fi
	vlsReturn="${vlsReturn,,}"

	## Returns
	echo "${vlsReturn}"

}

##-----------------------------------------------------------------------------------------------------
function fGetPlatform(){ :;
	##	Echos:
	##		cygwin, macosx, or linux
	##	History:
	##		- 20140304 JC: Created.
	local vlsReturn=""
	local vlsUname="$(fGetUname)"
	case "${vlsUname}" in
		"linux")
			vlsReturn="linux"
		;;
		"darwin")
			vlsReturn="macosx"
		;;
		"sunos")
			vlsReturn="solaris"
		;;
		"cygwin")
			vlsReturn="windows"
		;;
		"mingw")
			vlsReturn="windows"
		;;
		"freebsd")
			vlsReturn="bsd"
		;;
		"netbsd")
			vlsReturn="bsd"
		;;
		"openbsd")
			vlsReturn="bsd"
		;;
		"freebsd")
			vlsReturn="bsd"
		;;
		*)
			vlsReturn="${vlsUname}"
		;;
	esac
	echo "${vlsReturn}"
}

##-----------------------------------------------------------------------------------------------------
function fGetOS(){ :;
	##	Echos:
	##		ubuntu, linuxmint, solaris, cygwin, etc.
	##	History:
	##		- 20140304 JC: Created.
	##	TODO: Test on different platforms.
	local vlsReturn=""
	local vlsUname="$(fGetUname)"
	local vlsPlatform="$(fGetPlatform)"
	local vlsLsbReleaseIs=""
	fDefineTrap_Error_Ignore
		vlsLsbReleaseIs="$(lsb_release -is 2> /dev/null)"
		vlsLsbReleaseIs="${vlsLsbReleaseIs,,}"
	fDefineTrap_Error_Fatal


	case "${vlsPlatform}" in
		"linux")
			vlsReturn="${vlsLsbReleaseIs}"
		;;
		"macosx")
			vlsReturn="${vlsLsbReleaseIs}"
		;;
		"solaris")
			vlsReturn="${vlsLsbReleaseIs}"
		;;
		"windows")
			vlsReturn="$(fGetUname)"
		;;
		*)
			vlsReturn="unknown"
		;;
	esac
	echo "${vlsReturn}"
}

##-----------------------------------------------------------------------------------------------------
function fIsOS_DebianBased(){ :;
	##	Echos: true or false
	##	History:
	##		- 20140304 JC: Created.
	local vlsReturn="false"
	if [ "$(fGetPlatform)" == "linux" ]; then :;
		case "$(fGetOS)" in
			debian )
				vlsReturn="true"
			;;
			ubuntu | xubuntu | kubuntu | lubuntu )
				vlsReturn="true"
			;;
			mint | linuxmint )
				vlsReturn="true"
			;;
		esac
	fi
	echo "${vlsReturn}"
}

##-----------------------------------------------------------------------------------------------------
function fIsOS_FedoraBased(){ :;
	##	Echos: true or false
	##	History:
	##		- 20140304 JC: Created.
	local vlsReturn="false"
	if [ "$(fGetPlatform)" == "linux" ]; then :;
		case "$(fGetOS)" in
			fedora | redhat | centos | oraclelinux )
				vlsReturn="true"
			;;
		esac
	fi
	echo "${vlsReturn}"
}

##-----------------------------------------------------------------------------------------------------
function fGetPreferredEditor_GUI(){ :;
	## 20140224 JC: Created
	## 20160831 JC: Greatly improved, with conditional checking of sudo and handling of Geany "domain socket" error.
	local vlsReturn=""
	local vlsTest=""

	## If sudo
	if [ "$(fIsSudo)" == "true" ]; then :;
		vlsTest="geany";      if [ -z "${vlsReturn}" ]; then if [ "$(fIsInPath ${vlsTest})" == "true" ]; then vlsReturn="${vlsTest} -c /tmp/geany_root_socket"; fi; fi
		vlsTest="sublime";    if [ -z "${vlsReturn}" ]; then if [ "$(fIsInPath ${vlsTest})" == "true" ]; then vlsReturn="${vlsTest}"; fi; fi

	## Not sudo
	else :;
		vlsTest="sublime";    if [ -z "${vlsReturn}" ]; then if [ "$(fIsInPath ${vlsTest})" == "true" ]; then vlsReturn="${vlsTest}"; fi; fi
		vlsTest="geany";      if [ -z "${vlsReturn}" ]; then if [ "$(fIsInPath ${vlsTest})" == "true" ]; then vlsReturn="${vlsTest}"; fi; fi
	fi

	## The rest
	if [ -z "${vlsReturn}" ]; then :;
		vlsTest="pluma";      if [ -z "${vlsReturn}" ]; then if [ "$(fIsInPath ${vlsTest})" == "true" ]; then vlsReturn="${vlsTest}"; fi; fi
		vlsTest="mousepad";   if [ -z "${vlsReturn}" ]; then if [ "$(fIsInPath ${vlsTest})" == "true" ]; then vlsReturn="${vlsTest}"; fi; fi
		vlsTest="leafpad";    if [ -z "${vlsReturn}" ]; then if [ "$(fIsInPath ${vlsTest})" == "true" ]; then vlsReturn="${vlsTest}"; fi; fi
		vlsTest="gedit";      if [ -z "${vlsReturn}" ]; then if [ "$(fIsInPath ${vlsTest})" == "true" ]; then vlsReturn="${vlsTest}"; fi; fi
	fi

	## Return
	if [ -z "${vlsReturn}" ]; then :;
		fThrowError "No suitable GUI editor installed on system."
	else :;
		echo "${vlsReturn}"
	fi
}

##-----------------------------------------------------------------------------------------------------
function fGetPreferredEditor_CLI(){ :;
	## 20140224 JC: Created
	local vlsReturn=""
	if   [ "$(fIsInPath nano)" == "true" ]; then :;
		vlsReturn="nano"
	elif [ "$(fIsInPath pico)" == "true" ]; then :;
		vlsReturn="pico"
	elif [ "$(fIsInPath vi)" == "true" ]; then :;
		vlsReturn="vi"
	else :;
		fThrowError "No suitable CLI editor installed on system."
	fi
	echo "${vlsReturn}"
}

##-----------------------------------------------------------------------------------------------------
function fPromptYN(){ :;
	## 20140219 JRC: Copied/refactored from fPromptToRunScript().
	fEcho_IfDebug "fPromptYN()"

	local vlsTemp=""
	local -l vlsResponse=""

	read -p "Continue? (Y/n) " vlsTemp
	vlsResponse="${vlsTemp,,}"  ## Convert to lower-case
	fEcho_ResetBlankCounter

	case "$vlsResponse" in
		("y"|"ye"|"yes")
			:
		;;
		(*)
			fEcho "User declined."
			fEcho ""
			exit 0
		;;
	esac
}

##-----------------------------------------------------------------------------------------------------
function fPromptYN_v2(){ :;
	## 20190127 JRC: Copied from fPromptYN(). Doesn't wait for return key, and minimizes blank line echoes.
	fEcho_IfDebug "fPromptYN()"

	local vlsTemp=""
	local -l vlsResponse=""

	read -n 1 -p "Continue? (Y/n) " vlsTemp
	echo  ## Because there's no newline character after above.
	vlsResponse="${vlsTemp,,}"  ## Convert to lower-case
	fEcho_ResetBlankCounter

	case "$vlsResponse" in
		"y") : ;;  ## Do nothing
		*)   fEcho "User declined."; exit 0 ;;
	esac
}

##-----------------------------------------------------------------------------------------------------
function fPromptToRunScript(){ :;
	## 20130514 JRC: Copied from old jclibrary001-v001 and stripped down to its essentials.
	## 20140219 JC:
	##		- Moved logic into fPromptYN()
	##		- Renamed from fPromptToRunScript().
	fEcho_IfDebug "fPromptToRunScript()"
	fprivate_GenericWrapper_ShowDescriptionAndCopyright
	fPromptYN
}

##-----------------------------------------------------------------------------------------------------
function fFilesysObjectCannotExist(){ :;
	## 20170723-07 JC: Created.
	fEcho_IfDebug "fFilesysObjectCannotExist()"

	local vlsArg="$@"
	local vlbDoesExist="true"  ## Until proven otherwise

	## Test
	if [ ! -d "${vlsArg}" ]; then :;
		if [ ! -f "${vlsArg}" ]; then :;
			if [ ! -L "${vlsArg}" ]; then :;
				vlbDoesExist="false"
			fi
		fi
	fi

	## Act
	if [ "${vlbDoesExist}" == "true" ]; then :;
		fThrowError "File system object must not exist: ${cmsDoubleQuote_Open}${vlsArg}${cmsDoubleQuote_Close}"
	fi
}

##---------------------------------------------------------------------------------------
function fFolderMustExist(){ :;
	## 20140219 JC: Created.
	fEcho_IfDebug "fFolderMustExist()"
	local vlsArg="$@"
	if [ ! -d "${vlsArg}" ]; then :;
		fThrowError "Folder doesn’t exist: ${cmsDoubleQuote_Open}${vlsArg}${cmsDoubleQuote_Close}"
	fi
}

##---------------------------------------------------------------------------------------
function fFolderCannotExist(){ :;
	## 20140219-07 JC: Created.
	fEcho_IfDebug "fFolderCannotExist()"
	local vlsArg="$@"
	if [ -d "${vlsArg}" ]; then :;
		fThrowError "Folder must not exist: ${cmsDoubleQuote_Open}${vlsArg}${cmsDoubleQuote_Close}"
	fi
}

##---------------------------------------------------------------------------------------
function fIsInvokedFromCLI(){ :;
	## 20140219 JC: Copied/refactored/simplified from "...0-common/includes/...".
	local -l vlbTemp="false"
	if [ -t 0 ]; then :;
		vlbTemp="true"
	fi
	echo "${vlbTemp}"
}

##-----------------------------------------------------------------------------------------------------
function fMsgBlocking(){ :;
	## 20140219 JC: Copied/refactored/simplified from "...0-common/includes/...".
	fEcho_IfDebug "fMsgBlocking()"

	local vlsMessage="$@"
	local vlsScriptName="$(fGetFileName_OfMe)"

	if [ "$(fIsInvokedFromCLI)" == "true" ]; then :;
		if [ -z "${vlsMessage}" ]; then vlsMessage="Press [ENTER] when ready."; fi
		read -p "${vlsMessage}"
	else :;
		if [ -z "${vlsMessage}" ]; then vlsMessage="Press [OK] when ready."; fi
		zenity --info --title "${vlsScriptName} Pause" --text "${vlsMessage}"
	fi
}

##-----------------------------------------------------------------------------------------------------
function fIsSessionGUI(){ :;
	## 20140219 JC: Copied/refactored/simplified from "...0-common/includes/...".
	local -l vlbTemp="false"
	if [ -n "${DISPLAY}" ]; then :;
		vlbTemp="true"
	fi
	echo "${vlbTemp}"
}

##-----------------------------------------------------------------------------------------------------
function fEdit(){ :;
	## 20160827 JC: Created.
	fEcho_IfDebug "fEdit()"
	if [ "$(fIsSessionGUI)" == "true" ]; then :;
		fEdit_GUI_NonBlocking "$@"
	else :;
		fEdit_CLI "$@"
	fi
}

##-----------------------------------------------------------------------------------------------------
function fEdit_Blocking(){ :;
	## 20140219 JC: Copied/refactored/simplified from "...0-common/includes/...".
	fEcho_IfDebug "fEdit_Blocking()"
	if [ "$(fIsSessionGUI)" == "true" ]; then :;
		fEdit_GUI_Blocking "$@"
	else :;
		fEdit_CLI "$@"
	fi
}

##-----------------------------------------------------------------------------------------------------
function fEdit_GUI_Blocking(){ :;
	## 20140219 JC: Copied/refactored/simplified from "...0-common/includes/...".
	## 20160827 JC: Removed required argument constraint.
	fEcho_IfDebug "fEdit_GUI()"
	if [ "$(fIsInvokedFromCLI)" == "true" ]; then :;
		fEcho "Editing ${cmsDoubleQuote_Open}$@${cmsDoubleQuote_Close}; script will resume when editor is closed."
		$(fGetPreferredEditor_GUI) "$@" &> /dev/null
	else :;
		fEdit_GUI_NonBlocking
		fMsgBlocking "Press [OK] when you are finished editing."
	fi
}

##-----------------------------------------------------------------------------------------------------
function fEdit_GUI_NonBlocking(){ :;
	## 20140219 JC: Copied/refactored/simplified from "...0-common/includes/...".
	## 20160827 JC: Removed required argument constraint.
	fEcho_IfDebug "fEdit_GUI_NonBlocking()"
	$(fGetPreferredEditor_GUI) "$@" &> /dev/null & disown
}

##-----------------------------------------------------------------------------------------------------
function fEdit_CLI(){ :;
	## 20140219 JC: Copied/refactored/simplified from "...0-common/includes/...".
	## 20160827 JC: Removed required argument constraint.
	fEcho_IfDebug "fEdit_CLI()"
	local vlsFile="$@"
	$(fGetPreferredEditor_CLI) "${vlsFile}"
	if [ -f "${vlsFile}" ]; then :;
		fEcho_ResetBlankCounter
		fEcho ""
		echo "------------------------------------ BOF --------------------------------------"
		cat "${vlsFile}"
		echo "------------------------------------ EOF --------------------------------------"
		fEcho_ResetBlankCounter
		fEcho ""
	fi
}

##-----------------------------------------------------------------------------------------------------
function fPing(){ :;
	## 20140219 JC: Copied/refactored/simplified from "jcPing".
	fEcho_IfDebug "fPing()"

	local vlsAddress="$1"
	local vlsReply=""

	## Do the ping.
	fDefineTrap_Error_Ignore
		#vlsReply="$((ping -c 1 -w 2 -W 2 ${vlsAddress}  | grep icmp_ ) 2> /dev/null)"  ## This line screws up several text editor's formatting from here on
		#vlsReply="$(ping -c 1 -w 2 -W 2 ${vlsAddress}  | grep icmp_ 2> /dev/null)"
		vlsReply="$(ping -c 1 -w 2 -W 2 ${vlsAddress} 2> /dev/null | grep "icmp_" 2> /dev/null)"
	fDefineTrap_Error_Fatal

	##	Unused ping options:
	##		-D .......... Print timestamp

	## Note if no reply
	if [ -z "${vlsReply}" ]; then vlsReply="(Unreachable, error, and/or no reply.)"; fi

	## Pad output
	vlsFill='...........'
	local vlsOutput=""
	local vlsTimestamp=$(date "+%Y%m%d-%H%M%S")
	vlsOutput=$(printf "%s %s $vlsReply\n" $vlsAddress ${vlsFill:${#vlsAddress}})
	echo "[ ${vlsTimestamp} ] ${vlsOutput}"

}

##-----------------------------------------------------------------------------------------------------
function fMakeDir(){ :;
	## 20140219 JC: Copied/refactored/simplified from "jcinit_custom-folders-and-symlinks2".
	fEcho_IfDebug "fMakeDir()"

	local vlsFolderPath="$1"

	if [ "${mlbCheckOnly}" == "true" ]; then :;
		## Check only

		if [ -d "${vlsFolderPath}" ]; then :;
			fEcho "FYI: The directory ${cmsDoubleQuote_Open}${vlsFolderPath}${cmsDoubleQuote_Close} already exists."
		fi

	else :;
		## Do it

		## Make the folder
		fEchoAndDo "mkdir -p ${vlsFolderPath}"

	fi

}

##-----------------------------------------------------------------------------------------------------
function fMakeSymlink(){ :;
	local funcName="fMakeSymlink"
	##	Purpose:
	##		- Creates or deletes and recreates a symlink.
	##		- Safe: Does not delete object of same name, if it isn't a symlink.
	##	History:
	##		- 20140219 JC: Copied/refactored/simplified from "jcinit_custom-folders-and-symlinks2".
	##		- 20190525 JC:
	##			- Rewrote mostly from scratch with clearer stages, inferences, checks, and execution steps.
	##			- Made arguments read-only variables.
	fEcho_IfDebug "${funcName}()"

	## Arguments
	local -r sourceSpec="$1"  ## Source file or folder ("Target" in ln manpage)
	local -r linkSpec="$2"    ## Symlink to create

	## Variables; object statuses
	local sourceExists="false"
	local linkSpecObjectExists="false"
	local linkSpecIsLink="false"
	
	## Variables; actions
	local doDeleteLink="false"
	local doMakeLink="false"

	## Observe object statuses
	if [ -e "${sourceSpec}" ]; then sourceExists="true"        ; fi
	if [ -e "${linkSpec}" ]  ; then linkSpecObjectExists="true"; fi
	if [ -h "${linkSpec}" ]  ; then linkSpecIsLink="true"      ; fi

	## Inferences from object statuses, error-handling, and messages
	case "${sourceExists}_${linkSpecIsLink}_${linkSpecObjectExists}" in

		"false"*)
			## Source doesn't exist
			fThrowError "${funcName}(): Source object to symlink to doesn't exist: ${cmsDoubleQuote_Open}${sourceSpec}${cmsDoubleQuote_Close}."
			;;

		*"false_true")
			## Object exists but isn't a link
			fThrowError "${funcName}(): Object conflict: ${cmsDoubleQuote_Open}${linkSpec}${cmsDoubleQuote_Close} already exists but is not a symlink."
			;;

		*"true_true")
			## Valid link
			fEcho "FYI: The symlink ${cmsDoubleQuote_Open}${linkSpec}${cmsDoubleQuote_Close} already exists but will be deleted and re-created."
			doDeleteLink="true"
			doMakeLink="true"
			;;

		*"true_false")
			## Broken link; a correct but not very intuitive inference
			fEcho "FYI: The symlink ${cmsDoubleQuote_Open}${linkSpec}${cmsDoubleQuote_Close} is a broken symlink and will be deleted and re-created."
			doDeleteLink="true"
			doMakeLink="true"
			;;

		*"false_false")
			## Nothing at all exists by this link specification
		#	fEcho "DEBUG FYI: The object ${cmsDoubleQuote_Open}${sourceSpec}${cmsDoubleQuote_Close} does exist, and symlink ${cmsDoubleQuote_Open}${linkSpec}${cmsDoubleQuote_Close} does NOT already exist."
			doMakeLink="true"
			;;

		*)
			## Unexpected combination
			fThrowError "${funcName}(): An unexpected combination of variables '${sourceExists}_${linkSpecIsLink}_${linkSpecObjectExists}' was encountered; there may be a bug in the case statement."

	esac

#	## Debug
#	fEcho_VariableAndValue sourceExists
#	fEcho_VariableAndValue linkSpecObjectExists
#	fEcho_VariableAndValue linkSpecIsLink
#	fEcho_VariableAndValue doDeleteLink
#	fEcho_VariableAndValue doMakeLink

	## Do the things
	if [ "${mlbCheckOnly}" != "true" ]; then :;

		## Delete existing link
		if [ "${doDeleteLink}" == "true" ]; then rm "${linkSpec}"                   ; fi

		## Create link
		if [ "${doMakeLink}"   == "true" ]; then ln -s "${sourceSpec}" "${linkSpec}"; fi

	fi

}

##-----------------------------------------------------------------------------------------------------
function fEcho_VariableAndValue(){ :;
	## 20140206-07 JC: Copied/refactored/simplified from "...0-common/includes/...".
	local vlsVariableName="$1"
	if [ -z "${vlsVariableName}" ]; then :;
		fThrowError "fEcho_VariableAndValue(): No variable to echo value of."
	else :;
		local vlsValue="${!vlsVariableName}"
		fEcho "${vlsVariableName} = ${cmsDoubleQuote_Open}${vlsValue}${cmsDoubleQuote_Close}"
	fi
}

##-----------------------------------------------------------------------------------------------------
function fEcho_IfDebug_VariableAndValue(){ :;
	## 20140206-07 JC: Copied/refactored/simplified from "...0-common/includes/...".
	local vlsVariableName="$1"
	if [ -z "${vlsVariableName}" ]; then :;
		fThrowError "fEcho_IfDebug_VariableAndValue(): No variable to echo value of."
	else :;
		local vlsValue="${!vlsVariableName}"
		fEcho_IfDebug "${vlsVariableName} = ${cmsDoubleQuote_Open}${vlsValue}${cmsDoubleQuote_Close}"
	fi
}

##--------------------------------------------------------------------------------------------
function fMath_Int_Max(){ :;
	## Echos the maximum of two integers
	## 20140206-07 JC: Created.
	local -i vliArg1=$1
	local -i vliArg2=$2
	local -i vliReturn=0
	if [ $vliArg1 > $vliArg2 ]; then :;
		vliReturn=vliArg1
	else :;
		vliReturn=vliArg2
	fi
	echo $vliReturn
}

##--------------------------------------------------------------------------------------------
function fMath_Int_Min(){ :;
	## Echos the minimum of two integers
	## 20140206-07 JC: Created.
	local -i vliArg1=$1
	local -i vliArg2=$2
	local -i vliReturn=0
	if [ $vliArg1 -lt $vliArg2 ]; then :;
		vliReturn=vliArg1
	else :;
		vliReturn=vliArg2
	fi
	echo $vliReturn
}

##--------------------------------------------------------------------------------------------
function fPrintLineTerminalWidth(){ :;
	## 20140206-07 JC: Created.
	local -i vliCount
	local -i vliColumns=$(tput cols)
	local clsCharacter="—" ## ▞▚▒░▓䷀█▂▁▔—
	local vlsOutput=""
	for ((vliCount = 1 ; vliCount <= vliColumns ; vliCount++)); do
		vlsOutput="${vlsOutput}${clsCharacter}"
	done
	echo "$(tput setaf 5)${vlsOutput}$(tput sgr 0)"
}

##-----------------------------------------------------------------------------------------------------
function fAppendToFile(){ :;
	## 20140206-07 JC: Created.
	fEcho_IfDebug "fAppendToFile()"

	local vlsFile="$1"
	local vlsWhatToOutput="${@:2}"

	fVariableCannotBeEmpty "vlsFile"

	echo "${vlsWhatToOutput}" >> "${vlsFile}"

}

##-----------------------------------------------------------------------------------------------------
function fAppendCommentToFile(){ :;
	fEcho_IfDebug "fAppendCommentToFile()"

	local vlsFile="$1"
	local vlsWhatToOutput="${@:2}"

	if [ -z "${vlsWhatToOutput}" ]; then :;
		vlsWhatToOutput="##"
	else :;
		vlsWhatToOutput="## ${vlsWhatToOutput}"
	fi

	fAppendToFile "${vlsFile}" "${vlsWhatToOutput}"

}

##-----------------------------------------------------------------------------------------------------
function fVariableCannotBeEmpty(){ :;
	## 20140206-07 JC: Created.
	fEcho_IfDebug "fVariableCannotBeEmpty()"

	## Debug
	#echo "fVariableCannotBeEmpty(): \$1 = '$1'"

	#local vlsCallingFunction="$1"  ## Too hard to remember to include this
	local vlsVariableName="$1"
	local vlsVariableValue="${!vlsVariableName}"

	if [ -z "${vlsVariableValue}" ]; then :;
		fThrowError "The variable ${cmsDoubleQuote_Open}${vlsVariableName}${cmsDoubleQuote_Close} cannot be empty."
	fi
}

##---------------------------------------------------------------------------------------
function fFunctionArgumentCannotBeEmpty(){ :;
	## 20140206 JC: Created.
	## 20180306 JC: Added 4th argument for purpose of parameter.
	fEcho_IfDebug "fFunctionArgumentCannotBeEmpty()"

	## Arguments
	local vlsCallingFunction="$1"
	local vlsVariableOrdinal="$2"
	local vlsVariableValue="$3"
	local vlsVariablePurpose="$4"    ## Optional

	if [ -z "${vlsVariableValue}" ]; then :;
		local errorMsg="Parameter ${vlsVariableOrdinal} for function ${vlsCallingFunction} cannot be empty."
		[ -n "${vlsVariablePurpose}" ] && errorMsg="${errorMsg} It is supposed to contain: $4."
		fThrowError "${errorMsg}"
	fi
}

##---------------------------------------------------------------------------------------
function fFileMustExist(){ :;
	## 20140206-07 JC: Created.
	fEcho_IfDebug "fFileMustExist()"
	local vlsFile="$@"
	#fEcho_IfDebug_VariableAndValue "vlsFile"
	if [ ! -f "${vlsFile}" ]; then :;
		fThrowError "File does not exist: ${cmsDoubleQuote_Open}${vlsFile}${cmsDoubleQuote_Close}"
	fi
}

##---------------------------------------------------------------------------------------
function fFileCannotExist(){ :;
	## 20140206-07 JC: Created.
	fEcho_IfDebug "fFileCannotExist()"
	local vlsFile="$@"
	if [ -f "${vlsFile}" ]; then :;
		fThrowError "File must not exist: ${cmsDoubleQuote_Open}${vlsFile}${cmsDoubleQuote_Close}"
	fi
}

##---------------------------------------------------------------------------------------
function fDoesFolderExist(){ :;
	## 20140206-07 JC: Created.
	local vlsFolder="$@"
	local vlsReturn="false"
	if [ -d "${vlsFolder}" ]; then :;
		vlsReturn="true"
	fi
	echo "${vlsReturn}"
}

##---------------------------------------------------------------------------------------
function fDoesFileExist(){ :;
	## 20140206-07 JC: Created.
	local vlsFile="$@"
	local vlsReturn="false"
	if [ -f "${vlsFile}" ]; then :;
		vlsReturn="true"
	fi
	echo "${vlsReturn}"
}

##---------------------------------------------------------------------------------------
function fDoesFileOrFolderExist(){ :;
	## 20140206-07 JC: Created.
	local vlsFileOrFolder="$@"
	local vlsReturn="false"
	if [ -e "${vlsFileOrFolder}" ]; then :;
		vlsReturn="true"
	fi
	echo "${vlsReturn}"
}

##---------------------------------------------------------------------------------------
function fGetTimeStamp(){ :;
	##	Purpose:
	##		Returns a numerically sequential, minimally-formatted serial number based on date and time.
	##		Format: "YYYYMMDD-HHMMSS".
	##	History:
	##		- 20181028 JC: Created simplified version based on fGetTimeStamp2().
	fEcho_IfDebug "fGetTimeStamp()"

	echo "$(date "+%Y%m%d-%H%M%S")"
}

##---------------------------------------------------------------------------------------
function fGetTimeStamp2(){ :;
	##	Purpose:
	##		Returns a numerically sequential, minimally-formatted serial number based on date and time.
	##		By default, the format is "YYYYMMDD-HHMMSS".
	##	Arguments:
	##		1: Decimals of fractional seconds (0-6; defaults to 0).
	## 		2: Delimiter between date and time (defaults to "-").
	## 		3: Delimiter between time and fractional seconds (defaults to ".").
	##	History:
	##		- 20140129 JC: Created.
	##		- 20160725 JC: Updated:
	##			- Optional millisecond output with specified precision.
	##			- Optional delimiter overrides between date and time, and time and milliseconds.
	##		- 20181028 JC: Renamed fGetTimeStamp2(), and made fGetTimeStamp() a simplified version.
	fEcho_IfDebug "fGetTimeStamp2()"

	## Arguments
	local vlsFractionalSecondsDigits="$1"
	local vlsDelimiter1="$2"
	local vlsDelimiter2="$3"
	local vlsFormat=""
	local vlsReturn=""

	## Validate args and set defaults
	if [ -z "${vlsDelimiter1}" ]; then vlsDelimiter1="-"; fi
	if [ -n "${vlsFractionalSecondsDigits}" ]; then :;
		vlsFractionalSecondsDigits="%${vlsFractionalSecondsDigits}N"
		if [ -z "${vlsDelimiter2}" ]; then vlsDelimiter2="."; fi
	else :;
		vlsDelimiter2=""
	fi

	## Get formatted date, e.g. command: date "+%Y%m%d-%H%M%S.%4N"
	vlsFormat="+%Y%m%d${vlsDelimiter1}%H%M%S${vlsDelimiter2}${vlsFractionalSecondsDigits}"  #"+%Y%m%d-%H%M%S.%4N"
	vlsReturn="$(date "${vlsFormat}")"

	## Return
	echo "${vlsReturn}"
}

##-----------------------------------------------------------------------------------------------------
function fDoFunctionAs_Sudo(){ :;
	##	History:
	##		- 20180818 JC: Added "-E" flag to sudo command, to retain environment variables.
	fEcho_IfDebug "fDoFunctionAs_Sudo()"
	local -r vlsFunctionName="$1"
	local -r vlsPackedArgs="$2"
	local -r vlsNonPackedArgs="${@:3}"  ## Edit ID: 41be5316-0c17-439b-bf03-fae72e4cdf38

	if [ -n "${vlsFunctionName}" ]; then :;
		if [ "$(fIsSudo)" == "true" ]; then :;
			## Already running as sudo, so just do invoke the function directly.
			## 20140224 JC: Fixed bug by removing quotes.
			$vlsFunctionName "${vlsPackedArgs}" ${vlsNonPackedArgs}  ## Edit ID: 41be5316-0c17-439b-bf03-fae72e4cdf38
			#$vlsFunctionName "${vlsPackedArgs}"
		else :;
			## Need to call self re-entrantly as sudo. The execution control section at bottom will handle reentrancy and function calling.
			local vlsPath_Me="$(fGetFileSpec_OfMe)"
			fGetSudo
			sudo -E $vlsPath_Me "reentrant_do_function" "${vlsFunctionName}" "${vlsPackedArgs}" ${vlsNonPackedArgs}  ## Edit ID: 41be5316-0c17-439b-bf03-fae72e4cdf38
			#sudo $vlsPath_Me "reentrant_do_function" "${vlsFunctionName}" "${vlsPackedArgs}"
		fi
	else :;
		fThrowError "fDoFunctionAs_Sudo(): Programmer error - no function name specified as an argument."
	fi
}

##-------------------------------------------------------------------------------------------------------------------
function fIsSudo(){ :;
	local -l vlbReturn="false"
	if [ "$(id -u)" == "0" ]; then vlbReturn="true"; fi
	echo "${vlbReturn}"
}

##-----------------------------------------------------------------------------------------------------
function fIsSudoValid(){ :;
	fDefineTrap_Error_Ignore
		local -l vlbReturn="false"
		## First check to see if we are already sudo
		if [ "$(id -u)" == "0" ]; then :;
			vlbReturn="true"
		else :;
			## Next, check to see if sudo is still cached
			sudo -n echo &> /dev/null
			if [ $? -eq 0 ]; then :;
				vlbReturn="true"
			fi
		fi
		echo "${vlbReturn}"
	fDefineTrap_Error_Fatal
}

##-------------------------------------------------------------------------------------------------------------------
function fDoFunction_Forked_AndLog(){ :;
	fEcho_IfDebug "fDoFunction_Forked_AndLog()"
	local vlsFunctionName="$1"
	local vlsArgs="${@:2}"
	if [ -n "${vlsFunctionName}" ]; then :;
		## Need to call self re-entrantly as sudo. The execution control section at bottom will handle reentrancy and function calling.
		local vlsPath_Me="$(fGetFileSpec_OfMe)"
		fRunForked_AndLog "$vlsPath_Me" "reentrant_do_function" "${vlsFunctionName}" "${vlsArgs}"
	else :;
		fThrowError "fDoFunction_Forked_AndLog(): Programmer error - no function name specified as an argument."
	fi
	fEcho_ResetBlankCounter
}

##-------------------------------------------------------------------------------------------------------------------
function fDoFunction_Forked_AndLog_PackedArgs(){ :;
	##	TODO:
	##		- Like fDoFunction_Forked_AndLog(), but ingest and handle packed args.
	##		- Future edit ID: 9df8d781-e592-42b7-8edc-c2800bb575d6
}

##-------------------------------------------------------------------------------------------------------------------
function fprivateGetFileSpec_OfFunctionHost(){ :;
	##	Purpose: Returns a fully qualified path/filename of the script hosting the calling function (e..g /somepath/0_library_v2).
	##	History:
	##		- 20171217 JC: Created.
	local vlsReturn=""
	if [ -z "${vlsReturn}" ]; then vlsReturn="${BASH_SOURCE[2]}"; fi   ## I invented/discovered this but have no idea why it works. No answers on interwebs.
	if [ -z "${vlsReturn}" ]; then vlsReturn="${BASH_SOURCE[1]}"; fi
	if [ -z "${vlsReturn}" ]; then vlsReturn="${BASH_SOURCE[1]}"; fi
	if [ -z "${vlsReturn}" ]; then vlsReturn="$0"; fi
	#if [ -z "${vlsReturn}" ]; then vlsReturn="$( cd "$(dirname "$0")" ; pwd -P )"; fi
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fprivateGetFolder_OfFunctionHost(){ :;
	##	Purpose: Returns a fully qualified path of the script hosting the calling function (e..g /somepath of 0_library_v2).
	##	History:
	##		- 20171217 JC: Created.
	local vlsFileSpec="$(fprivateGetFileSpec_OfFunctionHost)"
	local vlsReturn="$(dirname "${vlsFileSpec}")"
	#local vlsReturn="$(cd -P "$(dirname "${vlsFileSpec}")" && pwd)/$(basename ${vlsFileSpec})"  ## As found on interwebs.
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fprivateGetFileName_OfFunctionHost(){ :;
	##	Purpose: Returns the filename (no path) of the script hosting the calling function (e..g 0_library_v2).
	##	History:
	##		- 20171217 JC: Created.
	local vlsFileSpec="$(fprivateGetFileSpec_OfFunctionHost)"
	local vlsReturn="$(basename "${vlsFileSpec}")"
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fGetFileSpec_OfMe(){ :;
	##	Purpose: Returns a fully qualified path/filename of currently running parent script (e.g. /somepath/jcMyScript).
	##	History:
	##		- 20171217 JC: Created.
	local vlsFileSpec=""
	if [ -z "${vlsFileSpec}" ]; then vlsFileSpec="$0"; fi
	if [ -z "${vlsFileSpec}" ]; then vlsFileSpec="${BASH_SOURCE[0]}"; fi
	if [ -z "${vlsFileSpec}" ]; then vlsFileSpec="${BASH_SOURCE[1]}"; fi
	if [ -z "${vlsFileSpec}" ]; then vlsFileSpec="${BASH_SOURCE[2]}"; fi

	echo "${vlsFileSpec}"
}

##-------------------------------------------------------------------------------------------------------------------
function fGetFolder_OfMe(){ :;
	##	Purpose: Returns the folder of to the currently running parent script (e.g. /somepath of jcMyScript).
	##	History:
	##		- ? JC: Created.
	##		- 20171217 JC: Use fGetFileSpec_OfMe() instead of own logic.
	local vlsFileSpec="$(fGetFileSpec_OfMe)"
	local vlsReturn="$(dirname "${vlsFileSpec}")"
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fGetFileName_OfMe(){ :;
	##	Purpose: Returns the filename (no path) of the currently running parent script (e.g. jcMyScript).
	##	History:
	##		- ? JC: Created.
	##		- 20171217 JC: Use fGetFileSpec_OfMe() instead of own logic.
	local vlsFileSpec="$(fGetFileSpec_OfMe)"
	local vlsReturn="$(basename "${vlsFileSpec}")"
	echo "${vlsReturn}"
}

##-------------------------------------------------------------------------------------------------------------------
function fEcho(){ :;
	if [ -n "$1" ]; then :;
		fEcho_Clean "[ $@ ]"
	else :;
		fEcho_Clean ""
	fi
}


##---------------------------------------------------------------------------------------
function fEcho_Force(){ :;
	fEcho_ResetBlankCounter
	fEcho "$@"
}


##---------------------------------------------------------------------------------------
function fEcho_IfDebug(){ :;
	if [ "${cmbDebug}" == "true" ]; then :;
		echo "--- Debug: $@"
	fi
}


##---------------------------------------------------------------------------------------
function fEchoAndDo(){ :;
	fEcho "Executing: eval ${cmsDoubleQuote_Open}$@${cmsDoubleQuote_Close}"
	if [ "${cmbEchoAndDo_EchoOnly}" != "true" ]; then :;
		eval "$@"
	fi
}

##-------------------------------------------------------------------------------------------------------------------
function fEchoAndDo_Async(){ :;
	fEcho "Executing: eval ${cmsDoubleQuote_Open}$@${cmsDoubleQuote_Close} & disown"
	eval "$@" & disown
}

##-------------------------------------------------------------------------------------------------------------------
function fEchoAndDo_HideAllOutput(){ :;
	fEcho "Executing: eval ${cmsDoubleQuote_Open}$@${cmsDoubleQuote_Close} &> /dev/null"
	eval "$@" &> /dev/null
}

##-------------------------------------------------------------------------------------------------------------------
function fEchoAndDo_Async_HideAllOutput(){ :;
	fEcho "Executing: eval ${cmsDoubleQuote_Open}$@${cmsDoubleQuote_Close} &> /dev/null & disown"
	eval "$@" &> /dev/null & disown
}

##-------------------------------------------------------------------------------------------------------------------
function fEchoAndDo_HideNonError(){ :;
	fEcho "Executing: eval ${cmsDoubleQuote_Open}$@${cmsDoubleQuote_Close} > /dev/null"
	eval "$@" > /dev/null
}

##-------------------------------------------------------------------------------------------------------------------
function fThrowError(){ :;
	##	History
	##		- ? JC: Created.
	##		- 20190525 JC: Don't set fatal, so that we can avoid breaking if we want to.
	#fEcho_IfDebug "fThrowError()"

	#fDefineTrap_Error_Fatal  ## Don't set fatal, so that we can avoid breaking if we want to.
	fpErrMsg "$@"
	exit 1
}

##-------------------------------------------------------------------------------------------------------------------
function fEcho_ResetBlankCounter(){ :;
	vmbLastEchoWasBlank="false"
}

##-------------------------------------------------------------------------------------------------------------------
function fDefineTrap_Error_Fatal(){ :;
	#fEcho_IfDebug "fDefineTrap_Error_Fatal()"
	true
	trap 'fpTrap_Error_Fatal ${LINENO}' ERR
	set -e
	#vmsErrHandlingStr="eE"
}

##-------------------------------------------------------------------------------------------------------------------
function fDefineTrap_Error_Ignore(){ :;
	fEcho_IfDebug "fDefineTrap_Error_Ignore()"
	trap 'fprivate_Trap_Error_Ignore' ERR
	set +e
	#vmsErrHandlingStr=""
}

##-------------------------------------------------------------------------------------------------------------------
function fprivate_Trap_Exit(){ :;
	fEcho_IfDebug "fprivate_Trap_Exit()"
	fCleanup; }
function fprivate_Trap_Error_Ignore(){ :;
	#fEcho_IfDebug "fprivate_Trap_Error_Ignore()"
	true; }
function fprivate_GenericWrapper_ShowDescriptionAndCopyright(){ :;
	#fEcho_IfDebug "fprivate_GenericWrapper_ShowDescriptionAndCopyright()"
	if [ ! "${vmbWasShown_DescriptionAndCopyright}" == "true" ]; then :;
		vmbWasShown_DescriptionAndCopyright="true"
	#	fEcho ""
		fDescriptionAndCopyright
	#	fEcho ""
	fi; }
function fprivate_GenericWrapper_ShowSyntaxAndQuit(){ :;
	fprivate_GenericWrapper_ShowDescriptionAndCopyright
	fEcho ""
	fSyntax
	fEcho ""
	exit 1; }
function _fprivateErrHandling_ByStr_Get(){ :;
	##	Arguments: (None)
	##	Returns via echo: A string with zero, one, or more of "e" or "E" in any order. Where:
	##		"e": Break on errors. If not included, errors are ignored
	##		"E": Include called files. If not included, ignored.
	local returnStr=""
	if [[ "$-" == *"e"* ]]; then returnStr="${returnStr}e"; fi
	if [[ "$-" == *"E"* ]]; then returnStr="${returnStr}E"; fi
	echo "${returnStr}" ; }
function _fprivateErrHandling_ByStr_Set(){ :;
	##	Argument: A string with zero, one, or more of "e" or "E" in any order. Where:
	##		"e": Break on errors. If not included, errors are ignored
	##		"E": Include called files. If not included, ignored.
	##	Returns via echo: String of previous state.
	local prevVal="$(_fprivateErrHandling_ByStr_Get)"
	if [[ "$1" == *"e"* ]]; then set -e; else set +e; fi
	if [[ "$1" == *"E"* ]]; then set -E; else set +E; fi
	echo "${prevVal}" ; }
function _fprivateErrHandling_ByStr_Set_Ignore(){ :;
	##	Arguments: (None)
	##	Returns via echo: String of previous state.
	local prevVal="$(_fprivateErrHandling_ByStr_Get)"
	_fprivateErrHandling_ByStr_Set ""
	echo "${prevVal}" ; }
function _fprivateErrHandling_ByStr_Set_Fatal(){ :;
	##	Arguments: (None)
	##	Returns via echo: String of previous state.
	local prevVal="$(_fprivateErrHandling_ByStr_Get)"
	_fprivateErrHandling_ByStr_Set "eE"
	echo "${prevVal}" ; }


##----------------------------------------------------------------------------------------------------
function fUnitTests(){ :;

	local errByStr_Prev=""
	local errNum=0
	local tmpInt=0
	local tmpStr=""

	clear
	echo "----------------------------------------------------------------------------------------------------"

	## -----------------------
	fUnitTest_StartSection "fArray_IsSet_1ndex"
	local -a arrayWith7items; arrayWith7items=("item1" "item2 with spaces" "" "item4" 5 "6" "item7")
	#fAssert_AreEqual_EvalFirstArg "fArray_IsSet_1ndex myArray1 2" "item2 with spaces"
	fAssert_AreEqual_EvalFirstArg "fArray_IsSet_1ndex arrayWith7items 1" "true"
	fAssert_AreEqual_EvalFirstArg "fArray_IsSet_1ndex arrayWith7items 3" "true"
	fAssert_AreEqual_EvalFirstArg "fArray_IsSet_1ndex arrayWith7items 7" "true"
	fAssert_AreEqual_EvalFirstArg "fArray_IsSet_1ndex arrayWith7items 0" "false"
	fAssert_AreEqual_EvalFirstArg "fArray_IsSet_1ndex arrayWith7items 8" "false"
	local -a arrayWith0items
	fAssert_AreEqual_EvalFirstArg "fArray_IsSet_1ndex arrayWith0items 1" "false"
	fAssert_AreEqual_EvalFirstArg "fArray_IsSet_1ndex arrayWith0items 100" "false"


	## -----------------------
	fUnitTest_StartSection "fArray_IsSet_1ndex"
	fAssert_AreEqual_EvalFirstArg "fArray_GetItemBy_1ndex arrayWith7items 1" "item1"
	fAssert_AreEqual_EvalFirstArg "fArray_GetItemBy_1ndex arrayWith7items 2" "item2 with spaces"
	fAssert_AreEqual_EvalFirstArg "fArray_GetItemBy_1ndex arrayWith7items 3" ""
	fAssert_AreEqual_EvalFirstArg "fArray_GetItemBy_1ndex arrayWith7items 5" "5"
	fAssert_AreEqual_EvalFirstArg "fArray_GetItemBy_1ndex arrayWith7items 6" "6"
	fAssert_AreEqual_EvalFirstArg "fArray_GetItemBy_1ndex arrayWith7items 7" "item7"
	fAssert_AreEqual_EvalFirstArg "fArray_GetItemBy_1ndex arrayWith7items 0" ""
	fAssert_AreEqual_EvalFirstArg "fArray_GetItemBy_1ndex arrayWith7items 8" ""
	fAssert_AreEqual_EvalFirstArg "fArray_GetItemBy_1ndex arrayWith0items 1" ""


	## -----------------------
	fUnitTest_StartSection "fGetFile*_OfMe()"
	echo "fGetFileSpec_OfMe() ...: '$(fGetFileSpec_OfMe)'"
	echo "fGetFolder_OfMe() .....: '$(fGetFolder_OfMe)'"
	echo "fGetFileName_OfMe() ...: '$(fGetFileName_OfMe)'"


	## -----------------------
	fUnitTest_StartSection "fprivateGet*_OfFunctionHost()"
	echo "fprivateGetFileSpec_OfFunctionHost() ...: '$(fprivateGetFileSpec_OfFunctionHost)'"
	echo "fprivateGetFolder_OfFunctionHost() .....: '$(fprivateGetFolder_OfFunctionHost)'"
	echo "fprivateGetFileName_OfFunctionHost() ...: '$(fprivateGetFileName_OfFunctionHost)'"


	## -----------------------
	fUnitTest_StartSection "fPackString(), fUnpackString()"
	local vlsOriginalInput="Line1\nLine2. Tabstart\tTabend. Bang! \$Dollars. #hashtag. Percent%. Semicolon; Colon: Comma, @at *star dash- brackets[] parens() braces{}"
	vlsOriginalInput="$(echo -e "${vlsOriginalInput}")"
	local vlsPacked_Once_Quoted="$(fPackString "${vlsOriginalInput}")"
	local vlsPacked_Twice_Quoted="$(fPackString "${vlsPacked_Once_Quoted}")"
	local clsExpectedPacked_Quoted="⦃packedstring-begin⦄Line1⦃newline⦄Line2.⦃space⦄Tabstart⦃tab⦄Tabend.⦃space⦄Bang!⦃space⦄⦃dollar⦄Dollars.⦃space⦄#hashtag.⦃space⦄Percent⦃percent⦄.⦃space⦄Semicolon;⦃space⦄Colon:⦃space⦄Comma,⦃space⦄@at⦃space⦄*star⦃space⦄dash-⦃space⦄brackets[]⦃space⦄parens()⦃space⦄braces{}⦃packedstring-end⦄"
	local vlsPacked_Once_Unquoted="$(fPackString ${vlsOriginalInput})"
	local vlsPacked_Twice_Unquoted="$(fPackString ${vlsPacked_Once_Unquoted})"
	local clsExpectedPacked_Unquoted="⦃packedstring-begin⦄Line1⦃space⦄Line2.⦃space⦄Tabstart⦃space⦄Tabend.⦃space⦄Bang!⦃space⦄⦃dollar⦄Dollars.⦃space⦄#hashtag.⦃space⦄Percent⦃percent⦄.⦃space⦄Semicolon;⦃space⦄Colon:⦃space⦄Comma,⦃space⦄@at⦃space⦄*star⦃space⦄dash-⦃space⦄brackets[]⦃space⦄parens()⦃space⦄braces{}⦃packedstring-end⦄"
	local vlsThriceUnpacked_OncePacked_Quoted="$(fUnpackString "${vlsPacked_Once_Quoted}")"
		vlsThriceUnpacked_OncePacked_Quoted="$(fUnpackString "${vlsThriceUnpacked_OncePacked_Quoted}")"
		vlsThriceUnpacked_OncePacked_Quoted="$(fUnpackString "${vlsThriceUnpacked_OncePacked_Quoted}")"
	local vlsThriceUnpacked_OncePacked_Unquoted="$(fUnpackString "${vlsPacked_Once_Unquoted}")"
		vlsThriceUnpacked_OncePacked_Unquoted="$(fUnpackString "${vlsThriceUnpacked_OncePacked_Unquoted}")"
		vlsThriceUnpacked_OncePacked_Unquoted="$(fUnpackString "${vlsThriceUnpacked_OncePacked_Unquoted}")"
	local vlsThriceUnpacked_TwicePacked_Quoted="$(fUnpackString "${vlsPacked_Twice_Quoted}")"
		vlsThriceUnpacked_TwicePacked_Quoted="$(fUnpackString "${vlsThriceUnpacked_TwicePacked_Quoted}")"
		vlsThriceUnpacked_TwicePacked_Quoted="$(fUnpackString "${vlsThriceUnpacked_TwicePacked_Quoted}")"
	local vlsThriceUnpacked_TwicePacked_Unquoted="$(fUnpackString "${vlsPacked_Twice_Unquoted}")"
		vlsThriceUnpacked_TwicePacked_Unquoted="$(fUnpackString "${vlsThriceUnpacked_TwicePacked_Unquoted}")"
		vlsThriceUnpacked_TwicePacked_Unquoted="$(fUnpackString "${vlsThriceUnpacked_TwicePacked_Unquoted}")"
	#echo "clsExpectedPacked_Quoted .................: '${clsExpectedPacked_Quoted}'"; echo
	#echo "clsExpectedPacked_Unquoted ...............: '${clsExpectedPacked_Unquoted}'"; echo
	#echo "vlsPacked_Once_Quoted ....................: '${vlsPacked_Once_Quoted}'"; echo
	#echo "vlsPacked_Twice_Quoted ...................: '${vlsPacked_Twice_Quoted}'"; echo
	#echo "vlsPacked_Once_Unquoted ..................: '${vlsPacked_Once_Unquoted}'"; echo
	#echo "vlsPacked_Twice_Unquoted .................: '${vlsPacked_Twice_Unquoted}'"; echo
	#echo "vlsOriginalInput .........................: '${vlsOriginalInput}'"; echo
	#echo "vlsThriceUnpacked_OncePacked_Quoted ......: '${vlsThriceUnpacked_OncePacked_Quoted}'"; echo
	#echo "vlsThriceUnpacked_TwicePacked_Quoted .....: '${vlsThriceUnpacked_TwicePacked_Quoted}'"; echo
	#echo "vlsThriceUnpacked_OncePacked_Unquoted ....: '${vlsThriceUnpacked_OncePacked_Unquoted}'"; echo
	#echo "vlsThriceUnpacked_TwicePacked_Unquoted ...: '${vlsThriceUnpacked_TwicePacked_Unquoted}'"; echo
	fAssert_AreEqual "${vlsPacked_Once_Quoted}"                  "${vlsPacked_Twice_Quoted}"                  "Quoted,   [packed once] = [packed twice]"
	fAssert_AreEqual "${vlsPacked_Once_Unquoted}"                "${vlsPacked_Twice_Unquoted}"                "Unquoted, [packed once] = [packed twice]"
	fAssert_AreEqual "${vlsOriginalInput}"                       "${vlsThriceUnpacked_OncePacked_Quoted}"     "[Original input] = [quoted, once packed,  thrice-unpacked]"
	fAssert_AreEqual "${vlsOriginalInput}"                       "${vlsThriceUnpacked_TwicePacked_Quoted}"    "[Original input] = [quoted, twice packed, thrice-unpacked]"
	fAssert_AreEqual "${vlsThriceUnpacked_OncePacked_Unquoted}"  "${vlsThriceUnpacked_TwicePacked_Unquoted}"  "Unquoted, [once packed, thrice unpacked] = [twice packed, thrice unpacked]"


	## -----------------------
	fUnitTest_StartSection "fPackArgs(), fUnpackArgs(), fIsString_PackedArgs(), fPackedArgs_GetCount(), fUnpackArg_Number()"
	local vlsPackedArgs="$(fPackArgs "" arg1 0 "" "" "1" "arg6" "" "" "" "")"
	local vlsPackedArgs="$(fPackArgs "${vlsPackedArgs}")"
	local clsExpectedPackedArgs="⦃packedargs-begin⦄⦃packedstring-begin⦄⦃empty⦄⦃packedstring-end⦄_⦃packedstring-begin⦄arg1⦃packedstring-end⦄_⦃packedstring-begin⦄0⦃packedstring-end⦄_⦃packedstring-begin⦄⦃empty⦄⦃packedstring-end⦄_⦃packedstring-begin⦄⦃empty⦄⦃packedstring-end⦄_⦃packedstring-begin⦄1⦃packedstring-end⦄_⦃packedstring-begin⦄arg6⦃packedstring-end⦄⦃packedargs-end⦄"
	local vlsUnPackedArgs="$(fUnpackArgs "${vlsPackedArgs}")"
	local vlsUnPackedArgs="$(fUnpackArgs "${vlsUnPackedArgs}")"
	local vlsUnPackedArgs="$(fUnpackArgs "${vlsUnPackedArgs}")"
	local clsExpectedUnpackedOutput="'' 'arg1' '0' '' '' '1' 'arg6'"
	#echo "vlsPackedArgs ....................: '${vlsPackedArgs}'"; echo
	#echo "clsExpectedPackedArgs ............: '${clsExpectedPackedArgs}'"; echo
	#echo "vlsUnPackedArgs ..................: '${vlsUnPackedArgs}'"; echo
	#echo "clsExpectedUnpackedOutput ........: '${clsExpectedUnpackedOutput}'"; echo
	#echo "clsExpectedUnpackedOutput (raw) ..: $(echo $clsExpectedUnpackedOutput)"; echo
	fAssert_AreEqual "${vlsPackedArgs}"                                     "${clsExpectedPackedArgs}"        "Packed args:   actual = expected"
	fAssert_AreEqual "${vlsUnPackedArgs}"                                   "${clsExpectedUnpackedOutput}"    "Unpacked args: actual = expected"
	fAssert_AreEqual "$(fIsString_PackedArgs "${vlsPackedArgs}")"           "true"                            "fIsString_PackedArgs([packed args])"
	fAssert_AreEqual "$(fIsString_PackedArgs "String that isn't packed")"   "false"                           "fIsString_PackedArgs([not packed])"
	fAssert_AreEqual "$(fPackedArgs_GetCount "${vlsPackedArgs}")"           "7"                               "fPackedArgs_GetCount()"
	fAssert_AreEqual "$(fPackedArgs_GetCount)"                              "0"                               "fPackedArgs_GetCount()"
	fAssert_AreEqual "$(fPackedArgs_GetCount "")"                           "0"                               "fPackedArgs_GetCount()"
	fAssert_AreEqual "$(fPackedArgs_GetCount "2")"                          "0"                               "fPackedArgs_GetCount()"


	## -----------------------
	fUnitTest_StartSection "fIsString_PackedArgs(), fPackedArgs_GetCount(), fUnpackArg_Number()"
	local vlsPackedArgs_Test1="$(fPackArgs )"
	local vlsPackedArgs_Test2="$(fPackArgs arg1 "" 3 "arg4")"
	local vlsPackedArgs_Test3="$(fPackArgs 42)"
	#echo "fPackedArgs_GetCount(vlsPackedArgs_Test1) ..........: '$(fPackedArgs_GetCount        "${vlsPackedArgs_Test1}")'     (should be '0')"
	#echo "fPackedArgs_GetCount(vlsPackedArgs_Test2) ..........: '$(fPackedArgs_GetCount        "${vlsPackedArgs_Test2}")'     (should be '4')"
	#echo "fPackedArgs_GetCount(vlsPackedArgs_Test3) ..........: '$(fPackedArgs_GetCount        "${vlsPackedArgs_Test3}")'     (should be '1')"
	#echo "fUnpackArg_Number(vlsPackedArgs_Test2 1)... '$(fUnpackArg_Number "${vlsPackedArgs_Test2}" 1)'  (should be 'arg1')"
	#echo "fUnpackArg_Number(vlsPackedArgs_Test2 2)... '$(fUnpackArg_Number "${vlsPackedArgs_Test2}" 2)'      (should be '')"
	#echo "fUnpackArg_Number(vlsPackedArgs_Test2 3)... '$(fUnpackArg_Number "${vlsPackedArgs_Test2}" 3)'     (should be '3')"
	#echo "fUnpackArg_Number(vlsPackedArgs_Test2 4)... '$(fUnpackArg_Number "${vlsPackedArgs_Test2}" 4)'  (should be 'arg4')"
	fAssert_AreEqual "$(fIsString_PackedArgs        "${vlsPackedArgs_Test1}")"    "true"  "fIsString_PackedArgs(vlsPackedArgs_Test1) = true"
	fAssert_AreEqual "$(fPackedArgs_GetCount        "${vlsPackedArgs_Test1}")"    "0"     "fPackedArgs_GetCount(vlsPackedArgs_Test1) = 0"
	fAssert_AreEqual "$(fPackedArgs_GetCount        "${vlsPackedArgs_Test2}")"    "4"     "fPackedArgs_GetCount(vlsPackedArgs_Test2) = 4"
	fAssert_AreEqual "$(fPackedArgs_GetCount        "${vlsPackedArgs_Test3}")"    "1"     "fPackedArgs_GetCount(vlsPackedArgs_Test3) = 1"
	fAssert_AreEqual "$(fUnpackArg_Number "${vlsPackedArgs_Test2}" 1)"  "arg1"  "fUnpackArg_Number(vlsPackedArgs_Test2, 1) = 'arg1'"
	fAssert_AreEqual "$(fUnpackArg_Number "${vlsPackedArgs_Test2}" 2)"  ""      "fUnpackArg_Number(vlsPackedArgs_Test2, 2) = ''"
	fAssert_AreEqual "$(fUnpackArg_Number "${vlsPackedArgs_Test2}" 3)"  "3"     "fUnpackArg_Number(vlsPackedArgs_Test2, 3) = '3'"
	fAssert_AreEqual "$(fUnpackArg_Number "${vlsPackedArgs_Test2}" 4)"  "arg4"  "fUnpackArg_Number(vlsPackedArgs_Test2, 3) = 'arg4'"


	## -----------------------
	fUnitTest_StartSection "fStr_GetRegexMatchOnly_EchoReturn"
	fAssert_AreEqual_EvalFirstArg "fStr_GetRegexMatchOnly_EchoReturn \"My dog has 37 FLEAS!\"     \"^.*[0-9]{1,4} fleas.*\$\"        "  "My dog has 37 FLEAS!"
	fAssert_AreEqual_EvalFirstArg "fStr_GetRegexMatchOnly_EchoReturn \"My dog has 37 FLEAS!\"     \"[0-9]{1,4} fleas\"               "  "37 FLEAS"
	fAssert_AreEqual_EvalFirstArg "fStr_GetRegexMatchOnly_EchoReturn \"SSN: 123-45-6789\"         \"[0-9]{3}-[0-9]{2}-[0-9]{4}\"     "  "123-45-6789"
	fAssert_AreEqual_EvalFirstArg "fStr_GetRegexMatchOnly_EchoReturn \"SSN: 123-45-6789\"         \"^[0-9]{3}-[0-9]{2}-[0-9]{4}\$\"  "  ""
	fAssert_AreEqual_EvalFirstArg "fStr_GetRegexMatchOnly_EchoReturn \"SSN: 123-45-Yahoo-6789\"   \"[0-9]{3}-[0-9]{2}-[0-9]{4}\"     "  ""


	## -----------------------
	fUnitTest_StartSection "fStrAppend"
	local test_fStrAppend=""
	fStrAppend test_fStrAppend "Adam"   ", "        ; fAssert_AreEqual "${test_fStrAppend}"  "Adam"
	fStrAppend test_fStrAppend "Bob"    ", "        ; fAssert_AreEqual "${test_fStrAppend}"  "Adam, Bob"
	fStrAppend test_fStrAppend ""       ", "        ; fAssert_AreEqual "${test_fStrAppend}"  "Adam, Bob, "
	fStrAppend test_fStrAppend "Cole"   ", "        ; fAssert_AreEqual "${test_fStrAppend}"  "Adam, Bob, , Cole"
	fStrAppend test_fStrAppend ""       ", " false  ; fAssert_AreEqual "${test_fStrAppend}"  "Adam, Bob, , Cole"


	## -----------------------
	fUnitTest_StartSection "fStrAppend2"
	local test_fStrAppend2=""
	fAssert_AreEqual_EvalFirstArg "fStrAppend2 test_fStrAppend2  \", \"  \"\"       true   true;  echo \"\${test_fStrAppend2}\"   "   ", "
	test_fStrAppend2=""
	fAssert_AreEqual_EvalFirstArg "fStrAppend2 test_fStrAppend2  \", \"  \"\"       false  false; echo \"\${test_fStrAppend2}\"   "   ""
	test_fStrAppend2=""
	fAssert_AreEqual_EvalFirstArg "fStrAppend2 test_fStrAppend2  \", \"  \"Bob\"    true   false; echo \"\${test_fStrAppend2}\"   "   ", Bob"
	test_fStrAppend2="Bob"
	#fStrAppend2 test_fStrAppend2  ", "  ""  false  true; fEcho_VariableAndValue test_fStrAppend2; exit
	fAssert_AreEqual_EvalFirstArg "fStrAppend2 test_fStrAppend2  \", \"  \"\"       false  true;  echo \"\${test_fStrAppend2}\"   "   "Bob, "
	test_fStrAppend2=""
	fAssert_AreEqual_EvalFirstArg "fStrAppend2 test_fStrAppend2  \", \"  \"Bob\"    true   false; echo \"\${test_fStrAppend2}\"   "   ", Bob"
	test_fStrAppend2="Adam"
	fAssert_AreEqual_EvalFirstArg "fStrAppend2 test_fStrAppend2  \"\"    \"Bob\"                ; echo \"\${test_fStrAppend2}\"   "   "AdamBob"
	test_fStrAppend2=""
	fStrAppend2 test_fStrAppend2  ", "  "Alpha"    ; fAssert_AreEqual "${test_fStrAppend2}"  "Alpha"
	fStrAppend2 test_fStrAppend2  ", "  "Bravo"    ; fAssert_AreEqual "${test_fStrAppend2}"  "Alpha, Bravo"
	fStrAppend2 test_fStrAppend2  ", "  "Charley"  ; fAssert_AreEqual "${test_fStrAppend2}"  "Alpha, Bravo, Charley"


	## -----------------------
	fUnitTest_StartSection "fMakeSymlink()"

	## Initialize variables defining actual filesystem test objects to create
	fUnitTest_StartSection "fMakeSymlink(): Init"
	local -r ut_msTempDir="$(mktemp -d)"
	local -r ut_msExistingSource_File="${ut_msTempDir}/real_file"
	local -r ut_msExistingSource_Folder="${ut_msTempDir}/real_folder"
	local -r ut_msNonExistSource_File="${ut_msTempDir}/real_non-existent_file"
	local -r ut_msNonExistSource_Folder="${ut_msTempDir}/real_non-existent_folder"
	local -r ut_msGoodLink_ToFile="${ut_msTempDir}/symlink_good_file"
	local -r ut_msGoodLink_ToFolder="${ut_msTempDir}/symlink_good_folder"
	local -r ut_msBrokenLink_ToFile="${ut_msTempDir}/symlink_broken_file"
	local -r ut_msBrokenLink_ToFolder="${ut_msTempDir}/symlink_broken_folder"
	local -r ut_msLinkActuallyA_File="${ut_msTempDir}/real_file_symlink-attempt"
	local -r ut_msLinkActuallyA_Folder="${ut_msTempDir}/real_folder_symlink-attempt"
	local -r lsCommand_Pre="(ls -lA --color=always --group-directories-first --human-readable --indicator-style=slash --time-style=+\"%Y-%m-%d %H:%M:%S\""
	local -r lsCommand_Post="2> /dev/null || true) | grep -vi 'total' || true"

	### Meta-unit-test
	#fEcho_VariableAndValue ut_msTempDir
	#fEcho_VariableAndValue ut_msExistingSource_File
	#fEcho_VariableAndValue ut_msExistingSource_Folder
	#fEcho_VariableAndValue ut_msNonExistSource_File
	#fEcho_VariableAndValue ut_msNonExistSource_Folder
	#fEcho_VariableAndValue ut_msGoodLink_ToFile
	#fEcho_VariableAndValue ut_msGoodLink_ToFolder
	#fEcho_VariableAndValue ut_msBrokenLink_ToFile
	#fEcho_VariableAndValue ut_msBrokenLink_ToFolder

	## Create the test objects
	fUnitTest_StartSection "fMakeSymlink(): Creating test objects ..."
	cd "${ut_msTempDir}"
	echo "Dummy test text" >                       "${ut_msExistingSource_File}"
	mkdir -p                                       "${ut_msExistingSource_Folder}"
	echo "Dummy test text" >                       "${ut_msNonExistSource_File}"
		ln -s "${ut_msNonExistSource_File}"        "${ut_msBrokenLink_ToFile}"
		rm                                         "${ut_msNonExistSource_File}"
	mkdir -p                                       "${ut_msNonExistSource_Folder}"
		ln -s "${ut_msNonExistSource_Folder}"      "${ut_msBrokenLink_ToFolder}"
		rm -rf                                     "${ut_msNonExistSource_Folder}"
	fUnitTest_StartSection "fMakeSymlink(): Testing creation of new symlinks to good objects ..."
		## Test: Create new file symlink that don't already exist
			fMakeSymlink "${ut_msExistingSource_File}"   "${ut_msGoodLink_ToFile}"
			if [ -e "${ut_msGoodLink_ToFile}" ] && [ -h "${ut_msGoodLink_ToFile}" ]; then
				fAssertResult_Msg_Passed "Exists and is a good link: '${ut_msGoodLink_ToFile}'."
			else
				fAssertResult_Msg_Failed "Doesn't exist or isn't a good link: '${ut_msGoodLink_ToFile}'."
			fi

		## Test: Create new folder symlink that don't already exist
			fMakeSymlink "${ut_msExistingSource_Folder}" "${ut_msGoodLink_ToFolder}"
			if [ -e "${ut_msGoodLink_ToFolder}" ] && [ -h "${ut_msGoodLink_ToFolder}" ]; then
				fAssertResult_Msg_Passed "Exists and is a good link: '${ut_msGoodLink_ToFolder}'."
			else
				fAssertResult_Msg_Failed "Doesn't exist or isn't a good link: '${ut_msGoodLink_ToFolder}'."
			fi
		eval "${lsCommand_Pre} \"${ut_msTempDir}\" ${lsCommand_Post}"
	fUnitTest_StartSection "fMakeSymlink(): Testing RE-creation of existing symlinks to good objects ..."
		## Test: RE-create an existing and good file symlink, to a valid file.
			fMakeSymlink "${ut_msExistingSource_File}"   "${ut_msGoodLink_ToFile}"
			if [ -e "${ut_msGoodLink_ToFile}" ] && [ -h "${ut_msGoodLink_ToFile}" ]; then
				fAssertResult_Msg_Passed "Exists and is a good link: '${ut_msGoodLink_ToFile}'."
			else
				fAssertResult_Msg_Failed "Doesn't exist or isn't a good link: '${ut_msGoodLink_ToFile}'."
			fi
		## Test: RE-create an existing and good folder symlink, to a valid folder.
			fMakeSymlink "${ut_msExistingSource_Folder}" "${ut_msGoodLink_ToFolder}"
			if [ -e "${ut_msGoodLink_ToFolder}" ] && [ -h "${ut_msGoodLink_ToFolder}" ]; then
				fAssertResult_Msg_Passed "Exists and is a good link: '${ut_msGoodLink_ToFolder}'."
			else
				fAssertResult_Msg_Failed "Doesn't exist or isn't a good link: '${ut_msGoodLink_ToFolder}'."
			fi
		eval "${lsCommand_Pre} \"${ut_msTempDir}\" ${lsCommand_Post}"
	fUnitTest_StartSection "fMakeSymlink(): Testing overwriting of existing bad symlinks, with new refs to good objects ..."
		## Test: RE-create an existing BAD file symlink, to a valid file.
			fMakeSymlink "${ut_msExistingSource_File}"   "${ut_msBrokenLink_ToFile}"
			if [ -e "${ut_msBrokenLink_ToFile}" ] && [ -h "${ut_msBrokenLink_ToFile}" ]; then
				fAssertResult_Msg_Passed "Exists and is a good link: '${ut_msBrokenLink_ToFile}'."
			else
				fAssertResult_Msg_Failed "Doesn't exist or isn't a good link: '${ut_msBrokenLink_ToFile}'."
			fi
		## Test: RE-create an existing BAD folder symlink, to a valid folder.
			fMakeSymlink "${ut_msExistingSource_Folder}" "${ut_msBrokenLink_ToFolder}"
			if [ -e "${ut_msBrokenLink_ToFolder}" ] && [ -h "${ut_msBrokenLink_ToFolder}" ]; then
				fAssertResult_Msg_Passed "Exists and is a good link: '${ut_msBrokenLink_ToFolder}'."
			else
				fAssertResult_Msg_Failed "Doesn't exist or isn't a good link: '${ut_msBrokenLink_ToFolder}'."
			fi
		eval "${lsCommand_Pre} \"${ut_msTempDir}\" ${lsCommand_Post}"
	fUnitTest_StartSection "fMakeSymlink(): Resetting test FS objects ..."
		if [ -h "${ut_msBrokenLink_ToFile}"   ]; then rm "${ut_msBrokenLink_ToFile}"  ; fi
		if [ -h "${ut_msBrokenLink_ToFolder}" ]; then rm "${ut_msBrokenLink_ToFolder}"; fi
		if [ -h "${ut_msGoodLink_ToFile}"   ]; then rm "${ut_msGoodLink_ToFile}"  ; fi
		if [ -h "${ut_msGoodLink_ToFolder}" ]; then rm "${ut_msGoodLink_ToFolder}"; fi
		echo "Dummy test text" > "${ut_msLinkActuallyA_File}"
		mkdir -p                 "${ut_msLinkActuallyA_Folder}"
#	fUnitTest_StartSection "fMakeSymlink(): Failure modes: Try to create symlinks to existing objects, OVER existing real objects ..."
#		## Try to create a symlink to a good file, over an existing file with same name as desired symlink (should FAIL)
#			errNum=0; set +eE
#				(fMakeSymlink "${ut_msExistingSource_File}" "${ut_msLinkActuallyA_File}" &> /dev/null)
#			errNum=$?; true; set -eE
#			if [ -f "${ut_msLinkActuallyA_File}" ] && [ ! -h "${ut_msLinkActuallyA_File}" ]; then
#				fAssertResult_Msg_Passed "Correctly didn't overwrite good file with symlink: '${ut_msLinkActuallyA_File}'."
#			else
#				fAssertResult_Msg_Failed "BAD: Overwrite real file '${ut_msLinkActuallyA_File}' with a symlink, an attempt which should have failed."
#			fi
#			if [ $errNum -ne 0 ]; then
#				fAssertResult_Msg_Passed "fMakeSymlink() correctly returned an error code."
#			else
#				fAssertResult_Msg_Failed "BAD: fMakeSymlink() did not trigger an error."
#			fi
#		## Try to create a symlink to a good folder, over an existing folder with same name as desired symlink (should FAIL)
#			errNum=0; set +eE
#				(fMakeSymlink "${ut_msExistingSource_File}" "${ut_msLinkActuallyA_File}" &> /dev/null)
#			errNum=$?; true; set -eE
#			if [ -d "${ut_msLinkActuallyA_Folder}" ] && [ ! -h "${ut_msLinkActuallyA_Folder}" ]; then
#				fAssertResult_Msg_Passed "Correctly didn't overwrite good folder with symlink: '${ut_msLinkActuallyA_Folder}'."
#			else
#				fAssertResult_Msg_Failed "BAD: Overwrite real folder '${ut_msLinkActuallyA_Folder}' with a symlink, an attempt which should have failed."
#			fi
#			if [ $errNum -ne 0 ]; then
#				fAssertResult_Msg_Passed "fMakeSymlink() correctly returned an error code."
#			else
#				fAssertResult_Msg_Failed "BAD: fMakeSymlink() did not trigger an error."
#			fi
	fUnitTest_StartSection "fMakeSymlink(): Cleaning up ..."
		if [ -d "${ut_msTempDir}" ]; then rm -rf "${ut_msTempDir}"; fi


	fUnitTest_StartSection "fInit_Integer()"
	tmpInt=         ; fInit_Integer tmpInt 10       ; fAssert_AreEqual "${tmpInt}"  "10"  "tmpInt='${tmpInt}'"
	tmpInt=""       ; fInit_Integer tmpInt  1       ; fAssert_AreEqual "${tmpInt}"   "1"  "tmpInt='${tmpInt}'"
	tmpInt="Phil"   ; fInit_Integer tmpInt          ; fAssert_AreEqual "${tmpInt}"   "0"  "tmpInt='${tmpInt}'"
	tmpInt=-1       ; fInit_Integer tmpInt  0  0    ; fAssert_AreEqual "${tmpInt}"   "0"  "tmpInt='${tmpInt}'"
	tmpInt=20       ; fInit_Integer tmpInt  0  0 10 ; fAssert_AreEqual "${tmpInt}"  "10"  "tmpInt='${tmpInt}'"
	tmpInt=50       ; fInit_Integer tmpInt "" 60 70 ; fAssert_AreEqual "${tmpInt}"  "60"  "tmpInt='${tmpInt}'"


	fUnitTest_StartSection "fIsProcessRunning()"
	fAssert_AreEqual_EvalFirstArg "fIsProcessRunning  \"xfce4-panel\"      "  "true"
	fAssert_AreEqual_EvalFirstArg "fIsProcessRunning  \"xfce4\"            "  "true"
	fAssert_AreEqual_EvalFirstArg "fIsProcessRunning  \"nemo\"             "  "true"
	fAssert_AreEqual_EvalFirstArg "fIsProcessRunning  \"qoiuyqerlkjhas\"   "  "false"
	fAssert_AreEqual_EvalFirstArg "fIsProcessRunning  \"xfe\"              "  "false"


	#fUnitTest_StartSection "fWaitForProcessToEnd(), fIsProcessRunning(), fCloseKillProcess()"
	fEcho "Executing: fRunForked \"xfe\""
	fRunForked "xfe"
	fEcho "Executing: fWaitForProcessToEnd \"xfe\" 2 6"
	fWaitForProcessToEnd "xfe" 2 6
	fAssert_AreEqual_EvalFirstArg "fIsProcessRunning  \"xfe\"              "  "true"
	fEcho "Executing: fCloseKillProcess \"xfe\ 4"  ## Wait 4 seconds then try to force-close."
	fCloseKillProcess "xfe" 4
	fAssert_AreEqual_EvalFirstArg "fIsProcessRunning  \"xfe\"              "  "false"
	

	fEcho_ResetBlankCounter
}


#########################################################################################
## Initial settings and execution control
#########################################################################################

## Note: Including function should invoke this script:
# set -e  ## Halt on error.
# set -E  ## Sourced scripts honor error handling.
# fMustBeInPath "0_library_v2"
# source 0_library_v2  ## Script execution resumes here

## Validate (a partial list)
fMustBeInPath "basename"
fMustBeInPath "dirname"
fMustBeInPath "realpath"

### Make sure this is running sourced from another script
#if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then :;
#	echo "Error: '$(basename ${0})' cannot be run directly, and can't be invoked without the 'source' prefix."
#	exit 1
#fi

## Define error trapping
fDefineTrap_Error_Fatal
trap 'fprivate_Trap_Exit' INT TERM EXIT
#declare vmsErrHandlingStr="$(fErrHandling_Get)"

## Constants (don't use -r due to potential reentrancy)
declare cmsDoubleQuote_Open="“"; declare cmsDoubleQuote_Close="”"; declare cmsSingleQuote_Open="‘"; declare cmsSingleQuote_Close="’"; declare cmsApostrophe="${cmsSingleQuote_Close}"
declare vmsMe_Pathspec="${0}" ##........................... Full filespec of parent script
declare vmsMe_Name="$(basename "${vmsMe_Pathspec}")" ##.... Name of parent script
declare vmsLib_Name="0_library_v2"
declare vmsLib_Pathspec="$(which "${vmsLib_Name}")"
declare vmsLog_Folder="${HOME}/var/log/${vmsMe_Name}"  ##... Legacy

## Variables
declare vmbWasShown_DescriptionAndCopyright="false"
if [ -z "${vmbInSudoSection}" ]; then declare vmbInSudoSection=""; fi
if [ -z "${vmbInAsUserSection}" ]; then declare vmbInAsUserSection=""; fi


## Legacy


## Initialize log file variables (but don't actually create it yet - that's up to consumer of template)
declare vmsSerial=""
declare vmsLog_Filespec=""
fVariableCannotBeEmpty vmsLog_Folder

## Run unit tests if calling function says so
if [ "${doUnitTests,,}" == "true" ]; then
	fUnitTests
	if [ -n "$(type fUnitTests_Local 2> /dev/null || true)" ]; then fUnitTests_Local; fi
	exit
fi

## Arg-related globals
declare vmsFirstArg="$1"
declare vmbNoArgsPassed="false"
declare vmbShowHelp="false"
declare vmbRunUnitTests="false"
case "${@,,}" in
	*"-h"|*"-help"*|"/h"|*"/help"*|*"/?"*|*"-?"*) vmbShowHelp="true";      ;;
	*"-unittest"*|"/unittest"*)                   vmbRunUnitTests="true";  ;;
	"")                                           vmbNoArgsPassed="true";  ;;
esac

## Check what to do here
if [ "${vmbShowHelp}" == "true" ]; then
	fprivate_GenericWrapper_ShowSyntaxAndQuit
elif [ "${vmbRunUnitTests}" == "true" ]; then
	fUnitTests
else
	case "${vmsFirstArg,,}" in

		"reentrant_do_function")

			#######################################################################
			## Reentry point after invoking as Sudo or forked
			#######################################################################

			## Second argument should be the function name.
			## Args three on should be arguments

			fEcho_IfDebug "Reentrant subroutine section"
			vmbInSudoSection="true"
			vmsFunction="$2"
			if [ -z "${vmsFunction}" ]; then :;
				fThrowError "Script reentered with ${cmsDoubleQuote_Open}reentrant_do_function${cmsDoubleQuote_Close} argument, but no function was specified."
			else :;

				###############################################################
				## Specific entry point
				###############################################################
				${vmsFunction} "$(fPackArgs "${@:3}")" ${@:3}  ## Edit ID: 41be5316-0c17-439b-bf03-fae72e4cdf38

			fi

		;;
		*)

			#######################################################################
			## Main non-sudo entry point
			#######################################################################

			if [ "${vmbLessVerbose}" != "true" ]; then fPrintLineTerminalWidth; fi
			fEcho_IfDebug "Main entry point"

			if [ -z "${cmwNumberOfRequiredArgs}" ]; then :;
				fThrowError "The variable ${cmsDoubleQuote_Open}cmwNumberOfRequiredArgs${cmsDoubleQuote_Close} is required but not declared."
			else :;
				if [ $# -lt $cmwNumberOfRequiredArgs ]; then :;
					fprivate_GenericWrapper_ShowSyntaxAndQuit
				else :;

					#Copyright and description
					if [ "${cmbAlwaysShowDescriptionAndCopyright}" == "true" ] && [ "${vmbLessVerbose}" != "true" ]; then :;
						fprivate_GenericWrapper_ShowDescriptionAndCopyright
					fi

					###############################################################
					## Specific entry point
					###############################################################
					fMain "$(fPackArgs "$@")" $@  ## Edit ID: 41be5316-0c17-439b-bf03-fae72e4cdf38

				fi
			fi
		;;
	esac

fi
