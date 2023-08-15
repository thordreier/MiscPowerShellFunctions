function New-ComplexPassword
{
    <#
        .SYNOPSIS
            Create a new complex password. Use at least one symbol from each group of characters. Should satisfy most password complexity requirements

        .DESCRIPTION
            xxx

        .PARAMETER xxx
            xxx

        .EXAMPLE
            xxx
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (
        [Parameter()]
        [byte]
        $Length = 20,

        [Parameter(ParameterSetName = 'Default')]
        [System.String[]]
        $Groups = @('abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', '0123456789', ',.-+;!#&@{}[]+$/()%'),

        [Parameter(ParameterSetName = 'Alphanumeric')]
        [switch]
        $Alphanumeric,

        [Parameter(ParameterSetName = 'Compatible')]
        [switch]
        $Compatible
    )

    Write-Verbose -Message "Begin (ErrorActionPreference: $ErrorActionPreference)"
    $origErrorActionPreference = $ErrorActionPreference
    $origErrorActionPreferenceGlobal = $global:ErrorActionPreference

    try
    {
        # Stop and catch all errors. Local ErrorAction isn't propagate when calling functions in other modules
        $global:ErrorActionPreference = $ErrorActionPreference = 'Stop'

        # Non-boilerplate stuff starts here

        if ($Alphanumeric) {$Groups = $Groups[0..2]}
        if ($Compatible) {$Groups = $Groups[0..2] + '.-_'}

        $grnd = $Groups | Get-Random -Count $Groups.Length
        (0..($Length-1) | ForEach-Object -Process {
            @(if ($_ -lt $grnd.Length) {$grnd[$_]} else {$grnd -join ''}).ToCharArray() | Get-Random
        } | Get-Random -Count $Length) -join ''

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
