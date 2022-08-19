function Invoke-ProcessWithFile
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
        [Parameter()]
        [string]
        $FilePath = '',

        [Parameter(Mandatory=$true, ParameterSetName='ArgumentList')]
        [string[]]
        $ArgumentList = @(),

        [Parameter(Mandatory=$true, ParameterSetName='Arguments', Position=0)]
        [string]
        $Arguments = '',

        [Parameter()]
        [hashtable]
        $Files = @{}
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference
    $origErrorActionPreferenceGlobal = $global:ErrorActionPreference

    try
    {
        # Stop and catch all errors. Local ErrorAction isn't propagate when calling functions in other modules
        $global:ErrorActionPreference = $ErrorActionPreference = 'Stop'

        # Non-boilerplate stuff starts here

        $tmpDir = $stdOut = $stdErr = $null
        $fileList = @()

        try
        {
            $stdOut = (New-TemporaryFile).FullName
            $stdErr = (New-TemporaryFile).FullName

            if ($Arguments)
            {
                $ArgumentList = @($Arguments -split ' (?=(?:[^"]|"[^"]*")*$)').ForEach({$_ -replace '"'})
            }

            if (-not $FilePath)
            {
                ($FilePath, $ArgumentList) = $ArgumentList
            }

            if ($Files.Count)
            {
                $tmpDir = Join-Path -Path $env:TEMP -ChildPath ([guid]::NewGuid())
                $null = New-Item -ItemType Directory -Path $tmpDir
                foreach ($k in $Files.Keys)
                {
                    $p = Join-Path -Path $tmpDir -ChildPath $k
                    $Files[$k] | Set-Content -NoNewline -Path $p
                    for ($i = 0; $i -lt $ArgumentList.Count; $i++)
                    {
                        $ArgumentList[$i] = $ArgumentList[$i] -replace "{{$k}}",$p
                    }
                    $fileList += $p
                }
            }

            $splat = @{
                FilePath               = $FilePath
                RedirectStandardOutput = $stdOut
                RedirectStandardError  = $stdErr
                Wait                   = $true;
                PassThru               = $true;
                NoNewWindow            = $true;
            }

            if ($ArgumentList)
            {
                $splat['ArgumentList'] = $ArgumentList
            }

            $cmd = Start-Process @splat
            $cmd | Add-Member -NotePropertyName StandardOutputString -NotePropertyValue ([string](Get-Content -Raw -Path $stdOut))
            $cmd | Add-Member -NotePropertyName StandardErrorString  -NotePropertyValue ([string](Get-Content -Raw -Path $stdErr))
            $cmd
        }
        finally
        {
            $null = Remove-Item -Path $stdOut,$stdErr -Force -ErrorAction Ignore
            if ($tmpDir)
            {
                $null = Remove-Item -Path $fileList -Force -ErrorAction Ignore
                $null = Remove-Item -Path $tmpDir -Force -ErrorAction Ignore
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
