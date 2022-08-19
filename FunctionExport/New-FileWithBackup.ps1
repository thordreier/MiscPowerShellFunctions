function New-FileWithBackup
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
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.String]
        $Content
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference
    $origErrorActionPreferenceGlobal = $global:ErrorActionPreference

    try
    {
        # Stop and catch all errors. Local ErrorAction isn't propagate when calling functions in other modules
        $global:ErrorActionPreference = $ErrorActionPreference = 'Stop'

        # Non-boilerplate stuff starts here

        $tmpPath = '{0}.{1}.tmp' -f $Path, [guid]::NewGuid().Guid
        Set-Content -Path $tmpPath -Value $Content -NoNewline

        if ($item = Get-Item -Path $Path -ErrorAction Ignore)
        {
            $bakName = '{0}.{1}{2}' -f $item.BaseName, $item.LastWriteTimeUtc.ToFileTimeUtc(), $item.Extension
            $bakPath = Join-Path -Path $item.Directory -ChildPath $bakName
            $null = Move-Item -Path $Path -Destination $bakPath
        }

        $null = Move-Item -Path $tmpPath -Destination $Path

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
