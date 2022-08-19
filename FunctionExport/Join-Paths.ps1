function Join-Paths ([array] $Path)
{
    if ($Path)
    {
        $p = $Path[0]
        $Path[1..($Path.Length)] | ForEach-Object -Process {
            $p = Join-Path -Path $p -ChildPath $_
        }
        $p
    }
}
