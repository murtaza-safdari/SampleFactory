# Run one Run 3 SIDM point end to end

`example_run_one.sh` runs a single signal point (4Mu, M_Bs=200, M_Zd=1.2, cτ=0.48 mm, era 2022,
50 events) through the whole recipe — gridpack → GEN-SIM → premix → RECO/AODSIM → **the LLPNanoAOD
add-on** — and prints a physics check.

Run it inside the el8 CMSSW image (needs a valid VOMS proxy on shared NFS for the pileup + gridpack
reads from EOS):

```
voms-proxy-init --valid 192:00 -voms cms
cp /tmp/x509up_u$(id -u) /uscms_data/d3/<user>/x509_proxy.pem
/cvmfs/cms.cern.ch/common/cmssw-el8 -B /uscms_data/d3 -- bash example_run_one.sh
```

Expected physics-check output (the last lines) — a real run gives:

```
RESULT .../SIDMchk : nEv=50 dpMass=1.1985 psMass=199.97 nMu=200 nEl=0 nDP=100 properCtau_mm=0.51 meas/nom=1.07
NANOCHECK nEv=50 DSAMuon=True GenPart_vx=True dsaMatch=True
```

i.e. correct masses (dark photon ≈ 1.2 GeV, pseudoscalar ≈ 200 GeV), correct 4Mu channel
(100 dark photons → 200 muons, 0 electrons), the displaced content present in the nano
(`DSAMuon`, `GenPart` vertices, `dsaMatch`), and the dark-photon lifetime reproduced within the
statistics of a 50-event run (`meas/nom ≈ 1.0` with ~10% stat uncertainty from ~100 dark photons).
The definitive lifetime check is the high-statistics 180-point scan (meas/nom = 0.995 ± 0.030); this
example just shows the whole chain works and the physics is sane.

To run a **different point / era**: change the gridpack name + `CTAU`, and take the GEN-SIM / premix /
RECO conditions from the target era's chain JSON in `data/chains/Run3/chain_Run3Summer<era>_SIDM.json`.
The full 180-point grid is listed in `sidm_run3_production/points_all.txt`.
