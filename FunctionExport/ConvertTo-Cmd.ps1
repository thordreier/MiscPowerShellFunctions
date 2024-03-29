function ConvertTo-Cmd
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
        [Parameter(ParameterSetName='PathDstConvertCmd',    Mandatory = $true)]
        [Parameter(ParameterSetName='PathDstCompatible',    Mandatory = $true)]
        [Parameter(ParameterSetName='PathStrConvertCmd',    Mandatory = $true)]
        [Parameter(ParameterSetName='PathStrCompatible',    Mandatory = $true)]
        [string]
        $Path,

        [Parameter(ParameterSetName='ContentDstConvertCmd', Mandatory = $true)]
        [Parameter(ParameterSetName='ContentDstCompatible', Mandatory = $true)]
        [Parameter(ParameterSetName='ContentStrConvertCmd', Mandatory = $true)]
        [Parameter(ParameterSetName='ContentStrCompatible', Mandatory = $true)]
        [string]
        $Content,

        [Parameter(ParameterSetName='PathDstConvertCmd')]
        [Parameter(ParameterSetName='PathDstCompatible')]
        [Parameter(ParameterSetName='ContentDstConvertCmd')]
        [Parameter(ParameterSetName='ContentDstCompatible')]
        [string]
        $Destination,

        [Parameter(ParameterSetName='PathStrConvertCmd',    Mandatory = $true)]
        [Parameter(ParameterSetName='PathStrCompatible',    Mandatory = $true)]
        [Parameter(ParameterSetName='ContentStrConvertCmd', Mandatory = $true)]
        [Parameter(ParameterSetName='ContentStrCompatible', Mandatory = $true)]
        [switch]
        $AsString,

        [Parameter()]
        [string]
        $TmpFile = '%TEMP%\{0}.tmp',

        [Parameter()]
        [string]
        $EndFile = '%TEMP%\{0}.ps1',

        [Parameter(ParameterSetName='PathDstConvertCmd')]
        [Parameter(ParameterSetName='PathStrConvertCmd')]
        [Parameter(ParameterSetName='ContentDstConvertCmd')]
        [Parameter(ParameterSetName='ContentStrConvertCmd')]
        $ConvertCmd = 'powershell -Command "[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String((gc %TMPFILE%))) | sc %ENDFILE% -NoNewline"',

        [Parameter(ParameterSetName='PathDstCompatible',    Mandatory = $true)]
        [Parameter(ParameterSetName='PathStrCompatible',    Mandatory = $true)]
        [Parameter(ParameterSetName='ContentDstCompatible', Mandatory = $true)]
        [Parameter(ParameterSetName='ContentStrCompatible', Mandatory = $true)]        [switch]
        $Compatible,

        [Parameter()]
        [AllowEmptyString()]
        [string]
        $ExecuteCmd = 'powershell -File %ENDFILE%',

        [Parameter()]
        [switch]
        $LeaveTmpFile,

        [Parameter()]
        [switch]
        $LeaveEndFile
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference
    $origErrorActionPreferenceGlobal = $global:ErrorActionPreference

    try
    {
        # Stop and catch all errors. Local ErrorAction isn't propagate when calling functions in other modules
        $global:ErrorActionPreference = $ErrorActionPreference = 'Stop'

        # Non-boilerplate stuff starts here

        if ($Path)
        {
            $Content = Get-Content -Raw -Path $Path
        }

        if ($Compatible)
        {
            # PowerShell 4 does not like -NoNewline
            $ConvertCmd = 'powershell -Command "[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String((gc %TMPFILE%))) | sc %ENDFILE%"'
        }

        $tmpName = [guid]::NewGuid() -replace '-'

        $TmpFile = $TmpFile -f $tmpName
        $EndFile = $EndFile -f $tmpName

        $base64 = [convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($Content))

        $str = @(
            '@echo off'
            "SET TMPFILE=$TmpFile"
            "SET ENDFILE=$EndFile"
            '> %TMPFILE% ('
            $base64 -split '(.{118})' | Where-Object -FilterScript {$_} | ForEach-Object -Process {"echo $_"}
            ")"
            $ConvertCmd
            if (-not $LeaveTmpFile) {'del %TMPFILE%'}
            $ExecuteCmd
            'SET EXITCODE=%ERRORLEVEL%'
            if (-not $LeaveEndFile) {'del %ENDFILE%'}
            'EXIT /B %EXITCODE%'
        ) -join "`r`n"
        
        if ($AsString)
        {
            $str
        }
        else
        {
            if (-not $Destination)            
            {
                $Destination = '{0}\{1}.cmd' -f $env:TEMP, ([guid]::NewGuid() -replace '-')
            }
            $str | Set-Content -Path $Destination -Encoding Ascii
            $Destination
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
