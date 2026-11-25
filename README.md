# windows-hw-monitoring

CPU temperature, load and clock speed of a Windows host in Prometheus and Grafana, read from Core Temp.

## Data path

```
Core Temp (shared memory) -> coretemp-prom.ps1 -> windows_exporter textfile collector -> Prometheus -> Grafana
```

## Contents

- `coretemp-prom.ps1` reads the shared memory block every 10 s and replaces the textfile in one move (`-once` for a single sample)
- `grafana/windows-cpu-thermal.json` dashboard
- `stress.ps1` timed all-core load
- `compare.py` side-by-side statistics for load runs, queried from Prometheus

## Setup

1. Run Core Temp and install windows_exporter with the textfile collector enabled
2. Register `coretemp-prom.ps1` as a scheduled task at logon, elevated, in the interactive session
3. Scrape the exporter from Prometheus and import the dashboard
