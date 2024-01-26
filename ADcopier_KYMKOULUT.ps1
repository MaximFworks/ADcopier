#! powershell.exe
############################################################
############################################################
<#
.SYNOPSIS
## This is version 2 for KYMKOULUT domain

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
### PART 1: Load modules needed and add some settings ###

Import-Module ActiveDirectory
Write-Host "This is verision 2 for KYMKOULUT"

#________________________________

### PART 2: Define functions ###

# This function asks for data to be worked on. Checks input for validity.
function Confirm-DataComputerNameIsValidAndExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    if ($name.Length -eq 0) {
        Write-Host "Error: No input provided (Both PC names needed)"
        exit 10
    }
# Define the regular expression pattern for a valid computer object name
$pattern = "^[a-zA-Z0-9._-]+$"

# Check if the name matches the regular expression pattern
$result = [System.Text.RegularExpressions.Regex]::Match($name, $pattern)

# Check if the name is a valid computer object name
if ($result.Success) {
    # Search for a computer object with the specified name
    #-Filter is one of parameters, that allow using variables of script scope inside script block.
    $computer = Get-ADComputer -Filter { Name -eq $name } -ErrorAction Stop

    # Check if a matching computer object was found
    if ($computer) {
        $returnValue = $true
        Write-Host "The name $name is a valid computer object name and a computer object with the specified name exists." -ForegroundColor Green
    } else {
        $returnValue = $false
        Write-Host "The name $name is a valid computer object name, but a computer object with the specified name does not exist." -ForegroundColor Red        
    }
} else {
    Write-Host "The name is not a valid computer object name."
    $returnValue = $false    
}
return $returnValue
} # endofofunction

#________________________________


### PART 3: Ask for data to be worked on.
# Script execution Start
# Ask the user to enter the old and new computer hostnames, do basic check
# Both used in every part from now, because this string is easilly accesible form Write-Host
function Get-ValidatedHostname {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$DefaultValue
    )

    do {
        # Check if DefaultValue is not null or whitespace
        $useDefaultValue = -not [string]::IsNullOrWhiteSpace($DefaultValue)

        # Adjust the prompt based on whether a valid default value is available
        if ($useDefaultValue) {
            $inputPrompt = "$Prompt (or leave empty to use '$DefaultValue'): "
        } else {
            $inputPrompt = "$Prompt`: "
        }

        $inputValue = Read-Host $inputPrompt

        # If input is empty and default value is valid, use the default value
        if ([string]::IsNullOrWhiteSpace($inputValue) -and $useDefaultValue) {
            return $DefaultValue
        }

        # Check for non-empty input and validate hostname format
        if (-not [string]::IsNullOrWhiteSpace($inputValue) -and $inputValue -match "^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$") {
            return $inputValue
        } else {
            Write-Host "Invalid hostname. Please enter a valid hostname." -ForegroundColor Red
        }
    } while ($true)
}

# Script execution
# Ensure $oldHostname and $newHostname are initialized as empty strings if not already set
if ($null -eq $oldHostname) { $oldHostname = '' }
if ($null -eq $newHostname) { $newHostname = '' }

$oldHostname = Get-ValidatedHostname -Prompt "Enter the old hostname" -DefaultValue $oldHostname
$newHostname = Get-ValidatedHostname -Prompt "Enter the new hostname" -DefaultValue $newHostname




#________________________________


### PART 4: Check input for validity and assign variables

# Check every hostname for validity
Write-Host "Checking your entry for validity; name of the old computer:" 
$resultOldComputerCheck = Confirm-DataComputerNameIsValidAndExists -Name $oldHostname
Write-Host "Checking your entry for validity; name of the New computer:" 
$resultNewComputerCheck = Confirm-DataComputerNameIsValidAndExists -Name $newHostname

# make decision to either continue script or stop execution based on validity check. Checking the last value of collection of objects:
if ($resultNewComputerCheck[-1] -and $resultOldComputerCheck[-1])
{    
# Make decision based on restricted paths and paths that are the same. 
##
    Write-Host "We are about to proceed with moving our computers"   
}
else 
{
    Write-Host "Sorry, but we cannot continue to work withoud valid computers"
    exit 10 # Exit with error
}


#### At this points we have valid computer names, so we need to perform check, if it is okay to do what script does
# Get computers from AD as an objects to be worked on. 
# Get the old computer object with description property (not specifying it will not append it!) Descpiption will be used in P.7
# Object used in P.5,6,7
$oldComputerObjectWithDescription = Get-ADComputer -Identity $oldHostname -Properties *
$newComputerObjectWithDescription = Get-ADComputer -Identity $newHostname # Must be re-initiated after moving.
# Display the old and current paths of the computer object in Active Directory, those are strings. 
# we will cut parent from theese strings, a parent is OU to move our computers
$oldPath = $oldComputerObjectWithDescription | Select-Object -ExpandProperty DistinguishedName
$newPath = $newComputerObjectWithDescription | Select-Object -ExpandProperty DistinguishedName
##  ^^ Those paths will be used later on, but firstt, print them:
Write-Host "Old computer path: $oldPath"
Write-Host "New computer path: $newPath"

##  Begginging to check, if current location of computers feels safe to operate (They are not in the same container)+
# (new machine is located exactly inside intended container and not in some strange place)

# Get names of the OU:s - there was LDAP path previously as STRING WITH COMMAS 
# But first separate it with -split operator, which will be producing array. Split operator
# must be grouped with it's parameters and index operator takes only [1] of resulting array, whch is OU
$oldOU = ($oldPath -split ',')[1]
$newOU = ($newPath -split ',')[1]
# Now we are checking if they are in same OU, this is no-no
if ($oldOU -eq $newOU) {
    Write-Host "`n`nThe hostnames are in the same OU: $oldOU - Sorry, that jsut feels wrong, we cannot continue, script will now exit" -ForegroundColor Red
    exit 11
} else {
    Write-Host "`n`nThe hostnames are in different OUs: $oldOU and $newOU, everyhing seems to be fine" -ForegroundColor Green
}


## Now we need to check if new computer's OU is exactly tyoasemat at specific path:
$checkingPath = "OU=Tyoasemat asennus,OU=Yhteiset,OU=PYHTAANKOULUT,DC=kymkoulut,DC=fi"
# If a new computer is not inside this path, script will not continue.
# Check if the NEW hostname is in the desired OU
if ($newPath -like "*$checkingPath*") {
    Write-Host "$newHostname is located in the following path $checkingPath " 
} else {
    $newComputerPathWithoutLeftCn = $newPath -replace 'CN=[^,]*(,|$)', ''
    Write-Host "Sorry, but the computer $newHostname is not in the right path, which is $checkingPath. It is in the $newComputerPathWithoutLeftCn, that feels very wrong." -ForegroundColor Red
    $userChoice = Read-Host "Do you want to continue? Y / [N]"
    if ($userChoice.ToUpper() -ne 'Y') {
        Write-Host "Script stopped by user choice." -ForegroundColor Yellow
        exit 12
    }
}


#________________________________

### PART 5: Move computer to a new AD location

# Ask the user if they want to move the new computer to the same path as the old computer
$moveComputer = Read-Host "`nDo you want to move the new computer to the same path as the old computer? [Default: Y] (Y/N/EXIT)"
if ($moveComputer -eq "YES" -or $moveComputer -eq "" -or $moveComputer -eq "Y" ){

    $oldComputerPathWithoutCn = $oldPath -replace 'CN=[^,]*(,|$)', ''
    Move-ADObject -Identity $newComputerObjectWithDescription.DistinguishedName -TargetPath $oldComputerPathWithoutCn -ErrorAction Stop
    $success = $false
    while (-not $success) {
        Start-Sleep -Seconds 1
        $newComputerObjectWithDescription = $null # Unassign the variable before each cycle
        try {
            $newComputerObjectWithDescription = Get-ADComputer -Identity $newHostname -Properties * -ErrorAction Stop
            if ($newComputerObjectWithDescription.DistinguishedName -notlike "*$oldComputerPathWithoutCn*") {
                throw "Computer not in expected path"
            }
            Write-Host "Moving operation successful. Computer $newHostname was moved to path $oldComputerPathWithoutCn"
            $success = $true
        } catch {
            Write-Host "Attempt to verify move failed, retrying..." -ForegroundColor Yellow
        }
    }

} elseif ($moveComputer -eq "EXIT" -or $moveComputer -eq "e") {
    Write-Host "User wanted to exit" -ForegroundColor Red
    exit 22
}
# endif

#________________________________

### PART 6: Copy groups of old compter to a new computer
Write-Host "`n`n***** Starting analysing and copying of groups **********`n" -BackgroundColor DarkMagenta
# Set the restricted groups that should not be copied
$restrictedGroupsToCopy = "Domain Computers", "testy3"

# Get the groups that the old computer object is a member of. Array of strings. 
$oldComputersGroups = Get-ADPrincipalGroupMembership -Identity $oldComputerObjectWithDescription.SamAccountName | Select-Object -ExpandProperty Name

# Get the groups that the new computer object is a member of. Array of strings. 
$groupsOfNewHost = Get-ADPrincipalGroupMembership -Identity $newComputerObjectWithDescription.SamAccountName | Select-Object -ExpandProperty Name

# Display the groups that the old computer object is a member of
Write-Host "Groups for $oldHostname`:"
foreach ($group in $oldComputersGroups) {
    Write-Host -NoNewLine "$group " 
}
## Give me some space
Write-Host ""
# Display the groups that the new computer object is a member of
Write-Host "Groups for $newHostname`:"
foreach ($group in $groupsOfNewHost) {
    Write-Host -NoNewLine "$group " 
}

Write-Host "`n`nWe will start prompting the user about copying new groups: `n" -ForegroundColor DarkMagenta

# Iterate over the groups that the old computer object is a member of
foreach ($group in $oldComputersGroups) {
    # Check if the new computer object is also a member of the group
    if ($groupsOfNewHost -contains $group) {
        # Inform the user that both computer objects are members of the same group
        Write-Host "Both $oldHostname and $newHostname are members of the $group group, nothing to copy" -ForegroundColor DarkGreen
    }
    else {
        # Check if the group is restricted
        if ($restrictedGroupsToCopy -contains $group) {
            # Inform the user that the group is restricted and no action will be taken
            Write-Host "The $group group is restricted and no action will be taken." -ForegroundColor Red
        }
        else {
            # Ask the user if they want to copy the group to the new computer object
                $copyGroup = Read-Host "Do you want to copy the $group group to $newHostname`? (Y/N/EXIT)"
                if ($copyGroup -eq "Y" -or $copyGroup -eq "") {
                    # Add the new computer object to the group
                    Add-ADGroupMember -Identity $group -Members $newComputerObjectWithDescription
                    Write-Host "The $newHostname computer object has been added to the $group group." -ForegroundColor DarkGreen
                } elseif($copyGroup -eq "EXIT" -or $copyGroup -eq "e") {
                    Write-Host "User wanted to exit. Changes are not reverted" -ForegroundColor Red
                    exit 23
                } else {
                    Write-host "Not copying."
                }
            }
            
        }
    }


# Display the final list of groups for the old and new computer objects

Write-Host "`nGroups of $oldHostname`:" -ForegroundColor DarkMagenta
foreach ($group in $oldComputersGroups) {
    Write-Host -NoNewLine "$group " 
}

# Update the groups that the new computer object is a member of, because they had changed.
$newComputerGroups = Get-ADPrincipalGroupMembership -Identity $newComputerObjectWithDescription.SamAccountName | Select-Object -ExpandProperty Name
Write-Host "`nFinal groups for $newHostname`:" -ForegroundColor DarkMagenta
foreach ($group in $newComputerGroups) {
    Write-Host -NoNewLine "$group " 
}
#________________________________



### PART 7: Copy description from old computer to new computer (OR write new desc.)
Write-Host "`n`n analysing Description: `n" -BackgroundColor DarkMagenta



# Check if the old computer object has a description
if ($oldComputerObjectWithDescription.Description) {
    # Inform the user of the old description
    Write-Host "Old description: $($oldComputerObjectWithDescription.Description)"
} else {
    # Inform the user that the old computer object has no description
    Write-Host "Old computer has no description, it is empty string"
}
# Prompt the user for a custom description
$description = Read-Host "Enter a custom description for the new computer object `
(enter EMPTY to set an empty string, or justpress Enter to copy the old description)"

# Use the custom description if provided, otherwise use the old description
if ($description -eq "EMPTY") {
    # Use an empty string
    $description = ""
# Copy older computer description as defaut action
} elseif ($description -eq "") {
    # Use the old description
    $description = $oldComputerObjectWithDescription.Description
}
# no else, as no action needed if if statements fail
if($description){
    Set-ADComputer -Identity $newHostname -Description $description
    # Get the description:
    $newComputerObjectWithDescription = Get-ADComputer -Identity $newHostname -Properties Description
    # Inform the user that the description was set
    Write-Host "Description set for $newHostname`: $($newComputerObjectWithDescription.Description)" -BackgroundColor Green
}
else {
    Write-Host "Description for new hostnme was not set, because you wanted it like that" -BackgroundColor DarkGreen
}

#________________________________
Write-Host "You had reached the end of script!" -ForegroundColor DarkGreen