function Get-CommandDependencyFrequency {
    <#
    .SYNOPSIS
    Get command dependencies in the public PowerShell scripts.

    .DESCRIPTION
    This function reads all the public PowerShell scripts and counts the number of times each command is used in them.
    It returns a list of all used commands, the number of times they are used, the module the command is from, and the
    files each command is used in.

    .EXAMPLE
    Get-CommandDependencyFrequency

    Gets all command dependencies in the public PowerShell scripts with their usage and source module.

    .EXAMPLE
    Get-CommandDependencyFrequency -ExcludeBuiltIn

    Gets all command dependencies in the public PowerShell scripts with their usage and source module, excluding built-in PowerShell commands.

    .EXAMPLE
    Get-CommandDependencyFrequency -ExcludeUnknown

    Gets all command dependencies in the public PowerShell scripts with their usage and source module, excluding unknown commands and private functions.

    .EXAMPLE
    Get-CommandDependencyFrequency -ExcludeBuiltIn -ExcludeUnknown

    Gets all command dependencies in the public PowerShell scripts with their usage and source module, excluding built-in PowerShell commands, unknown commands, and private functions.

    .NOTES
    To Do:
    - Track known, internal private functions so they can be reported accurately in the results. (In Progress)
    - Add a parameter to scan directories other than the default (public).
    - Define parameter sets as necessary to support the filters below:
    - Add a parameter to only show unknown/private commands.
    - Add a parameter to filter the results by module.
    - Add a parameter to filter the results by command name.
    - Add a parameter to filter the results by file name.
    - Add a parameter to filter the results by command usage count.
    #>

    [CmdletBinding()]
    param (
        # Exclude built-in PowerShell commands
        [Parameter()]
        [switch]
        $ExcludeBuiltIn,

        # Exclude unknown commands
        [Parameter()]
        [switch]
        $ExcludeUnknown
    )

    # region FilterResults
    $FilterConditions = '( $_ )'
    if ($ExcludeBuiltIn.IsPresent) {
        $FilterConditions += ' -and ( $_.Module -notin @("Pester", "PowerShellGet") -and $_.Module -notlike "Microsoft.PowerShell*" -and $_.Module -notlike "DnsClient*")'
    }
    if ($ExcludeUnknown.IsPresent) {
        $FilterConditions += ' -and ( $_.Module -ne "Unknown Module or Private Command" )'
    }
    $Filter = [scriptblock]::Create($FilterConditions)
    #endregion FilterResults

    #region GetInternalFunctions
    $InternalFunctionsPath = (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'powershell/internal')
    [string[]]$InternalFunctions = Get-ChildItem -Path $InternalFunctionsPath -File *.ps1 |
        Select-Object -ExpandProperty BaseName
    #endregion GetInternalFunctions

    $FileDependencies = New-Object System.Collections.Generic.List[PSCustomObject]
    $Files = Get-ChildItem -Path (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'powershell/public') -File *.ps1 -Recurse
    foreach ($file in $Files) {
        $Content = Get-Content $file -Raw
        $Parse = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
        $Commands = $parse.FindAll({
                $args | Where-Object { $_ -is [System.Management.Automation.Language.CommandAst] }
            }, $true) | ForEach-Object {
                ($_.CommandElements | Select-Object -First 1).Value
            } | Group-Object | Sort-Object @{e = { $_.Count }; Descending = $true }, Name

        foreach ($command in $Commands) {
            $FileDependencies.Add( [PSCustomObject]@{
                Command = $command.Name
                Count   = $command.Count
                File    = $file
            } )
        }
    }

    # Loop through $FileDependencies. Create a list of custom objects that contain the command name, the number of times it appears, and the files it appears in.
    $DependencyList = New-Object System.Collections.Generic.List[PSCustomObject]
    foreach ($item in $FileDependencies) {
        # Check if $DependencyList already contains an object with the same command name.
        if ($DependencyList.command -contains $item.command) {
            # If it is already in the list, increment the count and add the file to the files array.
            $ListItem = $DependencyList | Where-Object { $_.command -eq $item.command }
            $ListItem.count = $ListItem.count + $item.count
            $ListItem.files += $item.file
            continue
        } else {
            # Create a new item in the list.
            $Module = (Get-Command -Name $item.command -ErrorAction SilentlyContinue).Source
            if ( [string]::IsNullOrEmpty($Module) -and $InternalFunctions -contains $item.command ) {
                $Module = 'Maester (Internal Function)'
            }

            $DependencyList.Add( [PSCustomObject]@{
                Command = $item.command
                Module  = $Module
                Count   = $item.count
                Files   = @($item.file)
            } )
        }
    }

    $DependencyList = $DependencyList | Sort-Object -Property Module, Count, Name
    $DependencyList | Where-Object -FilterScript $Filter

}
