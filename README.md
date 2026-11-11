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

Status of the submitted layout (ser56, 11 Nov 2026): the GDS, precheck and gate-level test jobs pass, and DRC, LVS
and antenna are clean. In the project's own nine-corner electrical signoff on the layout's extracted wiring (tracked
in the project repository), every judged term passes: control-pin slew at the typical corner, data-pin slew at all
nine corners, output load, the library slew/cap limits, hold (at least 0.198 ns) and latch-aware setup (at least
36.8 ns). Core energy at the typical corner is 3.91 uJ per frame.

This design was first built for SKY130 (8x4); that version is kept on the `sky130-final` branch. The notes in
`docs/RELEASE_AND_RISKS.md` and some RTL comments date from it.

Created from the structure of the Tiny Tapeout Verilog template. Apache-2.0.
