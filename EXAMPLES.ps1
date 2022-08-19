# Join-Paths
Join-Paths 'C:','windows','system32','drivers','etc','hosts'

# New-FileWithBackup
Get-Date | New-FileWithBackup -Path (Join-Paths $env:TEMP,'a.txt')
