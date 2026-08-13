# Hardware Notes

`Livt.ML` currently favors simple, explicit integer implementations that are
easy to test in generated VHDL. Some components are useful references but may
need FPGA-oriented optimization before they are used in a timing-critical path.

## Variable-Divider Warnings

The compiler reports variable-divider warnings for:

- `Livt.ML.Numeric.RequantizeInt8`, because the readable reference API accepts
  a runtime divisor
- the QLinear CNN reference operators, because imported rational scales retain
  a runtime divisor per output channel
- `Livt.ML.Norm.RMSNorm`
- `Livt.ML.Activation.SoftmaxApprox`
- `Livt.ML.Model.LinearRegression`
- `Livt.Math.SqrtNewtonRaphson`, through the `Livt.Math` dependency

These warnings are expected for the current implementations. They mean the
generated hardware may include data-dependent divider circuits that can be
expensive or slow. They are hardware-cost caveats, not compiler bugs.

The first ONNX example calls `RequantizeInt8` with the constant divisor `10`.
A future optimized variant can specialize the divisor or use a precomputed
multiplier without changing the documented ties-to-even result.

The fixed MNIST operators use model-independent parameter storage, explicit
nested-loop scheduling, and bounded rational requantization. They are
vendor-neutral reference implementations. Optimized variants may infer ROM or
block RAM, share a chosen number of MAC lanes, and specialize the imported
divisors while preserving identical public tensor results.

## Reference and Streaming Variants

The tensor APIs remain the conformance reference. Livt public functions that
mutate large arrays currently generate function shadow signals, so these APIs
are intentionally not the preferred model-level datapath.

The first optimized vertical slice adds toggle-handshake `Stream` variants for
both MNIST pools and its 256-by-10 dense tail. A GHDL run of the two full-shape
streaming pool tests reports 1,921 simple signals and about 4 MB maximum RSS.
The earlier combined reference CNN-operator test reports 988,060 simple signals
and about 360 MB maximum RSS. The streaming dense conformance test, including
2,560 compact weights and its test harness, reports 45,281 simple signals and
about 20 MB maximum RSS. Treat these as local GHDL measurements, not synthesis
resource estimates.

The current dense stream performs ten MACs per accepted activation. Its loader
is a portable initialization mechanism, not a promise that every synthesizer
will infer a particular RAM primitive. A future external-memory engine can use
the same activation/output framing while making latency and lane count explicit.

The specialized convolution streams evaluate 25 or 200 MAC terms as a
context-free combinational accumulator for each output. This makes complete
GHDL inference practical, but it is a high-throughput/high-area choice rather
than a universal implementation. `QConv2DStreamBase` is intentionally separate
so projects can implement one-MAC or multi-lane schedules without changing
zero-point arithmetic. The generated full MNIST stream uses 155,531 simple
signals and about 62 MB RSS; its instrumented golden run completes in roughly
230 seconds, where the RAM reference exceeded ten minutes.

## RAM-Backed Reference Variants

The `Ram` variants preserve the software-like configure, compute, and getter
lifecycle while storing large byte tensors in `Livt.IO.Ram`. Livt.IO remains
the owner of the opaque RAM primitive and registered-read timing; Livt.ML owns
logical tensor length, banking, and ML operator schedules.

`ByteTensorRam2048`, `ByteTensorRam4096`, and `ByteTensorRam8192` provide one,
two, or four physical banks with a caller-selected logical byte length. Invalid
writes are ignored and invalid reads return zero. Signed int8 weights retain
their two's-complement bits in byte RAM and are converted to signed `int` only
at the multiplication boundary.

This design reduces whole-array function shadows but serializes accesses
through registered single-port RAM and scheduled wrapper calls. It is primarily
a lower-memory reference option, not the throughput implementation. Use the
streaming variants where GHDL wall time and hardware throughput are priorities.

The RAM convolution references copy each persistent input tensor once and each
output-channel kernel once into a compact function-local arithmetic working
set. This avoids invoking a registered RAM accessor in every inner MAC loop;
`ByteTensorRamTest.MaterializesArithmeticWorkingSet` protects the generated
VHDL behavior of that boundary. The copy is an explicit compute-phase cache,
not a second persistent tensor API.

For the generated MNIST classifier, RAM storage reduces GHDL elaboration from
2,532,800 to 504,969 simple signals and maximum RSS from about 923 MB to 200 MB.
The complete sequential CNN still exceeds ten minutes in GHDL, whereas the
full-shape streaming pooling fixture takes about 8.9 seconds. Consequently the
RAM variants should be selected for reference-style usability under memory
pressure; streaming variants should be selected for throughput.

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
