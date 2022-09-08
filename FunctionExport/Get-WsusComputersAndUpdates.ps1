function Get-WsusComputersAndUpdates
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

    [CmdletBinding(DefaultParameterSetName='Default')]
    param
    (
        [Parameter()]
        [object]
        $WsusServer = $null,

        [Parameter()]
        [switch]
        $Overview,

        [Parameter()]
        [System.Guid[]]
        $IgnoreUpdates = @()
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference
    $origErrorActionPreferenceGlobal = $global:ErrorActionPreference

    try
    {
        # Stop and catch all errors. Local ErrorAction isn't propagate when calling functions in other modules
        $global:ErrorActionPreference = $ErrorActionPreference = 'Stop'

        # Non-boilerplate stuff starts here

        # WSUS server
        if ($WsusServer -eq $null)
        {
            'WsusServer not defined, getting object from Get-WsusServer' | Write-Verbose
            $WsusServer = Get-WsusServer
        }
        elseif ($WsusServer.GetType().FullName -ne 'Microsoft.UpdateServices.Internal.BaseApi.UpdateServer')
        {
            # Doing it with GetType() instead of -is to avoid problems if Wsus class cannot be found
            throw 'WsusServer is not a [Microsoft.UpdateServices.Internal.BaseApi.UpdateServer]'
        }

        # Get "raw" data
        $computerTargets = $WsusServer.GetComputerTargets()
        $updates = @{}
        foreach ($computerTarget in $computerTargets)
        {
            'Processing {0}' -f $computerTarget.FullDomainName | Write-Verbose
            $targetUpdates = $computerTarget.GetUpdateInstallationInfoPerUpdate()
            foreach ($targetUpdate in $targetUpdates)
            {
                if ($Overview -and $targetUpdate.UpdateInstallationState -in @('Installed','NotApplicable'))
                {
                    # We don't need this to make the overview
                    continue
                }

                if ($IgnoreUpdates.Contains($targetUpdate.UpdateId))
                {
                    '  Ignoring update {0}' -f $targetUpdate.UpdateId | Write-Verbose
                    continue
                }

                $updateId = [string] $targetUpdate.UpdateId
                if (-not $updates.ContainsKey($updateId))
                {
                    '  Fetching update {0}' -f $updateId | Write-Verbose
                    $updates[$updateId] = $targetUpdate.GetUpdate()
                }
                $update = $updates[$updateId]
                $targetUpdate | Add-Member -NotePropertyName _Update -NotePropertyValue $update
            }
            $computerTarget | Add-Member -NotePropertyName _TargetUpdates -NotePropertyValue $targetUpdates
            $computerTarget | Add-Member -NotePropertyName _ComputerUpdateStatus -NotePropertyValue ''
        }

        # Maybe there's a better way get status!
        $computerTargetHash = $computerTargets | ForEach-Object -Begin {$h=@{}} -Process {$h[[string]$_.Id]=$_} -End {$h}
        foreach ($status in @('NoStatus','InstalledOrNotApplicable','Needed','Failed'))
        {
            # This is just plain silly. Why doesn't it just return an empty array
            if (($wsusComputers = Get-WsusComputer -UpdateServer $WsusServer -ComputerUpdateStatus $status) -eq 'No computers available.')
            {
                $wsusComputers = @()
            }
            foreach ($wsusComputer in $wsusComputers)
            {
                $computerTargetHash[[string]$wsusComputer.Id]._ComputerUpdateStatus = $status
            }
        }

        if ($Overview)
        {
            'Creating DTO objects' | Write-Verbose
            $computerTargetsDto = [System.Collections.ArrayList]::new()
            foreach ($computerTarget in $computerTargets)
            {
                $targetUpdates = $computerTarget._TargetUpdates
                $updateCount = $targetUpdates | ForEach-Object -Begin {$h=@{}} -Process {$h[$_.UpdateInstallationState]+=1} -End {$h}

                # Needed updates
                $neededTargetUpdates = $targetUpdates | Where-Object -Property UpdateInstallationState -NotIn -Value @('Installed','NotApplicable')
                $neededUpdatesDto = [System.Collections.ArrayList]::new()
                foreach ($targetUpdate in $neededTargetUpdates)
                {
                    $neededUpdateDto = [PSCustomObject] @{
                        Id    = [string]   $targetUpdate.UpdateId
                        State = [string]   $targetUpdate.UpdateInstallationState
                        Title = [string]   $targetUpdate._Update.Title
                        Date  = [datetime] $targetUpdate._Update.CreationDate
                    }
                    $null = $neededUpdatesDto.Add($neededUpdateDto)
                }

                # FIXXXME - this should probably be defined somewhere else
                $notReportingDays = 2
                $oldUpdateDays    = 31

                # Status
                $oldestNeededUpdate = $neededUpdatesDto | Sort-Object -Property Date | Select-Object -First 1 -ExpandProperty Date
                $status = [string] $computerTarget._ComputerUpdateStatus
                if ($computerTarget.LastReportedStatusTime -lt (Get-Date).AddDays(-$notReportingDays))
                {
                    $status = 'NotReporting'
                }
                elseif ($status -eq 'Needed' -and $oldestNeededUpdate -and $oldestNeededUpdate -lt (Get-Date).AddDays(-$oldUpdateDays))
                {
                    $status = 'NeededOld'
                }

                $computerTargetDto = [PSCustomObject] @{
                    FullDomainName           = [string]         $computerTarget.FullDomainName
                    Id                       = [string]         $computerTarget.Id
                    IPAddress                = [string]         $computerTarget.IPAddress
                    LastReportedStatusTime   = [datetime]       $computerTarget.LastReportedStatusTime
                    LastSyncResult           = [string]         $computerTarget.LastSyncResult
                    Make                     = [string]         $computerTarget.Make
                    Model                    = [string]         $computerTarget.Model
                    OSDescription            = [string]         $computerTarget.OSDescription
                    RequestedTargetGroupName = [string]         $computerTarget.RequestedTargetGroupName
                    Status                   = [string]         $status
                    UpdateCount              = [PSCustomObject] $updateCount
                    NeededUpdates            = [array]          $neededUpdatesDto
                }
                $null = $computerTargetsDto.Add($computerTargetDto)
            }

            # Return
            [PSCustomObject] @{
                ComputerTargets = $computerTargetsDto
            }
        }
        else
        {
            # Return
            [PSCustomObject] @{
                WsusServer      = $WsusServer
                ComputerTargets = $computerTargets
                Updates         = $updates.Values | Sort-Object -Property CreationDate
            }
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
