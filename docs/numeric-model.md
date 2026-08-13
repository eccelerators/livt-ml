# Numeric model

## Signed int8 tensors

Livt represents signed-int8 weights and activations as `int` values constrained
by the component contract to `[-128, 127]`. This keeps arithmetic signed and
explicit while the current language does not expose a dedicated signed 8-bit
primitive type.

Quantized real values follow:

```text
real = scale * (quantized - zeroPoint)
```

Reference, RAM-backed, and streaming quantized operators accept their required
zero points explicitly. The first MNIST convolution layers configure zero point
`0`, while its dense output configures `112`. Model-specific values belong in
the generated application rather than in the library implementation.

## Accumulators and biases

`Int8Linear4x8` and `Int8Linear8x3` calculate:

```text
accumulator[row] = bias[row] + sum(input[column] * weight[row,column])
```

Inputs and weights are signed-int8-range values. Biases and outputs use Livt
signed 32-bit `int` semantics. The layers do not saturate to int8 and do not
hide a scale conversion. A bias must already use the product scale
`inputScale * weightScale`.

## Requantization

`RequantizeInt8.Apply(value, divisor, outputZeroPoint)` performs:

1. divide the magnitude by a positive integer divisor;
2. round to nearest, with exact ties going to the even integer;
3. restore the sign;
4. add `outputZeroPoint`;
5. saturate to `[-128, 127]`.

A non-positive divisor returns the saturated output zero point. The readable
reference implementation accepts a variable divisor and may infer expensive
divider hardware. Optimized constant-divisor variants may be added separately
but must produce identical results.

## Unsigned ONNX activations

The CNN reference operators represent ONNX uint8 tensor values as Livt `int`
values constrained to `[0, 255]`. `RequantizeUInt8.ApplyRational` computes:

```text
round_ties_even(value * multiplier / divisor) + outputZeroPoint
```

and saturates to `[0, 255]`. It splits the input into quotient and remainder
before multiplication, avoiding overflow when the documented positive
`multiplier * divisor` product fits in a signed 32-bit Livt `int`. Model
importers approximate ONNX floating-point scale ratios with bounded rational
values and must verify the resulting tensors against their source runtime.

The quantized convolution and dense components keep signed int32 accumulators
and invoke this helper only at quantized tensor boundaries.

`QLinearMatMul256x10`, its RAM-backed variant, and its streaming variant apply
the same centered multiplication contract as quantized convolution:

```text
accumulator[column] +=
    (input[row] - inputZeroPoint)
    * (weight[column,row] - weightZeroPoint[column])
```

Their column configuration supplies weight and output zero points used during
accumulation and requantization. The activation zero point is scalar in the
ONNX contract; streaming configuration records therefore repeat it for every
column.
