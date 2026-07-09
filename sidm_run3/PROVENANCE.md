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
= the **IDM SampleFactory** Run 3 chain JSONs (byte-identical shape, driven by the same `runFactory`
machinery — which now runs on LPC, see "Running on LPC via runFactory" below; the
`sidm_run3/example/` script and the `sidm_run3_production/` reference implementation that produced
the samples are standalone alternatives), with three changes:
1. the GEN step uses the SIDM fragment (passed via `-f` at run time, not embedded in the JSON; below),
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
- **Release caveats** (global tags carry the conditions; releases differ mildly across central
  requests): our 2022EE steps run in CMSSW_12_4_11_patch3, while the mature central round and
  Sunil's script use 12_4_20 (GEN-SIM) / 12_4_16 (premix+RECO) — same 12_4 cycle and the same
  `postEE_v1` global tag. Central 2022 GEN-SIM used both 12_4_19 (ours) and 12_4_20 depending on
  the physics group. Align releases with the central choice in any future production round.
- **2023 global tag**: we use `130X_mcRun3_2023_realistic_v14` (the value on the official GTsRun3
  twiki for Run3Summer23); much of the higher-volume central Run3Summer23 production uses `_v15`.
  When the Run 3 background samples are chosen, match the signal DR/RECO conditions to theirs.
- **Beamspot / `--era`** (not in the table above): `Realistic25ns13p6TeVEarly2022Collision` with
  `--era Run3` for 2022/22EE; `Realistic25ns13p6TeVEarly2023Collision` with `--era Run3_2023` for
  2023/23BPix — the standard per-era values, as in central production and the reference implementation.

## The fragment — `data/fragments/SIDM_BsTo2DpTo4l_TuneCP5_13p6TeV_cff.py`
= the **Run 2 SIDM** genproductions fragment with these changes:
- `comEnergy` 13000 → **13600**,
- CP5 tune import `MCTunes2017` → **`MCTunesRun3ECM13p6TeV`**,
- **added** `SLHA:useDecayTable=off` + `32:tauCalc=off` (robustness — the lifetime is set by `32:tau0`,
  exactly as in Run 2 SIDM and Sunil's fragments; these two lines stop the gridpack's embedded
  `DECAY 32` width from silently overriding it) + `32:mayDecay=on`,
- **settings-block difference**: the Run 2 fragment included `pythia8aMCatNLOSettingsBlock` (aMC@NLO
  shower-matching settings: restricted shower starting scale, `MEcorrections=off`, global recoil);
  this fragment instead includes `pythia8PSweightsSettingsBlock` (parton-shower variation weights).
  The matching block targets NLO/aMC@NLO LHE input; these gridpacks are LO. Measured impact vs the
  2018 v10 samples (200 GeV / 1.2 GeV point): the dark-photon pT is ~6% softer at the median
  (KS D = 0.13) with correspondingly ~10% softer lepton pT and wider lepton-pair ΔR, and a slightly
  larger FSR tail (m(ll) < 0.95 m_Zd: 32% → 38%); masses, proper lifetime, and channel composition
  are unaffected. A few-percent ISR-recoil shape effect of this kind is absorbed by computing
  efficiencies on the Run 3 samples themselves (never transporting 2018 efficiencies). Kept as-is
  for the produced samples; revisit consciously before any future mass production.

**No gen filter** — the Run 3 samples cover the **full lepton phase space**. Note this does NOT
exactly match the v10 2018 samples: despite their YAML's *"no unwanted gen filters"*, the v10 gen
leptons carry acceptance cuts (a hard |η| < 2.4 edge — 0 of 46k measured leptons beyond it — and a
minimum lepton pT of about 1 GeV), while the Run 3 samples have none (lepton |η| out to ~6, pT to
~0.1 GeV). Consequences: (i) acceptance/efficiency denominators differ between v10 and Run 3 — a
Run 3 "per generated event" efficiency is not directly comparable to a v10 one; (ii) for shape
comparisons, apply |η| < 2.4 (and pT > 1 GeV) to the Run 3 gen leptons first — the validation
notebook does this explicitly. Sunil's Run 3 fragments add a ≥4-lepton acceptance filter; we omit
any filter. The gridpack path and cτ are per-job environment variables (`GRIDPACK`, `CTAU`), exactly
as in the IDM fragments.

## The gridpacks
Built from the **Run 2 SIDM** MadGraph cards at 13.6 TeV. **One gridpack per (M_Bs, M_Zd, channel)**
serves all 5 cτ of a cell — the cτ is set in Pythia (`32:tau0`), the gridpack's LHE width is ignored
— so **36 gridpacks, not 180**. This is an optimization over per-cτ gridpacks; verified equivalent
(reusing a cell's gridpack — originally built for the cτ=0.48 point — at `32:tau0=4.8` reproduces a
measured 4.65 mm).

## What's validated, and how
- **Lifetime + kinematics, all 180 points, both channels:** measured/nominal proper cτ = **0.995 ±
  0.030** (GEN-level scan); cross-checked at nano level (0.97–1.03). The gen-level validation plots —
  the meas/nom cτ scan and per-point kinematics (dark-photon mass, lepton pT, ΔR between a dark
  photon's two leptons) — are in the SIDM analysis repo:
  `sidm/studies/run3_signal_validation/run3_signal_validation.ipynb`.
- **End-to-end example:** `sidm_run3/example/example_run_one.sh` runs one point through the whole chain
  and prints a physics check — masses, lifetime, and the displaced `DSAMuon`/`GenPart` content. Run it
  to see it work.

## Running on LPC via runFactory
The upstream `runFactory` is LXPLUS/CRAB-oriented; four minimal, backward-compatible changes make it
drive the chains above on the LPC batch system (IDM/LXPLUS behaviour is unchanged):
1. `data/condor/lpc/condor.jds` — an LPC condor template (selected by `--host lpc`) using the
   `cms:rhel8` apptainer image and your VOMS proxy, with no CRAB/CERN-specific classads. (All four
   eras' steps are el8 — gcc10 for 2022/22EE, gcc11 for 2023/23BPix — so the one `cms:rhel8` image
   covers the whole chain.)
2. `configs/user_$USER.json` — your EOS output area (the gitignored per-user config; the committed
   `configs/user_pviscone.json` is the LXPLUS example).
3. `runFactory.py` — the output-directory **label** parsers now recognise the Run 3 eras
   (`__parse_year`) and the SIDM gridpack channel/mass naming (`__parse_mass`, `__parse_ctau`) instead
   of raising or returning `None` on non-IDM names, and the per-user config name reads `$USER` (default
   still `alabdelh`). These name the job's output directory only; they touch no physics.
   (One label-only side effect: IDM chain names containing a bare "22"/"23" that previously fell
   through to a `None` label now get a year label — directory naming only.)
4. the fragment resolves the gridpack to an absolute path (`os.path.abspath`) so
   `ExternalLHEProducer` finds the condor-transferred tarball — a no-op when the path is already
   absolute (the standalone/cvmfs case) — and requires `CTAU` explicitly (fail loud, like `GRIDPACK`)
   rather than silently defaulting.

Validated on LPC via runFactory. All **four eras × both channels** were run through runFactory to
AODSIM — 2022 and 2022EE (gcc10), 2023 and 2023BPix (gcc11) — each with the correct masses (pscalar
199.9–200.1, dark photon 1.199–1.202 GeV) and channel composition (4Mu → 200 μ / 0 e, 2Mu2E →
100 μ / 100 e); the **4Mu / 2022** point additionally ran to the LLPNanoAOD nano, carrying the
`DSAMuon` table and `GenPart` vertices. The dark-photon lifetime is not re-measured here — it is
validated at high statistics by the reference 180-point GEN scan (measured/nominal proper cτ =
0.995 ± 0.030); the five 50-event points here average meas/nom cτ = 1.00 with ~10% per-point scatter,
a consistent sanity check.

The full 180-point grid does **not** need re-running on this path: runFactory feeds the identical
`cmsDriver` steps as the reference implementation, and its GEN fragment is **physically identical** to
the reference's — byte-identical Pythia tune, `comEnergy`, and lifetime/decay `processParameters`;
only the gridpack/cτ *delivery* differs (Python `os.environ` vs shell expansion). So the grid-level
physics the reference implementation validated carries over unchanged. Exact commands are in
`sidm_run3/README.md`.

## Reference implementation
`sidm_run3_production/` is the standalone HTCondor chain that actually **produced the 720 signal
samples** (180 points × 4 eras, 2000 events each) on `lpcmetx` EOS. It encodes the same recipe as the chains above; it
exists because we ran the full campaign on LPC before expressing it SampleFactory-native.
