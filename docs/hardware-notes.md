# Hardware Notes

`Livt.ML` currently favors simple, explicit integer implementations that are
easy to test in generated VHDL. Some components are useful references but may
need FPGA-oriented optimization before they are used in a timing-critical path.

## Variable-Divider Warnings

The compiler reports variable-divider warnings for:

- `Livt.ML.Norm.RMSNorm`
- `Livt.ML.Activation.SoftmaxApprox`
- `Livt.ML.Model.LinearRegression`
- `Livt.Math.SqrtNewtonRaphson`, through the `Livt.Math` dependency

These warnings are expected for the current implementations. They mean the
generated hardware may include data-dependent divider circuits that can be
expensive or slow. They are hardware-cost caveats, not compiler bugs.

## Suggested Future Optimizations

- replace divisions by constants with shifts or reciprocal multiplies when the
  scale allows it
- add fixed-point helper components in `Livt.Math`
- consider LUT or piecewise approximations for expensive nonlinear operations
- keep reference components and hardware-optimized components separate when the
  public behavior is useful but the implementation tradeoff differs

## Embedding Initialization

`FixedTokenEmbedding` supports a mutable table through `SetValue(...)`. It is
tested directly. Earlier integration experiments showed that constructor-driven
repeated child mutation can be fragile in generated VHDL, so larger table
initialization flows should prefer explicit setup functions until a robust
weight-loading pattern is established.

## Stateful Test Components

Livt test component instances keep their field state across test methods. Tests
for configurable components should reset weights or state explicitly at the
start of each test. `FeedForwardBlockTest` uses `ClearWeights()` for this
reason.

## Same-Function Array Staging

Avoid writing an intermediate array and reading it again later in the same
component function when the value is needed by generated VHDL immediately. The
first `FeedForwardBlock` version staged hidden activations in a local array and
then consumed that array for output projection. Simulation showed stale values
for later rows.

The current FFN implementation streams each hidden activation directly into the
output accumulation. That shape avoids the read-after-update hazard and maps
well to fixed-size hardware.
