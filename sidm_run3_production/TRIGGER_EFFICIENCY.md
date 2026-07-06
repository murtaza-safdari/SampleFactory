# Run 3 trigger efficiency on the produced signal

Measured on the produced Run 3 signal LLPNanoAOD (2000 ev/sample), per point, per era, with
`trigger_eff_grid.py <era>` (run in the analysis venv; reads the HLT branches over the nanos on EOS).
The per-point tables are `trigger_efficiency_<era>.txt`.

## What is measured

Pass fraction of grouped HLT displaced-dimuon paths, and the combined OR:
- **2018 set** (the paths the 2018 analysis uses): `DoubleL2Mu23/25NoVtx_2Cha` (+`CosmicSeed`, +`Eta2p4`).
- **Run3 L3 displaced**: `DoubleL3Mu16_10/18_10/20_10NoVtx_DxyMin0p01cm`, `DoubleL3dTksMu16_10NoVtx_DxyMin0p01cm`.
- **Run3 L2 high-threshold**: `DoubleL2Mu30NoVtx_2Cha_Eta2p4` (+`CosmicSeed`).
- **Run3 L2 prompt-veto**: `DoubleL2Mu10/12/14NoVtx_2Cha_VetoL3Mu0DxyMax1cm`.
- **Full Run3 OR** = the union of all four groups.

## Result (grid means)

| era | 4Mu 2018 → OR | 2Mu2E 2018 → OR | max VetoL3 |
|-----|---------------|-----------------|------------|
| 2022     | 62.5% → 70.3% (+7.8) | 20.9% → 28.1% (+7.2) | 37% |
| 2022EE   | 62.4% → 70.1% (+7.7) | 20.9% → 28.3% (+7.3) | 35% |
| 2023     | 62.4% → 70.5% (+8.1) | 20.8% → 28.3% (+7.5) | 34% |
| 2023BPix | 62.5% → 70.6% (+8.1) | 20.8% → 28.4% (+7.6) | 36% |

- The Run3-improved paths add **~+8% (4Mu) / ~+7% (2Mu2E)** to the 2018 set, uniformly across eras,
  with the largest per-point gains (up to +26%) in the soft/low-mass, intermediate–long-cτ corners.
- **2Mu2E is markedly trigger-limited** (~28% even with the full OR): it has only one muon pair.
- **The VetoL3 (prompt-veto) paths are strongly cτ-dependent** — ~0% at short cτ (muons look prompt →
  vetoed), rising to 34–37% at long cτ — so they are the dominant new path in the displaced regime and
  belong in the OR (they read 0% only if you look at a short-cτ point in isolation).

## Note

These efficiencies are gen-truth-independent detector-level pass fractions; a proper analysis trigger
efficiency (with a Run 3 measurement/scale-factor, not the 2018 one) is a separate analysis task. This
document establishes only that the produced nanos carry the expected Run 3 displaced-dimuon paths and
that the improved OR helps where the physics is hardest.
