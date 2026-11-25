# coretemp-prom.ps1 - reads Core Temp's shared memory and writes a Prometheus textfile
# Path: Core Temp (already running) -> this script (every 10 s) -> windows_exporter textfile collector -> Prometheus -> Grafana
$out = "C:\Program Files\windows_exporter\textfile_inputs\coretemp.prom"
Add-Type -AssemblyName System.Core

function Read-CoreTemp {
    $mmf = [System.IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting("CoreTempMappingObject")
    $view = $mmf.CreateViewAccessor(0, 2700, [System.IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read)
    $coreCnt = $view.ReadUInt32(1536)
    $cpuCnt  = $view.ReadUInt32(1540)
    $speed   = $view.ReadSingle(2572)
    $nameBytes = New-Object byte[] 100
    [void]$view.ReadArray(2584, $nameBytes, 0, 100)
    $name = ([Text.Encoding]::ASCII.GetString($nameBytes)).Split([char]0)[0].Trim()
    $fahr  = $view.ReadByte(2684)
    $delta = $view.ReadByte(2685)
    $total = $coreCnt * $cpuCnt
    $rows = @()
    for ($i = 0; $i -lt $total; $i++) {
        $t = $view.ReadSingle(1544 + 4 * $i)
        $tj = $view.ReadUInt32(1024 + 4 * [math]::Floor($i / $coreCnt))
        $load = $view.ReadUInt32(4 * $i)
        if ($delta -eq 1) { $t = $tj - $t }
        if ($fahr -eq 1) { $t = ($t - 32) * 5 / 9 }
        $rows += [pscustomobject]@{ Core = $i; Temp = $t; Load = $load; TjMax = $tj }
    }
    $view.Dispose(); $mmf.Dispose()
    [pscustomobject]@{ Name = $name; Speed = $speed; Rows = $rows }
}

while ($true) {
    $lines = New-Object System.Collections.Generic.List[string]
    try {
        $d = Read-CoreTemp
        $cpu = $d.Name -replace '"', ''
        $inv = [Globalization.CultureInfo]::InvariantCulture
        $lines.Add("# TYPE coretemp_temperature_celsius gauge")
        $lines.Add("# TYPE coretemp_load_percent gauge")
        $lines.Add("# TYPE coretemp_cpu_speed_mhz gauge")
        foreach ($r in $d.Rows) {
            $lines.Add("coretemp_temperature_celsius{cpu=`"$cpu`",core=`"$($r.Core)`"} " + ([double]$r.Temp).ToString("0.0", $inv))
            $lines.Add("coretemp_load_percent{cpu=`"$cpu`",core=`"$($r.Core)`"} $($r.Load)")
        }
        $lines.Add("# TYPE coretemp_tjmax_celsius gauge")
        $lines.Add("coretemp_tjmax_celsius{cpu=`"$cpu`"} $($d.Rows[0].TjMax)")
        $lines.Add("coretemp_cpu_speed_mhz{cpu=`"$cpu`"} " + ([double]$d.Speed).ToString("0", $inv))
    } catch {
        $lines.Add("# Core Temp not running or shared memory unavailable: $($_.Exception.Message)")
    }
    $tmp = "$out.tmp"
    Set-Content -Path $tmp -Value $lines -Encoding ASCII
    Move-Item -Path $tmp -Destination $out -Force
    if ($args -contains "-once") { break }
    Start-Sleep -Seconds 10
}
