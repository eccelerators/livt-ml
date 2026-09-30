# Base-library arithmetic audit — 2026-09-30

This pass reviewed production Livt sources in Base, Math, ML, IO, Collections,
and Utils. It targets unintended combinational division/remainder, rather than
removing arithmetic operators regardless of hardware cost. Changes are in
**livt-ml and livt-base**. The shared Math API was implemented in the preceding
change and is required by ML; Math was not changed again during this pass.

## Disposition

| Repository | Result |
| --- | --- |
| livt-ml | Scheduled variable division in normalization, softmax, regression, and requantization; scheduled non-power-of-two score/group scaling; nine convolution/matmul consumers use the new scheduled UInt8 API |
| livt-base | Bit helpers use shifts/masks and bounded rotation reduction; decimal formatting uses bounded scheduled digit extraction without a Math dependency |
| livt-math | Earlier shared API and consumer migrations retained; remaining source operators use constant power-of-two divisors |
| livt-io | Constant UART configuration arithmetic and SPI parity checks retained; no FIFO or UART redesign |
| livt-collections | No production source division/remainder found |
| livt-utils | No production source division/remainder found |

The [ML policy](integer-division.md) explains remaining operators. The former
static `RequantizeUInt8` API has now been removed; all callers must instantiate
`ScheduledRequantizeUInt8`, serialize access, and wait for completion. The
[Base migration record](../../livt-base/docs/arithmetic-migration.md) describes
its dependency-independent algorithms and formatter synthesis.

The [remaining-operator inventory](evidence/arithmetic-migration/remaining-operators.json)
records source locations after migration. It excludes comments and strings;
the historical snapshot includes compile-time arithmetic, power-of-two
scaling/addressing, and the static API subsequently removed. This is a source audit, not a
claim that every arithmetic path in every configuration meets timing.

## Behavioral contracts

Scheduled calls add latency and complete before their callers advance. Owned
workers are used serially. Streaming consumers remain in their computation
phase while waiting; output acknowledgment still controls payload replacement.
Nearest-even rounding, zero-point handling, and saturation algorithms are
preserved within their existing intermediate-overflow domain. No global
fixed-point width or rounding redesign is included.

The Base formatter now also accepts INT_MIN through unsigned magnitude handling.
Its public calls must be serialized because decimal workspace is shared.
No dependency cycles, package version changes, commits, or publications were
introduced. Publish the pending Math API before consuming ML through registry
dependencies; Base is an independently publishable update.

## Validation

The results below predate removal of the static compatibility API; retained
reports and source hashes describe those historical snapshots.

Tests use the installed Livt compiler and GHDL 4.1.0. ML validation uses isolated
project copies with a local Math dependency; IO/Base/Collections dependencies
remain their registry versions. Base is tested separately against its changed
source. There is no claim of a combined full-board build.

- Base: 272 tests passed, including full-width decimal and rotation boundaries.
- Full ML regression snapshot: 122 tests passed in 1081 seconds, including
  convolution/matmul RAM and streaming consumers. See [full results](evidence/arithmetic-migration/ml.xml).
- Final targeted ML checks: 12 passed, including signed rounding equivalence,
  stalled LayerNorm output payloads, attention, and non-power-of-two tensor groups.
- Matrix grouping integration: one passed, covering group crossings within and
  across rows, power-of-two specialization, and failure/recovery.

See [targeted ML results](evidence/arithmetic-migration/ml-final.xml),
[matrix grouping results](evidence/arithmetic-migration/grouping.xml), and
[final source hashes](evidence/arithmetic-migration/source-sha256.json).
The full run preceded the final group-indexing and score-scale changes. Those
changes and strengthened tests passed in the targeted runs: 125 unique ML test
cases passed across the three runs. The grouping fixture was added after the
targeted run and tested separately.
Final code differs from those snapshots only in comments/whitespace.

To reproduce, use a development copy with
`"Livt.Math" = { path = "/home/vagrant/git/livt/livt-math" }` in `livt.toml`,
then run `livt test`. The checked-in manifest retains its registry dependency.

## Focused requantizer synthesis

Vivado 2026.1 synthesized the complete exposed ScheduledRequantizeUInt8 interface
on xc7a100tcsg324-1 at 20 ns with four threads, a 20 GiB memory guard, and a
600-second limit (148 seconds actual). Result: **1,925 LUTs, 2,189 FFs, eight
DSPs, no BRAM, no latches; internal pre-route setup WNS +10.528 ns**.
The multipliers remain DSP-backed; this change schedules division, not every
arithmetic primitive. There is no before/after area-reduction claim.

See the [resource report](evidence/arithmetic-migration/requantize/utilization.rpt),
[timing report](evidence/arithmetic-migration/requantize/timing.rpt), and
[commands/input hashes](evidence/arithmetic-migration/requantize/result.json).
The retained Tcl and wrapper describe the complete public interface and require
relocating temporary paths to reproduce. Inputs were the generated worker's
11-file transitive package/entity closure. An earlier attempt included unrelated
test-specialized modules without their test packages and failed elaboration;
these reports are from the corrected run.

Only internal synthesis timing is measured. Boundary ports lack input/output
delays, no physical clock source was supplied, and no placement/routing or
full-model FPGA build was performed. The source snapshot preceded documentation
comments added to the worker; its executable code is unchanged.

## Static UInt8 API removal

The static class and its duplicate test fixture were deleted after the migration.
`ScheduledRequantizeUInt8` is now the sole supported UInt8 requantizer. The
cross-sign test uses an independent bounded subtraction oracle rather than the
removed API. All four focused tests passed with GHDL 4.1.0 (33.26 seconds), using
an isolated project containing the unchanged scheduled worker, its revised test,
and local Math dependency. See [results](evidence/uint8-api-removal/results.xml)
and [source hashes](evidence/uint8-api-removal/source-sha256.json).

No executable references to the removed type remain in `src/`, `tests/`, or the
manifest. The scheduled implementation and its nine library consumers are
unchanged, so the earlier synthesis and consumer regression evidence still
applies; the full suite was not repeated for removal of the unused API.
