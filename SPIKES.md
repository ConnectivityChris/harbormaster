# Future-work spikes

Items that need a real bench test before being implemented. Each entry should
be runnable in isolation against a real project. Delete an entry once it lands
or is confirmed not worth pursuing.

## Parallel iOS + Android execution via Maestro device sharding

**Goal.** When `--platform both`, run iOS and Android in parallel rather than
sequentially. Today `scripts/run-flows.sh:99-106` runs each platform in turn,
making wall-time = `t_iOS + t_Android` instead of `max(t_iOS, t_Android)`.

**Approach to verify.**

```bash
maestro --device "$IOS_UDID,$ANDROID_SERIAL" test \
  --shard-split 2 \
  --output report.xml --format JUNIT \
  --debug-output ./out --flatten-debug-output \
  .maestro/
```

Per `maestro test --help`:
- `--device, --udid` accepts a comma-separated list.
- `--shard-split N` distributes flows across `N` connected devices.
- `--shard-all N` runs every flow on every device.

**Open questions to answer in the spike.**

1. Does Maestro segment its `--debug-output` per-device, or does it co-mingle
   screenshots/recordings/logs from both devices into one directory? If
   co-mingled, can `--flatten-debug-output` be safely combined with multi-device
   runs, or do we need separate output dirs per device?
2. JUnit `report.xml` — single file with both devices, or one per device? If
   single, are test cases tagged with device id so a CI consumer can tell
   which platform a failure came from?
3. What happens if one device disconnects mid-run — does the surviving device
   complete its shard, or does the whole invocation fail?
4. Are there flow-author footguns? E.g. `clearKeychain` is iOS-only — does it
   silently no-op on Android, or fail the flow when sharded onto an Android
   device?

**Decision criterion.** If wall-time improves by >30% on the validation project
(Expo SDK 55 + iOS 26.2 + Android API 33) and per-device artifacts are
recoverable from the output directory, ship it. Otherwise document why not and
keep the sequential implementation.

**Files that will change if it lands.** `scripts/run-flows.sh` (replace the
`run_one` per-platform invocation with a single sharded invocation when both
devices are present), `references/troubleshooting.md` (artifact paths if they
move).
