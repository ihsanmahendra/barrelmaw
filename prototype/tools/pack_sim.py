# Card pack economy simulation (design/gdd/card-packs.md, section 4.6). Run: python3 tools/pack_sim.py
# First-pass numbers; odds, prices, pity and merge costs mirror the GDD tables.
import random, statistics as st
random.seed(7)
R=["C","R","E","L","T"]
POOL={"C":14,"R":11,"E":6,"L":2,"T":4}
STEP={"C":[2,3,5,8],"R":[2,3,5,7],"E":[2,3,5,6],"L":[2,3,4,5],"T":[2,3,3,4]}   # copies consumed per level-up (Lv1->2 ... Lv4->5)
# pack tiers: (cards, per-slot odds list, slot weights) slot weights are % for C,R,E,L,T
def slots(tier):
    if tier=="crate":   return [[88,11,1,0,0]]*3
    if tier=="iron":    return [[70,27,3,0,0]]*3+[[0,85,14,1,0]]
    if tier=="coffer":  return [[45,40,14,1,0]]*3+[[0,0,90,10,0]]
    if tier=="gilded":  return [[0,55,40,5,0]]*4+[[0,0,80,18,2]]
    if tier=="vault":   return [[0,0,72,28,0]]*4+[[0,0,0,62,38]]
GATE={"crate":0,"iron":10,"coffer":30,"gilded":41,"vault":51}
PRICE={"crate":150,"iron":600,"coffer":2000,"gilded":6000,"vault":9000}
PITY={"E":30,"L":60,"T":8}  # cards-since: Epic+ every 30 cards, Legendary+ every 100, vault packs w/o new T every 8

def unlocked_pool(stage):
    p={"C":9,"R":0,"E":0,"L":0,"T":0}
    if stage>=10:p["C"]=14;p["R"]=6 if stage<20 else (11 if stage>=30 else 9)
    if stage>=10 and stage<20:p["R"]=1
    if stage>=20:p["R"]=5
    if stage>=30:p["R"]=11
    if stage>=30:p["E"]=2
    if stage>=40:p["E"]=6
    if stage>=40:p["L"]=2
    if stage>=50:p["T"]=4
    return p

class Player:
    def __init__(s):
        s.copies={}; s.lvl={}; s.since={"E":0,"L":0}; s.vault_dry=0; s.packs=0; s.dollars=0
        s.packs_by={t:0 for t in PRICE}
    def roll_rarity(s,w,stage):
        pool=unlocked_pool(stage)
        r=random.choices(R,weights=w)[0]
        while pool[r]==0: r=R[R.index(r)-1]
        return r
    def open(s,tier,stage):
        s.packs+=1; s.packs_by[tier]+=1
        res=[]
        sl=slots(tier)
        for i,w in enumerate(sl):
            r=s.roll_rarity(w,stage)
            # Epic+/Legendary+ pity (only for packs that can yield them)
            if tier!="crate":
                s.since["E"]+=1; s.since["L"]+=1
                if s.since["L"]>=PITY["L"] and unlocked_pool(stage)["L"]>0 and tier in("gilded","vault","coffer"): r="L"
                elif s.since["E"]>=PITY["E"] and unlocked_pool(stage)["E"]>0 and R.index(r)<2: r="E"
                if r in("E","L","T"): s.since["E"]=0
                if r in("L","T"): s.since["L"]=0
            res.append(r)
        if tier=="vault":
            s.vault_dry=0 if "T" in res else s.vault_dry+1
            if s.vault_dry>=6 and "T" not in res: res[-1]="T"; s.vault_dry=0
        pool=unlocked_pool(stage)
        out=[]
        for r in res:
            if r=="T":
                owned=[c for c in range(4) if ("T",c) in s.copies]
                if tier=="vault" and len(owned)<4 and s.vault_dry>=0:
                    unown=[c for c in range(4) if ("T",c) not in s.copies]
                    c=random.choice(unown) if unown and random.random()<0.6 else random.randrange(4)  # duplicate protection
                else: c=random.randrange(4)
            else: c=random.randrange(pool[r])
            s.add((r,c)); out.append((r,c))
        return out
    def add(s,k):
        s.copies[k]=s.copies.get(k,0)+1
        s.lvl.setdefault(k,1)
        s.try_merge(k)
    def try_merge(s,k):
        r=k[0]
        while s.lvl[k]<5 and s.copies[k]>=STEP[r][s.lvl[k]-1]+1:
            s.copies[k]-=STEP[r][s.lvl[k]-1]; s.lvl[k]+=1
    def avg_level(s,stage):
        pool=unlocked_pool(stage); lv=[]
        for r in "CREL":
            for c in range(pool[r]): lv.append(s.lvl.get((r,c),1))
        return statistics_mean(lv)
def statistics_mean(x): return sum(x)/len(x) if x else 1

def run(strategy,days=100,stages_per_day=6,replays=8):
    global SPD
    stages_per_day=SPD
    p=Player(); stage=0; rows={}
    for d in range(1,days+1):
        p.open("crate" if d%7 else "iron",stage)   # daily crate, streak day 7 = Ironbound
        for _ in range(stages_per_day):
            if stage<100:
                stage+=1
                p.dollars+=40+20*3*0.6   # first clear + average 1.8 stars
                if stage%5==0 and stage%10: p.open("crate",stage); p.open("crate",stage)
                if stage in (55,65,75,85,95) and random.random()<0.6: p.open("vault",stage)
                if stage%10==0:
                    for t in {10:["iron"]*2,20:["iron"]*2,30:["coffer"],40:["coffer"]*2,50:["gilded"],60:["vault"],70:["gilded"],80:["vault"],90:["gilded"],100:["vault"]*2}[stage]: p.open(t,stage)
        p.dollars+=replays*10
        # spend: strategy A buys the best available tier it can afford; B only crates
        while True:
            opts=[t for t in PRICE if stage>=GATE[t] and p.dollars>=PRICE[t]]
            if strategy=="B": opts=[t for t in opts if t=="crate"]
            if not opts: break
            t=opts[-1] if strategy=="A" else opts[0]
            p.dollars-=PRICE[t]; p.open(t,stage)
        if d in(3,7,14,21,30,45,60,100): rows[d]=(stage,round(p.avg_level(stage),2),p.packs,sum(1 for k,v in p.lvl.items() if v==5),sum(1 for k in p.lvl if k[0]=="T"))
    return rows,p
for SPD in (3,6):
  for strat in "A":
    allrows=[run(strat)[0] for _ in range(200)]
    print("Pace",SPD,"stages/day, strategy",strat)
    for d in (3,7,14,21,30,45,60,100):
        print(f" day {d:3}: stage {st.mean(r[d][0] for r in allrows):5.1f}  avgLv {st.mean(r[d][1] for r in allrows):.2f}  packs {st.mean(r[d][2] for r in allrows):6.1f}  maxed {st.mean(r[d][3] for r in allrows):4.1f}  Tcards {st.mean(r[d][4] for r in allrows):.1f}")
# pity check: packs to first Legendary from Gilded only
def first_leg(tier,stage,n=2000):
    res=[]
    for _ in range(n):
        p=Player();k=0
        while True:
            k+=1
            if any(c[0] in "LT" for c in p.open(tier,stage)): break
        res.append(k)
    res.sort(); return st.mean(res),res[int(n*.5)],res[int(n*.9)],res[-1]
print("packs to first Legendary+ (mean,median,p90,max): gilded",first_leg("gilded",60),"coffer",first_leg("coffer",60),"iron",first_leg("iron",60))
def first_T(n=2000):
    res=[]
    for _ in range(n):
        p=Player();k=0
        while sum(1 for x in p.copies if x[0]=="T")<4:
            k+=1;p.open("vault",60)
        res.append(k)
    return st.mean(res),max(res)
print("vault packs to own all 4 Transcended (mean,max):",first_T())
# distribution of rarity per pack tier (no pity) as sanity
for t in ("crate","iron","coffer","gilded","vault"):
    sl=slots(t); ev=[sum(w[i]*1 for w in sl)/len(sl)/100 for i in range(5)]
    print(t,[round(x*len(sl),2) for x in ev],"cards",len(sl))
