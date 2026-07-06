# SIDM Run 3 signal production — fundamentals, what we changed, and how it works

Companion to `README.md` (which is the how-to-run). This document explains **what** we are
generating and **why the chain is built the way it is**, and places it against the two existing
efforts it draws on — the IDM **SampleFactory** driver and **Sunil Dogra's** Run 3 SIDM production
(`smdogra/SiDM`). It is written so a collaborator can understand and validate the samples.

## 1. The signal

We generate the SIDM benchmark: a pseudoscalar bound state is produced and decays to a pair of
dark photons, each of which decays to a collimated lepton pair (a "lepton-jet"):

```
p p -> pscalar (pdgId 35) -> Z_d Z_d (pdgId 32) ,  Z_d -> l+ l-
```

- **Channels:** `4Mu` (both `Z_d -> mu mu`) and `2Mu2E` (one `Z_d -> mu mu`, one `Z_d -> e e`).
- **The dark photon `Z_d` is long-lived** — its proper decay length cτ is the key scanned variable
  (from ~2 µm to ~40 cm across the grid). Because the two leptons come from a low-mass (0.25–5 GeV)
  boosted `Z_d`, they are **soft and collimated** (ΔR ~ 0.02–0.1) and, for a long-lived `Z_d`,
  **displaced** from the primary vertex.
- **Grid:** 6 bound-state masses `{100,150,200,500,800,1000}` GeV × 3 dark-photon masses
  `{0.25,1.2,5.0}` GeV × 5 cτ/cell = 90 points/channel → **180 points**, over the four Run 3 eras
  (2022, 2022EE, 2023, 2023BPix). This matches the analysis's 2018 v10 grid.

## 2. Why a custom NanoAOD from AOD (the central tiers are not enough)

The displaced signature lives in objects that **central MiniAOD/NanoAOD slim away**: displaced
standalone muons (`displacedStandAloneMuons`), displaced global muons (`displacedGlobalMuons`), and
the general tracks needed to build displaced dimuon vertices exist in **AOD** but are dropped
downstream. The SIDM analysis reads a custom **LLPNanoAOD** that re-adds them. This production runs
the LLPNanoAOD step with `includeDSAMuon=True` (the `DSAMuon` table + `Muon.dsaMatch*` indices),
`includeGenPart=True` (extended `GenPart` vertex fields `vx/vy/vz`), `includeBS`/`includeRefittedTracks`,
and — matching the analysis's current v10 inputs — **`includeDGLMuon=False`** (the displaced-global
table is available in LLPNanoAOD but is not written here). So the production **must run a custom
NanoAOD step on the AODSIM** — a central-NanoAOD shortcut would silently lose the displaced content.
This is the single most important structural fact about the chain.

Data-tier flow per event:

```
gridpack (MadGraph LHE)  ->  GEN-SIM  ->  premix (PU + DIGI + L1 + HLT)  ->  RECO/AODSIM
                                                                              |
                                                    custom LLPNanoAOD (PAT->NANO on the AODSIM)
                                                                              |
                                                             xrdcp -> shared lpcmetx EOS
```

## 3. Lineage — how this relates to SampleFactory and to Sunil's production

### 3a. IDM SampleFactory (`cms-idm/SampleFactory`, branch `iDM_run3`)

SampleFactory is a **McM-transcription + code-generation driver**: `getChains.py` scrapes McM
`get_test` for each step's PrepId into a chain JSON (per-step `SCRAM_ARCH`/`CMSSW_VERSION` +
`cmsDriver` `OPTIONS` + `KEEPS`), a hand-written Pythia fragment is injected into the GEN step, and
`runFactory.py` code-generates a `run.sh` (per step: `cmsrel` → `cmsDriver --no_exec` → `cmsRun`)
that it submits to CRAB or HTCondor and `xrdcp`s the kept tiers to EOS.

- **What we reuse (conceptually):** the per-step `cmsDriver --no_exec` + `cmsRun` chain idiom; the
  per-step (SCRAM_ARCH, CMSSW, GT, era, procModifiers, pileup) recipe layout; the
  ship-a-fragment-into-GEN pattern; the run-in-a-Singularity/Apptainer-image-for-the-right-OS and
  xrdcp-outputs-to-EOS patterns.
- **What we replace, and why:** we do **not** use the McM-scrape / chain-JSON / `runFactory.py`
  code-gen. Our signal and grid are fixed and known, so a **direct parametrized Condor chain**
  (`chain_job.sh` taking `MBs MDp CHAN CTAU ERA NEV JOBIDX`) is simpler, transparent, and easy to
  scale/validate, and lets us bake in the SIDM-specific pieces below. SampleFactory's Run 3 chains
  also stop at MiniAOD (2022EE) or **central** NanoAODv12 (2023) — neither produces the displaced
  LLPNanoAOD the analysis needs — and it is not wired for all four eras with our signal. (The
  fragment/gridpack are also fundamentally different physics: SampleFactory's iDM long-lived
  particle is the χ₂ with the lifetime set by a fixed width; our LLP is the dark photon `Z_d` with
  the lifetime set by `32:tau0`.)

### 3b. Sunil Dogra's Run 3 production (`smdogra/SiDM`, `run3TarBallMiniAOD`)

Sunil's is the closest prior effort and uses the **same signal** (`BsTo2DpTo{4Mu,2Mu2e}` gridpacks).
He established a **per-era staged cmsDriver recipe** for all four Run 3 eras (plus partial 2024):
`GEN-SIM → premix → AODSIM → MiniAODSIM → central NANOAODSIM`, submitted from **CERN lxplus/AFS**
HTCondor with the nano written to **KNU Tier-2**.

- **What we reuse/confirm from his work:** the per-era GT / beamspot / HLT / procModifier table
  (our values agree — `124X_..._v12` for 2022, `..._postEE_v1` + HLT `2022v14` for 22EE,
  `130X_..._2023_realistic_v14` + HLT `2023v12` for 2023, and the **drop of `siPixelQualityRawToDigi`
  in 2023/23BPix reco**); and the principle that one gridpack per mass cell serves all cτ with the
  lifetime set downstream by `32:tau0`.
- **Where ours differs or corrects:**
  1. **Custom LLPNanoAOD step (the scientific difference).** His Run 3 chain stops at **central
     NanoAOD** (`--step NANO`), which does not carry the displaced-muon/LLP content. Ours adds the
     custom **LLPNanoAOD** step (`cms-sidm/LLPNanoAOD @ LLPnanoAODv1_Run3_devel`, prebuilt
     `CMSSW_13_0_13`) on the AODSIM, so the displaced content survives into the final tuple.
  2. **Beam energy.** Ours sets `comEnergy = 13600` (13.6 TeV) with the `MCTunesRun3ECM13p6TeV`
     CP5 tune. His per-point fragments set `comEnergy = 13000` (**13 TeV**) despite the Run 3
     GTs/beamspots — a √s that should be reconciled for Run 3.
  3. **Output + host.** Ours runs on **FNAL LPC** HTCondor (el8 CMSSW apptainer via `+ApptainerImage`
     on el9 workers) and writes to **shared** `lpcmetx` EOS, so the whole collaboration on LPC can
     read the samples directly; his run 3 nano goes to KNU T2 and his gridpacks live on CERN AFS.
  4. **One arch, gridpack reuse.** Our gridpacks are `el8_amd64_gcc10` and are reused across all four
     eras' (el8) GEN-SIM releases and across all cτ of a cell; his are `el9_amd64_gcc11/CMSSW_13_2_9`
     per-cτ tarballs, with mixed el8/el9 GEN-SIM releases across eras.

## 4. What we changed to make it work (the non-obvious pieces)

1. **Lifetime fix.** The gridpack's LHE header carries a fixed `DECAY 32` width (~10 MeV → prompt);
   read after init it clobbers `32:tau0`, giving prompt decays. The fix (validated) is
   `SLHA:useDecayTable = off` + `32:tauCalc = off` alongside `LesHouches:setLifetime = 2` and
   `32:tau0 = <cτ>`, so Pythia sets the lifetime and ignores the gridpack width. This is why **one
   gridpack per (M_Bs, M_Zd, channel) serves all 5 cτ** (36 gridpacks, not 180).
2. **Per-era RECO procModifiers.** 2022/22EE reco uses `siPixelQualityRawToDigi`; **2023/23BPix must
   not** (it raises `NoProxyException: SiPixelQuality forRawToDigi`) — use `premix_stage2` only in
   premix and no reco procModifiers. Encoded per-era in `chain_job.sh`.
3. **el8 on el9 workers, EOS-fed.** LPC workers run el9 and do not mount `/uscms_data`. The job is
   forced into the el8 CMSSW image via `+ApptainerImage = /cvmfs/singularity.opensciencegrid.org/cmssw/cms:rhel8`
   (runs on el9 hosts, no nesting); stock CMSSW comes from cvmfs; the gridpack and the LLPNanoAOD
   payload are pulled from EOS by xrootd; outputs go back by xrdcp. The chain is idempotent
   (skip-if-output-exists) so resubmission only fills gaps.
4. **Gridpack build hardening.** A gridpack build on a worker must run inside a full genproductions
   checkout (with `.git`, so `gridpack_generation.sh`'s path resolution works) and with stdin from
   `/dev/null` (so MadGraph's interactive switch prompt auto-defaults instead of aborting on a
   no-TTY worker); otherwise it silently produces an incomplete gridpack missing the MadEvent
   `process/`. `build_gp_job.sh` does both and verifies `process/madevent` before uploading.

## 5. How it was validated

- **Lifetime + kinematics, all 180 points, both channels** (GEN-level scan): measured/nominal proper
  cτ = **0.995 ± 0.030**, all within 10% of 1.0, unbiased across five orders of magnitude in cτ;
  pscalar mass exact, dark-photon mass within the Breit-Wigner width; channel composition correct.
  Cross-checked at the produced-nano level via the analysis location YAML (meas/nom ≈ 0.97–1.03).
- **Trigger efficiency** (Run 3 displaced-dimuon OR vs the 2018 L2 set), stable across all four eras:
  4Mu 62% → 70%, 2Mu2E 21% → 28% (grid means), largest gains in the soft/displaced corners
  (per-era/per-point tables + method in `TRIGGER_EFFICIENCY.md`).
- **Note for the analysis:** the current `SidmProcessor` does not yet run on Run 3 nano out of the
  box. There are (at least) two blockers: (1) Run 2-specific electron-ID branch names (e.g.
  `mvaFall17V2noIso_WPL`) and a `mass` field the schema expects; and (2) `sidm/configs/run_periods.yaml`
  has only `2018`, so `postprocess`'s `get_lumixs_weight(year)` lookup raises `KeyError` for the Run 3
  eras. The samples are gen-valid, but the coffea analysis needs a Run 3 adaptation pass (electron ID +
  a Run 3 `run_periods` entry) before it can process them. Tracked separately.

## 6. Reproducing

See `README.md`: build the 36 gridpacks (`build.sub`), generate the job list
(`make_campaign_args.py`), submit (`campaign.sub`), and generate the analysis location YAML
(`make_run3_location_yaml.py`). Per-era conditions are in the table in `README.md` and encoded in
`chain_job.sh`.
