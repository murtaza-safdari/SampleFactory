# SIDM Run 3 signal production — what it is, and exactly what we changed

This is deliberately a **small, explicit delta** on three already-validated workflows — **not** a new
framework:

- the **IDM SampleFactory** Run 3 driver (`cms-idm/SampleFactory @ iDM_run3`),
- the **Run 2 SIDM** signal production (the validated 2018 / v10 samples),
- **Sunil Dogra's** Run 3 SIDM chain (`smdogra/SiDM`, `run3TarBallMiniAOD`).

Everything SIDM-specific for Run 3 reduces to: **one new step** (LLPNanoAOD), a **~3-line fragment
change**, and **per-era conditions we re-verified against McM**. Here is exactly what came from where.

## The one genuinely new thing — the LLPNanoAOD step
`sidm_run3/run_llpnano.sh`. The IDM/central chains and Sunil's chain all stop at the standard tiers
(MiniAOD / central NanoAOD), which **slim away the displaced muons the search needs**. We run the
custom LLPNanoAOD (PAT→NANO, `cms-sidm/LLPNanoAOD`) on the AODSIM so the `DSAMuon` table,
`Muon.dsaMatch*` indices, and `GenPart` vertices survive. This is the only reason a private Run 3
production is needed at all.

## The chains — `data/chains/Run3/chain_Run3Summer*_SIDM.json`
= the **IDM SampleFactory** Run 3 chain JSONs (same structure, run by the same `runFactory` machinery),
with three changes:
1. the GEN step's fragment = the SIDM fragment (below),
2. **`KEEPS` = the RECO/AODSIM step** — we stop at AODSIM, and the LLPNanoAOD add-on runs on it,
3. per-era conditions set to the McM-verified values below.

**Per-era conditions** — re-verified against McM `get_test` of real central DRPremix datasets; they
match Sunil's table:

| era | GEN-SIM | premix+reco | global tag | HLT | premix procMods | reco procMods | LLPnano year |
|-----|---------|-------------|-----------|-----|-----------------|---------------|--------------|
| 2022     | CMSSW_12_4_19       | CMSSW_12_4_16       | 124X_mcRun3_2022_realistic_v12         | 2022v12 | premix_stage2,siPixelQualityRawToDigi | siPixelQualityRawToDigi | 2022PreEE  |
| 2022EE   | CMSSW_12_4_11_patch3| CMSSW_12_4_11_patch3| 124X_mcRun3_2022_realistic_postEE_v1   | 2022v14 | premix_stage2,siPixelQualityRawToDigi | siPixelQualityRawToDigi | 2022PostEE |
| 2023     | CMSSW_13_0_17       | CMSSW_13_0_14       | 130X_mcRun3_2023_realistic_v14         | 2023v12 | premix_stage2 | (none) | 2023PreBPix  |
| 2023BPix | CMSSW_13_0_14       | CMSSW_13_0_14       | 130X_mcRun3_2023_realistic_postBPix_v6 | 2023v12 | premix_stage2 | (none) | 2023PostBPix |

Two per-era points worth calling out (both verified against central production):
- **2023 / 2023BPix RECO uses NO `siPixelQualityRawToDigi` procModifier** (2022/22EE do). Using the
  2022 setting on 2023 raises `NoProxyException: SiPixelQuality forRawToDigi`.
- **2022EE uses the Summer22 (non-EE) premix library and HLT `2022v14`** (McM-confirmed on
  `EXO-Run3Summer22EEDRPremix-01379`). An older IDM chain JSON shows the Summer22EE premix + `2022v12`
  — that is stale; central Run3Summer22EE uses what we use.

## The fragment — `data/fragments/SIDM_BsTo2DpTo4l_TuneCP5_13p6TeV_cff.py`
= the **Run 2 SIDM** genproductions fragment with exactly:
- `comEnergy` 13000 → **13600**,
- CP5 tune import `MCTunes2017` → **`MCTunesRun3ECM13p6TeV`**,
- **added** `SLHA:useDecayTable=off` + `32:tauCalc=off` (robustness — the lifetime is set by `32:tau0`,
  exactly as in Run 2 SIDM and Sunil's fragments; these two lines just stop the gridpack's embedded
  `DECAY 32` width from silently overriding it).

**No gen filter** — matches the v10 Run 2 SIDM samples (whose YAML says *"no unwanted gen filters"*).
Sunil's Run 3 fragments add a ≥4-lepton acceptance filter; we omit it to match v10. The gridpack path
and cτ are per-job environment variables (`GRIDPACK`, `CTAU`), exactly as in the IDM fragments.

## The gridpacks
Built from the **Run 2 SIDM** MadGraph cards at 13.6 TeV. **One gridpack per (M_Bs, M_Zd, channel)**
serves all 5 cτ of a cell — the cτ is set in Pythia (`32:tau0`), the gridpack's LHE width is ignored
— so **36 gridpacks, not 180**. This is an optimization over per-cτ gridpacks; verified equivalent
(reusing the cτ=0.48 gridpack at `32:tau0=4.8` reproduces a measured 4.65 mm).

## What's validated, and how
- **Lifetime + kinematics, all 180 points, both channels:** measured/nominal proper cτ = **0.995 ±
  0.030** (GEN-level scan); cross-checked at nano level (0.97–1.03).
- **Trigger efficiency**, all four eras (see `sidm_run3_production/TRIGGER_EFFICIENCY.md`).
- **End-to-end example:** `sidm_run3/example/example_run_one.sh` runs one point through the whole chain
  and prints a physics check (masses, lifetime, displaced branches). Run it to see it work.

## Reference implementation
`sidm_run3_production/` is the standalone HTCondor chain that actually **produced the 2,880 samples**
(180 points × 4 eras × 2000 ev) on `lpcmetx` EOS. It encodes the same recipe as the chains above; it
exists because we ran the full campaign on LPC before expressing it SampleFactory-native.
