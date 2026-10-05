--!nocheck
-- R151 pull announcements, part 1: PullAnnounceRules (the shared pure rules) on the Roblox mock with the REAL modules (SeedPackRules, GardenDisplayNames,
-- VerityCatalog, OddsText85, HudNoticeLayout, ItemWeight):
--  1. thresholds: InServerMinRarity (Legendary) and GlobalMinRarity (Secret = Secret, Cosmic, King and anything above), the Studio attribute overrides
--  2. events: every field sanitised (markup, control and direction characters, long names, odds, size, coat, record keys), the rarity ALWAYS from the catalog
--  3. text: the banner sentence, the other-server sentence, the record sentence, the chat line and its colour, the small line, the headline per rarity, the odds format
--  4. the queue: at most 3 waiting, a flood keeps the best rarity and counts "+N more", records first, late banners dropped, timing, the chat rate limit
--  5. the payload: compact / expand round trip, the 1 kB batch, freshness (stale and future messages)
local W=require('./world');local R=W.R;local E=require('./announce_env')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=W.module('PullAnnounceRules');local Packs=W.module('SeedPackRules');local Odds=W.module('OddsText85')
local Mod=W.RS.PullAnnounceRules
-- a real King and a real Cosmic seed of the roster (not the retired aliases): the first of each in the catalog
local function firstOf(rarity)for _,spec in ipairs(Packs.SeedDesigns)do if spec.id~='VeritySeed'and Packs.GetRarity(spec.id)==rarity then return spec end end end
local KING,COSMIC=firstOf('King'),firstOf('Cosmic')
local KINGNAME=Rules.SeedInfo(KING.id).Name
local function reset()for k in pairs(Rules.Defaults)do Mod:SetAttribute(k,nil)end end

-- 1. thresholds -------------------------------------------------------------------------------------------------------------------------------------
do
 local inServer={Common=false,Uncommon=false,Rare=false,Legendary=true,Mythic=true,Secret=true,Cosmic=true,King=true}
 local global={Common=false,Uncommon=false,Rare=false,Legendary=false,Mythic=false,Secret=true,Cosmic=true,King=true}
 for _,name in ipairs(Packs.RarityOrder)do
  check(Rules.Qualifies('InServer',name)==inServer[name],'in-server banner at '..name..' = '..tostring(inServer[name]))
  check(Rules.Qualifies('Global',name)==global[name],'all-server shout at '..name..' = '..tostring(global[name]))
 end
 check(Rules.Defaults.InServerMinRarity=='Legendary'and Rules.Defaults.GlobalMinRarity=='Secret'and Rules.Setting('InServerMinRarity')=='Legendary'and Rules.Setting('GlobalMinRarity')=='Secret','the defaults: Legendary in the server, Secret across servers')
 check(not Rules.Qualifies('InServer','Banana')and not Rules.Qualifies('Global',nil)and not Rules.Qualifies('Global',7)and not Rules.Qualifies('InServer',''),'unknown rarities (a bad name, nil, a number) never qualify')
 check(Rules.Rank('King')==8 and Rules.Rank('Common')==1 and Rules.Rank('Banana')==0,'ranks come from SeedPackRules.Rarities')
 -- "Secret, Cosmic, King and anything above": a future rarity with a higher rank qualifies without a code change
 Packs.Rarities.Mythical={Rank=9,Weight=.001,Color=R.Color3.fromRGB(255,255,255)}
 check(Rules.Qualifies('Global','Mythical')and Rules.Qualifies('InServer','Mythical'),'a rarity above King (rank 9) qualifies for both')
 check(Rules.Headline({Kind='Pull',Rarity='Mythical'})=='MYTHICAL PULL!','... and has a plain headline')
 Packs.Rarities.Mythical=nil
 -- Studio overrides (an attribute on the module), never trusted when invalid
 Mod:SetAttribute('InServerMinRarity','Mythic')
 check(not Rules.Qualifies('InServer','Legendary')and Rules.Qualifies('InServer','Mythic'),'InServerMinRarity = Mythic: Legendary is no longer shown, Mythic is')
 Mod:SetAttribute('GlobalMinRarity','Cosmic')
 check(not Rules.Qualifies('Global','Secret')and Rules.Qualifies('Global','Cosmic')and Rules.Qualifies('Global','King'),'GlobalMinRarity = Cosmic: Secret stays home, Cosmic and King travel')
 Mod:SetAttribute('InServerMinRarity','Banana');Mod:SetAttribute('GlobalMinRarity',5)
 check(Rules.Setting('InServerMinRarity')=='Legendary'and Rules.Setting('GlobalMinRarity')=='Secret','an invalid override (an unknown rarity, a number) falls back to the default')
 reset()
 Mod:SetAttribute('BannerSeconds',99);Mod:SetAttribute('MaxWaiting',-1);Mod:SetAttribute('PublishGapSeconds',0)
 check(Rules.Setting('BannerSeconds')==4 and Rules.Setting('MaxWaiting')==3 and Rules.Setting('PublishGapSeconds')==5,'numbers outside their limits are ignored (4 s, 3 waiting, 5 s)')
 Mod:SetAttribute('BannerSeconds',6);Mod:SetAttribute('MaxWaiting',1)
 check(Rules.Setting('BannerSeconds')==6 and Rules.Setting('MaxWaiting')==1,'numbers inside their limits are used')
 reset()
 check(Rules.Topic=='PullAnnounce151'and Rules.RemoteName=='PullAnnounce151','topic and remote names')
end

-- 2. events -----------------------------------------------------------------------------------------------------------------------------------------
do
 local fire={Name='Ann',UserId=12345,Id='ab12-3',SeedId='FirePepperSeed',Odds=800,Size=1.2344,Mutation='Gold',At=1700000000}
 local e=Rules.Event('Pull',fire)
 check(e and e.Kind=='Pull'and e.Name=='Ann'and e.UserId==12345 and e.Id=='ab12-3'and e.SeedId=='FirePepperSeed'and e.SeedName=='Fire Pepper'and e.Rarity=='Mythic'and e.Odds==800
  and e.Size==1.234 and e.Mutation=='Gold'and e.At==1700000000,'a good pull: name, id, seed, display name, rarity, odds, size to 3 places, coat, time')
 -- the rarity is the catalog's, whatever the sender claims
 local liar=Rules.Event('Global',{Name='Bo',SeedId='SunflowerSeed',Rarity='King',Id='x-1',Odds=2})
 check(liar and liar.Rarity==Packs.GetRarity('SunflowerSeed')and liar.Rarity~='King','a message that claims King for a Common seed gets the catalog rarity ('..tostring(liar and liar.Rarity)..')')
 check(Rules.Event('Pull',{Name='Cy',SeedId='NoSuchSeed',Odds=5})==nil and select(2,Rules.Event('Pull',{Name='Cy',SeedId='NoSuchSeed'}))=='seed','an unknown seed is refused')
 check(Rules.Event('Pull',{Name='Cy'})==nil and Rules.Event('Global',{Name='Cy'})==nil,'a pull without a seed is refused')
 check(Rules.Event('Record',{Name='Cy',Record='BestPull'})~=nil,'a record needs no seed')
 check(Rules.Event('Chat',fire)==nil and Rules.Event(nil,fire)==nil and Rules.Event('Pull',nil)==nil and Rules.Event('Pull','x')==nil,'unknown kinds and non-table fields are refused')
 -- names
 local function name(n)local ev=Rules.Event('Pull',{Name=n,SeedId='FirePepperSeed'});return ev and ev.Name end
 check(name('<b>Hax</b>')=='bHax/b','markup characters are removed ('..tostring(name('<b>Hax</b>'))..')')
 check(name('A&B "q" \'s\'')=='AB q s','& and quotes are removed')
 check(name('Zed\n\t\r  X')=='Zed X','control characters and runs of spaces become one space')
 check(name('a\u{202E}b\u{200B}c\u{2066}d')=='a b c d','right-to-left overrides, zero-width and isolate characters are blanked')
 check(name('   ')==nil and name('')==nil and name('<>&')==nil and name(nil)==nil and name(5)==nil and name(string.rep('x',201))==nil,'nothing printable left (spaces, empty, only markup, nil, a number, 201 bytes) = no event')
 check(name('\255\254bad')==nil,'invalid UTF-8 is refused')
 check(name(string.rep('x',40))==string.rep('x',24),'at most 24 characters')
 check(name(string.rep('é',40))==string.rep('é',24)and utf8.len(name(string.rep('é',40)))==24,'... counted in characters, not bytes (accents are not cut in half)')
 check(name('🌟Star🌟')=='🌟Star🌟','emoji are kept')
 Mod:SetAttribute('MaxNameLength',10);check(name(string.rep('y',40))==string.rep('y',10),'MaxNameLength is a tunable');reset()
 -- user id, odds, size, coat, ids
 local function field(k,v)local f=table.clone(fire);f[k]=v;return Rules.Event('Pull',f)end
 check(field('UserId',-5).UserId==0 and field('UserId',1.5).UserId==0 and field('UserId','7').UserId==0 and field('UserId',2^60).UserId==0 and field('UserId',0/0).UserId==0,'a bad user id becomes 0 (negative, fractional, a string, huge, NaN)')
 check(field('Odds',0.5).Odds==nil and field('Odds',0/0).Odds==nil and field('Odds',math.huge).Odds==nil and field('Odds',2e15).Odds==nil and field('Odds','5').Odds==nil and field('Odds',1).Odds==1,'odds must be 1 .. 1e15')
 check(field('Size',0).Size==nil and field('Size',-1).Size==nil and field('Size',1001).Size==nil and field('Size',0/0).Size==nil and field('Size',25).Size==25,'size must be .001 .. 1000')
 check(field('Mutation','Rainbow').Mutation=='None'and field('Mutation',nil).Mutation=='None'and field('Mutation','Diamond').Mutation=='Diamond','only Gold and Diamond coats; anything else is None')
 check(field('Id','bad id!').Id==nil and field('Id',string.rep('a',49)).Id==nil and field('Id',5).Id==nil and field('Id','ok_1:2-3').Id=='ok_1:2-3','ids: letters, digits, - _ : up to 48')
 check(field('At',-1).At==nil and field('At','now').At==nil and field('At',1.7e9).At==1700000000,'the time must be a number')
 -- records
 local rec=Rules.Event('Record',{Name='Dee',UserId=9,Record='BestPull',SeedId=KING.id,Size=20})
 check(rec and rec.Record=='BestPull'and rec.Rarity=='King'and rec.SeedName==KINGNAME,'a record with a seed ('..KINGNAME..')')
 check(Rules.Event('Record',{Name='Dee',Record='Best Pull!'}).Record=='Record'and Rules.Event('Record',{Name='Dee',Record=string.rep('A',25)}).Record=='Record'and Rules.Event('Record',{Name='Dee',Record=7}).Record=='Record'
  and Rules.Event('Record',{Name='Dee',Record='LongestFruit'}).Record=='LongestFruit','record keys are letters only, up to 24; anything else is the plain "Record"')
 check(Rules.Event('Pull',fire).Record==nil,'a pull has no record key')
 -- every roster seed the game can roll has a name and a real rarity
 local bad=0;for _,spec in ipairs(Packs.SeedDesigns)do local info=Rules.SeedInfo(spec.id);if not info or info.Name==''or not Packs.Rarities[info.Rarity]then bad+=1 end end
 check(bad==0,'all '..#Packs.SeedDesigns..' catalog seeds (roster, Mech, Verity) resolve to a name and a rarity')
 check(Rules.SeedInfo('VeritySeed').Name=='Verity Seed'and Rules.SeedInfo('VeritySeed').Rarity=='King','the Verity seed reads "Verity Seed" (King)')
 check(Rules.SeedInfo(nil)==nil and Rules.SeedInfo(5)==nil and Rules.SeedInfo(string.rep('a',61))==nil and Rules.SeedInfo('')==nil,'bad seed ids')
end

-- 3. text -------------------------------------------------------------------------------------------------------------------------------------------
do
 local pull=Rules.Event('Pull',{Name='Ann',UserId=1,Id='a-1',SeedId='FirePepperSeed',Odds=800})
 check(Rules.Line(pull)=='🌟 Ann pulled a MYTHIC Fire Pepper! (1/800)','the in-server sentence: "'..Rules.Line(pull)..'"')
 local sec=Rules.Event('Global',{Name='Ann',UserId=1,Id='a-2',SeedId='ObsidianMawSeed',Odds=1000})
 check(Rules.Line(sec)=='🌐 Ann pulled a SECRET Obsidian Maw (1/1,000)!','the other-server sentence: "'..Rules.Line(sec)..'"')
 check(Rules.Line(Rules.Event('Pull',{Name='Ann',SeedId='FirePepperSeed'}))=='🌟 Ann pulled a MYTHIC Fire Pepper!','no odds known = no odds in the sentence')
 check(Rules.Line(Rules.Event('Global',{Name='Ann',Id='a-3',SeedId='ObsidianMawSeed'}))=='🌐 Ann pulled a SECRET Obsidian Maw!','... also for another server')
 local rec=Rules.Event('Record',{Name='Ann',Record='BestPull'})
 check(Rules.Line(rec)=='🏆 Ann took BEST PULL TODAY!','the record sentence: "'..Rules.Line(rec)..'"')
 check(Rules.Line(Rules.Event('Record',{Name='Ann',Record='BiggestFruit'}))=='🏆 Ann took BIGGEST FRUIT TODAY!'and Rules.Line(Rules.Event('Record',{Name='Ann',Record='LongestFruit'}))=='🏆 Ann took LONGEST FRUIT!','record titles: known keys and a CamelCase key spelled out')
 check(Rules.Article('MYTHIC')=='a'and Rules.Article('ELITE')=='an'and Rules.Article('')=='a','a / an')
 -- rich text: the rarity word in its colour
 local rich=Rules.Line(pull,true)
 local hex=Rules.Hex(Rules.RarityColor('Mythic'))
 check(rich=='🌟 Ann pulled a <font color="'..hex..'">MYTHIC</font> Fire Pepper! (1/800)','the banner line colours only the rarity word ('..rich..')')
 check(Rules.Hex(Rules.RarityColor('Mythic'))==string.format('#%02X%02X%02X',230,125,255)or Rules.Hex(Rules.RarityColor('Mythic')):match('^#%x%x%x%x%x%x$')~=nil,'colours are #RRGGBB')
 -- every name and seed name is escaped in rich text (a seed name with an apostrophe or an ampersand)
 local nasty={Kind='Pull',Name='A<b>',SeedName="Dragon's & <i>Fruit</i>",Rarity='Mythic',Odds=5}
 local line=Rules.Line(nasty,true)
 check(line:find('<i>',1,true)==nil and line:find('&amp;',1,true)~=nil and line:find('&apos;',1,true)~=nil and line:find('&lt;i&gt;',1,true)~=nil,'rich text escapes markup in any name ('..line..')')
 check(Rules.Line(nasty,false):find("Dragon's & <i>Fruit</i>",1,true)~=nil,'plain text is left as it is (it is never parsed)')
 -- chat: rarity colour in this server, gold from another one, amber for records; one colour for the whole line
 local chat=Rules.Chat(pull)
 check(chat==('<font color="%s">🌟 Ann pulled a MYTHIC Fire Pepper! (1/800)</font>'):format(hex),'the chat line is one colour run in the rarity colour ('..chat..')')
 check(Rules.Chat(sec)==('<font color="%s">🌐 Ann pulled a SECRET Obsidian Maw (1/1,000)!</font>'):format(Rules.Hex(Rules.Gold)),'an other-server chat line is gold')
 check(Rules.Chat(rec):find(Rules.Hex(Rules.Amber),1,true)~=nil and Rules.Chat(rec):find('BEST PULL TODAY',1,true)~=nil,'a record chat line is amber')
 check(Rules.ChatColor(pull)==Rules.RarityColor('Mythic')and Rules.ChatColor(sec)==Rules.Gold and Rules.ChatColor(rec)==Rules.Amber,'ChatColor (the old-chat fallback) matches')
 check(Rules.Gold.R==1 and Rules.Gold.G>.8 and Rules.Gold.B<.4,'gold is gold')
 -- the small line
 local sub=Rules.Subline(Rules.Event('Pull',{Name='Ann',SeedId='FirePepperSeed',Mutation='Gold',Size=1}))
 check(sub:find('Lava seed',1,true)==1 and sub:find('GOLD',1,true)~=nil and sub:find('kg',1,true)~=nil,'the small line of a pull: biome, coat, weight ('..sub..')')
 check(Rules.Subline(Rules.Event('Pull',{Name='Ann',SeedId='FirePepperSeed'}),2):find('+2 more',1,true)~=nil,'... and "+2 more" when banners were merged into it')
 check(Rules.Subline(Rules.Event('Pull',{Name='Ann',SeedId='FirePepperSeed'}),0):find('more',1,true)==nil,'... but not for 0')
 check(Rules.Subline(sec):sub(1,17)=='in another server','the small line of an other-server pull starts "in another server" ('..Rules.Subline(sec)..')')
 check(Rules.Subline(Rules.Event('Record',{Name='Ann',Record='BestPull'}))=='congratulations!','a record without a seed: "congratulations!"')
 check(Rules.Subline(Rules.Event('Record',{Name='Ann',Record='BestPull',SeedId='FirePepperSeed',Size=2})):find('MYTHIC Fire Pepper',1,true)~=nil,'a record with a seed names it')
 -- headlines and effects by rarity
 local want={Legendary='LEGENDARY PULL!',Mythic='MYTHIC PULL!!',Secret='SECRET PULL!!!',Cosmic='COSMIC PULL!!!',King='KING PULL!!!!'}
 for name,text in pairs(want)do check(Rules.Headline({Kind='Pull',Rarity=name})==text,'headline '..name..' = '..text)end
 check(Rules.Headline({Kind='Record'})=='🏆 NEW RECORD!','headline of a record')
 check(Rules.Fx({Kind='Pull',Rarity='Legendary'}).Sparkles==4 and not Rules.Fx({Kind='Pull',Rarity='Legendary'}).Shine and Rules.Fx({Kind='Pull',Rarity='King'}).Sparkles==18 and Rules.Fx({Kind='Pull',Rarity='Secret'}).Shine,'sparkles grow with rarity; the shine starts at Mythic')
 check(Rules.Fx({Kind='Global',Rarity='King'}).Sparkles==12,'an other-server banner never goes past the Secret treatment')
 check(Rules.Variant(sec)=='Small'and Rules.Variant(pull)=='Full'and Rules.Variant(rec)=='Full','variants: Small for other servers')
 check(Rules.Accent(pull)==Rules.RarityColor('Mythic')and Rules.Accent(sec)==Rules.Gold and Rules.Accent(rec)==Rules.Amber,'frame colours: rarity, gold, amber')
 -- cues
 check(Rules.Cue(pull).Rank==5 and Rules.Cue(Rules.Event('Pull',{Name='A',SeedId=KING.id})).Rank==8 and Rules.Cue(rec).Rank==5 and Rules.Cue(sec).Key=='Chime','sound cues: the rarity burst; a quiet chime for another server')
 -- odds format = the game's
 local same=true
 for _,n in ipairs({1,2,6,26,800,1000,1250,9999,12500,240000,1e6,1.67e9,1e12,1e15})do
  if Rules.OddsLabel(n)~=Odds.Format(100/n)then same=false;print('odds mismatch',n,Rules.OddsLabel(n),Odds.Format(100/n))end
 end
 check(same,'the odds read exactly like OddsText85.Format (1/800, 1/1,000, 1/13K ...)')
 check(Rules.OddsLabel(0)==nil and Rules.OddsLabel(nil)==nil and Rules.OddsLabel(0/0)==nil and Rules.OddsLabel(.5)==nil,'no odds for a bad number')
end

-- 4. the queue, timing, chat limit ---------------------------------------------------------------------------------------------------------------------
do
 local function ev(seed,kind)return Rules.Event(kind or'Pull',{Name='N',Id='i-'..math.random(1,1e9),SeedId=seed,Odds=100})end
 local leg,myth,sec,cos,king='SunflowerBloomSeed','FirePepperSeed','ObsidianMawSeed',COSMIC.id,KING.id
 local q=Rules.NewQueue()
 check(Rules.Enqueue(q,ev(leg),0)and Rules.Enqueue(q,ev(myth),1)and Rules.Enqueue(q,ev(sec),2)and#q.Items==3 and q.Dropped==0,'three banners wait')
 check(Rules.Enqueue(q,ev(cos),3)==true and#q.Items==3 and q.Dropped==1,'a fourth (Cosmic) evicts the lowest rarity (the Legendary)')
 local ranks={};for _,it in ipairs(q.Items)do ranks[#ranks+1]=Rules.Rank(it.Event.Rarity)end
 check(table.concat(ranks,',')=='5,6,7','... the others keep their order (Mythic, Secret, Cosmic)')
 local best;for _,it in ipairs(q.Items)do if it.More>0 then best=it end end
 check(best and best.Event.Rarity=='Cosmic'and best.More==1,'... and the best waiting banner (Cosmic) says "+1 more"')
 check(Rules.Enqueue(q,ev(leg),4)==false and#q.Items==3 and q.Dropped==2,'a new Legendary under three better ones is itself the one dropped')
 check(best.More==2,'... and counted on the best banner (+2 more)')
 -- equal rarity: the oldest goes
 local q2=Rules.NewQueue();local ids={}
 for i=1,3 do local e=ev(myth);ids[i]=e.Id;Rules.Enqueue(q2,e,i)end
 local fourth=ev(myth);Rules.Enqueue(q2,fourth,4)
 local left={};for _,it in ipairs(q2.Items)do left[#left+1]=it.Event.Id end
 check(#left==3 and left[1]==ids[2]and left[2]==ids[3]and left[3]==fourth.Id,'among equals the OLDEST goes')
 -- records first; an other-server pull ranks under a pull of the same rarity here
 local q3=Rules.NewQueue()
 Rules.Enqueue(q3,ev(sec,'Global'),0);Rules.Enqueue(q3,ev(sec),1);Rules.Enqueue(q3,ev(king),2);Rules.Enqueue(q3,Rules.Event('Record',{Name='R',Record='BestPull'}),3)
 local kinds={};for _,it in ipairs(q3.Items)do kinds[#kinds+1]=it.Event.Kind end
 check(table.concat(kinds,',')=='Pull,Pull,Record','a record survives; the Secret pull from another server is the one that goes ('..table.concat(kinds,',')..')')
 check(Rules.Priority(Rules.Event('Record',{Name='R'}))>Rules.Priority(ev(king))and Rules.Priority(ev(sec))>Rules.Priority(ev(sec,'Global')),'priority: record > any pull; here > another server at the same rarity')
 -- a flood
 local q4=Rules.NewQueue();local total=0
 for i=1,60 do local seed=({leg,myth,sec,cos,king})[i%5+1];total+=1;Rules.Enqueue(q4,ev(seed),i*.01)end
 local carried=0;for _,it in ipairs(q4.Items)do carried+=it.More end
 check(#q4.Items==3 and#q4.Items+carried==total,'a flood of 60: 3 wait and every other one is counted in a "+N more" ('..#q4.Items..' + '..carried..' = '..total..')')
 local top=0;for _,it in ipairs(q4.Items)do top=math.max(top,Rules.Rank(it.Event.Rarity))end
 check(top==8,'... and the best of them (King) survived the flood')
 -- dequeue is first in, first out, and drops banners that waited too long
 local q5=Rules.NewQueue();local a,b=ev(leg),ev(myth);Rules.Enqueue(q5,a,0);Rules.Enqueue(q5,b,15)
 local first=Rules.Dequeue(q5,25)
 check(first and first.Event==b and q5.Dropped==1,'a banner that waited more than 20 s is dropped, the next one shows')
 check(Rules.Dequeue(q5,26)==nil and Rules.Dequeue(Rules.NewQueue(),0)==nil,'an empty queue gives nothing')
 local q6=Rules.NewQueue();Rules.Enqueue(q6,a,0);Rules.Enqueue(q6,b,1)
 check(Rules.Dequeue(q6,2).Event==a and Rules.Dequeue(q6,2).Event==b,'first in, first out')
 Mod:SetAttribute('MaxWaiting',0);local q7=Rules.NewQueue()
 check(Rules.Enqueue(q7,ev(king),0)==false and#q7.Items==0,'MaxWaiting 0 queues nothing');reset()
 Mod:SetAttribute('MaxWaiting',1);local q8=Rules.NewQueue();Rules.Enqueue(q8,ev(leg),0);Rules.Enqueue(q8,ev(king),1)
 check(#q8.Items==1 and q8.Items[1].Event.Rarity=='King'and q8.Items[1].More==1,'MaxWaiting is a tunable');reset()
 -- timing
 local t=Rules.Timing(0,false)
 check(math.abs(t.In+t.Hold+t.Out-4)<1e-9 and t.In>0 and t.Out>0,'one banner lasts 4 s: slide in '..t.In..' + hold '..t.Hold..' + slide out '..t.Out)
 local t1,t2=Rules.Timing(1,false),Rules.Timing(2,false)
 check(t1.Hold<t.Hold and t2.Hold<t1.Hold and t2.Hold>=1.2,'a backlog shortens the hold (never under 1.2 s): '..t.Hold..' > '..t1.Hold..' > '..t2.Hold)
 local tr=Rules.Timing(0,true)
 check(tr.In==0 and tr.Out==0 and math.abs(tr.Hold-4)<1e-9,'ReducedMotion: no slide, the banner holds the whole 4 s')
 Mod:SetAttribute('BannerSeconds',2);check(Rules.Timing(0,false).Hold>=1.2,'a short BannerSeconds still holds 1.2 s');reset()
 -- chat limit
 local log={};local ok=0;for i=1,12 do if Rules.ChatAllowed(log,i*.1)then ok+=1 end end
 check(ok==8,'at most 8 chat lines in 10 s ('..ok..')')
 check(Rules.ChatAllowed(log,5)==false and Rules.ChatAllowed(log,11.0)==true,'... still refused at 5 s, and allowed again once the window has moved on (the first lines are over 10 s old)')
end

-- 5. payload ----------------------------------------------------------------------------------------------------------------------------------------
do
 local e=Rules.Event('Pull',{Name='Ann',UserId=77,Id='ab12cd34-5',SeedId='FirePepperSeed',Odds=799.6,Size=1.5,Mutation='Gold'})
 local back=Rules.Event('Global',Rules.Expand(Rules.Compact(e)))
 check(back and back.Name=='Ann'and back.UserId==77 and back.Id=='ab12cd34-5'and back.SeedId=='FirePepperSeed'and back.Odds==800 and back.Size==1.5 and back.Mutation=='Gold'and back.Rarity=='Mythic'and back.Kind=='Global','compact -> expand -> event round trip (odds as a whole number)')
 local c=Rules.Compact(Rules.Event('Pull',{Name='Ann',Id='x-1',SeedId='FirePepperSeed'}))
 check(c.m==nil and c.o==nil and c.z==nil and c.s=='FirePepperSeed','empty fields are left out of the message')
 check(Rules.Expand(5)==nil and Rules.Expand(nil)==nil,'expand of a non-table')
 local list={};for i=1,8 do list[i]=Rules.Event('Pull',{Name=string.rep('é',24),UserId=1e9+i,Id='abcdef12-'..i,SeedId='ObsidianMawSeed',Odds=1e12,Size=123.456,Mutation='Diamond'})end
 local text,count=Rules.Batch(list,'11111111-2222-3333-4444-555555555555',1700000000,E.encode)
 check(count>=3 and count<8 and#text<=900,'a batch of the longest events fits 900 bytes: '..count..' of 8 in '..#text..' bytes')
 check(#text<=1000,'... and under the Roblox limit of 1,000')
 local decoded=E.decode(text)
 check(decoded.v==1 and decoded.j=='11111111-2222-3333-4444-555555555555'and decoded.t==1700000000 and#decoded.p==count,'the message decodes: version, origin, time, '..count..' pulls')
 local small=Rules.Batch({list[1]},'job',5,E.encode);check(small~=nil and#small<300,'one pull is a short message ('..#small..' bytes)')
 local none,zero=Rules.Batch({},'job',5,E.encode);check(none==nil and zero==0,'an empty list sends nothing')
 local huge,hz=Rules.Batch({list[1]},string.rep('j',950),5,E.encode);check(huge==nil and hz==0,'one that cannot fit alone is never sent')
 Mod:SetAttribute('MaxBytes',400);local _,fit=Rules.Batch(list,'job',5,E.encode);check(fit>=1 and fit<count,'MaxBytes is a tunable ('..fit..' pulls at 400 bytes)');reset()
 local failing,fc=Rules.Batch(list,'job',5,function()error('boom')end);check(failing==nil and fc==0,'an encoder that errors sends nothing')
 -- freshness
 local now=1700000100
 check(Rules.Fresh(now-60,now)==true and Rules.Fresh(now-61,now)==false,'a message is stale after 60 s')
 check(Rules.Fresh(now+30,now)==true and Rules.Fresh(now+31,now)==false,'... and a clock at most 30 s ahead is accepted')
 check(Rules.Fresh(now,now)==true and Rules.Fresh(nil,now)==false and Rules.Fresh('5',now)==false and Rules.Fresh(0/0,now)==false,'now is fresh; nil, a string and NaN are not')
 Mod:SetAttribute('StaleSeconds',10);check(Rules.Fresh(now-11,now)==false and Rules.Fresh(now-10,now)==true,'StaleSeconds is a tunable');reset()
end

-- 6. names on a phone, the merged small line, where the banner goes -------------------------------------------------------------------------------------------
do
 check(Rules.ShortName('Ann',14)=='Ann'and Rules.ShortName(string.rep('x',14),14)==string.rep('x',14),'a name within the limit is left alone')
 check(Rules.ShortName(string.rep('x',20),14)==string.rep('x',13)..'…'and utf8.len(Rules.ShortName(string.rep('x',20),14))==14,'a longer one is cut to 14 characters with an ellipsis')
 check(Rules.ShortName(string.rep('é',20),14)==string.rep('é',13)..'…'and Rules.ShortName(string.rep('🌟',20),5)==string.rep('🌟',4)..'…','... by characters, not bytes (accents and emoji stay whole)')
 check(Rules.ShortName('Ann',nil)=='Ann'and Rules.ShortName(string.rep('x',30),nil)==string.rep('x',30),'no limit = no cut')
 local e=Rules.Event('Pull',{Name=string.rep('N',24),SeedId='FirePepperSeed',Odds=800})
 check(Rules.Line(e,true,14):find(string.rep('N',13)..'…',1,true)~=nil and Rules.Line(e,true):find(string.rep('N',24),1,true)~=nil,'Line shortens the name only when asked; the chat keeps all 24 ('..#Rules.Chat(e)..' bytes)')
 check(Rules.Chat(e):find(string.rep('N',24),1,true)~=nil,'the chat line has the whole name')
 -- the merged small line is short
 local pull=Rules.Event('Pull',{Name='Ann',SeedId='FirePepperSeed',Mutation='Gold',Size=2})
 local plain,merged=Rules.Subline(pull,0),Rules.Subline(pull,3)
 check(plain:find('kg',1,true)~=nil and merged:find('kg',1,true)==nil and merged:find('+3 more',1,true)~=nil,'a banner that merged others drops the weight and says "+3 more" ('..merged..')')
 check(Rules.Subline(pull,0,true):find('seed',1,true)==nil and Rules.Subline(pull,0,false):find('Lava seed',1,true)~=nil,'phones leave the biome out of the small line')
 local rec=Rules.Event('Record',{Name='Ann',Record='BestPull',SeedId='FirePepperSeed',Size=2})
 check(Rules.Subline(rec,0):find('kg',1,true)~=nil and Rules.Subline(rec,2):find('kg',1,true)==nil,'... a record too')
 -- metrics
 local desk,phone,tiny=Rules.Metrics(1280,720,'Full'),Rules.Metrics(390,844,'Full'),Rules.Metrics(300,700,'Full')
 check(desk.Width==560 and desk.Height==86 and desk.Avatar==56 and desk.NameChars==20 and not desk.Short,'desktop: 560 x 86, avatar 56, names to 20 characters')
 check(phone.Width==366 and phone.Avatar==46 and phone.NameChars==14 and phone.Short,'portrait phone: 366 wide, names to 14, a short small line')
 check(tiny.Width<320 and tiny.Avatar==0,'under 320 px wide the headshot goes')
 local comp=Rules.Metrics(844,390,'Full');check(comp.Compact and comp.Width==math.floor(844*.44)and comp.Overhang==8,'a short landscape phone: 44% of the width (as the notice rows), a smaller ribbon')
 check(Rules.Metrics(1280,720,'Small').Ribbon==nil and Rules.Metrics(1280,720,'Small').RibbonH==0 and Rules.Metrics(1280,720,'Small').Overhang==0,'the small banner has no ribbon')
 local inner=Rules.Inner(desk)
 check(inner.Avatar.X==desk.Pad and inner.Pic.X+inner.Pic.W==desk.Width-desk.Pad and inner.Line1.X>=inner.Avatar.X+inner.Avatar.W and inner.Line1.X+inner.Line1.W<=inner.Pic.X and inner.Ribbon.Y==-desk.Overhang,'the parts are laid out left to right: avatar, text, picture; the ribbon straddles the top edge')
 -- placement: the first notice row, then clear of buttons; balances only covered on a portrait phone
 local m=Rules.Metrics(1280,720,'Full');local at=Rules.Place(1280,720,53,{},m)
 check(at.Y==61+m.Overhang and at.Top==61 and at.Bottom==at.Y+m.Height and at.X==360,'desktop: the first notice row (y 61), centred')
 local lower=Rules.Place(1280,720,200,{},m);check(lower.Top>=208,'below a tutorial card that ends at y 200')
 local btn={{N='Hub',X=500,Y=61,W=100,H=60}}
 local dodged=Rules.Place(1280,720,53,btn,m);check(dodged.Top>=127,'a button in the way: the banner goes below it (top '..dodged.Top..')')
 local pm=Rules.Metrics(390,844,'Full')
 local wallets={{N='WalletSpeed',X=234,Y=73,W=144,H=44},{N='WalletCash',X=234,Y=119,W=144,H=44},{N='WalletGem',X=234,Y=165,W=144,H=44},{N='Status',X=241,Y=8,W=137,H=59}}
 local pp=Rules.Place(390,844,53,wallets,pm);check(pp.Top==61 and pp.Bottom<=200,'portrait phone: dodging the balances would drop it to y 215+, so it stays at the top over them ('..pp.Top..')')
 local hubAndWallets={wallets[1],wallets[2],wallets[3],wallets[4],{N='Hub',X=10,Y=61,W=64,H=64}}
 local ph=Rules.Place(390,844,53,hubAndWallets,pm);check(ph.Top>=125,'... but a button (the menu hub) is always avoided ('..ph.Top..')')
 local deep=Rules.Place(300,200,53,{},Rules.Metrics(300,200,'Full'));check(deep.Bottom<=200-8,'a very short screen: the banner is kept on screen ('..deep.Bottom..' of 200)')
end

print(('R151 rules: %d checks, %d fails'):format(checks,fails))
if fails>0 then error('failures')end
print(('%d/%d checks passed'):format(checks-fails,checks))
