# Changelog

All notable changes to this package are documented here.

## 1.6.0 - 2026-11-07

### Added

- `Linear.Int8MatrixAccumulator32<ACTIVATION_BITS, PRODUCT_STAGES>` for
  64-column INT8 matrix chunks with signed int32 activations and up to 1,024
  retained BRAM-backed int64 sums. Supports bias seeding and checked updates.
- `Linear.Int8MatrixAccumulator32Stream` for ordered ready/valid row batches
  over the same native core. Eight multiply lanes overlap row feeding,
  reduction and BRAM commits without a second 512-bit weight-row buffer.
- Checked activation ranges from 2 to 32 bits and one- or two-stage product
  pipelines with identical arithmetic. Overflow and source failures invalidate
  retained sums until explicit recovery.
- Public Livt regressions and a matrix contract documenting packing, ownership,
  acceptance, completion, cancellation, reset and failure recovery.

### Compatibility

- Existing APIs and defaults are unchanged. Dependencies remain
  `Livt.Math 1.7.0` and `Livt.IO 1.3.0`.
- Serialize scheduled calls. A successful batch returns only after every row
  has committed. The producer must retain each valid row until its transfer
  edge and report unavailable sources through `streamError`; there is no
  implicit timeout.
- The native core uses synchronous active-high reset. Reset producer and
  consumer together across a rising clock edge, then call `Begin` before use.
  RAM payload is not reset. Model layout, memory transport, scaling and
  rounding remain caller responsibilities.

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
  generated-wrapper regression for the paired-row API.

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

## Earlier releases

Earlier release history remains available in Git; the preceding tagged version
is `1.4.1`.
