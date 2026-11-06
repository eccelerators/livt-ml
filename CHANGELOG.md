# Changelog

All notable changes to this package are documented here.

## 1.5.0 - 2026-11-06

### Added

- `Attention.AttentionAccumulator32<PRODUCT_STAGES>` for exact 32-element Q.K
  scores and retained probability-times-V numerators using the checked Math core.
- `Attention.AttentionAccumulator32Port<PRODUCT_STAGES>` for live 512-bit input
  rows, avoiding full-row copies through scheduled argument frames.
- Ordered block-pair validation, query invalidation, partial-score checks and
  poisoned weighted-sum recovery. Results carry the checked int64 sum and a
  failure flag together; reset cancels pending work.
- One- and two-stage product configurations with identical arithmetic, and a
  generated-wrapper regression for the paired-row API. The Metis integration
  also validates live-row ordering, failure recovery and numeric parity.

### Changed

- Update the `Livt.Math` dependency from `1.3.0` to `1.7.0` for the checked
  block arithmetic primitive. `Livt.IO` remains pinned to `1.3.0`.

### Compatibility

- Existing INT8/16-bit kernels and their defaults are unchanged. The new
  attention components require exactly 32 signed int32 values, supplied as
  two little-endian sixteen-lane blocks.
- Score scaling, softmax, final division, fixed-point rounding and external
  memory layout remain the caller's responsibility. Serialize operations;
  live-row inputs must remain stable until the scheduled call returns.

### Validation

- The Metis integration passes 1,854 exact attention comparisons and runs at
  100 MHz on the Arty A7-100T with routed setup/hold slack +0.103/+0.010 ns.
- The same integration passes 187 board checks, including 972 exact numeric
  values and 30 unchanged reference replies, plus 22 latency checks. These
  are integration results, not timing or throughput guarantees for other designs.

## Earlier releases

Earlier release history remains available in Git; the preceding tagged version
is `1.4.1`.
