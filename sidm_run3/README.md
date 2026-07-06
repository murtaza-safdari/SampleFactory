# SIDM Run 3 signal production (SampleFactory-native)

A deliberately **minimal, explicit delta** on three validated workflows — the IDM SampleFactory Run 3
driver, the Run 2 SIDM production, and Sunil's Run 3 chain. **Read `PROVENANCE.md` first** — it maps
every artifact to its origin and the exact change.

- `../data/chains/Run3/chain_Run3Summer*_SIDM.json` — the per-era chains (gen → **AODSIM**), run
  by the standard `runFactory` (byte-identical shape to IDM's Run 3 chains) = IDM's chains with our
  McM-verified conditions + the SIDM fragment + stop at AODSIM. **These run on LPC** — see
  "Run one point on LPC" below (validated end to end). The `example/` script and the
  `../sidm_run3_production/` reference implementation are standalone alternatives.
- `../data/fragments/SIDM_BsTo2DpTo4l_TuneCP5_13p6TeV_cff.py` — the SIDM fragment = the Run 2 SIDM
  fragment + 3 labeled lines (13.6 TeV, Run 3 CP5 tune, the lifetime robustness lines).
- **`run_llpnano.sh`** — THE one new step: run the custom LLPNanoAOD on the AODSIM (the only tier that
  carries the displaced muons the search needs).
- `example/` — run one point end to end and see the physics check.
- `points_sidm.json` — the 180-point grid and how to map a point to its gridpack / cτ / era.
- `../sidm_run3_production/` — the standalone HTCondor **reference implementation** that produced the
  720 signal samples (180 points × 4 eras, 2000 events each) on `lpcmetx` EOS.


## Run one point on LPC (via runFactory)

The chains run through the standard `runFactory` on the LPC batch system. One-time setup — create
`configs/user_$USER.json` pointing at your EOS output area (the gitignored per-user config; the
committed `configs/user_pviscone.json` is the LXPLUS example):

```json
{
    "XROOTD_HOST": "root://cmseos.fnal.gov/",
    "LFN_PATH": "/store/group/lpcmetx/SIDM/run3_samplegen/samplefactory",
    "envs": { "CTAU": "0.48" }
}
```

Then submit one point (2022, 4Mu, M_Bs=200 / M_Zd=1.2, cτ=0.48, 50 events; M_Zd is the dark-photon
mass, written `MDp` in the gridpack filenames):

```bash
export X509_USER_PROXY=/uscms_data/d3/$USER/x509_proxy.pem   # a valid VOMS proxy on shared NFS
./runFactory.py \
  -c data/chains/Run3/chain_Run3Summer22_SIDM.json \
  -f data/fragments/SIDM_BsTo2DpTo4l_TuneCP5_13p6TeV_cff.py \
  -n 50 -j 1 \
  --gridpack SIDM_BsTo2DpTo4Mu_MBs-200_MDp-1p2_gridpack.tar.xz \
  --gridpack_prefix root://cmseos.fnal.gov//store/group/lpcmetx/SIDM/run3_samplegen/gridpacks/ \
  --host lpc --das_premix --skip-confirm
```

`--host lpc` selects the LPC condor template (`data/condor/lpc/condor.jds`: the `cms:rhel8` apptainer
image + your proxy, no CRAB); runFactory copies the proxy `X509_USER_PROXY` points at into the job, so
use a long-lived one (`voms-proxy-init --valid 192:00 -voms cms`) on shared NFS. The chain writes the
AODSIM to your EOS area; then run the LLPNanoAOD add-on on it for the nano:

```bash
./sidm_run3/run_llpnano.sh <AODSIM> 2022PreEE   # LLPnano year per era: points_sidm.json llpnano_year_by_era
```

cτ is per point via the `CTAU` env, set in the user config's `envs` — it reaches both the worker
(the physics) and the output-directory label. For a different point/era, swap the chain JSON, the
gridpack, and `CTAU`.

Validated on LPC via runFactory: all **four eras × both channels** run to a correct AODSIM (masses
M_Bs ≈ 200 / M_Zd ≈ 1.2 everywhere; 4Mu → 200 μ / 0 e, 2Mu2E → 100 μ / 100 e), and the **4Mu / 2022**
point runs the whole way to the LLPNanoAOD nano (`DSAMuon` table + `GenPart` vertices intact). The
dark-photon lifetime is validated at high statistics by the reference 180-point GEN scan
(measured/nominal proper cτ = 0.995 ± 0.030); the 50-event per-point cτ here is only a ~10% sanity
check. See `PROVENANCE.md` for why the full grid need not be re-run on this path.
