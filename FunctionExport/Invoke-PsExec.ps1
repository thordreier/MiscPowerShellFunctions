function Invoke-PsExec
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
        [Parameter(Mandatory=$true)]
        [pscredential]
        $Credential,

        [Parameter(Mandatory=$true)]
        [string]
        $ComputerName,

        [Parameter(Mandatory=$true, ParameterSetName='ArgumentList')]
        [string[]]
        $ArgumentList = @(),

        [Parameter(Mandatory=$true, ParameterSetName='Arguments')]
        [string]
        $Arguments = ''
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference
    $origErrorActionPreferenceGlobal = $global:ErrorActionPreference

    try
    {
        # Stop and catch all errors. Local ErrorAction isn't propagate when calling functions in other modules
        $global:ErrorActionPreference = $ErrorActionPreference = 'Stop'

        # Non-boilerplate stuff starts here

        if ($Arguments)
        {
            $ArgumentList = @($Arguments -split ' (?=(?:[^"]|"[^"]*")*$)').ForEach({$_ -replace '"'})
        }

        $arg = @(
            '-accepteula'
            '-nobanner'
            '-i'
            '-h'
            '-u'
            $Credential.UserName
            '-p'
            $Credential.GetNetworkCredential().Password
            "\\$ComputerName"
        )

        Invoke-ProcessWithFile -FilePath psexec -ArgumentList ($arg + $ArgumentList)

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
