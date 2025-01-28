function Invoke-CommandWithRetryAndLimit
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
        [Parameter(ParameterSetName='ScriptBlock', Mandatory=$true)]
        [ScriptBlock]
        $ScriptBlock,

        [Parameter(ParameterSetName='Command', Mandatory=$true)]
        [string]
        $Command = $null,

        [Parameter(ParameterSetName='Command')]
        [hashtable]
        $Parameters = @{},

        [Parameter()]
        [switch]
        $VerboseOnRetry,

        [Parameter()]
        [string]
        $SuccessExceptionRegex = '',

        [Parameter()]
        [byte]
        $RetryCount = 3,

        [Parameter()]
        [byte]
        $WaitSeconds = 5,

        [Parameter()]
        [byte]
        $WaitSecondsOK = 0,

        [Parameter()]
        [object]
        $TotalTryCountdownVariable = $null,

        [Parameter()]
        [uint16]
        $TotalTryCountdownInit = 0,

        [Parameter()]
        [object]
        $SuccessCountdownVariable = $null,

        [Parameter()]
        [uint16]
        $SuccessCountdownInit = 0,

        [Parameter()]
        [switch]
        $CountdownReset
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference
    $origErrorActionPreferenceGlobal = $global:ErrorActionPreference
    $origVerbosePreferenceGlobal = $global:VerbosePreference

    try
    {
        # Stop and catch all errors. Local ErrorAction isn't propagate when calling functions in other modules
        $global:ErrorActionPreference = $ErrorActionPreference = 'Stop'

        # Non-boilerplate stuff starts here

        if ($Command)
        {
            $ScriptBlock = [ScriptBlock]::Create("$Command @Parameters")
        }

        function ProcessVar ($Name, $Init)
        {
            $v1 = Get-Variable -Scope 1 -Name $Name -ValueOnly
            if ($v1 -is [string])
            {
                try
                {
                    $v2 = Get-Variable -Scope Global -Name $v1
                }
                catch
                {
                    $v2 = Set-Variable -Scope Global -Name $v1 -Value $Init -PassThru
                }
                Set-Variable -Scope 1 -Name $Name -Value $v2
            }
            elseif ($v1 -ne $null -and $v1 -isnot [PSVariable])
            {
                throw "$Name is neither [string] or [PSVariable]"
            }
            if ($CountdownReset)
            {
                "Reset $Name to $Init" | Write-Verbose
                (Get-Variable -Scope 1 -Name $Name).Value.Value = $init
            }
        }

        ProcessVar -Name TotalTryCountdownVariable -Init $TotalTryCountdownInit
        ProcessVar -Name SuccessCountdownVariable  -Init $SuccessCountdownInit

        $beVerbose = $false
        do
        {
            if ($TotalTryCountdownVariable -and $TotalTryCountdownVariable.Value -le 0)
            {
                throw ('TotalTryCountdownVariable ${0} is zero' -f $TotalTryCountdownVariable.Name)
            }
            if ($SuccessCountdownVariable -and $SuccessCountdownVariable.Value -le 0)
            {
                throw ('SuccessCountdownVariable ${0} is zero' -f $SuccessCountdownVariable.Name)
            }
            
            try
            {
                if ($TotalTryCountdownVariable)
                {
                    'TotalTryCountdownVariable ${0} is {1}' -f $TotalTryCountdownVariable.Name, $TotalTryCountdownVariable.Value-- | Write-Verbose
                }
                'Running ScriptBlock...' | Write-Verbose
                if ($beVerbose -and $VerboseOnRetry)
                {
                    $global:VerbosePreference = 'Continue'
                }
                & $ScriptBlock
                $global:VerbosePreference = $origVerbosePreferenceGlobal
                break
            }
            catch
            {
                $global:VerbosePreference = $origVerbosePreferenceGlobal
                'Exception thrown from ScriptBlock: {0}' -f  $_ | Write-Warning
                if ($SuccessExceptionRegex -and $_ -cmatch $SuccessExceptionRegex)
                {
                    'Exception matches "{0}", treating it as a success' -f $_ | Write-Warning
                    break
                }
                if (-not $RetryCount) {throw $_}
                if ($TotalTryCountdownVariable -and $TotalTryCountdownVariable.Value -le 0) {continue}
                if ($SuccessCountdownVariable  -and $SuccessCountdownVariable.Value  -le 0) {continue}
                'Number of retries left {0}, next retry in {1} seconds' -f $RetryCount, $WaitSeconds | Write-Verbose
                Start-Sleep -Seconds $WaitSeconds
                $beVerbose = $true
            }
        }
        while ($RetryCount--)
        $beVerbose = $false
        Start-Sleep -Seconds $WaitSecondsOK
        if ($SuccessCountdownVariable)
        {
            'SuccessCountdownVariable ${0} is now {1}' -f $SuccessCountdownVariable.Name, --$SuccessCountdownVariable.Value | Write-Verbose
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
        $global:VerbosePreference = $origVerbosePreferenceGlobal
    }

    Write-Verbose -Message 'End'
}
