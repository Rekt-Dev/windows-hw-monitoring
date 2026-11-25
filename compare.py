#!/usr/bin/env python3
"""Compare load runs recorded in Prometheus.

usage: compare.py http://PROMETHEUS:9090 "label=2026-01-31 12:00:00" ["label=..."]
"""
import json
import sys
import time
import urllib.parse
import urllib.request

METRICS = (
    ("avg CPU load %", "avg(coretemp_load_percent)", "mean"),
    ("avg temp C", "avg(coretemp_temperature_celsius)", "mean"),
    ("hottest core C", "max(coretemp_temperature_celsius)", "max"),
    ("min speed MHz", "max(coretemp_cpu_speed_mhz)", "min"),
    ("avg speed MHz", "max(coretemp_cpu_speed_mhz)", "mean"),
)
AGG = {"mean": lambda v: sum(v) / len(v), "max": max, "min": min}


def values(base, expr, start, end):
    query = urllib.parse.urlencode({"query": expr, "start": start, "end": end, "step": 15})
    with urllib.request.urlopen(f"{base}/api/v1/query_range?{query}", timeout=30) as resp:
        result = json.load(resp)["data"]["result"]
    return [float(v[1]) for s in result for v in s["values"] if v[1] != "NaN"]


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    base = sys.argv[1].rstrip("/")
    runs = [a.split("=", 1) for a in sys.argv[2:]]
    for title, first, last in (("whole 10 min", 10, 600), ("last 3 min (steady)", 420, 600)):
        print(title)
        print(" " * 20 + "".join(f"{label:>16}" for label, _ in runs))
        for name, expr, how in METRICS:
            row = ""
            for _, started in runs:
                t0 = time.mktime(time.strptime(started, "%Y-%m-%d %H:%M:%S"))
                data = values(base, expr, t0 + first, t0 + last)
                row += f"{AGG[how](data):16.1f}" if data else f"{'no data':>16}"
            print(f"  {name:<18}{row}")


if __name__ == "__main__":
    main()
