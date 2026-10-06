"""R152 game text sample sheet: builds preview/game_text.html (the most-seen screens and notices with the new words).
Every text on the sheet is looked up in the source first (T(file, text)): if the game's text drifts from the sheet this stops.
Usage: python3 build_game_text_sheet.py && node render_game_text.mjs      (writes ../game_text.png)"""
import os,re,sys,html,json
HERE=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.abspath(os.path.join(HERE,'..','..','..','..'))
SRC=os.path.join(ROOT,'src')
def strings(src):
    """the string literals of a Lua source, outside comments: [(line, value, raw)]"""
    i=0;n=len(src);line=1;out=[]
    while i<n:
        c=src[i]
        if c=='\n': line+=1;i+=1;continue
        if c=='-' and src.startswith('--',i):
            m=re.match(r'--\[(=*)\[',src[i:i+40])
            if m:
                close=']'+m.group(1)+']';j=src.find(close,i)
                if j<0:j=n
                line+=src[i:j].count('\n');i=j+len(close);continue
            j=src.find('\n',i)
            if j<0:j=n
            i=j;continue
        if c in '"\'':
            q=c;j=i+1;buf=[]
            while j<n and src[j]!=q:
                if src[j]=='\\' and j+1<n:
                    d=src[j+1]
                    if d=='n':buf.append('\n')
                    elif d=='t':buf.append('\t')
                    elif d in '\\"\'':buf.append(d)
                    elif d=='u':
                        m=re.match(r'\\u\{([0-9a-fA-F]+)\}',src[j:j+14])
                        if m: buf.append(chr(int(m.group(1),16)));j+=len(m.group(0));continue
                        buf.append(src[j:j+2])
                    else: buf.append(src[j:j+2])
                    j+=2;continue
                if src[j]=='\n': break
                buf.append(src[j]);j+=1
            out.append((line,''.join(buf),src[i:j+1]));i=j+1;continue
        if c=='[':
            m=re.match(r'\[(=*)\[',src[i:i+10])
            if m:
                close=']'+m.group(1)+']';j=src.find(close,i+len(m.group(0)))
                if j<0:j=n
                out.append((line,src[i+len(m.group(0)):j],src[i:j+len(close)]));line+=src[i:j].count('\n');i=j+len(close);continue
        i+=1
    return out
cache={}
def lits(f):
    if f not in cache:
        s=open(os.path.join(SRC,f),encoding='utf8').read()
        cache[f]=(s,[v for _,v,_ in strings(s)])
    return cache[f]
def T(f,text):
    """the string literal (or the part of one) `text` exists in file f; returns it"""
    s,L=lits(f)
    if not any(text in v for v in L): raise SystemExit('NOT IN SOURCE: %s :: %r'%(f,text))
    return text
E=html.escape
RS='ReplicatedStorage/';SS='ServerScriptService/ChestChaseServer/';CL='StarterPlayer/StarterPlayerScripts/'

# ---- texts (each one checked against the source) ----
t={}
t['cash']=T(RS+'SimpleGameText.lua','NOT ENOUGH CASH!')
t['room']=T(RS+'SimpleGameText.lua','MAKE ROOM IN UR BAG FIRST!')
t['close']=T(RS+'SimpleGameText.lua','TOO CLOSE! MOVE A BIT')
t['hold']=T(RS+'SimpleGameText.lua','HOLD A SEED FIRST!')
t['picked']=T(RS+'SimpleGameText.lua','PICKED! 🌾')
t['base']=T(RS+'SimpleGameText.lua','GET TO UR BASE FIRST!')
t['maxed']=T(RS+'SimpleGameText.lua','CASH IS MAXED OUT!')
t['bonus']=T(RS+'SimpleGameText.lua','🎁 BONUS ROLL READY! TAP IT')
t['bagtitle']=T(CL+'Hotbar.client.lua','Ur Bag')
t['baghint']=T(CL+'Hotbar.client.lua','Click to hold it • Drag it onto the hotbar')
t['gemwords']=T(CL+'GamePassClient.client.lua','FILL UR PLANT INDEX')
t['gemdetail']=T(CL+'GamePassClient.client.lua','Grab Gems from ur plant index!')
t['placeholder']=T(CL+'GamePassClient.client.lua','Type a number')
t['grabgems']=T(SS+'PremiumProgress.lua','Ur Gems are on the way!')
t['already']=T(SS+'PremiumProgress.lua','U ALREADY HAVE THIS!')
t['mech']=T(SS+'PremiumProgress.lua','Mech pack is in ur bag!')
t['upsave']=T(SS+'PlayerDataService.lua','Not enough cash!')
t['mystery_ready']=T(CL+'MysteryPackClient.client.lua','UNLOCKED! GRAB IT 🎁')
t['mystery_taken']=T(CL+'MysteryPackClient.client.lua','✓ GRABBED TODAY')
t['mystery_ur']=T(CL+'MysteryPackClient.client.lua','UR')
t['mystery_take']=T(SS+'MysteryPackService.lua','Grab')
t['mystery_note']=T(SS+'MysteryPackService.lua','🔓 Ur Mystery Pack is unlocked! Go to ur base and grab it 🎁')
t['mystery_room']=T(SS+'MysteryPackService.lua','Make room in ur bag first!')
t['give_q']=T(CL+'FruitGiftClient.client.lua','Give <font color="#FFE547">%s</font> to <font color="#93FF45">%s</font>?')
t['give_close']=T(CL+'FruitGiftClient.client.lua',' first!')
t['void_hint']=T(RS+'VoidGiveawayRules152.lua','LIMITED! 1 PER PLAYER')
t['void_prompt']=T(RS+'VoidGiveawayRules152.lua','Grab ur FREE Void Pack')
t['void_note']=T(SS+'VoidGiveaway152.lua','🌑 FREE VOID PACK! Check ur bag!')
t['void_room']=T(SS+'VoidGiveaway152.lua','🎒 Make room in ur bag first! (nothing got used)')
t['shovel_q']=T(CL+'GardenShovel.client.lua','?\nThis removes the plant and any fruit still on it. U won\'t get the seed back.')
t['hole_hint']=T(RS+'TrackHoleConfig.lua','🕳️ dig holes on the track to trap players • tap a plant in ur garden to remove it') # R153: the shovel tip also says it removes plants
t['hole_ground']=T(RS+'TrackHoleConfig.lua','ONLY DIG ON THE TRACK!')
t['hole_cap']=T(RS+'TrackHoleConfig.lua','%d HOLES MAX! COVER ONE OR WAIT')
t['quest_done']=T(SS+'DailyProgress.lua','! Grab ur 💎')
t['title_click']=T(RS+'TitleScreen104.lua','Click to play!')
t['kick']=T(SS+'PlayerDataService.lua',"Couldn't load ur progress. Rejoin to try again! Ur saved data is safe.")
t['pull_a']=T(RS+'PullAnnounceRules.lua',' just pulled ')
t['pull_nice']=T(RS+'PullAnnounceRules.lua',' Nice pull!')
t['took']=T(RS+'PullAnnounceRules.lua',' just took ')
t['darkened']=T(RS+'NoticeCopy83.lua','The Darkened is here!!')
t['spawn']=T(RS+'NoticeCopy83.lua',' just spawned in ')
t['became']=T(RS+'NoticeCopy83.lua',' got ')
t['vq']=T(RS+'VerityConfig.lua',"I dare u to steal a Void Pack from the scary Darkened One at the end of Storm Peaks! Bring it to me and I'll give u a ")
t['vthanks']=T(RS+'VerityConfig.lua',"Yay, thanks! Here's ur ")
t['vhere']=T(RS+'VerityConfig.lua','🌑 THE DARKENED IS HERE!!')
t['vvoid']=T(RS+'VerityConfig.lua','UR VOID PACKS')
t['vbusy']=T(RS+'VerityConfig.lua','WHOA, FINISH UR RUN FIRST!')
t['vnote']=T(RS+'VerityConfig.lua','🌟 Yippee! Verity gave u a ')
t['gift_ok']=T(SS+'FruitGiftService.lua','Get closer to ')
t['market']=T(CL+'EconomyClient.client.lua','Go to the market to sell ur crops!')
t['offline']=T(CL+'OfflineGrowthNotice.client.lua','Plants grow offline')
t['pack_cant']=T(SS+'PremiumService.lua',"Couldn't open the purchase. Try again!")
t['wait']=T(RS+'ShopMenu.lua','Wait a sec')
t['hubcl']=T(RS+'HubDisplayRules.lua','Open a pack to grab it!')
t['pick']=T(CL+'PlantInspection.client.lua',' to pick')
t['daily_gems']=T(SS+'DailyProgress.lua','Ur Gems are on the way!')
t['dq']=T(SS+'DailyProgress.lua','🤖 FREE MECH PACK! Check ur bag!')

print('all',len(t),'texts found in the source')


def n(text,kind='red',size=20):
    return f'<div class="n {kind}" style="font-size:{size}px">{E(text)}</div>'
def rich(s):
    # <font color="#xxxxxx">..</font> and <b> pass through, the rest is escaped
    parts=re.split(r'(<font color="#[0-9A-Fa-f]{6}">|</font>|<b>|</b>)',s)
    out=''
    for p in parts:
        if p.startswith('<font') or p in('</font>','<b>','</b>'): out+=p
        else: out+=E(p)
    return out
def font(c,text): return f'<font color="{c}">{E(text)}</font>'
pack='Verity Pack'
cards=[]
def card(title,sub,body,w=1): cards.append(f'<div class="card" style="grid-column:span {w}"><div class="ct">{E(title)} <i>{E(sub)}</i></div>{body}</div>')

# A. refusals and good news
card('Short notices','phone, top of the screen',
 '<div class="phone">'+n(t['cash'])+n(t['room'])+n(t['close'])+n(t['hold'])+n(t['base'])+n(t['maxed'])+n(t['picked'],'green')+n('SOLD! +$1.2K 💰','green')+n(t['bonus'],'yellow')+'</div>')

# B. sentence notices
dark=f'🌑 {font("#DDC3FF",t["darkened"])}  {font("#B88DFF","Two Void Packs")} are up in {font("#A2BBFF","Storm Peaks")}. {font("#FFCE40","Verity")} wants one!'
spawn=f'✨ A {font("#FFCE40","Rare Pack")}{E(t["spawn"])}{font("#3AE69D","Jungle")}!'
weather=f'🌈 {font("#FFFFFF","Your Apple plant")}{E(t["became"])}{font("#7FD6FF","Frosted")}!'
gift='🎁 '+font('#93FF45','Sunny')+' gave you '+font('#FFE547','Golden Apple')+'!'
card('Sentence notices','phone',
 '<div class="phone">'+''.join(f'<div class="n rich" style="font-size:17px">{x}</div>' for x in (dark,spawn,weather,gift))+
 f'<div class="n rich" style="font-size:17px">{E(t["vnote"])}{E(pack)}!</div>'+'</div>')

# C. Verity window
q=t['vq']+pack+'!'
card('Verity, phone upright','quest window',
 f'''<div class="vwin"><div class="vh">🌟 VERITY<span class="x">×</span></div>
 <div class="vq">{E(q)}</div><div class="vl purple">{E(t["vhere"])}</div>
 <div class="vchips"><div><small>{E(t["vvoid"])}</small>1</div><div><small>YOU GAVE ME</small>1</div></div>
 <div class="vex"><span class="pk v">✦</span>→<span class="pk g">☺</span><b>SWAP! 1 VOID PACK = 1 VERITY PACK</b></div>
 <div class="vs mint">Ooh, a Void Pack! Hand it over!</div>
 <div class="vb"><span class="gold">GIVE VOID PACK 🌑</span><span class="blue">BYE! 👋</span></div></div>
 <div class="phone" style="margin-top:10px"><div class="n rich" style="font-size:17px">{E(t["vthanks"])}{E(pack)}!</div>{n(t["vbusy"],"red",18)}</div>''')

# D. Bag
card('Bag','computer, open with the Bag button',
 f'''<div class="bag"><div class="bt">{E(t["bagtitle"])}<span class="x">×</span></div>
 <div class="search">Search</div>
 <div class="tabs"><span class="on">All</span><span>Seeds</span><span>Fruit</span><span>Tools</span></div>
 <div class="rar">Rarity: All</div>
 <div class="grid">{''.join('<span></span>' for _ in range(8))}</div>
 <div class="bh">{E(t["baghint"])}</div></div>
 <div class="phone" style="margin-top:10px">{n(t["room"])}</div>''')

# E. gem shop
card('Gem shop','Robux shop window',
 f'''<div class="shop"><div class="sh1">CASH TO GEMS</div><div class="sh2">250 Cash = 1 Gem</div>
 <div class="sh3">How many Gems?</div><div class="inp">{E(t["placeholder"])}</div>
 <div class="sh4"><span class="gold">MAX</span><span class="cyan">CONVERT</span></div>
 <div class="ways"><b>{E(t["gemwords"])}</b><br>{E(t["gemdetail"])}</div>
 <div class="stat">{E(t["grabgems"])}</div></div>
 <div class="phone" style="margin-top:10px">{n(t["already"],"yellow",18)}<div class="stat" style="margin-top:6px">{E(t["mech"])}</div></div>''')

# F. upgrade sign
card('Treadmill upgrade sign','in the world, after a press',
 f'''<div class="usign"><div class="u1">UPGRADE</div><div class="u2">LV 3  &gt;  LV 4</div><div class="u3">2x &gt; 3x</div><div class="u4">$14K</div></div>
 <div class="ubtn"><div>UPGRADE<br>TREADMILL</div><div class="hint">{E(t["upsave"])}</div></div>''')

# G. mystery pedestal
card('Mystery pack pedestal','signs over it + the prompt',
 f'''<div class="msigns"><div class="ms"><b class="gold">✨ {E(t["mystery_ur"])} MYSTERY PACK</b><br>{E(t["mystery_ready"])}</div>
 <div class="ms taken"><b class="mint">{E(t["mystery_taken"])}</b><br>NEW PACK IN 2h 46m</div></div>
 <div class="prompt"><span class="key">E</span><div><b>{E(t["mystery_take"])}</b><br><small>Mystery Pack</small></div></div>
 <div class="phone" style="margin-top:10px"><div class="n rich" style="font-size:17px">{E(t["mystery_note"])}</div>{n("🎒 "+t["mystery_room"],"yellow",18)}</div>''')

# H. chat
def chat(c,s): return f'<div class="chat" style="color:{c}">{rich(s)}</div>'
card('Chat announcements','pulls and records',
 '<div class="chatbox">'+
 chat('#FF7E4C','🌟 Ann'+t['pull_a']+'a <b>MYTHIC</b> Fire Pepper! (1/800)'+t['pull_nice'])+
 chat('#FFD046','🌐 Ben'+t['pull_a']+'a <b>SECRET</b> Obsidian Maw (1/1,000)!')+
 chat('#FFB020','🏆 Cam'+t['took']+'BEST PULL TODAY!')+
 chat('#FFB020','🏆 Dee'+t['took']+'BIGGEST FRUIT TODAY!')+'</div>')

# I. gifting
gq=t['give_q'].replace('%s','Golden Apple',1).replace('%s','Sunny',1)
card('Gifting','dialog + notice',
 f'''<div class="gdlg"><div class="g1">🎁 Give item?</div><div class="g2">{rich(gq)}</div><div class="g3"><span class="green">Give</span><span class="red">Cancel</span></div></div>
 <div class="phone" style="margin-top:10px">{n("Get closer to Sunny"+t["give_close"],"red",18)}{n("Hold the item u want to give.","red",18)}</div>''')

# J. void giveaway
card('Free Void Pack pedestal','sign, prompt, notices',
 f'''<div class="vgs"><small>FREE VOID PACK</small><b>487 / 500 LEFT</b><span>{E(t["void_hint"])}</span></div>
 <div class="prompt"><span class="key">E</span><div><b>{E(t["void_prompt"])}</b><br><small>Void Pack giveaway</small></div></div>
 <div class="phone" style="margin-top:10px"><div class="n rich" style="font-size:17px">{E(t["void_note"])}</div><div class="n rich amber" style="font-size:16px">{E(t["void_room"])}</div></div>''')

# K. shovel
sq=t['shovel_q'].replace('\n','<br>')
card('Shovel','remove a plant, dig holes',
 f'''<div class="gdlg"><div class="g1">Remove Apple{sq.split('<br>')[0]}</div><div class="g2">{E(sq.split('<br>')[1].replace('&#x27;',"'"))}</div><div class="g3"><span class="red">Remove</span><span class="blue">Keep plant</span></div></div>
 <div class="phone" style="margin-top:10px">{n(t["hole_hint"],"white",18)}{n(t["hole_ground"],"orange",18)}{n(t["hole_cap"].replace("%d","3"),"orange",18)}</div>''')

# L. daily
card('Daily rewards','quest done notice, claim answer',
 f'''<div class="phone">{n("✅ QUEST DONE: Steal 3 packs"+t["quest_done"]+"5 in 🎁 DAILY","green",17)}</div>
 <div class="shop" style="margin-top:10px"><div class="sh1">📜 DAILY QUESTS</div><div class="qrow"><span>🎒 Steal 3 packs</span><span class="gold">CLAIM</span></div><div class="stat">{E(t["daily_gems"])}</div></div>
 <div class="phone" style="margin-top:10px"><div class="n rich" style="font-size:17px">{E(t["dq"])}</div></div>''')

# M. small ones
card('Sell, hub board, tips','market line, board plaque, E hint',
 f'''<div class="shop"><div class="stat" style="margin:0 0 8px">{E(t["market"])}</div>
 <div class="plaque"><small>BEST PULL TODAY</small><b>Nobody yet</b><span>{E(t["hubcl"])}</span></div>
 <div class="stat" style="margin-top:8px">Press E{E(t["pick"])}</div></div>''')

# N. title / esc / kick
card('Title, Esc menu, disconnect','',
 f'''<div class="title"><div>STEAL A</div><div>PACK</div><span>{E(t["title_click"])}</span></div>
 <div class="esc">🌱 {E(t["offline"])}</div>
 <div class="kick"><b>Disconnected</b><br>{E(t["kick"])}</div>''',1)

CSS='''
@font-face{font-family:F;src:url('../../shop_R120/tests/FredokaOne.ttf')}
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0e1120;color:#dfe6ff;font-family:F,"Noto Color Emoji",sans-serif;width:1522px;padding:26px 28px 30px}
h1{font-weight:400;font-size:34px;color:#fff}
.sub{font-size:16px;color:#9fb0e8;margin:4px 0 20px;max-width:1360px;line-height:1.35}
.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:22px;align-items:start}
.card{background:#151a33;border-radius:14px;padding:14px 16px 16px;box-shadow:0 0 0 2px #232a52}
.ct{font-size:19px;color:#ffd75a;margin-bottom:10px}.ct i{font-style:normal;color:#8d9bd4;font-size:13px;margin-left:6px}
.phone{background:linear-gradient(180deg,#27346b,#1a2147);border-radius:12px;padding:12px 10px;width:100%;display:flex;flex-direction:column;gap:6px;align-items:center}
.n{font-size:20px;text-align:center;color:#fff;line-height:1.15;-webkit-text-stroke:5px #000;paint-order:stroke fill;padding:2px 6px}
.n.red{color:#ff3741}.n.green{color:#41eb7d}.n.yellow{color:#ffd746}.n.white{color:#fff}.n.orange{color:#ffbb5b}.n.amber{color:#ffbe5a}
.lbl,.vq,.vl,.vs,.vb span,.stat,.sh1,.sh2,.sh3,.g1,.g2,.u1,.u2,.u3,.u4,.hint,.bt,.bh,.search,.tabs span,.rar,.ms,.key,.prompt b,.vgs,.plaque,.title div,.esc,.kick,.chat,.vh,.vchips,.vex b,.ways,.inp,.qrow{-webkit-text-stroke:3px #080d18;paint-order:stroke fill;color:#fff}
.vwin{background:linear-gradient(180deg,#414c8f,#191e40);border-radius:9px;box-shadow:0 0 0 3px #0c1126;overflow:hidden;width:338px;margin:0 auto}
.vh{background:linear-gradient(160deg,#b8ff6f,#40c94b);padding:8px 12px;font-size:22px;position:relative}.x{position:absolute;right:6px;top:6px;background:#e1344d;border-radius:6px;width:30px;text-align:center;font-size:20px}
.vq{padding:12px 12px 6px;font-size:17px;line-height:1.15;text-align:center}
.vl{text-align:center;font-size:15px;padding:4px}.purple{color:#d0a8ff}.mint{color:#7cf0a8}.gold{color:#ffe08a}.cyan{color:#9be7ff}.green{color:#7cf0a8}.red{color:#ff8a9c}.blue{color:#9bb3ff}
.vchips{display:flex;gap:8px;padding:2px 12px;font-size:22px;text-align:center}.vchips div{flex:1;background:#30366a;border-radius:10px;padding:2px;box-shadow:inset 0 0 0 2px #ffce40}.vchips small{display:block;font-size:11px}
.vex{display:flex;align-items:center;gap:8px;padding:8px 12px;font-size:20px}.vex b{font-weight:400;font-size:15px;text-align:center;flex:1}
.pk{display:inline-block;width:42px;height:52px;border-radius:8px;text-align:center;line-height:52px;font-size:24px}.pk.v{background:#2a1a5a;box-shadow:0 0 0 2px #8a6bff}.pk.g{background:#ffd23a;color:#000;-webkit-text-stroke:0}
.vs{text-align:center;font-size:15px;padding:2px 12px 6px}.vb{display:flex;gap:8px;padding:4px 12px 12px;font-size:19px}.vb span{flex:1;border-radius:6px;text-align:center;padding:8px 2px;box-shadow:0 0 0 2px #0c1126}.vb .gold{background:linear-gradient(180deg,#ffd75a,#e1a12a)}.vb .blue{background:linear-gradient(180deg,#7d95ff,#4a63d6)}
.bag{background:#232a52;border-radius:12px;padding:12px;width:100%}.bt{font-size:22px;position:relative;margin-bottom:8px}.search{background:#161b38;border-radius:8px;padding:6px 10px;margin-bottom:8px;font-size:15px;color:#8d9bd4}
.tabs{display:flex;gap:6px;margin-bottom:6px}.tabs span{flex:1;background:#30366a;border-radius:8px;padding:10px 0;text-align:center;font-size:14px}.tabs .on{background:#4a63d6}
.rar{background:#30366a;border-radius:8px;padding:5px 10px;margin-bottom:8px;font-size:15px}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin-bottom:8px}.grid span{background:#161b38;border-radius:8px;height:46px}
.bh{font-size:12px;color:#aab6ea}
.shop{background:#232a52;border-radius:12px;padding:12px;width:100%}.sh1{font-size:20px;color:#bff0ff}.sh2{font-size:16px;margin-top:2px}.sh3{font-size:14px;margin-top:6px}
.inp{background:#181a28;border-radius:8px;padding:6px 10px;margin-top:4px;font-size:16px;color:#7f86a8}.sh4{display:flex;gap:8px;margin-top:8px;font-size:17px}.sh4 span{flex:1;text-align:center;border-radius:8px;padding:7px;background:#30366a}
.ways{margin-top:10px;font-size:14px;line-height:1.3;background:#2d3566;border-radius:8px;padding:8px}.ways b{font-weight:400;color:#ffe08a;font-size:16px}
.stat{background:#10121a;border-radius:8px;padding:6px 10px;color:#7cf0a8;font-size:16px;margin-top:8px;text-align:center}
.usign{background:#3b2f63;border-radius:10px;padding:10px;text-align:center;box-shadow:0 0 0 4px #b076ff;width:78%;margin:6px auto}.u1{font-size:30px}.u2{font-size:20px;color:#e2c8ff}.u3{font-size:18px;color:#b076ff}.u4{background:#c84241;border-radius:10px;font-size:28px;margin-top:6px;padding:2px}
.ubtn{background:#c84241;border-radius:12px;margin:10px auto 0;width:78%;text-align:center;padding:10px;font-size:26px;line-height:1.1;box-shadow:0 0 0 4px #8a2c2c}.hint{font-size:20px;margin-top:8px;color:#fff}
.msigns{display:flex;gap:8px}.ms{flex:1;background:#2a1e58;border-radius:12px;padding:8px;text-align:center;font-size:14px;box-shadow:0 0 0 2px #8a6bff;line-height:1.3}.ms b{font-weight:400;font-size:15px}.ms.taken{background:#0e2420;box-shadow:0 0 0 2px #48a06c}
.prompt{display:flex;align-items:center;gap:10px;background:#0b0e1c;border-radius:12px;padding:8px 12px;margin-top:10px;box-shadow:0 0 0 2px #3a4170}.key{width:30px;height:30px;border-radius:50%;background:#fff;color:#000;-webkit-text-stroke:0;text-align:center;line-height:30px;font-size:18px}.prompt b{font-weight:400;font-size:19px}.prompt small{font-size:13px;color:#aab6ea}
.chatbox{background:rgba(0,0,0,.45);border-radius:10px;padding:10px;display:flex;flex-direction:column;gap:6px}.chat{font-size:15px;line-height:1.2;-webkit-text-stroke:0;paint-order:normal;font-family:F,"Noto Color Emoji",sans-serif}
.gdlg{background:#232a52;border-radius:12px;padding:12px;text-align:center}.g1{font-size:21px;color:#ffe08a}.g2{font-size:16px;margin:8px 0;line-height:1.25}.g3{display:flex;gap:8px;font-size:17px}.g3 span{flex:1;border-radius:8px;padding:8px;background:#30366a}
.vgs{background:#241a4a;border-radius:12px;padding:10px;text-align:center;box-shadow:0 0 0 2px #8a6bff}.vgs small{display:block;font-size:13px;color:#d0b8ff}.vgs b{display:block;font-weight:400;font-size:30px;color:#ffe08a}.vgs span{font-size:13px;color:#aab6ea}
.qrow{display:flex;justify-content:space-between;align-items:center;margin-top:8px;background:#30366a;border-radius:8px;padding:8px;font-size:16px}.qrow .gold{background:#e1a12a;border-radius:6px;padding:4px 10px}
.plaque{background:#1d2650;border-radius:10px;padding:8px;text-align:center;box-shadow:0 0 0 2px #ffce40;line-height:1.3}.plaque small{display:block;font-size:13px;color:#ffe08a}.plaque b{display:block;font-weight:400;font-size:20px}.plaque span{font-size:13px;color:#aab6ea}
.title{background:radial-gradient(circle at 50% 40%,#3b5bd1,#10183c);border-radius:12px;padding:18px;text-align:center}.title div{font-size:38px;line-height:1}.title span{display:block;margin-top:12px;font-size:16px;color:#fff}
.esc{margin-top:10px;font-size:34px;text-align:center;background:linear-gradient(90deg,#ff7a7a,#ffd36b,#7aff9a,#7ad3ff,#c77aff);-webkit-background-clip:text;color:transparent;-webkit-text-stroke:4px #16102a;paint-order:stroke fill}
.kick{margin-top:10px;background:#393b3d;border-radius:8px;padding:12px;font-size:15px;line-height:1.35;-webkit-text-stroke:0;color:#eee;font-family:Arial,sans-serif}
'''
body='<h1>The game\'s words, in the owner\'s voice</h1><div class="sub">The most-seen screens and notices with the R152 text. Not the game: an HTML drawing with the real FredokaOne, laid out roughly like the game. Every text on this sheet is looked up in the source when the sheet is built (docs/proposals/R152/preview/build_game_text_sheet.py), so it cannot drift from the code.</div><div class="grid3">'+''.join(cards)+'</div>'
open(os.path.join(HERE,'game_text.html'),'w',encoding='utf8').write(f'<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Game text, R152</title><style>{CSS}</style></head><body>{body}</body></html>')
print('ok',len(cards),'cards')
