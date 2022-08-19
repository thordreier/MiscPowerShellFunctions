### Join-Paths ###
Join-Paths 'C:','windows','system32','drivers','etc','hosts'

### New-FileWithBackup ###
Get-Date | New-FileWithBackup -Path (Join-Paths $env:TEMP,'a.txt')

### Invoke-ProcessWithFile ###
# Don't start a program that require user-input
@(
    Invoke-ProcessWithFile 'cmd /c echo "hello A"'
    Invoke-ProcessWithFile -ArgumentList 'cmd','/c','echo','hello B'
    Invoke-ProcessWithFile -FilePath 'cmd' -Arguments '/c echo "hello C"'
    Invoke-ProcessWithFile -FilePath 'cmd' -ArgumentList '/c','echo','hello D'
    Invoke-ProcessWithFile 'cmd /c echo "{{e.txt}}"' -Files @{'e.txt' = 'Hello E'}
    Invoke-ProcessWithFile 'cmd /c type "{{f.txt}}"' -Files @{'f.txt' = 'Hello F'}
    Invoke-ProcessWithFile 'powershell -File "{{g.ps1}}"' -Files @{'g.ps1' = '[string]$host.Version; throw'}
    Invoke-ProcessWithFile 'pwsh -File "{{h.ps1}}"' -Files @{'h.ps1' = '[string]$host.Version; throw'}
) | select ExitCode,StandardOutputString,StandardErrorString

#### Invoke-PsExec ####
# PsExec needs to be installed
# https://docs.microsoft.com/en-us/sysinternals/downloads/psexec
Invoke-PsExec -ComputerName dc1.contoso.com -ArgumentList 'dcdiag /e' | select ExitCode,StandardOutputString,StandardErrorString | fl
