# SIDM Run 3 signal production (SampleFactory-native)

A deliberately **minimal, explicit delta** on three validated workflows — the IDM SampleFactory Run 3
driver, the Run 2 SIDM production, and Sunil's Run 3 chain. **Read `PROVENANCE.md` first** — it maps
every artifact to its origin and the exact change.

- `../data/chains/Run3/chain_Run3Summer*_SIDM.json` — the per-era chains (gen → **AODSIM**), run by
  the standard `runFactory`. = IDM's chains with our McM-verified conditions + the SIDM fragment + stop at AODSIM.
- `../data/fragments/SIDM_BsTo2DpTo4l_TuneCP5_13p6TeV_cff.py` — the SIDM fragment = the Run 2 SIDM
  fragment + 3 labeled lines (13.6 TeV, Run 3 CP5 tune, the lifetime robustness lines).
- **`run_llpnano.sh`** — THE one new step: run the custom LLPNanoAOD on the AODSIM (the only tier that
  carries the displaced muons the search needs).
- `example/` — run one point end to end and see the physics check.
- `points_sidm.json` — the 180-point grid and how to map a point to its gridpack / cτ / era.
- `../sidm_run3_production/` — the standalone HTCondor **reference implementation** that produced the
  2,880 samples (180 points × 4 eras × 2000 ev) on `lpcmetx` EOS.
