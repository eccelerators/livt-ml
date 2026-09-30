# Integer division policy

Scheduled library code uses `Livt.Math.Arithmetic.IntegerDivision<BITS>` or
`UnsignedDivision<BITS>` for runtime integer division and remainder. Both
implement `IIntegerDivision<T>`. A reusable consumer can borrow a constrained
worker type and instance; serialize calls and result observations.

Use `Compute` once followed by `GetQuotient` and `GetRemainder` when both are
needed. `Divide` truncates toward zero, `Remainder` follows the dividend's sign,
and `ModuloEuclidean` explicitly requests a nonnegative residue. Unsigned calls
use `uint` operands, with explicit casts for signed variables and large constants.
Zero divisors, out-of-range operands, and signed minimum divided by -1 fail with
zero results. `Compute` returns success; convenience methods expose failure via
`Failed`. Do not substitute these operations for nearest-even fixed-point division.

The math package's `docs/IntegerDivision.md` defines the full ownership, reset,
error, and latency contract. Adding a scheduled call changes latency, even when
numeric results are identical. Existing callers must wait for completion.

## Implemented integration

- `QuantizedTensorWeights.Select` checks positive dimensions with a scheduled
  31-bit unsigned divider before multiplying them. It preserves the overflow
  rejection, dimension clearing, and successful-selection recovery behavior.
- `FixedTransformerKernels.Attention` and `CachedAttention` use a shared scheduled
  worker for the head/width bound after validating width.
- `ProjectArgMax` needs no product-overflow check when MAX_WIDTH <= 32767:
  65536 * 32767 <= INT_MAX. Larger generic widths retain a scheduled guard.

- `RequantizeInt8` shares quotient/remainder computation while retaining its
  nearest-even rounding and saturation logic.
- `ScheduledRequantizeUInt8` is the supported completion-based UInt8 API. All nine ML convolution/matmul consumers now own this
  worker, including the RAM and toggle-stream variants.
- `RMSNorm`, `SoftmaxApprox`, and `LinearRegression` use scheduled division.
  Regression also schedules its non-power-of-two scale conversion.
- `LayerNorm64Stream` waits for the divider within its compute phase. Input
  acceptance remains stalled during computation; output payloads stay held until
  acknowledgment. Processing latency increases; no cycle-rate guarantee is added.
- `ScaledDotProductAttention` schedules its division by the score scale of three.
- Tensor storage and quantized matrices schedule non-power-of-two `GROUP_SIZE`
  indexing. Power-of-two groups retain constant arithmetic; shape-only constant
  expressions remain compile-time operations.

## Deliberate remaining operators

| Area | Disposition |
| --- | --- |
| Fixed-point power-of-two scaling | Retained to preserve signed truncation; a plain arithmetic shift is not equivalent for negative values |
| `KVCache` | Capacity is a fixed four, so wrapping remains constant modulo |
| Packed byte/nibble addressing | Nonnegative constant division/remainder by two or four retained |
| Shape assertions and constant group counts | Compile-time expressions retained |

Requantization retains its existing supported intermediate-overflow domain; this
migration does not introduce widened or saturating intermediate arithmetic.
The former static `RequantizeUInt8` API has been removed. External callers must
construct `ScheduledRequantizeUInt8` and invoke its instance methods, waiting for
completion and serializing access. This is an intentional source-breaking change.

The debug manifest no longer suppresses `variable-divisor` globally. Review those
diagnostics instead of assuming all divisions are cheap.
Base-library consistency is an API and review rule, not a mechanical replacement
of every `/` or `%`. Livt.Base cannot depend on Livt.Math because Math already
depends on Base; bit helpers and foundational formatting need equivalent bounded
algorithms or a separate higher-level scheduled service.

## Development validation

The new Math API must be available before building this ML change with registry
dependencies. No packages have been published by this work. Validation uses an
isolated copy of this project with the Math dependency changed to:

```toml
"Livt.Math" = { path = "/home/vagrant/git/livt/livt-math" }
```

The committed manifest retains its registry dependency. Publish the corresponding
Math changes before publishing/consuming this ML update, or use a local dependency
in a development copy. `QuantizedTensorShapeTest` exercises both sides of signed
int32 product overflow without allocating large model storage.

The initial shape-guard migration is recorded in the
[earlier validation record](evidence/integer-division/README.md). The wider
[migration audit](arithmetic-migration.md) records this follow-up. Full-model
synthesis and routed timing have not been rerun.
