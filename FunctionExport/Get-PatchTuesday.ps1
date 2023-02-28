function Get-PatchTuesday
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
        [Parameter(ParameterSetName='ThisMonth')]
        [switch]
        $ThisMonth,

        [Parameter(ParameterSetName='NextMonth', Mandatory=$true)]
        [switch]
        $NextMonth,

        [Parameter(ParameterSetName='PreviousMonth', Mandatory=$true)]
        [switch]
        $PreviousMonth,

        [Parameter(ParameterSetName='Next', Mandatory=$true)]
        [switch]
        $Next,

        [Parameter(ParameterSetName='Previous', Mandatory=$true)]
        [switch]
        $Previous,

        [Parameter(ParameterSetName='YearMonth', Mandatory=$true)]
        [ValidateRange(1970,2199)]
        [int]
        $Year,
        
        [Parameter(ParameterSetName='YearMonth', Mandatory=$true)]
        [ValidateRange(1,12)]
        [int]
        $Month,

        [Parameter(ParameterSetName='YearMonthDate', Mandatory=$true)]
        [System.DateTime]
        $YearMonthDate,

        [Parameter(ParameterSetName='TestDate', Mandatory=$true)]
        [switch]
        $TestDate,

        [Parameter(ParameterSetName='TestDate')]
        [System.DateTime]
        $Date,

        [Parameter()]
        [System.DayOfWeek]
        $DayOfWeek = 'Tuesday',
        
        [Parameter()]
        [ValidateRange(1,4)]
        [int]
        $NthWeekDayInMonth = 2,

        [Parameter()]
        [ValidateRange(0, 31)]
        [int]
        $AddDays = 0
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference
    $origErrorActionPreferenceGlobal = $global:ErrorActionPreference

    try
    {
        # Stop and catch all errors. Local ErrorAction isn't propagate when calling functions in other modules
        $global:ErrorActionPreference = $ErrorActionPreference = 'Stop'

        # Non-boilerplate stuff starts here

        $now = Get-Date

        if ($PSCmdlet.ParameterSetName -eq 'ThisMonth')
        {
            $YearMonthDate = $now
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'NextMonth')
        {
            $YearMonthDate = $now.AddMonths(1)
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'PreviousMonth')
        {
            $YearMonthDate = $now.AddMonths(-1)
        }
        elseif ($PSCmdlet.ParameterSetName -in @('Next', 'Previous'))
        {
            $YearMonthDate = $now
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'YearMonth')
        {
            $YearMonthDate = [System.DateTime]::new($Year, $Month, 1)
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'YearMonthDate')
        {
            # nothing
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'TestDate' -and -not $Date)
        {
            $YearMonthDate = $now.AddDays(-$AddDays)
            $Date = $now
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'TestDate' -and $Date)
        {
            $YearMonthDate = [System.DateTime]::new($Date.Year, $Date.Month, 1).AddDays(-$AddDays)
        }
        else
        {
            throw 'Undefined input'
        }

        $numInMonth = 0
        $patchDate = [datetime]::new($YearMonthDate.Year, $YearMonthDate.Month, 1)
        while ($true)
        {
            if ($patchDate.DayOfWeek -eq $DayOfWeek -and ++$numInMonth -eq $NthWeekDayInMonth)
            {
                break
            }
            $patchDate = $patchDate.AddDays(1)
        }

        $patchDate = $patchDate.AddDays($AddDays)

        # Return
        if ($PSCmdlet.ParameterSetName -eq 'Next')
        {
            if ($patchDate.Date -gt $now.Date)
            {
                $patchDate
            }
            else
            {
                $null = $PSBoundParameters.Remove('Next')
                Get-PatchTuesday @PSBoundParameters -NextMonth
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Previous')
        {
            if ($patchDate.Date -lt $now.Date)
            {
                $patchDate
            }
            else
            {
                $null = $PSBoundParameters.Remove('Previous')
                Get-PatchTuesday @PSBoundParameters -PreviousMonth
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'TestDate')
        {
            'PatchDate should be {0}, neares patchdate seems to be {1}' -f $Date.Date, $patchDate.Date | Write-Verbose
            $Date.Date -eq $patchDate.Date
        }
        else
        {
            $patchDate.Date
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
