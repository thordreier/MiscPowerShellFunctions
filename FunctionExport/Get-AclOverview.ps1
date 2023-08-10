function Get-AclOverview
{
    <#
        .SYNOPSIS
            xxx

        .DESCRIPTION
            xxx

        .PARAMETER xxx
            xxx

        .EXAMPLE
            xxx
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position=0)]
        [System.String]
        $Path,

        [Parameter()]
        [ValidateRange(0,255)]
        [int]
        $Depth = 50,

        [Parameter()]
        [ValidateSet('First','All','Dirs','None')]
        [System.String]
        $ShowInherited = 'First',

        [Parameter()]
        [switch]
        $Grid,

        [Parameter()]
        [switch]
        $Force
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference
    $origErrorActionPreferenceGlobal = $global:ErrorActionPreference

    try
    {
        # Stop and catch all errors. Local ErrorAction isn't propagate when calling functions in other modules
        $global:ErrorActionPreference = $ErrorActionPreference = 'Stop'

        # Non-boilerplate stuff starts here

        $ids = @{}
        $list = [System.Collections.ArrayList]::new()
        $dirOrFile = @{'True' = 'Directory'; 'False' = 'File'}

        function LoopAcl ($Path, $Depth, $Items = @())
        {
            'Depth:{0} {1}' -f $Depth, $Path | Write-Verbose

            if ($Depth -and (-not $Items -or $Items[0].PSIsContainer))
            {
                $Items += Get-ChildItem -LiteralPath $Path -Force:$Force
            }

            foreach ($item in $Items)
            {
                try
                {
                    $acl = Get-Acl  -LiteralPath $item.FullName
                    if ($access = $acl.Access.Where({
                        -not $_.IsInherited -or
                        $ShowInherited -eq 'All' -or
                        ($ShowInherited -eq 'Dirs' -and $item.PSIsContainer) -or
                        $item._INCLUDE
                    }))
                    {
                        [PSCustomObject] @{
                            Path   = $item.FullName
                            Type   = $dirOrFile[[string]$item.PSIsContainer]
                            Access = $access
                        }
                    }
                    if ($Depth -and $item.PSIsContainer)
                    {
                        LoopAcl -Path $item.FullName -Depth ($Depth - 1)
                    }
                }
                catch
                {
                    '{0}: {1}' -f $item.FullName, $_ | Write-Warning
                }
            }
        }

        $item = Get-Item -LiteralPath $Path
        if ($ShowInherited -in @('First','All') -or ($ShowInherited -eq 'Dirs' -and $item.PSIsContainer))
        {
            $item | Add-Member -NotePropertyName _INCLUDE -NotePropertyValue $true
        }

        if ($Grid)
        {
            $processBlock = {
                $e = [ordered] @{
                    Path = $_.Path
                    Type = $_.Type
                }
                foreach ($a in $_.Access)
                {
                    $ids[[string]$a.IdentityReference] = 1
                    $e[[string]$a.IdentityReference] = '{0}: {1}' -f $a.AccessControlType, $a.FileSystemRights
                }
                $null = $list.Add([PSCustomObject] $e)
            }
        }
        else
        {
            $processBlock = {
                foreach ($a in $_.Access)
                {
                    [PSCustomObject] @{
                        Path      = $_.Path
                        Type      = $_.Type
                        Id        = $a.IdentityReference
                        AclType   = $a.AccessControlType
                        Rights    = $a.FileSystemRights
                        Inherited = $a.IsInherited
                    }
                }
            }
        }

        LoopAcl -Path $Path -Depth $Depth -Items @($item) | ForEach-Object -Process $processBlock

        if ($Grid)
        {
            $list | Select-Object -Property (('Path','Type') + ($ids.Keys | Sort-Object))
        }

        # Non-boilerplate stuff ends here
    }
    catch
    {
        # If error was encountered inside this function then stop processing
        # But still respect the ErrorAction that comes when calling this function
        # And also return the line number where the original error occured
        $msg = $_.ToString() + "`r`n" + $_.InvocationInfo.PositionMessage.ToString()
        Write-Verbose -Message "Encountered an error: $msg"
        Write-Error -ErrorAction $origErrorActionPreference -Exception $_.Exception -Message $msg
    }
    finally
    {
        # Clean up ErrorAction
        $global:ErrorActionPreference = $origErrorActionPreferenceGlobal
    }

    Write-Verbose -Message 'End'
}
