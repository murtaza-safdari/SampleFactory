import sys, math, numpy as np
from DataFormats.FWLite import Events, Handle
name = sys.argv[1]; ctau = float(sys.argv[2])
events = Events(name + "_gen.root"); h = Handle("vector<reco::GenParticle>")
proper = []; nmu = 0; nel = 0; dpm = []; psm = []; nev = 0
for ev in events:
    nev += 1
    ev.getByLabel("genParticles", h)
    for g in h.product():
        if abs(g.pdgId()) == 35:
            psm.append(g.mass())
        if abs(g.pdgId()) == 32:
            dpm.append(g.mass()); lep = None
            for k in range(g.numberOfDaughters()):
                d = g.daughter(k); pid = abs(d.pdgId())
                if pid == 13: nmu += 1; lep = d
                elif pid == 11: nel += 1; lep = d
            if lep is not None and g.mass() > 0:
                dl = math.sqrt((lep.vx()-g.vx())**2 + (lep.vy()-g.vy())**2 + (lep.vz()-g.vz())**2)
                proper.append(dl / (g.p()/g.mass()) * 10.0)  # proper ctau in mm
proper = np.array(proper)
pm = proper.mean() if len(proper) else -1.0
print("RESULT %s : nEv=%d dpMass=%.4f psMass=%.2f nMu=%d nEl=%d nDP=%d properCtau_mm=%.4f meas/nom=%.3f" % (
    name, nev, (np.mean(dpm) if dpm else -1), (np.mean(psm) if psm else -1),
    nmu, nel, len(proper), pm, (pm/ctau if pm > 0 else -1)))
