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
| 2024     | CMSSW_14_0_21       | CMSSW_14_0_21       | 140X_mcRun3_2024_realistic_v26         | 2024v14 | premix_stage2 | (none) | 2024 (LLPNano in CMSSW_14_0_21) |

Two per-era points worth calling out (both verified against central production):
- **2023 / 2023BPix RECO uses NO `siPixelQualityRawToDigi` procModifier** (2022/22EE do). Using the
  2022 setting on 2023 raises `NoProxyException: SiPixelQuality forRawToDigi`.
- **2023 / 2023BPix AODSIM event content**: central Summer23(+BPix) DRPremix additionally keeps the
  muon rechit collections (`dt1DRecHits`, `csc2DRecHits`, `rpcRecHits`) in AODSIM via an
  `outputCommands` customisation; our chain writes default AODSIM. Nothing consumed downstream
  breaks (the LLPNanoAOD `DSAMuon` content is built from tracks/hitPattern), but rechit-level
  studies (e.g. muon-detector shower tagging) are not possible on these AODSIMs. Add the
  `outputCommands` extension in any future production round.
- **2022EE uses the Summer22 (non-EE) premix library and HLT `2022v14`** (McM-confirmed on
  `EXO-Run3Summer22EEDRPremix-01379`). An older IDM chain JSON shows the Summer22EE premix + `2022v12`
  — that is stale; central Run3Summer22EE uses what we use.
- **Release caveats** (global tags carry the conditions; releases differ mildly across central
  requests): our 2022EE steps run in CMSSW_12_4_11_patch3 — the Run3Summer22EE campaign's own
  release for central GEN-SIM and the early central DRPremix rounds (McM public API); later central
  rounds moved to 12_4_20 (GEN-SIM) / 12_4_16 (premix+RECO), as in Sunil's script, at the same
  `postEE_v1` global tag. Central 2022 GEN-SIM used both 12_4_19 (ours) and 12_4_20 depending on
  the physics group. Align releases with the central choice in any future production round.
- **2023 global tag**: we use `130X_mcRun3_2023_realistic_v14` (the value on the official GTsRun3
  twiki for Run3Summer23); much of the higher-volume central Run3Summer23 production uses `_v15`.
  When the Run 3 background samples are chosen, match the signal DR/RECO conditions to theirs.
  Likewise 2023BPix: our 13_0_14 + `postBPix_v6` pairing takes each element from a central round
  (early central used 13_0_14 + `postBPix_v2`, later rounds 13_0_17 + `postBPix_v6`) — i.e. the
  GTs here follow the GTsRun3 twiki snapshot values rather than one frozen per-campaign pairing.
- **2024** (central campaign `RunIII2024Summer24` — note `RunIII2024`, not `Run3Summer24`, in the DAS
  names): read from McM `get_setup` (public REST API) of three central chains, all `status: done`:
  `GEN-RunIII2024Summer24wmLHEGS-00217` → `GEN-RunIII2024Summer24DRPremix-00308` →
  `GEN-RunIII2024Summer24MiniAODv6-00258` → `GEN-RunIII2024Summer24NanoAODv15-00258`
  (TTto2L2Nu-2Jets amcatnloFXFX, 200M events); `GEN-RunIII2024Summer24wmLHEGS-00213` →
  `GEN-RunIII2024Summer24DRPremix-00455` (TTto2L2Nu-3Jets MLM, 300M); `GEN-RunIII2024Summer24DRPremix-00054`
  (QCD-4Jets HT-100to200, 120M). All three agree on everything except the release: GS and DR
  `--conditions 140X_mcRun3_2024_realistic_v26`, `--era Run3_2024`, GS `--beamspot DBrealistic` (the
  2024 vertex smearing comes from the GT's beamspot, not a named `Realistic25ns...` scenario), premix
  `--procModifiers premix_stage2 --datamix PreMix --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:2024v14`,
  `--pileup_input dbs:/Neutrino_E-10_gun/RunIIISummer24PrePremix-Premixlib2024_140X_mcRun3_2024_realistic_v26-v1/PREMIX`,
  RECO `--step RAW2DIGI,L1Reco,RECO,RECOSIM` with **no procModifiers** and **no AODSIM `outputCommands`
  customisation** (default AODSIM, unlike Summer23), all `el8_amd64_gcc12`. Downstream central tiers:
  MiniAODv6 (PAT) and NanoAODv15 in CMSSW_15_0_2 at `150X_mcRun3_2024_realistic_v2`; the earlier
  14_0 MiniAOD/NanoAOD round (`GEN-RunIII2024Summer24NanoAOD-00285`, 14_0_21_patch4) used
  `140X_mcRun3_2024_realistic_v26`.
  **Release caveat:** the DR release varies across central requests: 14_0_21 (`-00308`, and both GS
  requests), 14_0_21_patch4 (`-00455`), 14_0_19 (`-00054`); a DAS `release dataset=` survey of 40
  random 2024 DRPremix AODSIM datasets (of 3575) found 14_0_19 … 14_0_24_patch1, with 14_0_21 carrying
  most of the events (8 datasets, 200M events of the sampled 246M). We use CMSSW_14_0_21 for GS and DR
  (one release, the TTto2L2Nu-2Jets chain's own; the GT carries the conditions).
  **LLPNanoAOD for 2024:** the 13_0_13 payload cannot open 14_0_X AODSIM (`FileOpenError ... Fatal Root
  Error: @SUB=TList::Clear` from PoolSource, tested on a central 2024 AODSIM file), and no
  `cms-sidm/LLPNanoAOD` branch has a 2024 year. 2024 therefore runs the same code
  (`LLPnanoAODv1_Run3_devel` 164e620 + the same RecoVertex/PhysicsTools corrections, whose stock files are
  identical in 13_0_13 and 14_0_21) built in CMSSW_14_0_21, with `year=2024` → `Run3_2024`,
  `140X_mcRun3_2024_realistic_v26` and the 13_0-only `process.options` `FailPath`/`SkipEvent` dropped
  (`sidm_run3_production/llpnano_2024/`). Its standard-NANO part is the 14_0 (NanoAODv14) schema: e.g.
  `MET_*` is `PFMET_*`, `Muon_mvaTTH`/`Electron_mvaTTH` are gone; the LLP content (`DSAMuon`, `Muon_dsaMatch*`,
  the muon-vertex tables, `BS`, `GenPart_v*`) has the same branches as 2023BPix.
- **Beamspot / `--era`** (not in the table above): `Realistic25ns13p6TeVEarly2022Collision` with
  `--era Run3` for 2022/22EE; `Realistic25ns13p6TeVEarly2023Collision` with `--era Run3_2023` for
  2023/23BPix; `DBrealistic` with `--era Run3_2024` for 2024 — the standard per-era values, as in central
  production and the reference implementation.

## The fragment — `data/fragments/SIDM_BsTo2DpTo4l_TuneCP5_13p6TeV_cff.py`
= the **Run 2 SIDM** genproductions fragment with these changes:
- `comEnergy` 13000 → **13600**,
- CP5 tune import `MCTunes2017` → **`MCTunesRun3ECM13p6TeV`**,
- **added** `SLHA:useDecayTable=off` + `32:tauCalc=off` (robustness — the lifetime is set by `32:tau0`,
  exactly as in Run 2 SIDM and Sunil's fragments; these two lines stop the gridpack's embedded
  `DECAY 32` width from silently overriding it) + `32:mayDecay=on`,
- **settings blocks**: `pythia8CommonSettings`, `pythia8CP5Settings`, `pythia8PSweightsSettings`
  (parton-shower variation weights) and `processParameters`. The public Run 2 genproductions fragment
  (`genfragments/ThirteenTeV/SIDM/SIDM_BsTo2DpTo4l_ctau-XXX_TuneCP5_13TeV_pythia8_cff.py`) lists
  `pythia8aMCatNLOSettings` instead of the PS-weights block, but the 2018 v10 samples the analysis
  uses were not produced from it: the generator configuration stored in a v10 file (edmProvDump,
  2026-11-04) carries exactly the four blocks above and no matching block (no `pTmaxMatch` lines).
  The shower settings of this fragment therefore match the v10 samples. An earlier version of this
  note attributed a ~6% softer dark-photon pT and ~10% softer lepton pT (200 GeV / 1.2 GeV point) to
  a missing matching block; that comparison had not applied the v10 generator filter (>= 4 prompt
  final-state leptons with pT > 4 GeV and |eta| < 2.4) to the Run 3 side. With the filter emulated on
  both sides, dark-photon and lepton pT agree to +0.2%, |eta| and the lepton-pair ΔR agree
  (ΔR −0.3 ± 0.4%), and the mean proper cτ is consistent (SIDM study
  `sidm/studies/run3_signal_validation`, 2026-11-04). The FSR-tail fraction quoted earlier
  (m(ll) < 0.95 m_Zd: 32% → 38%) was measured without the filter and has not been re-measured.

**No gen filter** — the Run 3 samples cover the **full lepton phase space**. Note this does NOT
exactly match the v10 2018 samples: despite their YAML's *"no unwanted gen filters"*, the v10 GEN
process carries a generator filter (`genfilter` + `gencount`: at least four prompt final-state leptons
from the hard process with pT > 4 GeV, |η| < 2.4, production vertex ρ < 740 cm and |z| < 960 cm; 0 of
46k measured leptons lie beyond |η| = 2.4), while the Run 3 samples have none (lepton |η| out to ~6,
pT to ~0.1 GeV). Consequences: (i) acceptance/efficiency denominators differ between v10 and Run 3 — a
Run 3 "per generated event" efficiency is not directly comparable to a v10 one; (ii) for shape
comparisons, apply the v10 filter to the Run 3 gen leptons first — the SIDM study
`sidm/studies/run3_signal_validation` emulates it in `gen_requirement.py`; 0.58 of the 2022 4Mu events
at 200 GeV / 1.2 GeV / 4.8 mm pass it. Sunil's Run 3 fragments add a ≥4-lepton acceptance filter; we omit
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

## v2 production (all five eras, EXONanoAOD) — `sidm_run3_production/chain_job_v2.sh`
The v1 samples above stay as they are (`run3_samplegen/outputs/<era>/`). v2 re-runs the whole chain with the
McM campaign definitions as they stood on 2026-11-02 (McM shows the 2022 to 2023BPix campaigns last updated on 2026-07-01 and the two 2024 campaigns on 2026-09-22) and replaces the LLPNanoAOD step
with the central EXO PAG custom NanoAOD (EXONanoAOD, `PAT,NANO:@EXO` from AODSIM in one step, `CMSSW_16_0_10`).
Gridpacks, GEN fragment (13.6 TeV, lifetime via `32:tau0`, **no gen filter**, as v1) and sample names are v1's.

| era | GEN-SIM + DR release | GT (GS/DR) | HLT | premix library (`/Neutrino_E-10_gun/.../PREMIX`) | beamspot | `--era` | procModifiers premix / reco | nano GT (16_0_10) |
|---|---|---|---|---|---|---|---|---|
| 2022 | CMSSW_12_4_26 (gcc10) | 124X_mcRun3_2022_realistic_v12 | 2022v12 | Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2 | Realistic25ns13p6TeVEarly2022Collision | Run3 | premix_stage2,siPixelQualityRawToDigi / siPixelQualityRawToDigi | 130X_mcRun3_2022_realistic_v5 |
| 2022EE | CMSSW_12_4_26 (gcc10) | 124X_mcRun3_2022_realistic_postEE_v1 | 2022v14 | same as 2022 | same as 2022 | Run3 | same as 2022 | 130X_mcRun3_2022_realistic_postEE_v6 |
| 2023 | CMSSW_13_0_25 (gcc11) | 130X_mcRun3_2023_realistic_v15 | 2023v12 | Run3Summer21PrePremix-Summer23_130X_mcRun3_2023_realistic_v13-v1 | Realistic25ns13p6TeVEarly2023Collision | Run3_2023 | premix_stage2 / none | 130X_mcRun3_2023_realistic_v15 |
| 2023BPix | CMSSW_13_0_25 (gcc11) | 130X_mcRun3_2023_realistic_postBPix_v6 | 2023v12 | Run3Summer21PrePremix-Summer23BPix_130X_mcRun3_2023_realistic_postBPix_v1-v1 | same as 2023 | Run3_2023 | premix_stage2 / none | 130X_mcRun3_2023_realistic_postBPix_v6 |
| 2024 | CMSSW_14_0_25 (gcc12) | 140X_mcRun3_2024_realistic_v26 | 2024v14 | RunIIISummer24PrePremix-Premixlib2024_140X_mcRun3_2024_realistic_v26-v1 | DBrealistic | Run3_2024 | premix_stage2 / none | 150X_mcRun3_2024_realistic_v2 |

Nano step, every era: `cmsDriver.py --scenario pp --mc --step PAT,NANO:@EXO --datatier NANOAODSIM --eventcontent
NANOEDMAODSIM1 --era <era> --conditions <nano GT>` in CMSSW_16_0_10 (el8_amd64_gcc13). The EDM-format nano is then
flattened exactly as the central NANO merge step does (`Configuration.DataProcessing.Merge.mergeProcess(...,
mergeNANO=True)`, i.e. `NanoAODOutputModule`); only that flat file is kept. All releases are el8_amd64, so v1's
`cms:rhel8` container is kept for every step at LPC (`+ApptainerImage`). The same script was also submitted
from CERN lxplus, where the el8 container is requested with `MY.WantOS = "el8"` (two-site submission: SIDM
census README, `sidm/studies/run3_signal_validation/v2_census/README.md`).

**Recipe oracle** (`work/recipe_diff_<era>.txt` in the task record; produced by a dry run of `chain_job_v2.sh`
with shimmed `cmsDriver.py`, diffed field by field against McM `get_setup`): GS = the newest `done` wmLHEGS request
created after 2026-07-01 (`EXO-Run3Summer22wmLHEGS-05300`, `EXO-Run3Summer22EEwmLHEGS-05295`,
`EXO-Run3Summer23wmLHEGS-04353`, `EXO-Run3Summer23BPixwmLHEGS-04353`, `TOP-RunIII2024Summer24wmLHEGS-00254`);
DR = the newest `done` B2G DRPremix request created after 2026-07-01 (`B2G-Run3Summer22DRPremix-06899`,
`B2G-Run3Summer22EEDRPremix-07198`, `B2G-Run3Summer23DRPremix-06497`, `B2G-Run3Summer23BPixDRPremix-06500`,
`B2G-RunIII2024Summer24DRPremix-07498`); 2024 nano = `EXO-RunIII2024Summer24NanoAODv15-06879`. Compared: release,
arch, conditions, step, era, beamspot, pileup_input, procModifiers, datamix, geometry, customise, eventcontent,
datatier, scenario. Result: **no difference outside the allowed list** (file names, event counts, nThreads,
addMonitoring, our RNG `--customise_commands`) in any era. Caveats: (i) the B2G chains' own GS requests are older
(12_4_25 / 13_0_24), which is why the GS oracle is taken from other requests; requests created before 2026-07-01
still show the older releases (e.g. newest EXO 2023BPix DRPremix, 13_0_24; newest EXO 2024 DRPremix,
14_0_24_patch1). (ii) McM has no EXONano request yet for 2022–2023: there the nano reference is the stated
recipe; its GTs equal those of the newest central NanoAODv12 requests (`EXO-Run3Summer22NanoAODv12-05417`:
`130X_mcRun3_2022_realistic_v5`; `EXO-Run3Summer23NanoAODv12-04695`: `130X_mcRun3_2023_realistic_v15`).

**2022 / 2022EE additions (12_4_X AODSIM read by the 16_0_10 EXONano)**, neither in any central request because
McM has no 2022 EXONano flow yet (central 2022 EXO chains still run MiniAODv4 → NanoAODv12; their DR has no output
customisation, e.g. `EXO-Run3Summer22DRPremix-05903`, `EXO-Run3Summer22EEDRPremix-06467`):
1. 16_0_10 cannot deserialise the HLT scouting products of 12_4_X AODSIM (`FatalRootError ... TBufferFile::CheckByteCount:
   object of class vector<Run3ScoutingVertex> read too many bytes`): 12_4_X files lack the StreamerInfo of those classes
   (cms-sw/cmssw issues 41348, 45888). Fix: the nano step adds `--customise
   IOPool/Input/fixReading_12_4_X_Files.fixReading_12_4_X_Files` (the `FixMissingStreamerInfos` service).
2. The EXONano `dtMDSshowerTable` / CSC MDS cluster producers read `dt1DRecHits` / `csc2DRecHits`, which the 12_4_X AOD
   content keeps only under `bParking` (13_0_X added both to `RecoLocalMuonAOD`, so 2023/2024 AODSIM carry them):
   `ProductNotFound dt1DRecHits` otherwise. Fix: the RECO step adds `--outputCommands "keep *_dt1DRecHits_*_*,keep
   *_csc2DRecHits_*_*"` (appended to `AODSIMoutput`), i.e. the 2022 AODSIM gets the 13_0_X muon-rechit content.
Both are 2022/2022EE only and change no nano content: every era's EXONano carries the same tables (DSAMuon,
DSAMuonVertex, extended PAT muons, ElectronVertex, DispJet, csc/dtMDSCluster, GenPart vertices). The
`run3_miniAOD_12X` era modifier is not used (cms-sw/cmssw PR 45240 deleted it in 14_1_X in 2024, so 16_0_10 does not have it). In the recipe diffs these
two show as `APPROVED` (round 3), no other difference outside the allowed list.

**Test-job fingerprints** (one 200-event job per era, 200 GeV / 1.2 GeV / 4.8 mm 4Mu; read back from the flat nano
with `era_fingerprint.provenance()` / `read_file()` of the SIDM analysis repo; references: the v1 samples for
2022–2023BPix, which use the same premix libraries and beamspots, and a central RunIII2024Summer24 NANO file for 2024):

| era | SIM / HLT / RECO | NANO | HLT menu (HLT_ branches; ref) | ⟨nTrueInt⟩ (ref) | GenVtx x / y / σz cm (ref) | √s median |
|---|---|---|---|---|---|---|
| 2022 | 12_4_26, `..._v12` | 16_0_10, `130X_..._2022_realistic_v5` | /frozen/2022/2e34/v1.2/HLT/V1 (754; 754) | 37.2±0.7 (37.5) | 0.1007 / −0.0149 / 3.87 (0.1006 / −0.0150 / 3.81) | 13597 GeV |
| 2022EE | 12_4_26, `..._postEE_v1` | 16_0_10, `..._postEE_v6` | /frozen/2022/2e34/v1.4/HLT/V1 (616; 616) | 37.3±0.7 (37.4) | 0.1007 / −0.0149 / 4.11 (0.1006 / −0.0150 / 3.81) | 13597 GeV |
| 2023 | 13_0_25, `..._2023_realistic_v15` | 16_0_10, same GT | /frozen/2023/2e34/v1.2/HLT/V2 (689; v1: 688, menu V1) | 51.3±0.8 (50.9) | 0.0458 / −0.0170 / 3.58 (0.0459 / −0.0170 / 3.61) | 13596 GeV |
| 2023BPix | 13_0_25, `..._postBPix_v6` | 16_0_10, same GT | /frozen/2023/2e34/v1.2/HLT/V2 (689; v1: 688, menu V1) | 53.2±0.8 (51.3) | 0.0458 / −0.0170 / 3.71 (0.0459 / −0.0170 / 3.59) | 13598 GeV |
| 2024 | 14_0_25, `140X_..._v26` | 16_0_10, `150X_mcRun3_2024_realistic_v2` | /frozen/2024/2e34/v1.4/HLT/V1 (716; 716) | 44.6±0.7 (45.4) | 0.0285 / −0.0167 / 3.90 (0.0285 / −0.0166 / 3.61) | 13598 GeV |

All five: 200 nano events = 200 GEN-SIM events (no filter), every required branch present (DSAMuon_*, Muon_pt,
Electron_pt, GenPart_vx/pdgId, LHEPart_pt, cscMDSCluster_*, dtMDSCluster_*), generator comEnergy 13600. The 2023
menu key `2023v12` resolves in 13_0_25 to `/frozen/2023/2e34/v1.2/HLT/V2` (v1, 13_0_14: `V1`; one more HLT_
branch). σz and ⟨nTrueInt⟩ agree within 2.3σ of 200-event statistics. Per-step cost (s/event at 4 threads, peak
RSS): GS 4.2–6.7 s, 1.6 GB; PREMIX 2.2–4.4 s, 5.0–7.0 GB (2024 highest); RECO 2.6–3.6 s, 3.4–3.9 GB; PAT,NANO
1.4–2.0 s, 3.2 GB. Sizes: flat nano 23–24 kB/event, EDM nano 43–44 kB/event, MINIAODSIM 110–125 kB/event (test only).
Resources: request_cpus 4, request_memory 9500 MB (2024) / 7500 MB (others), request_disk 4 GB.

**EOS layout**: `/store/group/lpcmetx/SIDM/run3_samplegen/outputs_v2/<era>/<sample>/<sample>_<era>_jNNN.root`
(flat EXONanoAOD); test jobs under `outputs_v2/test/<era>/` (nano + MINIAODSIM). Column: the 36
`reduced_points.txt` samples × 120 chunks (v1's split, kept as v1 for the file layout the analysis tooling knows:
j000–j039 × 500 + j040–j119 × 1000 events = 100k; not a uniform 120 × 833); grid: all 180 `points_all.txt` points ×
4 × 500 events, as v1 (for the 36 column points j000–j003 are the column's files: those grid nodes skip on the
existing-output check, or redo a chunk the column lost).
**Submission**: one outer DAG, `run3v2.dag` (`make_dag_v2.py outer`), with ten `SUBDAG EXTERNAL` nodes, the five
era columns then the five era grids, ordered by `PRIORITY` (2024, 2022, 2022EE, 2023, 2023BPix in each group), no
edges, and `DAGMAN_MAX_JOBS_SUBMITTED = 2` in its `CONFIG`: two sub-DAGs run at a time and the next starts when one
finishes, on the schedd. Each sub-DAG (`make_dag_v2.py <era> <column|grid>`) has one node per chunk, `RETRY 3`, its
own `CONFIG` (`DAGMAN_MAX_JOBS_IDLE = 500`, `DAGMAN_MAX_JOBS_SUBMITTED = 1500`), a `NODE_STATUS_FILE` (as does the
outer DAG; `status.sh` reads progress from these files, not from `condor_q`) and the `+SIDMCampaign = "run3v2"`
ClassAd on every job. Submitted once: `_CONDOR_DAGMAN_INSERT_SUB_FILE=$PWD/dagman_insert.sub condor_submit_dag
-notification never run3v2.dag`. The LPC schedd rejects jobs with neither a DesiredOS nor an Apptainer image; the
sub-DAGMan jobs that the outer DAGMan submits on the schedd get `+DesiredOS = "EL9"` (the login client's default)
from `dagman_insert.sub`, which reaches the recursive `condor_submit_dag` through DAGMan's `getenv = _CONDOR_*`.

**Job records**: every v2 job leaves two files that condor transfers back, `<name>_<era>_jNNN.cksum` and
`<name>_<era>_jNNN.faillog.gz` (`chain_job_v2.sh` lines 31 to 41; `prod_v2.sub`). The header comment of
`chain_job_v2.sh` (lines 10 and 11) still calls the `.cksum` "the only file condor transfers back"; it predates the
fail log. The script is kept byte-identical to the one that ran at both sites (md5
a3af76b526123b1a6999308a8230b9e0), so the comment is corrected here and not in the script.
