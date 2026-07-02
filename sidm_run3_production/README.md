# SIDM Run 3 signal sample production

Private full-chain Run 3 signal Monte Carlo for the SIDM displaced dark-photon (lepton-jets)
search. This is a standalone HTCondor production chain (not the McM-driven SampleFactory driver
in the repo root); it lives here as the SIDM Run 3 production area.

## Signal and grid

Process: `pp -> pseudoscalar (pdgId 35) -> 2 dark photons Z_d (pdgId 32) -> collimated dilepton
lepton-jets`. Two channels: **4Mu** (both `Z_d -> mu mu`) and **2Mu2E** (one `Z_d -> mu mu`, one
`Z_d -> e e`). The dark photon is long-lived; its proper decay length cτ is scanned.

Grid (matches the 2018 v10 analysis grid): 6 bound-state masses `M_Bs ∈ {100,150,200,500,800,1000}`
GeV × 3 dark-photon masses `M_Zd ∈ {0.25,1.2,5.0}` GeV × 5 cτ per cell = 90 points/channel →
**180 points**. cτ values per (M_Bs, M_Zd) cell follow the analysis `sidm/configs/signal_grid.yaml`.
Four Run 3 eras: 2022 (pre-EE), 2022EE (post-EE), 2023 (pre-BPix), 2023BPix (post-BPix).

## One gridpack per (M_Bs, M_Zd, channel), reused across cτ

The dark-photon lifetime is set at the Pythia8 hadronization step via `32:tau0`, **not** in the
gridpack. The gridpack's SLHA decay width is explicitly ignored (`SLHA:useDecayTable = off`), so a
single gridpack per (M_Bs, M_Zd, channel) — **36 total** — serves all 5 cτ of its cell. (Verified:
reusing the cτ=0.48 mm gridpack while requesting `32:tau0 = 4.8` reproduces a measured proper
cτ = 4.65 mm.) Gridpacks are built with MadGraph5 (`pscalar_darkphoton_UFO` model) at 13.6 TeV.

## Lifetime setup (critical)

The GEN fragment `processParameters` must be exactly:

```
ParticleDecays:tau0Max = 1000.1
LesHouches:setLifetime = 2     # draw the decay time from tau0
SLHA:useDecayTable = off       # ignore the gridpack's DECAY 32 width
32:tau0 = <cτ in mm>
32:tauCalc = off               # never recompute tau0 from a width
32:mayDecay = on
```

Without `SLHA:useDecayTable = off` + `32:tauCalc = off`, the gridpack's embedded `DECAY 32` width
(a fixed ~10 MeV) is read after init and clobbers `32:tau0`, giving a prompt decay.

## Per-era chain configuration (from McM `get_test` of the corresponding central campaigns)

| era | GEN-SIM release | premix+reco release | global tag | HLT menu | premix procMods | reco procMods | LLPnano year |
|-----|-----------------|---------------------|-----------|----------|-----------------|---------------|--------------|
| 2022     | CMSSW_12_4_19 (gcc10)      | CMSSW_12_4_16 (gcc10)      | 124X_mcRun3_2022_realistic_v12         | 2022v12 | premix_stage2,siPixelQualityRawToDigi | siPixelQualityRawToDigi | 2022PreEE  |
| 2022EE   | CMSSW_12_4_11_patch3       | CMSSW_12_4_11_patch3       | 124X_mcRun3_2022_realistic_postEE_v1   | 2022v14 | premix_stage2,siPixelQualityRawToDigi | siPixelQualityRawToDigi | 2022PostEE |
| 2023     | CMSSW_13_0_17 (gcc11)      | CMSSW_13_0_14 (gcc11)      | 130X_mcRun3_2023_realistic_v14         | 2023v12 | premix_stage2 | (none) | 2023PreBPix  |
| 2023BPix | CMSSW_13_0_14 (gcc11)      | CMSSW_13_0_14 (gcc11)      | 130X_mcRun3_2023_realistic_postBPix_v6 | 2023v12 | premix_stage2 | (none) | 2023PostBPix |

Beamspot: `Realistic25ns13p6TeVEarly2022Collision` (2022/22EE), `...Early2023Collision` (2023/23BPix).
`--era Run3` (2022/22EE), `Run3_2023` (2023/23BPix). Premix pileup: the matching Run3Summer21
PrePremix `Neutrino_E-10_gun` PREMIX dataset per era. The single-step LLPNanoAOD PAT→NANO
(`year=<...>` hardcodes the corresponding MiniAOD/NANO global tag) runs in the prebuilt CMSSW_13_0_13.

**Important:** 2023/2023BPix RECO must NOT use the 2022 `siPixelQualityRawToDigi` procModifier — it
raises `NoProxyException: SiPixelQuality forRawToDigi`. 2023 uses `premix_stage2` only (premix) and
no reco procModifiers. This is encoded per-era in `chain_job.sh`.

## How to run

All jobs run in the el8 CMSSW apptainer via `+ApptainerImage = /cvmfs/singularity.opensciencegrid.org/cmssw/cms:rhel8`
(works on el9 workers, no nesting). Workers do not mount `/uscms_data`, so inputs are pulled from EOS
via xrootd and stock CMSSW comes from cvmfs. Set `x509userproxy` in the `.sub` files to a valid VOMS
proxy on shared NFS.

1. **Build the 36 gridpacks** (once): `condor_submit build.sub` — queues `build_gp_job.sh` over
   `build_args.txt` (the 36 cells). Each fetches a full genproductions checkout, builds the gridpack,
   verifies it contains the MadEvent `process/`, and xrdcp's it to EOS `gridpacks/`. Idempotent.
2. **Generate the campaign job list:**
   `for era in 2022 2022EE 2023 2023BPix; do python3 make_campaign_args.py points_all.txt $era <ev/sample> <ev/job> >> campaign_args.txt; done`
3. **Submit the campaign:** `mkdir -p logs && condor_submit campaign.sub` — queues `chain_job.sh` over
   `campaign_args.txt`. Each job runs the full chain for one (point, era, chunk) and xrdcp's the
   LLPNanoAOD to EOS `outputs/<era>/<name>/`. Idempotent (skips existing outputs); resubmitting the
   same args re-runs only the missing chunks.
4. **GEN-level validation** (optional): `condor_submit gen_validate.sub` — a GEN-only (LHE,GEN)
   lifetime + kinematics check per point (measured/nominal proper cτ, masses, channel), written to
   EOS `validation/`.
5. **Location YAML for the analysis:** `python3 make_run3_location_yaml.py <out_dir>` — crawls the
   produced nanos and writes `signal_4mu_run3.yaml` / `signal_2mu2e_run3.yaml` in the `make_fileset`
   shape (keyed by era), for `sidm/configs/ntuples/` in the analysis repo.

EOS layout: `/store/group/lpcmetx/SIDM/run3_samplegen/{gridpacks, payload, outputs/<era>/<name>/, validation}`.
The LLPNanoAOD payload is `cms-sidm/LLPNanoAOD @ LLPnanoAODv1_Run3_devel`, prebuilt in CMSSW_13_0_13.

## Validation summary

- **Lifetime + kinematics** (180-point GEN-level scan): measured/nominal proper cτ = 0.995 ± 0.030,
  all 180 points within 10% of 1.0, unbiased across five orders of magnitude in cτ; pscalar mass
  exact, dark-photon mass within the Breit-Wigner width; channel composition correct at every point.
- **Trigger efficiency** (Run3 displaced-dimuon OR vs the 2018 L2 set), stable across eras:
  4Mu 62% → 70%, 2Mu2E 21% → 28% (grid means), with the largest gains in the soft/displaced corners.

## Build gotcha (why `build_gp_job.sh` is the way it is)

The gridpack build must run inside a full genproductions checkout (the script fetches one with its
`.git`, so `gridpack_generation.sh`'s `git rev-parse` path resolution works) and with stdin from
`/dev/null` (so MadGraph's interactive switch prompt auto-defaults instead of aborting the
integration on a no-TTY worker). Either omission silently yields an incomplete gridpack (missing
`process/`), so the script verifies `process/madevent` is present before uploading.
