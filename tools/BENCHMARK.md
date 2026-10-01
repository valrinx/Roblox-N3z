# N3Z Shield v3 Benchmark

Benchmark date: 2026-10-02. The live Luau numbers below were measured through the connected Roblox client and should be treated as environment-specific.

## Reproduce

From `tools/`:

```powershell
python benchmark_shield.py --file n3z-dock.lua --source-ref b4559de --iterations 5 --emit-luau-dir ../dist/luau-bench
python benchmark_shield.py --file modules/warz_pvp.lua --source-ref b4559de --iterations 5 --emit-luau-dir ../dist/luau-bench-warz
```

The Python benchmark measures protected output size, build time, peak host allocation, and decoder round-trip speed. The emitted Luau benchmark measures decode time and payload compile time without executing the decoded payload.

## Live Luau results

| Payload | Profile | Input | Blocks | Rounds | Decode avg | Compile avg | Startup avg |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| n3z-dock.lua | performance | 38,702 B | 26 | 1 | 12.16 ms | 2.05 ms | 14.21 ms |
| n3z-dock.lua | max | 38,702 B | 61 | 3 | 25.99 ms | 2.70 ms | 28.70 ms |
| modules/warz_pvp.lua | performance | 66,112 B | 44 | 1 | 19.43 ms | 3.17 ms | 22.60 ms |
| modules/warz_pvp.lua | max | 66,112 B | 104 | 3 | 42.29 ms | 3.27 ms | 45.56 ms |

`max` is roughly 2x the measured startup cost while increasing output size by less than 1% versus `performance` for these samples.

## Profile policy

`auto` is now the default build mode. It uses a 28 KiB plaintext threshold plus file-role overrides:

- `init.lua`, `n3z.lua`, and `n3z-compat.lua` are always `max`.
- `n3z-dock.lua` is always `performance`.
- Files under `modules/` use `max` at or below 28 KiB and `performance` above it.
- Other files use the same size threshold.

The threshold can be changed with `--auto-threshold-kib N`. Explicit `--profile performance` or `--profile max` bypasses Auto completely.

With the current plaintext revision `b4559de`, Auto selects 5 files as `max` and 5 as `performance`. Every build records its final decisions in `shield-manifest.json`.

Use `performance` manually for large or frequently reloaded code where startup latency matters. Use `max` manually for small, high-value code that runs infrequently and where the extra startup cost is acceptable.

## Memory note

The Luau harness exposes `gcNetDeltaKb`, but Roblox garbage collection can run during the sample and make the net delta negative. Do not use that value as a peak-memory measurement. Host-side peak allocation from Python is stable enough for build-tool regression checks, while runtime memory should be profiled separately with a controlled client session.
