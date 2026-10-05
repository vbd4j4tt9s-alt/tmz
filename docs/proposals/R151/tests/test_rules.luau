--!nocheck
-- R151 pull announcements, part 1: PullAnnounceRules (the shared pure rules) on the Roblox mock with the REAL modules (SeedPackRules, GardenDisplayNames,
-- VerityCatalog, OddsText85). The announcements are CHAT LINES only (the owner: "pull announcement should only be said in chat"):
--  1. thresholds: InServerMinRarity (Legendary) and GlobalMinRarity (Secret = Secret, Cosmic, King and anything above), the Studio attribute overrides
--  2. events: every field sanitised (control and direction characters, long names with an ellipsis, odds, record keys), the rarity ALWAYS from the catalog
--  3. text: the three chat lines (a pull here, a pull in another server, a record), their colours, the rich text of every line well formed and escaped,
--     the old-chat plain line, the rate limit, and that nothing of the banner (queue, layout, sparkles, sound cues, size, coat) is left in the rules
--  4. the payload: compact / expand round trip, the 1 kB batch, freshness (stale and future messages)
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
  check(Rules.Qualifies('InServer',name)==inServer[name],'in-server chat line at '..name..' = '..tostring(inServer[name]))
  check(Rules.Qualifies('Global',name)==global[name],'all-server chat line at '..name..' = '..tostring(global[name]))
 end
 check(Rules.Defaults.InServerMinRarity=='Legendary'and Rules.Defaults.GlobalMinRarity=='Secret'and Rules.Setting('InServerMinRarity')=='Legendary'and Rules.Setting('GlobalMinRarity')=='Secret','the defaults: Legendary in the server, Secret across servers')
 check(not Rules.Qualifies('InServer','Banana')and not Rules.Qualifies('Global',nil)and not Rules.Qualifies('Global',7)and not Rules.Qualifies('InServer',''),'unknown rarities (a bad name, nil, a number) never qualify')
 check(Rules.Rank('King')==8 and Rules.Rank('Common')==1 and Rules.Rank('Banana')==0,'ranks come from SeedPackRules.Rarities')
 -- "Secret, Cosmic, King and anything above": a future rarity with a higher rank qualifies without a code change
 Packs.Rarities.Mythical={Rank=9,Weight=.001,Color=R.Color3.fromRGB(255,255,255)}
 check(Rules.Qualifies('Global','Mythical')and Rules.Qualifies('InServer','Mythical'),'a rarity above King (rank 9) qualifies for both')
 local future=Rules.Event('Pull',{Name='Ann',Id='f-1',SeedId='FirePepperSeed',Odds=5});future.Rarity='Mythical'
 check(Rules.Line(future):find('a MYTHICAL Fire Pepper',1,true)~=nil and Rules.Chat(future):find('#FFFFFF',1,true)~=nil,'... and its line reads MYTHICAL in its own colour')
 Packs.Rarities.Mythical=nil
 -- Studio overrides (an attribute on the module), never trusted when invalid
 Mod:SetAttribute('InServerMinRarity','Mythic')
 check(not Rules.Qualifies('InServer','Legendary')and Rules.Qualifies('InServer','Mythic'),'InServerMinRarity = Mythic: Legendary is no longer shown, Mythic is')
 Mod:SetAttribute('GlobalMinRarity','Cosmic')
 check(not Rules.Qualifies('Global','Secret')and Rules.Qualifies('Global','Cosmic')and Rules.Qualifies('Global','King'),'GlobalMinRarity = Cosmic: Secret stays home, Cosmic and King travel')
 Mod:SetAttribute('InServerMinRarity','Banana');Mod:SetAttribute('GlobalMinRarity',5)
 check(Rules.Setting('InServerMinRarity')=='Legendary'and Rules.Setting('GlobalMinRarity')=='Secret','an invalid override (an unknown rarity, a number) falls back to the default')
 reset()
 Mod:SetAttribute('ChatBurst',99);Mod:SetAttribute('ChatWindow',-1);Mod:SetAttribute('PublishGapSeconds',0)
 check(Rules.Setting('ChatBurst')==8 and Rules.Setting('ChatWindow')==10 and Rules.Setting('PublishGapSeconds')==5,'numbers outside their limits are ignored (8 lines, 10 s, 5 s)')
 Mod:SetAttribute('ChatBurst',3);Mod:SetAttribute('ChatWindow',20)
 check(Rules.Setting('ChatBurst')==3 and Rules.Setting('ChatWindow')==20,'numbers inside their limits are used')
 reset()
 check(Rules.Topic=='PullAnnounce151'and Rules.RemoteName=='PullAnnounce151','topic and remote names')
 -- the banner tunables are gone
 for _,gone in ipairs({'BannerSeconds','MaxWaiting','WaitSeconds'})do check(Rules.Defaults[gone]==nil and Rules.Limits[gone]==nil,'the banner tunable '..gone..' no longer exists')end
end

-- 2. events -----------------------------------------------------------------------------------------------------------------------------------------
do
 local fire={Name='Ann',UserId=12345,Id='ab12-3',SeedId='FirePepperSeed',Odds=800,At=1700000000}
 local e=Rules.Event('Pull',fire)
 check(e and e.Kind=='Pull'and e.Name=='Ann'and e.UserId==12345 and e.Id=='ab12-3'and e.SeedId=='FirePepperSeed'and e.SeedName=='Fire Pepper'and e.Rarity=='Mythic'and e.Odds==800 and e.At==1700000000,'a good pull: name, id, seed, display name, rarity, odds, time')
 check(e.Size==nil and e.Mutation==nil and e.Stage==nil,'an event has no size, coat or biome: a chat line needs none of them')
 local sized=Rules.Event('Pull',{Name='Ann',SeedId='FirePepperSeed',Size=3,Mutation='Gold'})
 check(sized.Size==nil and sized.Mutation==nil,'a sent size or coat is ignored')
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
 check(name(string.rep('x',24))==string.rep('x',24),'24 characters fit as they are')
 check(name(string.rep('x',40))==string.rep('x',23)..'…','a longer name is cut to 24 characters in all, the last one an ellipsis')
 check(name(string.rep('é',40))==string.rep('é',23)..'…'and utf8.len(name(string.rep('é',40)))==24,'... counted in characters, not bytes (accents are not cut in half)')
 check(name(string.rep('🌟',30))==string.rep('🌟',23)..'…','... and emoji stay whole')
 check(name('Abcdefghij Klmnopqrstu Wxyz')=='Abcdefghij Klmnopqrstu…','a cut that lands right after a space drops the space ('..tostring(name('Abcdefghij Klmnopqrstu Wxyz'))..')')
 check(name('🌟Star🌟')=='🌟Star🌟','emoji are kept')
 Mod:SetAttribute('MaxNameLength',10);check(name(string.rep('y',40))==string.rep('y',9)..'…','MaxNameLength is a tunable');reset()
 -- user id, odds, ids
 local function field(k,v)local f=table.clone(fire);f[k]=v;return Rules.Event('Pull',f)end
 check(field('UserId',-5).UserId==0 and field('UserId',1.5).UserId==0 and field('UserId','7').UserId==0 and field('UserId',2^60).UserId==0 and field('UserId',0/0).UserId==0,'a bad user id becomes 0 (negative, fractional, a string, huge, NaN)')
 check(field('Odds',0.5).Odds==nil and field('Odds',0/0).Odds==nil and field('Odds',math.huge).Odds==nil and field('Odds',2e15).Odds==nil and field('Odds','5').Odds==nil and field('Odds',1).Odds==1,'odds must be 1 .. 1e15')
 check(field('Id','bad id!').Id==nil and field('Id',string.rep('a',49)).Id==nil and field('Id',5).Id==nil and field('Id','ok_1:2-3').Id=='ok_1:2-3','ids: letters, digits, - _ : up to 48')
 check(field('At',-1).At==nil and field('At','now').At==nil and field('At',1.7e9).At==1700000000,'the time must be a number')
 -- records
 local rec=Rules.Event('Record',{Name='Dee',UserId=9,Record='BestPull',SeedId=KING.id})
 check(rec and rec.Record=='BestPull'and rec.Rarity=='King'and rec.SeedName==KINGNAME,'a record with a seed ('..KINGNAME..')')
 check(Rules.Event('Record',{Name='Dee',Record='Best Pull!'}).Record=='Record'and Rules.Event('Record',{Name='Dee',Record=string.rep('A',25)}).Record=='Record'and Rules.Event('Record',{Name='Dee',Record=7}).Record=='Record'
  and Rules.Event('Record',{Name='Dee',Record='LongestFruit'}).Record=='LongestFruit','record keys are letters only, up to 24; anything else is the plain "Record"')
 check(Rules.Event('Pull',fire).Record==nil,'a pull has no record key')
 -- every roster seed the game can roll has a name and a real rarity
 local bad=0;for _,spec in ipairs(Packs.SeedDesigns)do local info=Rules.SeedInfo(spec.id);if not info or info.Name==''or not Packs.Rarities[info.Rarity]then bad+=1 end end
 check(bad==0,'all '..#Packs.SeedDesigns..' catalog seeds (roster, Mech, Verity) resolve to a name and a rarity')
 check(Rules.SeedInfo('VeritySeed').Name=='Verity Seed'and Rules.SeedInfo('VeritySeed').Rarity=='King'and Rules.SeedInfo('VeritySeed').Stage==nil,'the Verity seed reads "Verity Seed" (King)')
 check(Rules.SeedInfo(nil)==nil and Rules.SeedInfo(5)==nil and Rules.SeedInfo(string.rep('a',61))==nil and Rules.SeedInfo('')==nil,'bad seed ids')
end

-- 3. text -------------------------------------------------------------------------------------------------------------------------------------------
-- a rich-text line is well formed when the only tags in it are the ones we write (one <font color="#RRGGBB"> run, a bold rarity word), nothing else has a < or a >, and every
-- & starts one of the five entities Roblox rich text knows
local ENTITIES={amp='&',lt='<',gt='>',quot='"',apos="'"}
local function stripTags(rich)
 local s=rich:gsub('<font color="#%x%x%x%x%x%x">',''):gsub('</font>',''):gsub('<b>',''):gsub('</b>','')
 return s
end
local function countOf(text,pattern)local _,n=text:gsub(pattern,'');return n end
local function wellFormed(rich)
 if countOf(rich,'<font color="#%x%x%x%x%x%x">')~=1 or countOf(rich,'</font>')~=1 or rich:sub(1,6)~='<font 'or rich:sub(-7)~='</font>'then return false,'one font run around everything'end
 if countOf(rich,'<b>')~=countOf(rich,'</b>')or countOf(rich,'<b>')>1 then return false,'bold tags are balanced'end
 local body=stripTags(rich)
 if body:find('[<>]')then return false,'a stray < or >'end
 local pos=1
 while true do
  local at=body:find('&',pos,true);if not at then break end
  local name=body:match('^&(%a+);',at);if not name or not ENTITIES[name]then return false,'a bare &' end
  pos=at+1
 end
 return true
end
local function unescape(text)return(text:gsub('&(%a+);',function(n)return ENTITIES[n]end))end
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
 check(Rules.Line(Rules.Event('Record',{Name='Ann',Record='BestPull',SeedId=KING.id}))=='🏆 Ann took BEST PULL TODAY!','a record that names a seed has the same line (the seed is for the hub display)')
 check(Rules.Article('MYTHIC')=='a'and Rules.Article('ELITE')=='an'and Rules.Article('')=='a','a / an')
 -- rich text: the whole line in ONE colour run, the rarity word bold, every part escaped
 local hex=Rules.Hex(Rules.RarityColor('Mythic'))
 check(Rules.Line(pull,true)=='🌟 Ann pulled a <b>MYTHIC</b> Fire Pepper! (1/800)','the rich sentence bolds the rarity word ('..Rules.Line(pull,true)..')')
 check(Rules.Chat(pull)==('<font color="%s">🌟 Ann pulled a <b>MYTHIC</b> Fire Pepper! (1/800)</font>'):format(hex),'the chat line is one colour run in the rarity colour ('..Rules.Chat(pull)..')')
 check(hex:match('^#%x%x%x%x%x%x$')~=nil and hex==Rules.Hex(Packs.Rarities.Mythic.Color),'the colour is the game\'s own Mythic colour as #RRGGBB ('..hex..')')
 check(Rules.Chat(sec)==('<font color="%s">🌐 Ann pulled a <b>SECRET</b> Obsidian Maw (1/1,000)!</font>'):format(Rules.Hex(Rules.Gold)),'an other-server chat line is gold ('..Rules.Chat(sec)..')')
 check(Rules.Chat(rec)==('<font color="%s">🏆 Ann took BEST PULL TODAY!</font>'):format(Rules.Hex(Rules.Amber)),'a record chat line is amber ('..Rules.Chat(rec)..')')
 check(Rules.Gold.R==1 and Rules.Gold.G>.8 and Rules.Gold.B<.4,'gold is gold')
 check(Rules.ChatColor(pull)==Rules.RarityColor('Mythic')and Rules.ChatColor(sec)==Rules.Gold and Rules.ChatColor(rec)==Rules.Amber,'ChatColor: the rarity colour, gold, amber')
 -- every rarity: the line carries ITS colour (not a neighbour's), for a pull in this server; gold and amber stay gold and amber whatever the rarity
 local seen={}
 for _,name in ipairs({'Legendary','Mythic','Secret','Cosmic','King'})do
  local spec=firstOf(name);local ev=Rules.Event('Pull',{Name='Ann',Id='r-'..name,SeedId=spec.id,Odds=1234})
  local want=Rules.Hex(Packs.Rarities[name].Color)
  check(Rules.Chat(ev):find('<font color="'..want..'">',1,true)==1 and Rules.Chat(ev):find('<b>'..string.upper(name)..'</b>',1,true)~=nil,name..': the line is in '..want..' and names '..string.upper(name))
  check(not seen[want],name..': its colour is its own');seen[want]=true
  local g=Rules.Event('Global',{Name='Ann',Id='g-'..name,SeedId=spec.id,Odds=1234})
  check(Rules.Chat(g):find('<font color="'..Rules.Hex(Rules.Gold)..'">',1,true)==1,name..': from another server it is gold')
 end
 -- the old chat: plain text, nothing that could be read as markup
 check(Rules.Plain(pull)=='🌟 Ann pulled a MYTHIC Fire Pepper! (1/800)'and Rules.Plain(sec)==Rules.Line(sec)and Rules.Plain(rec)==Rules.Line(rec),'the plain line (old chat) is the sentence without markup')
 check(Rules.Plain({Kind='Pull',Name='A<b>x</b>',SeedName='S>t',Rarity='Mythic',Odds=5}):find('[<>]')==nil,'... and a < or > from anywhere is dropped from it')
 -- escaping: a name, a seed name and a record title are escaped in rich text (a seed name with an apostrophe or an ampersand, a name that tries to open a tag)
 local nasty={Kind='Pull',Name='A<b>&"x"\'',SeedName="Dragon's & <i>Fruit</i>",Rarity='Mythic',Odds=5}
 local line=Rules.Line(nasty,true)
 check(line:find('<i>',1,true)==nil and line:find('&amp;',1,true)~=nil and line:find('&apos;',1,true)~=nil and line:find('&lt;i&gt;',1,true)~=nil and line:find('&quot;',1,true)~=nil,'rich text escapes markup in any name ('..line..')')
 check(wellFormed(Rules.Chat(nasty)),'... the whole chat line of it is well formed')
 check(unescape(stripTags(Rules.Chat(nasty)))==Rules.Line(nasty,false),'... and escaping loses nothing: unescaped it reads exactly as the plain sentence')
 check(Rules.Line(nasty,false):find("Dragon's & <i>Fruit</i>",1,true)~=nil,'plain text is left as it is (it is never parsed)')
 check(Rules.Escape('<>&"\'')=='&lt;&gt;&amp;&quot;&apos;'and Rules.Escape('a&amp;b')=='a&amp;amp;b'and Rules.Escape(5)=='5','Escape: the five characters, & first (an entity typed by a player is not an entity), numbers')
 local worst=Rules.Chat({Kind='Record',Name='<font color="#FF0000">RED</font>',Record='<b>Hack</b>'})
 check(wellFormed(worst)and worst:find('&lt;font color=&quot;#FF0000&quot;&gt;RED&lt;/font&gt;',1,true)~=nil,'a name that carries a whole <font> tag is printed as text, never as a tag ('..worst..')')
 -- every roster seed, every kind: well formed
 local malformed=0;local longest=0
 for _,spec in ipairs(Packs.SeedDesigns)do
  for _,kind in ipairs({'Pull','Global','Record'})do
   local ev=Rules.Event(kind,{Name='Ann Bo',Id='w-'..spec.id,SeedId=spec.id,Odds=1e9+7,Record='BestPull'})
   if ev then
    ev.Name='Ann <&> "Bo\'s"' -- (a name straight into the line, past the cleaning: the escaping alone must keep it well formed)
    local rich=Rules.Chat(ev);local ok,why=wellFormed(rich)
    if not ok or unescape(stripTags(rich))~=Rules.Line(ev,false)then malformed+=1;print('malformed:',kind,spec.id,why,rich)end
    longest=math.max(longest,#rich)
   end
  end
 end
 check(malformed==0,'the chat line of every seed in the catalog, for every kind, is well formed and lossless (longest '..longest..' bytes)')
 -- the longest case: a 24-character name of wide letters, the longest seed name, the biggest odds: still one run, still well formed
 local longestSeed,longestName='',nil
 for _,spec in ipairs(Packs.SeedDesigns)do local info=Rules.SeedInfo(spec.id);if info and#info.Name>#longestSeed then longestSeed=info.Name;longestName=spec.id end end
 local big=Rules.Event('Global',{Name=string.rep('W',24),Id='big-1',SeedId=longestName,Odds=1e15})
 check(big and wellFormed(Rules.Chat(big))and#Rules.Chat(big)<=400,'a 24-letter name + "'..longestSeed..'" + 1/'..tostring(Rules.OddsLabel(1e15))..' is one well formed line of '..#Rules.Chat(big)..' bytes')
 local cut=Rules.Event('Pull',{Name=string.rep('N',60),Id='big-2',SeedId=longestName,Odds=5})
 check(utf8.len(cut.Name)==24 and cut.Name:sub(-3)=='…'and Rules.Line(cut):find(cut.Name,1,true)~=nil and wellFormed(Rules.Chat(cut)),'a 60-letter name is cut to 24 with an ellipsis and the line stays well formed')
 -- odds format = the game's
 local same=true
 for _,n in ipairs({1,2,6,26,800,1000,1250,9999,12500,240000,1e6,1.67e9,1e12,1e15})do
  if Rules.OddsLabel(n)~=Odds.Format(100/n)then same=false;print('odds mismatch',n,Rules.OddsLabel(n),Odds.Format(100/n))end
 end
 check(same,'the odds read exactly like OddsText85.Format (1/800, 1/1,000, 1/13K ...)')
 check(Rules.OddsLabel(0)==nil and Rules.OddsLabel(nil)==nil and Rules.OddsLabel(0/0)==nil and Rules.OddsLabel(.5)==nil,'no odds for a bad number')
 -- nothing of the banner is left in the rules
 for _,gone in ipairs({'Enqueue','Dequeue','NewQueue','Priority','Timing','Metrics','Inner','Place','SoftBoxes','Subline','Headline','Headlines','Fx','Sparkles','Accent','Variant','Cue','ShortName','Mutations'})do
  check(Rules[gone]==nil,'the banner rule '..gone..' is gone')
 end
 local ok=pcall(function()return Rules.Line(pull,true,14)end);check(ok and Rules.Line(pull,true,14)==Rules.Line(pull,true),'Line takes no name limit any more (a third argument changes nothing)')
end

-- 4. chat limit ------------------------------------------------------------------------------------------------------------------------------------
do
 local log={};local ok=0;for i=1,12 do if Rules.ChatAllowed(log,i*.1)then ok+=1 end end
 check(ok==8,'at most 8 chat lines in 10 s ('..ok..')')
 check(Rules.ChatAllowed(log,5)==false and Rules.ChatAllowed(log,11.0)==true,'... still refused at 5 s, and allowed again once the window has moved on (the first lines are over 10 s old)')
 Mod:SetAttribute('ChatBurst',2);local l2={};local n=0;for i=1,5 do if Rules.ChatAllowed(l2,i*.1)then n+=1 end end
 check(n==2,'ChatBurst is a tunable');reset()
end

-- 5. payload ----------------------------------------------------------------------------------------------------------------------------------------
do
 local e=Rules.Event('Pull',{Name='Ann',UserId=77,Id='ab12cd34-5',SeedId='FirePepperSeed',Odds=799.6})
 local back=Rules.Event('Global',Rules.Expand(Rules.Compact(e)))
 check(back and back.Name=='Ann'and back.UserId==77 and back.Id=='ab12cd34-5'and back.SeedId=='FirePepperSeed'and back.Odds==800 and back.Rarity=='Mythic'and back.Kind=='Global','compact -> expand -> event round trip (odds as a whole number)')
 local c=Rules.Compact(Rules.Event('Pull',{Name='Ann',Id='x-1',SeedId='FirePepperSeed'}))
 check(c.o==nil and c.z==nil and c.m==nil and c.s=='FirePepperSeed','empty fields are left out of the message; there is no size or coat in it')
 check(Rules.Expand(5)==nil and Rules.Expand(nil)==nil,'expand of a non-table')
 local list={};for i=1,8 do list[i]=Rules.Event('Pull',{Name=string.rep('é',24),UserId=1e9+i,Id='abcdef12-'..i,SeedId='ObsidianMawSeed',Odds=1e12})end
 local text,count=Rules.Batch(list,'11111111-2222-3333-4444-555555555555',1700000000,E.encode)
 check(count>=4 and count<=8 and#text<=900,'a batch of the longest events fits 900 bytes: '..count..' of 8 in '..#text..' bytes')
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

print(('R151 rules: %d checks, %d fails'):format(checks,fails))
if fails>0 then error('failures')end
print(('%d/%d checks passed'):format(checks-fails,checks))
