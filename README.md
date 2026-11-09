![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# AquaFuse-1 — Tiny Tapeout submission (GF180MCU, TTGF26c, 4x4)

A sensor-direct, always-on fish-presence wake gate: a streaming INT8 neural network with an accumulator-domain
background model, a temporal head and a held wake bit. See [docs/info.md](docs/info.md) for how it works, the
pins, the tests and, importantly, **what has and has not been measured**.

* Process and shuttle: GlobalFoundries 180 nm (`gf180mcuD`, 7-track cells) on Tiny Tapeout GF 26c, hardened by
  the `ttgf26c` GDS action. `tiles: "4x4"`, the largest TTGF26c allows (1.4 x 0.64 mm).
* `src/` is the RTL as hardened, plus `config.json` and `pnr.sdc`, the hardening settings the design needs.
* `test/` is the Tiny Tapeout cocotb harness with known-answer vectors from the part's integer oracle, run on the
  GF180 gate-level netlist by the `gl_test` job.
* `info.yaml` is the project description. The rated clock is 6.25 MHz (160 ns); the deployment clock is far lower.

Status of the submitted layout (ser48, 8 Nov 2026): the GDS, precheck and gate-level test jobs pass, and DRC, LVS
and antenna are clean. In the project's own nine-corner electrical signoff (tracked in the project repository),
hold, output load and the library slew/cap limits pass; the project's tighter slew limits are not yet met on a few
dozen pins. A revision that closes them will replace this one before the shuttle deadline.

This design was first built for SKY130 (8x4); that version is kept on the `sky130-final` branch. The notes in
`docs/RELEASE_AND_RISKS.md` and some RTL comments date from it.

Created from the structure of the Tiny Tapeout Verilog template. Apache-2.0.
