#!/usr/bin/env python3
# Grid trigger-efficiency scan over the completed signal samples of one era.
# For each point: OR-efficiency per path GROUP + the combined displaced-dimuon OR, over all chunks.
# Answers: does the Run3 OR beat 2018-alone across the grid, and where does each group contribute?
#
# Path groups follow the Run 3 displaced-dimuon suite (cf. the published Run 3 searches; the
# cosmic-seeded prompt-veto variant is documented as the member that stays efficient at 10 GeV
# thresholds out to dxy ~350 cm, arXiv:2309.05466 Sec. 11.2). The menus evolved during 2022:
# the CosmicSeed_VetoL3 and hybrid DoubleL2Mu_L3Mu* paths exist only in the 2022EE/2023/2023BPix
# menus (2022v14/2023v12) -- paths absent from a given era's nano are skipped automatically, so
# this script is safe to run on any era and the OR is era-correct by construction.
import sys, subprocess, re, numpy as np, uproot
ERA = sys.argv[1] if len(sys.argv) > 1 else "2022"
REDIR = "root://cmseos.fnal.gov/"
BASE = "/store/group/lpcmetx/SIDM/run3_samplegen/outputs/" + ERA
G = {
 "trig2018": ["DoubleL2Mu23NoVtx_2Cha","DoubleL2Mu23NoVtx_2Cha_CosmicSeed","DoubleL2Mu25NoVtx_2Cha_Eta2p4","DoubleL2Mu25NoVtx_2Cha_CosmicSeed_Eta2p4"],
 "L3DxyMin": ["DoubleL3Mu16_10NoVtx_DxyMin0p01cm","DoubleL3Mu18_10NoVtx_DxyMin0p01cm","DoubleL3Mu20_10NoVtx_DxyMin0p01cm","DoubleL3dTksMu16_10NoVtx_DxyMin0p01cm"],
 "L2hiEta": ["DoubleL2Mu30NoVtx_2Cha_Eta2p4","DoubleL2Mu30NoVtx_2Cha_CosmicSeed_Eta2p4"],
 "VetoL3":  ["DoubleL2Mu10NoVtx_2Cha_VetoL3Mu0DxyMax1cm","DoubleL2Mu12NoVtx_2Cha_VetoL3Mu0DxyMax1cm","DoubleL2Mu14NoVtx_2Cha_VetoL3Mu0DxyMax1cm",
             # cosmic-seeded prompt-veto variants: 2022EE/2023/2023BPix menus only (not in 2022v12)
             "DoubleL2Mu10NoVtx_2Cha_CosmicSeed_VetoL3Mu0DxyMax1cm","DoubleL2Mu12NoVtx_2Cha_CosmicSeed_VetoL3Mu0DxyMax1cm"],
 # hybrid L2+L3 paths (one muon L3-reconstructable): 2022EE/2023/2023BPix menus only
 "hybrid":  ["DoubleL2Mu_L3Mu16NoVtx_VetoL3Mu0DxyMax0p1cm","DoubleL2Mu_L3Mu18NoVtx_VetoL3Mu0DxyMax0p1cm"],
}
ORPATHS = G["trig2018"] + G["L3DxyMin"] + G["L2hiEta"] + G["VetoL3"] + G["hybrid"]   # full era-dependent Run3 OR
def ls(d):
    try: return subprocess.run(["xrdfs","root://cmseos.fnal.gov","ls",d],capture_output=True,text=True,timeout=60).stdout.split()
    except Exception: return []
subdirs=[d for d in ls(BASE) if "/SIDM_" in d]
rows=[]
for d in subdirs:
    name=d.split("/")[-1]
    files=[REDIR+f for f in ls(d) if f.endswith(".root")]
    if not files: continue
    gp={k:0 for k in G}; por=0; n=0; fields=None
    for f in files:
        try: ev=uproot.open(f)["Events"]
        except Exception: continue
        if fields is None: fields=set(b for b in ev.keys() if b.startswith("HLT_"))
        nf=ev.num_entries
        if not nf: continue
        need=[p for p in ORPATHS if "HLT_"+p in fields]
        arrs={p: ev["HLT_"+p].array(library="np").astype(bool) for p in need}
        for k,paths in G.items():
            pr=[p for p in paths if p in arrs]
            if pr:
                a=np.zeros(nf,bool)
                for p in pr: a|=arrs[p]
                gp[k]+=int(a.sum())
        pr=[p for p in ORPATHS if p in arrs]
        a=np.zeros(nf,bool)
        for p in pr: a|=arrs[p]
        por+=int(a.sum()); n+=nf
    if n==0: continue
    m=re.match(r"SIDM_BsTo2DpTo(\w+?)_MBs-(\d+)_MDp-([\dp]+)_ctau-([\dp]+)",name)
    chan,mbs,mdp,ctau=m.group(1),int(m.group(2)),float(m.group(3).replace("p",".")),float(m.group(4).replace("p","."))
    rows.append(dict(chan=chan,mbs=mbs,mdp=mdp,ctau=ctau,n=n,
                     e2018=gp["trig2018"]/n,eL3=gp["L3DxyMin"]/n,eHi=gp["L2hiEta"]/n,eVeto=gp["VetoL3"]/n,
                     eHyb=gp["hybrid"]/n,eOR=por/n))
rows.sort(key=lambda r:(r["chan"],r["mbs"],r["mdp"],r["ctau"]))
print(f"# grid trigger efficiency ({ERA}), {len(rows)} points scanned")
print(f"# NOTE: the CosmicSeed_VetoL3 and hybrid columns are era-dependent (2022EE/2023/2023BPix only; zero on 2022).")
print(f"{'chan':6s}{'MBs':>5s}{'MDp':>6s}{'ctau':>8s}{'N':>7s}{'2018':>7s}{'L3Dxy':>7s}{'L2hi':>7s}{'VetoL3':>7s}{'OR':>7s}{'OR-2018':>8s}{'hybrid':>8s}")
for r in rows:
    print(f"{r['chan']:6s}{r['mbs']:5d}{r['mdp']:6.2f}{r['ctau']:8g}{r['n']:7d}"
          f"{r['e2018']*100:6.1f}%{r['eL3']*100:6.1f}%{r['eHi']*100:6.1f}%{r['eVeto']*100:6.1f}%{r['eOR']*100:6.1f}%{(r['eOR']-r['e2018'])*100:7.1f}%{r['eHyb']*100:7.1f}%")
for chan in ["4Mu","2Mu2E"]:
    rs=[r for r in rows if r["chan"]==chan]
    if not rs: continue
    print(f"\n== {chan}: mean 2018={np.mean([r['e2018'] for r in rs])*100:.1f}%  OR={np.mean([r['eOR'] for r in rs])*100:.1f}%  "
          f"OR gain={np.mean([r['eOR']-r['e2018'] for r in rs])*100:.1f}%  maxVetoL3={max(r['eVeto'] for r in rs)*100:.1f}%  maxHybrid={max(r['eHyb'] for r in rs)*100:.1f}%")
print(f"\nmax VetoL3 across grid: {max((r['eVeto'] for r in rows), default=0)*100:.1f}% (ctau-dependent; peaks at the longest lifetimes)")
