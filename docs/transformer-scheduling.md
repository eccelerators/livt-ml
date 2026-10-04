# Transformer kernel scheduling

`FixedTransformerKernels` uses direct static helpers for `ValueValid`, `Shape`
and `Overlap`. They depend only on their arguments and generic constants, so
scheduled calls would add argument queues and arbitration without providing a
shared stateful service. Keep these helpers pure and bounded. Capture repeated
results into separate named locals before combining them: compiler #611 currently loses earlier direct
call results in compound conditions. The explicit captures are covered by signed
boundary, admission and numerical regressions.

`Span` remains scheduled because it calls the memory provider. `Round`, division,
square root and other wide arithmetic retain their scheduled workers. Converting
those operations to direct helpers would change the hardware cost and handshake
contract and requires separate analysis.

The public kernel operations remain serialized. Callers await completion and
keep input/model spans stable until then; they must not depend on exact cycle
counts. Direct checks can reduce latency without changing values, accepted spans,
overlap rules or failure publication. Shared scratch reset and ownership rules
remain documented in [transformer-scratch.md](transformer-scratch.md).

Tang TM-FLAN-007E measured the production specialization with identical compiler
and synthesis options: 3,331 fewer FF and 7,705 fewer LUT-plus-ALU cells, including
owned arithmetic helpers. ALU usage increased while LUT usage decreased. Estimated
synthesis Fmax changed from 61.088 to 59.161 MHz; this is not routed timing or a
generic resource guarantee. The board project archives the complete comparison
under `docs/tm-flan-007e/`.
