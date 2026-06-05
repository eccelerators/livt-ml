# Usage Examples

`Livt.ML` exposes fixed-size ML hardware components. These examples show common
call order and state handling. They are intentionally small and focus only on
the package components.

## Linear Projection

`Linear8x8` stores eight weight rows. Configure rows first, then call
`Compute(input)` and read elements with `GetOutput(index)`.

```livt
namespace Example

using Livt.ML.Linear

component LinearExample
{
	layer: Linear8x8

	new()
	{
		this.layer = new Linear8x8()
	}

	public fn Run(input: int[8])
	{
		this.layer.SetRowValues(0, 1, 0, 0, 0, 0, 0, 0, 0)
		this.layer.SetRowValues(1, 0, 1, 0, 0, 0, 0, 0, 0)
		this.layer.Compute(input)
		var first: int = this.layer.GetOutput(0)
		var second: int = this.layer.GetOutput(1)
	}
}
```

## Activation Functions

`ReLU` is stateless. Vector activation approximations store their result until
the next `Compute(...)` call.

```livt
namespace Example

using Livt.ML.Activation

component ActivationExample
{
	relu: ReLU
	silu: SiLUApprox

	new()
	{
		this.relu = new ReLU()
		this.silu = new SiLUApprox()
	}

	public fn Run()
	{
		var clipped: int = this.relu.Apply(-5)
		var input: int[8] = [-2, -1, 0, 1, 2, 3, 4, 5]

		this.silu.Compute(input)
		var approx: int = this.silu.GetOutput(4)
	}
}
```

## Embedding Table

`FixedTokenEmbedding` exposes a mutable `16 x 8` integer table. Write table
values first, then call `Embed(token)`.

```livt
namespace Example

using Livt.ML.Embedding

component EmbeddingExample
{
	embedding: FixedTokenEmbedding

	new()
	{
		this.embedding = new FixedTokenEmbedding()
	}

	public fn Run()
	{
		this.embedding.SetValue(2, 0, 128)
		this.embedding.SetValue(2, 1, 256)
		this.embedding.Embed(2)

		var first: int = this.embedding.GetOutput(0)
		var second: int = this.embedding.GetOutput(1)
	}
}
```

## Attention Cache

`ScaledDotProductAttention` owns a four-slot `KVCache`. Write key/value pairs,
compute with a query, and read the weighted output vector.

```livt
namespace Example

using Livt.ML.Attention

component AttentionExample
{
	attention: ScaledDotProductAttention

	new()
	{
		this.attention = new ScaledDotProductAttention()
	}

	public fn Run()
	{
		var key: int[8] = [1, 0, 0, 0, 0, 0, 0, 0]
		var value: int[8] = [10, 0, 0, 0, 0, 0, 0, 0]
		var query: int[8] = [1, 0, 0, 0, 0, 0, 0, 0]

		this.attention.ClearCache()
		this.attention.Write(key, value)
		this.attention.Compute(query)

		var first: int = this.attention.GetOutput(0)
	}
}
```

## Transformer Feed-Forward Block

`FeedForwardBlock` has separate hidden and output weight rows. Clear or set
weights explicitly when reusing the same component instance in tests.

```livt
namespace Example

using Livt.ML.Transformer

component FeedForwardExample
{
	ffn: FeedForwardBlock

	new()
	{
		this.ffn = new FeedForwardBlock()
	}

	public fn Run(input: int[8])
	{
		this.ffn.ClearWeights()
		this.ffn.SetHiddenRowValues(0, 1, 1, 0, 0, 0, 0, 0, 0)
		this.ffn.SetOutputRowValues(0, 3, 0, 0, 0, 0, 0, 0, 0)
		this.ffn.Compute(input)

		var projected: int = this.ffn.GetOutput(0)
	}
}
```

## Linear Regression

`LinearRegression` fits up to 32 samples. The slope is stored as `aFixed`, scaled
by `LinearRegression.SCALE`.

```livt
namespace Example

using Livt.ML.Model

component LinearRegressionExample
{
	model: LinearRegression

	new()
	{
		this.model = new LinearRegression()
	}

	public fn Run()
	{
		var x: int[32]
		var y: int[32]

		x[0] = 10
		x[1] = 20
		x[2] = 30
		y[0] = 15
		y[1] = 25
		y[2] = 35

		this.model.Fit(x, y, 3)
		var prediction: int = this.model.Predict(40)
		var slopeFixed: int = this.model.GetAFixed()
	}
}
```
