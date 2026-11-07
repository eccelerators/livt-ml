# Checked INT8 matrix accumulation

`Livt.ML.Linear.Int8MatrixAccumulator32<ACTIVATION_BITS = 32, PRODUCT_STAGES = 1>`
is available in 1.6.0. It computes matrix–vector products in
64-column chunks while retaining up to 1,024 signed int64 output sums.
Existing `Int8Dot64x8` and `Int8BroadcastMac64x8` APIs remain unchanged.

## Numeric and shape contract

- Activations are signed int32. `ACTIVATION_BITS` selects a checked signed range
  from 2 to 32 bits; out-of-range values fail rather than truncate.
- Weights are signed INT8. A weight row occupies 512 bits: lane zero is bits 7..0.
- An activation block contains sixteen signed int32 lanes: lane zero is bits
  31..0. Blocks 0 through 3 form the 64 activations reused across output rows.
- The exact 64-product dot sum fits in 46 signed bits for every permitted input.
  The worker then checks its addition to the retained int64 row sum. Overflow
  is checked **at each 64-column update boundary**, not against a seeded sum
  after every scalar product. This matches an exact block-dot-plus-checked-add
  workflow. No narrowing, scaling, rounding, saturation or bias conversion occurs.
- `PRODUCT_STAGES` is 1 or 2. Both produce identical results and failures. Two
  stages split the product into low/high partial products and a registered join.
- `Begin(rows)` selects 1..1,024 output rows. Column count is any sequence of
  64-column chunks. For a final short chunk, the caller must zero-pad unused
  activation and weight lanes; no automatic padding or shape inference occurs.

The physical bank has 1,024 int64 cells regardless of the selected row count.
A smaller row count reduces initialization work, not the bank's declared
capacity. The initial implementation uses eight physical 32x8 multiplier lanes;
smaller activation ranges do not promise proportional DSP savings.

## Scheduled interface

| Operation | Contract |
|---|---|
| `Begin(rows) -> bool` | Zero the selected sums, clear failure, invalidate all activation blocks. An invalid count invalidates the bank. Completion includes the last RAM write. |
| `LoadActivations(block) -> bool` | Load block 0..3 from `values`. All lanes must fit the configured range. Rejected data invalidates that block; an invalid index invalidates all blocks. Does not clear prior sums. |
| `Accumulate(row) -> bool` | Add the exact dot product of the loaded activations and current INT8 `values` row to sum `row`. Requires an initialized bank and all four valid activation blocks. |
| `Read(row) -> logic[65]` | Bit 64 indicates failure; bits 63..0 hold the signed int64 bit pattern. Failed payloads are zero. Invalid reads do not poison an otherwise valid bank. |
| `Seed(row, value) -> bool` | Replace one sum with a caller-supplied int64 bias. The caller owns its scale. Invalid writes poison the bank. |

Failed accumulation, including an invalid row or missing activation block,
poisons the entire sum bank. Further updates, seeds and reads fail until a
successful `Begin` or hardware reset. A later opposite-signed update cannot
hide a previous overflow. Hardware reset invalidates the bank, so `Begin` is
still required afterward. Activation loads alone cannot recover a poisoned bank.

For each matrix operation:

1. Call `Begin(outputRows)` and optionally seed biases.
2. For each 64-column chunk, load all four activation blocks.
3. For each output row, supply its packed 64 weights and call `Accumulate(row)`.
4. Read the sums and apply the model's scaling/rounding in the caller.

Check every returned status before using results. See the executable
[Livt tests](../tests/linear/Int8MatrixAccumulator32Test.lvt) for examples.

## Ownership and timing

One caller owns the component and serializes all operations. `values` is a live
input port shared between activation loads and weight rows. Hold all 512 bits
stable from before the corresponding method call until it returns. A producer
that already retains a DDR or RAM row can connect that row directly; otherwise
provide an owned staging register. There is no input FIFO, early acceptance or
promise of overlap between commands.

The native `Int8MatrixAccumulator32Primitive` uses request/acknowledge toggles.
Configuration ports are constant for the instance. Hold operation, index,
values and seed stable until acknowledgment matches request. `busy` observes
internal work, but it is not a ready/valid acceptance signal. Inspect result
only at completion; it remains available while idle. Reset both producer and
consumer in the same clock domain. The native core uses synchronous active-high
reset, independent of the application default reset style; assert reset across
a rising edge in both producer and consumer. Reset cancels outstanding work, clears
acknowledgment and invalidates activations and sum-bank access. No stale
pre-reset completion is returned.

The sum bank uses a synchronous read and a registered write port with block-RAM
inference. Payload cells are not reset. `Begin` explicitly initializes the
accessible rows, and write completion precedes acknowledgment so immediate
reads are well defined. Wait for completion instead of assuming a fixed latency.

DDR requests, prefetch policy, matrix layout, tensor catalogs and model-specific
addresses remain outside the kernel. Activation packing, data transport,
initialization, scheduled call overhead and final scaling must all be included
when measuring an application speedup. Kernel timing is not full-board timing.

## Validation

The public regression is written in Livt:

```sh
livt test --run Int8MatrixAccumulator32Test
```

It covers both product settings, signed limits, sparse lane/block ordering,
192/768-column accumulation, immediate reads, capacity boundaries, overflow,
poison recovery and range rejection. Existing 16-bit kernel tests remain intact.

## Streaming batches

`Int8MatrixAccumulator32Stream<ACTIVATION_BITS, PRODUCT_STAGES>` owns the same
native core, with the same numeric contracts and existing scheduled methods.
It adds `AccumulateRows(first, count)`: add one 64-column update to consecutive
rows `first..first+count-1`, in order. The range must be nonempty and entirely
inside the active bank. All four activation blocks must already be valid.
Invalid spans, missing activation blocks, source errors and accumulator overflow
poison the bank; `Begin` or hardware reset is required to recover.

- `values` remains the shared live 512-bit activation/weight input. During a
  batch the producer drives packed INT8 weights and `valid`. It must assert
  valid independently of ready and retain valid/data until a rising edge with
  both valid and `ready` high. Gaps are allowed between rows. The producer must
  stop after exactly `count` transfers and must not withdraw an offered row.
- This retained-row receiver inspects the row during eight feeding cycles and
  asserts ready for the final group. Acceptance therefore releases the producer's
  storage; it is not an early FIFO enqueue. There is no duplicate weight buffer.
- Feed, reduction and checked BRAM commit overlap across ordered rows. The
  receiver assigns row identifiers from the requested span; rows cannot reorder
  or target the same sum twice inside one batch. Full dots use exact 46-bit sums;
  every update checks the final int64 addition before committing.
- `AccumulateRows` blocks until all accepted rows have committed, or returns false
  on failure. Successful immediate reads are valid. Configuration/command inputs
  stay stable until completion; weight data follows the handshake instead.
- `streamError` cancels an active batch, suppresses further input acceptance and
  poisons sums. `failed` tells the producer to stop. Earlier writes may remain,
  but no poisoned sum is accessible. There is no implicit stream timeout; a
  producer/owner with bounded availability must assert streamError on timeout.
- Reset both producer and consumer in the same clock domain. Reset cancels
  pending commands and invalidates sums/activation loads. No stale completion
  or ready transfer can occur during reset.
- Between batches, deassert valid and serialize reads, seeds and activation
  loads. Data for scheduled activation/individual accumulation calls retains
  the original hold-until-return contract.

The eight-lane datapath is unchanged. Wider lane counts and fused scaling are
separate measured decisions, not implied by a streaming interface. Existing
blocking users need no source changes; unused stream ports are tied inactive.

### Stream validation

Run the additive public regression with:

```sh
livt test --run Int8MatrixAccumulator32StreamTest
```

The public stream tests cover ordered batches, immediate reads, repeated
updates, invalid spans, source cancellation, overflow and recovery. They use
an independent clocked producer that retains each row until acceptance.
The blocking tests cover both product-stage settings and checked activation
ranges; existing dot/broadcast regressions remain registered in `livt.toml`.

The stream `busy` output includes producer waits during a batch. It reports
operation lifetime, not arithmetic utilization.
