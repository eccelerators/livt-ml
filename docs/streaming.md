# Streaming Inference Components

The streaming components are optimized alternatives to the readable
configure/compute/get reference components. They preserve the same tensor order
and numeric result but avoid passing whole tensors through public functions.

## Toggle handshake

Each channel has `request`, `acknowledge`, and payload signals:

1. The producer waits until `request == acknowledge`.
2. It places a stable payload and toggles `request`.
3. The consumer samples the payload and copies the new request value to
   `acknowledge`.
4. Neither side reuses the channel until request and acknowledge match again.

Unlike a one-cycle valid pulse, this remains correct when Livt constructor-port
accessors add latency. Output payload and `last` remain stable while the
consumer applies backpressure.

## Components

`QConv2DStreamBase` is the reusable numeric layer for specialized convolution
streams. It applies the ONNX-style `(activation - inputZeroPoint) * (weight -
weightZeroPoint)` MAC contract. Shape, storage, parallelism, and framing remain
explicit in the specialized component.

`QConv2D1x8Kernel5Image28Stream` and
`QConv2D8x16Kernel5Image14Stream` are ready-to-use high-throughput examples.
Both load signed-byte weights and per-output-channel bias, rational scale, and
zero-point records through toggle handshakes. They retain one compact input
frame, evaluate one specialized output accumulator combinationally, and stream
outputs in flattened NCHW order. They do not store a complete output tensor.
Their parallel accumulator is a deliberate speed/area choice; a project can
reuse `QConv2DStreamBase` to build a resource-shared schedule with the same
numeric behavior.

`MaxPool8x28To14Stream` consumes 6,272 uint8 values in flattened NCHW order and
emits 1,568 values. It stores one 28-byte line buffer.

`MaxPool16x14To4Stream` consumes 3,136 uint8 values and emits 256. ONNX floor
sizing means the final two rows and columns do not contribute. Consequently,
the last output is emitted before the final ignored inputs have been accepted.

`QLinearMatMul256x10Stream` has three toggle-handshake inputs:

- 2,560 weights, loaded output-column-major as signed two's-complement
  `logic[8]` values;
- ten `(multiplier, divisor, inputZeroPoint, weightZeroPoint, outputZeroPoint)`
  quantization records in output-column order;
- one frame of 256 uint8 activations.

`configured` becomes high after both configuration streams are complete. The
engine centers each activation and weight with the corresponding quantization
record, updates ten int32 accumulators in parallel for every activation, then
emits ten `(outputData, outputAccumulator)` results. `frameError` reports an
early or missing activation `last` marker. Configuration is intended to be
loaded once before inference; instantiate a fresh component to replace it.
ONNX `QLinearMatMul` uses one activation zero point, so every column record must
repeat the same `inputZeroPoint`; weight and output zero points may vary by
column.

These concrete shapes deliberately match the imported MNIST graph. A later
model should add or generate another fixed shape rather than introducing a
dynamic tensor protocol.

The package therefore exposes two useful levels: small reusable numeric and
handshake building blocks, plus named specialized shapes that developers can
instantiate directly or study when creating a different specialization.

`Int8Mac8` is the corresponding context-free building block for transformer
and projection datapaths whose memory interface supplies eight signed weights
at once. It contains no tensor storage or handshake policy, so a specialized
component can combine it with registers, Livt.IO RAM, or external memory.

`Int8BroadcastMac64x8` and `Int8Dot64x8` are portable, scheduled engines for a
common transformer width. Both infer eight signed 16-by-8 multipliers and
register their products. The broadcast engine applies one activation to a
packed row of 64 weights and updates eight of its 64 int32 accumulators per
cycle. The dot engine consumes a packed 64-weight row in eight groups and uses
a balanced registered-product reduction. The wrappers use the same toggle
request/acknowledge discipline internally, while presenting `Reset`,
`AccumulateRow`/`Compute`, and indexed result functions to Livt callers.

Their fixed lane count is intentional: it bounds DSP use and combinational
depth while allowing an external-memory design to prefetch the next 64-byte
row during the eight-cycle MAC window. Activations are narrowed explicitly to
signed 16-bit at the primitive boundary; callers must keep them in range.

## Choosing an implementation

Use the existing tensor components for readable operator tests and exact
reference behavior. Use the `Stream` variants in model datapaths where
simulation footprint, bounded storage, and backpressure matter. Model
generators should keep weights in compact eight-bit form and drive the loader
from generated initialization logic or a memory wrapper.
