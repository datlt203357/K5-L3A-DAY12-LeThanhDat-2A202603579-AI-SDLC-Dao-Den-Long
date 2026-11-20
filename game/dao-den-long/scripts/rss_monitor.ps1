param(
    [Parameter(Mandatory = $true)][int]$TargetPid,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$StopPath
)

$peak = 0L
while (-not (Test-Path -LiteralPath $StopPath)) {
    try {
        $process = Get-Process -Id $TargetPid -ErrorAction Stop
        $peak = [Math]::Max($peak, [int64]$process.WorkingSet64)
        [System.IO.File]::WriteAllText($OutputPath, $peak.ToString())
    } catch {
        break
    }
    Start-Sleep -Milliseconds 100
}
