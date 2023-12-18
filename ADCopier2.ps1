<#
.SYNOPSIS
## This is version 1.8 with logging

.DESCRIPTION
..Reference table:  
### PART 1: Load modules needed  
________________________________
### PART 2: Define functions
________________________________
### PART 3: Ask for data to be worked on.
________________________________
### PART 4: Check input for validity and assign variables
________________________________
### PART 5: Move computer to a new AD location
________________________________
### PART 6: Copy Groups from old computer to new computer
________________________________
### PART 7: Copy description from old computer to new computer (OR write new desc.)
________________________________
.PARAMETER Name
No parameters in this version
.EXAMPLE
TBD
.NOTES
$newComputerObjectWithDescription  is re-declared after moving
#>

### PART 1: Load modules needed  ###

Import-Module ActiveDirectory

#________________________________

### PART 2: Define functions ###

# Initialize Logging Functionality
function Start-Logging {
    param (
        [string]$oldHostname,
        [string]$newHostname
    )

    $logFileName = "$((Get-Date).ToString('yyyy-MM-dd_HH-mm-ss'))_$oldHostname-$newHostname.log"
    $global:logFilePath = Join-Path (Get-Location) $logFileName
    Add-Content -Path $global:logFilePath -Value "Logging started. Log file: $global:logFilePath"
}

function Add-ToLogMessage {
    param (
        [string]$message,
        [string]$type = "INFO"
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "$timestamp [$type] $message"
    Add-Content -Path $global:logFilePath -Value $logEntry
}

function Add-ToErrorAndExit {
    param (
        [string]$message,
        [int]$exitCode
    )

    Add-ToLogMessage -message $message -type "ERROR"
    Write-Host $message -ForegroundColor Red
    exit $exitCode
}

# This function asks for data to be worked on. Checks input for validity.
function Confirm-DataComputerNameIsValidAndExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($name.Length -eq 0) {
        Add-ToLogMessage -message "Error: No input provided (Both PC names needed)" -type "ERROR"
        exit 10
    }

    # Define the regular expression pattern for a valid computer object name
    $pattern = "^[a-zA-Z0-9._-]+$"

    # Check if the name matches the regular expression pattern
    $result = [System.Text.RegularExpressions.Regex]::Match($name, $pattern)

    # Check if the name is a valid computer object name
    if ($result.Success) {
        try {
            # Search for a computer object with the specified name
            $computer = Get-ADComputer -Filter { Name -eq $name } -ErrorAction Stop
            # Check if a matching computer object was found
            if ($computer) {
                $returnValue = $true
                Add-ToLogMessage -message "The name $name is a valid computer object name and a computer object with the specified name exists." -type "INFO"
            } else {
                $returnValue = $false
                Add-ToLogMessage -message "The name $name is a valid computer object name, but a computer object with the specified name does not exist." -type "WARN"
            }
        } catch {
            Add-ToErrorAndExit -message "Error occurred while searching for the computer object: $_" -exitCode 11
        }
    } else {
        Add-ToLogMessage -message "The name $name is not a valid computer object name." -type "WARN"
        $returnValue = $false
    }
    return $returnValue
}

#________________________________

### PART 3: Ask for data to be worked on.
# Script execution Start
# Ask the user to enter the old and new computer hostnames, do basic check
$oldHostname = Read-Host "Enter the old hostname" 
$newHostname = Read-Host "Enter the new hostname"

# Initialize Logging
Start-Logging -oldHostname $oldHostname -newHostname $newHostname

#________________________________

### PART 4: Check input for validity and assign variables

# Check every hostname for validity
Add-ToLogMessage -message "Checking your entry for validity; name of the old computer: $oldHostname" -type "INFO"
$resultOldComputerCheck = Confirm-DataComputerNameIsValidAndExists -Name $oldHostname
Add-ToLogMessage -message "Checking your entry for validity; name of the New computer: $newHostname" -type "INFO"
$resultNewComputerCheck = Confirm-DataComputerNameIsValidAndExists -Name $newHostname

# Make decision to either continue script or stop execution based on validity check.
if ($resultNewComputerCheck -and $resultOldComputerCheck) {
    Add-ToLogMessage -message "Both old and new computer names are valid. Proceeding with the script." -type "INFO"
} else {
    Add-ToErrorAndExit -message "Invalid computer names. Exiting script." -exitCode 12
}

#### At this points we have valid computer names, so we need to perform checks and proceed with the script
# (Continue the script with the remaining parts, ensuring that all actions are logged using Add-ToLogMessage and errors using Add-ToErrorAndExit)

# (Implement the rest of the script with logging as done in the earlier parts)

#________________________________
Add-ToLogMessage -message "Script execution completed successfully." -type "INFO"
Write-Host "You had reached the end of script!" -ForegroundColor DarkGreen
