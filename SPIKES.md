# Future-work spikes

Items that need a real bench test before being implemented. Each entry should
be runnable in isolation against a real project. Delete an entry once it lands
or is confirmed not worth pursuing.

## Parallel iOS + Android execution via Maestro device sharding — PARKED (2026-04-30)

**Status.** Evaluated, not pursued. The sequential implementation in
`scripts/run-flows.sh` (independent execution per platform with union exit
code) is sufficient for the plugin's job: enable `--platform both`, surface
per-platform pass/fail, leave flow-portability concerns to the flow author.

**Bench numbers** (Expo dev-build project, 2 flows, iPhone 17 Pro + Pixel 8 Pro):

| Mode | Wall time | Notes |
|---|---|---|
| Sequential (`run-flows.sh --platform both`) | 176 s | Each platform runs in turn, independent exit codes |
| Sharded (`maestro --device "$IOS,$ANDROID" test --shard-split 2`) | 104 s | 40 % improvement; bar was 30 % |

**Why parked despite hitting the bar.** The 72-second saving applies only to
the `--platform both` path, which is the rarer mode (most authoring is
single-platform; cross-platform is a pre-release smoke). No user has reported
sequential as a pain point. Implementing it would require a second code path
in `run-flows.sh` (sharded artifacts use a co-mingled directory with shard-
suffixed filenames rather than the current per-platform sub-dirs), plus an
"Expo Go is incompatible with sharding" caveat in docs, plus the round-robin-
flow-routing footgun discussed below. Maintenance surface > value at current
usage. Revisit if `--platform both` becomes a frequent CI bottleneck.

**Findings worth keeping** (regardless of whether sharding ever ships):

1. **Artifact recovery (Q1).** `--debug-output <dir> --flatten-debug-output` co-
   mingles files but uses consistent per-shard naming:
   `commands-shard-N-(<flow>).json`, `screenshot-shard-N-…-(<flow>).png`.
   `maestro.log` is a single file with `[shard N]` line prefixes. Splittable
   by filename pattern.
2. **JUnit (Q2).** Single `report.xml` with one `<testsuite device="…">`
   element per device — the `device=` attribute carries platform + UDID/AVD
   name. CI consumers can split per-platform on this attribute. `<failure>`
   text is `[shard N]` prefixed.
3. **Disconnect tolerance (Q3).** Not exercised. The sequential implementation
   is already disconnect-tolerant (one platform's failure doesn't abort the
   other); a sharded implementation that aborts the surviving device on a peer
   disconnect would be a regression.
4. **Footguns (Q4).**
   - **Expo Go is sharding-incompatible.** A single `--env APP_ID=…` value
     can't carry two divergent bundle IDs (iOS `host.exp.Exponent` vs Android
     `host.exp.exponent`). Hard launch failure on the wrong-platform shard.
   - **Dev builds shard cleanly** when `bundleId == package` (the common case
     for RN/Expo).
   - **Round-robin flow-to-shard routing**, not platform-aware. Maestro
     assigns flows to shards by index against the `--device "id1,id2"` list.
     A flow with platform-specific commands without `runFlow: when: platform:`
     gating will fail when routed onto the wrong platform. The cross-platform
     templates in `references/flow-examples/login.yaml` and patterns in
     `references/writing-flows.md` already encode this.
   - **Flow ordering can no longer be relied on for state setup.** Sequential
     mode lets users put `login.yaml` before `view-settings.yaml` and have
     logged-in state carry over. Sharded mode breaks this. Self-sufficient
     flows (their own `clearState` + gated `clearKeychain`) are required.

**Files that would change if revived.** `scripts/run-flows.sh` (sharded code
path when both devices booted), `references/troubleshooting.md` (artifact
layout doc), `references/writing-flows.md` (Expo Go incompatibility
footnote), `skills/harbormaster/SKILL.md` (run-flow step rewrite).
