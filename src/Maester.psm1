<#
.DISCLAIMER
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.

	Copyright (c) Microsoft Corporation. All rights reserved.
#>

## Set Strict Mode for Module. https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode
# Set-StrictMode -Version 3.0

## Initialize Module Configuration

## Initialize Module Variables
$script:ModuleRoot = $PSScriptRoot

# Import private and public scripts and expose the public ones
$privateScripts = @(Get-ChildItem -Path "$PSScriptRoot\internal" -Recurse -Filter "*.ps1")
$publicScripts = @(Get-ChildItem -Path "$PSScriptRoot\public" -Recurse -Filter "*.ps1")
$scriptScripts = @(Get-ChildItem -Path "$PSScriptRoot\scripts" -Recurse -Filter "*.ps1")
$checkScripts = @(Get-ChildItem -Path "$PSScriptRoot\checks" -Recurse -Filter "*.ps1")

foreach ($file in ($privateScripts + $publicScripts + $scriptScripts + $checkScripts)) {
	try {
		. $file.FullName
	} catch {
		Write-Error -Message ("Failed to import function {0}: {1}" -f $file, $_)
	}
}

Export-ModuleMember -Function $publicScripts.BaseName
