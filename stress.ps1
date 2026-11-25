# stress.ps1 - all-core load; run as a scheduled task so it survives an SSH session closing
param([int]$Seconds = 600, [string]$Label = "run", [string]$Log = "$PSScriptRoot\stress-log.txt")
$start = Get-Date
Add-Content $log ("{0:yyyy-MM-dd HH:mm:ss} START {1} for {2}s on {3} worker processes" -f $start, $Label, $Seconds, $env:NUMBER_OF_PROCESSORS)
$cmd = '$e=(Get-Date).AddSeconds(' + $Seconds + '); while((Get-Date) -lt $e){ for($i=0;$i -lt 300000;$i++){ [void][math]::Sqrt($i) } }'
$procs = 1..[int]$env:NUMBER_OF_PROCESSORS | ForEach-Object {
    $p = Start-Process powershell -ArgumentList "-NoProfile","-WindowStyle","Hidden","-Command",$cmd -WindowStyle Hidden -PassThru
    $p.PriorityClass = "BelowNormal"
    $p
}
$procs | Wait-Process
Add-Content $log ("{0:yyyy-MM-dd HH:mm:ss} END {1}" -f (Get-Date), $Label)
