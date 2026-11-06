# Block attention accumulation

`Livt.ML.Attention.AttentionAccumulator32<PRODUCT_STAGES=1>` owns one
`Livt.Math.Arithmetic.CheckedBlockMac32<32,32,64,PRODUCT_STAGES>` worker. Serialize
all calls. Inputs are pairs of little-endian 512-bit blocks, each containing
sixteen signed int32 lanes. PRODUCT_STAGES can be 1 or 2.

1. `LoadQuery(low, high)` loads all 32 Q values. Until it succeeds, Score fails.
2. `Score(keyLow, keyHigh)` returns the exact Q.K sum. Bit 64 indicates failure;
   low 64 bits contain a sign-extended integer result, or zero on failure.
3. `ClearValues()` clears weighted sums for a new query/head.
4. `Accumulate(probability, valueLow, valueHigh)` adds one token's weighted V.
5. `Read(index)` returns a numerator and error bit for index 0..31.

No softmax, division, normalization, scale adjustment, truncation or saturation
is applied. The caller checks status before using any result and keeps its
existing fixed-point operator boundaries. Check each int64 addition for overflow
in original order, including the prefix between the two score blocks. Failed
weighted updates poison the whole bank until ClearValues or hardware reset.
Hardware reset also invalidates the query and cancels pending work.

Storage is bounded: one 32-element query and 32 wide sums, plus one row and the
pipeline. External memory remains the caller's responsibility. This first
specialization requires exactly 32 elements; it does not silently pad or
truncate other shapes. Existing INT8/16-bit kernels remain unchanged.

The native worker uses a completion toggle, retaining result/status until the
next command completes. See the [Math contract](../../livt-math/docs/CheckedBlockMac.md)
for transaction, input-width, overflow and reset details. `Livt.ML 1.5.0` pins
`Livt.Math 1.7.0`, which provides this primitive. Install or publish that Math
version before synchronizing the ML dependencies.

## Live-row interface

`AttentionAccumulator32Port<PRODUCT_STAGES=1>` exposes a `values` input port
for one 512-bit row. It owns the same `CheckedBlockMacPrimitive` arithmetic
core; only the control wrapper differs. This avoids storing a full row in every
scheduled argument frame. It is useful when the producer already retains its
DDR result or query row. The existing paired-row API remains available.

The producer must hold all 512 bits stable from before a method call until the
method returns. Only one caller may operate the component or replace its input.
There is no asynchronous queue or overlap guarantee. Reset cancels work, clears
weighted sums and invalidates the query; both producer and consumer must reset
in the same clock domain.

1. Drive each Q row and call `LoadQueryBlock(0)`, then `(1)`. Partial or invalid
   loads prevent scoring.
2. Drive each K row and call `ScoreBlock(0)`, then `(1)`. The first returns a
   checked partial sum; only the second is the full score. Check bit 64 on both.
3. Call `ClearValues()` once per head/query.
4. Drive each V row and call `AccumulateBlock(0, probability)`, then
   `AccumulateBlock(1, probability)`. A changed probability, invalid order or
   arithmetic failure poisons updates and reads until clear/reset.
5. `Read(0..31)` returns each numerator. Reads during a partial pair fail.

No arithmetic boundary changes: the caller still performs score scaling,
softmax and denominator division. `ScoreBlock(1)` without a successful block 0
fails instead of exposing an old score. A new query load invalidates partial
score state.

The live-row adapter waits for private completion without returning a 65-bit
payload through that private dispatcher. Public methods read the retained
primitive result before returning; the single caller cannot start the next
transaction until that return. Public results and ordering/poison checks are
unchanged.
