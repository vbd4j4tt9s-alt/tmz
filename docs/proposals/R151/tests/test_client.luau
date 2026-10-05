--!nocheck
-- R151 pull announcements, part 3: the CLIENT (the REAL PullAnnouncerClient + PullAnnounceRules + BonusGiftArt + HudLayout + HudNoticeLayout, and the real HudNotices
-- for the notice rows) on the Roblox mock with a stepping TweenService (ui_world.luau):
--  1. nothing exists until the first announcement; an idle client runs no per-frame code
--  2. one pull: the banner text, ribbon, colours, headshot, seed picture, chat line, sound, slide in / hold / slide out (4 s), cleanup
--  3. every rarity: headline, frame colour, sparkles (4 / 8 / 12 / 14 / 18), the shine from Mythic
--  4. the other-server banner (small, gold, "in another server"), the record banner
--  5. the queue: a flood of 12 keeps at most 3 waiting, the best rarity survives, "+N more", the chat keeps its own limit; duplicates and stale waiters
--  6. sound: the rarity burst once per banner, your own pull is silent, Effects 0 is silent; chat: TextChatService, the old chat, neither
--  7. ReducedMotion (no slide, no sparkles, no per-frame code), FastMode (no shine, at most 3 sparkles)
--  8. the headshot cache (one request per player, a failed request is retried later, 40 kept)
--  9. HudNotices: the real notice rows move below the banner while it shows and come back after
-- 10. hostile payloads, resize while showing, teardown
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=W.module('PullAnnounceRules');local Packs=W.module('SeedPackRules')
local Enum,UDim2=R.Enum,R.UDim2
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.DisplayName='Me D';me.UserId=1000;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
W.service('SoundService')
local view={1280,720}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(view[1],view[2])end;return o end;W.env.Instance=R.Instance end
-- stand-ins for the parts that need Roblox itself -----------------------------------------------------------------------------------------------------
local picShown,picCleared={},0
W.stub('ItemPictures',{Show=function(holder,tool,priority)picShown[#picShown+1]={Holder=holder,Seed=tool:GetAttribute('SeedId'),Garden=tool:GetAttribute('GardenSeed'),Mutation=tool:GetAttribute('Mutation'),Priority=priority}end,
 Clear=function()picCleared+=1 end,Warm=function()end})
local reveal={Preloads=0,Calls={}}
W.stub('RarityRevealAudio',{Preload=function()reveal.Preloads+=1 end,Burst=function(rank,t)reveal.Calls[#reveal.Calls+1]={'Burst',rank,t}end,
 Play=function(key,pitch,skip,volume)reveal.Calls[#reveal.Calls+1]={'Play',key,pitch,volume}end})
local effects=100
W.stub('AudioMixer',{Get=function(key)return key=='Effects'and effects or 100 end,Route=function()end})
local fxTier=3
W.stub('ClientFxBudget',{Get=function()return fxTier end})
local thumbCalls,thumbFail={},{}
function Players.GetUserThumbnailAsync(_,id,kind,size)
 thumbCalls[#thumbCalls+1]={Id=id,Kind=kind,Size=size}
 if thumbFail[id]then error('Thumbnail request failed')end
 return 'rbxthumb://type=AvatarHeadShot&id='..id,true
end
local TCS=W.service('TextChatService')
local chatLog={};local channels=R.new('Folder');channels.Name='TextChannels';channels.Parent=TCS
local general=R.new('Folder');general.Name='RBXGeneral';general.Parent=channels
local chatError=false
general.DisplaySystemMessage=function(_,text,meta)if chatError then error('chat unavailable')end;chatLog[#chatLog+1]={Text=text,Meta=meta}end
local SG=W.service('StarterGui');local oldChat={}
SG.SetCore=function(_,name,value)oldChat[#oldChat+1]={Name=name,Value=value}end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local ctx
local function boot()
 if ctx then ctx.Script:Destroy();ctx.Remote:Destroy()end
 table.clear(picShown);picCleared=0;table.clear(reveal.Calls);table.clear(thumbCalls);table.clear(chatLog);table.clear(oldChat)
 local remote=R.new('RemoteEvent');remote.Name='PullAnnounce151';remote.OnClientEvent=R.signal();remote.FireServer=function()error('the client must never call FireServer')end;remote.Parent=remotes
 local script=R.new('LocalScript');script.Name='PullAnnouncerClient'
 W.load('PullAnnouncerClient',script)
 ctx={Script=script,Remote=remote}
 return ctx
end
local serial=0
local function pull(seed,extra)
 serial+=1
 local t={Kind='Pull',Id='t-'..serial,UserId=2000+serial,Name='Ann'..serial,SeedId=seed,Odds=800,Size=1.2,Mutation='None'}
 for k,v in pairs(extra or{})do t[k]=v end
 return t
end
local function send(payload)ctx.Remote.OnClientEvent:Fire(payload)end
local function gui()return pg:FindFirstChild('PullAnnouncer')end
local function banner()local g=gui();return g and g:FindFirstChild('Banner')end
local function panel()local b=banner();return b and b:FindFirstChild('Panel')end
local function eventOf(p)return Rules.Event(p.Kind,p)end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function sameColor(a,b)local ar,ag,ab=rgb(a);local br,bg,bb=rgb(b);return ar==br and ag==bg and ab==bb end
local function seconds(s)UW.seconds(s,1/60)end
local function stroke(o)return o:FindFirstChildOfClass('UIStroke')end
local function bursts(count)local n=0;for _,r in ipairs(reveal.Calls)do if r[1]==count then n+=1 end end;return n end
local function seedOf(rarity,not_)for _,spec in ipairs(Packs.SeedDesigns)do if spec.id~='VeritySeed'and Packs.GetRarity(spec.id)==rarity then return spec.id end end end
local LEG,MYTH,SEC,COS,KING=seedOf('Legendary'),seedOf('Mythic'),seedOf('Secret'),seedOf('Cosmic'),seedOf('King')

-- 1. nothing until the first announcement -------------------------------------------------------------------------------------------------------------
boot()
check(gui()==nil,'no ScreenGui and no instance before the first announcement')
check(UW.frameListeners()==0,'an idle client has no per-frame connection ('..UW.frameListeners()..')')
check(reveal.Preloads>=1,'the reveal sounds are preloaded at start')
check(ctx.Remote.OnClientEvent._c[1]~=nil and#ctx.Remote.OnClientEvent._c==1,'one listener on the remote')

-- 2. one pull ---------------------------------------------------------------------------------------------------------------------------------------
do
 local p=pull(LEG,{Mutation='Gold'});local e=eventOf(p)
 local t0=R.clock
 send(p)
 local g=gui()
 check(g~=nil and g.DisplayOrder==62 and g.ResetOnSpawn==false and g.ZIndexBehavior==Enum.ZIndexBehavior.Sibling and g.ScreenInsets==Enum.ScreenInsets.CoreUISafeInsets,'the banner lives in its own ScreenGui (DisplayOrder 62: above the menus, under the pack-opening cover)')
 local b,pn=banner(),panel()
 check(b.Visible and b.Active==false,'the banner is visible and takes no input')
 check(pn.Line1.Text==Rules.Line(e,true)and pn.Line1.RichText==true,'the sentence: "'..tostring(pn.Line1.Text)..'"')
 check(pn.Line2.Text==Rules.Subline(e,0)and pn.Line2.Text:find('GOLD',1,true)~=nil,'the small line: "'..tostring(pn.Line2.Text)..'"')
 check(b.Ribbon.Visible and b.Ribbon.Title.Text=='LEGENDARY PULL!','the ribbon says LEGENDARY PULL!')
 check(sameColor(stroke(pn).Color,Rules.RarityColor('Legendary'))and sameColor(stroke(pn.InnerLine).Color,Rules.RarityColor('Legendary'))and sameColor(stroke(pn.Avatar).Color,Rules.RarityColor('Legendary')),'the frame, the inner line and the avatar ring are the rarity colour')
 check(pn.Avatar.Visible and pn.Avatar.Headshot.Visible and pn.Avatar.Headshot.Image=='rbxthumb://type=AvatarHeadShot&id='..p.UserId and not pn.Avatar.Initial.Visible,'the headshot shows (the player\'s own image, not the letter)')
 check(#thumbCalls==1 and thumbCalls[1].Id==p.UserId and thumbCalls[1].Kind==Enum.ThumbnailType.HeadShot and thumbCalls[1].Size==Enum.ThumbnailSize.Size100x100,'one thumbnail request: HeadShot, 100x100')
 check(#picShown==1 and picShown[1].Seed==LEG and picShown[1].Garden==true and picShown[1].Mutation=='Gold'and picShown[1].Holder==pn.Pic.Picture,'the seed picture: ItemPictures gets a seed look (id, Gold coat) for the picture holder')
 check(#chatLog==1 and chatLog[1].Text==Rules.Chat(e)and chatLog[1].Meta=='PullAnnounce151'and chatLog[1].Text:find(Rules.Hex(Rules.RarityColor('Legendary')),1,true)~=nil,'one chat line, rarity coloured: '..tostring(chatLog[1]and chatLog[1].Text))
 check(#reveal.Calls==1 and reveal.Calls[1][1]=='Burst'and reveal.Calls[1][2]==4,'the Legendary reveal burst plays once')
 local bottom=pg:GetAttribute('PullBannerBottom')
 check(type(bottom)=='number'and bottom>=56+86 and bottom<=300,'PullBannerBottom tells the HUD where the banner ends ('..tostring(bottom)..')')
 check(g:GetAttribute('Showing')==p.Id,'(the banner says which announcement it shows)')
 -- slide in
 local final=UDim2.fromOffset(0,0)
 local startY=b.Position.Y.Offset
 check(startY<0,'it starts above the screen (y '..startY..')')
 seconds(.5)
 local landed=b.Position.Y.Offset
 check(landed>0 and math.abs(landed-(pg:GetAttribute('PullBannerBottom')-b.Size.Y.Offset+4))<=8,'... and lands where PullBannerBottom says (y '..landed..')')
 local rects=UW.rects(g,1280,720);local byPath={};for _,r in ipairs(rects)do byPath[r.Path]=r end
 local bannerRect=byPath['PullAnnouncer.Banner']
 check(bannerRect and bannerRect.X>=0 and bannerRect.X+bannerRect.W<=1280 and math.abs(bannerRect.X+bannerRect.W/2-640)<=1,'the banner is centred at the top ('..string.format('%.0f..%.0f',bannerRect.X,bannerRect.X+bannerRect.W)..')')
 -- hold
 seconds(3.2)
 check(banner().Visible,'still on screen at 3.7 s')
 seconds(.5)
 check(not banner().Visible and pg:GetAttribute('PullBannerBottom')==nil and g:GetAttribute('Showing')==nil,'gone at 4.2 s: hidden, the HUD attribute cleared')
 check(R.clock-t0>=4 and R.clock-t0<=4.5,'about 4 s in all')
 check(picCleared>=1 and#banner().Fx:GetChildren()==0,'the picture is released and no sparkle is left')
 check(UW.frameListeners()==0,'idle again: no per-frame connection ('..UW.frameListeners()..')')
 check(UW.live(gui():GetPropertyChangedSignal('AbsoluteSize'))==0 and UW.live(pg:GetAttributeChangedSignal('TutorialCardBottom'))==0,'the resize and tutorial-card listeners are gone too')
end

-- 3. every rarity ----------------------------------------------------------------------------------------------------------------------------------
do
 local table_={{'Legendary',LEG,4,4,false},{'Mythic',MYTH,5,8,true},{'Secret',SEC,6,12,true},{'Cosmic',COS,7,14,true},{'King',KING,8,18,true}}
 for _,row in ipairs(table_)do
  boot();local rarity,seed,rank,sparkles,shine=row[1],row[2],row[3],row[4],row[5]
  local p=pull(seed);local e=eventOf(p)
  send(p);local pn,b=panel(),banner()
  check(b.Ribbon.Title.Text==Rules.Headline(e)and sameColor(stroke(pn).Color,Rules.RarityColor(rarity)),rarity..': headline "'..b.Ribbon.Title.Text..'" and the rarity-coloured frame')
  check(pn.Line1.Text:find(Rules.Hex(Rules.RarityColor(rarity)),1,true)~=nil and pn.Line1.Text:find(string.upper(rarity),1,true)~=nil,rarity..': the sentence colours the word '..string.upper(rarity))
  check(reveal.Calls[1]and reveal.Calls[1][2]==rank,rarity..': the burst of rank '..rank)
  seconds(.7)
  check(#b.Fx:GetChildren()==sparkles,rarity..': '..sparkles..' sparkles ('..#b.Fx:GetChildren()..')')
  local sweep=pn.ShinePane.Sweep
  check(sweep.Visible==shine,rarity..': the shine sweep '..(shine and'runs'or'does not run'))
  seconds(1.2)
  check(UW.frameListeners()==0 and#b.Fx:GetChildren()==0,rarity..': after the flourish the animator is gone while the banner still shows')
  check(b.Visible,'(still showing at 1.9 s)')
  seconds(2.4)
 end
end

-- 4. other server, record --------------------------------------------------------------------------------------------------------------------------
do
 boot()
 local p=pull(SEC,{Kind='Global',Odds=1000});local e=eventOf(p)
 send(p);local pn,b=panel(),banner()
 check(not b.Ribbon.Visible and pn.Line1.Text==Rules.Line(e,true)and pn.Line1.Text:find('🌐',1,true)==1,'other server: no ribbon, the 🌐 sentence ('..pn.Line1.Text..')')
 check(pn.Line2.Text:sub(1,17)=='in another server','... and the small line says "in another server"')
 check(sameColor(stroke(pn).Color,Rules.Gold),'... in a gold frame')
 check(b.Size.Y.Offset<86,'... and is the smaller banner ('..b.Size.Y.Offset..' px high)')
 check(#chatLog==1 and chatLog[1].Text==Rules.Chat(e)and chatLog[1].Text:find(Rules.Hex(Rules.Gold),1,true)==14,'the chat line is gold: '..chatLog[1].Text)
 check(reveal.Calls[1][1]=='Play'and reveal.Calls[1][2]=='Chime'and reveal.Calls[1][4]==.09,'its sound is the quiet chime, not the big burst')
 check(picShown[1].Seed==SEC,'the seed picture is shown')
 seconds(4.5)
 -- a record
 local r={Kind='Record',Id='rec-1',UserId=3000,Name='Rex',Record='BestPull',SeedId=KING,Odds=5e6,Size=20}
 send(r);local e2=eventOf(r)
 check(banner().Ribbon.Visible and banner().Ribbon.Title.Text=='🏆 NEW RECORD!'and panel().Line1.Text==Rules.Line(e2,true)and panel().Line1.Text=='🏆 Rex took BEST PULL TODAY!','record: "'..panel().Line1.Text..'" under a 🏆 ribbon')
 check(sameColor(stroke(panel()).Color,Rules.Amber)and panel().Line2.Text:find('KING',1,true)~=nil,'... amber frame, the seed named on the small line ('..panel().Line2.Text..')')
 check(reveal.Calls[#reveal.Calls][2]==5,'... a Mythic-sized fanfare')
 seconds(4.5)
 send({Kind='Record',Id='rec-2',UserId=3001,Name='Roy',Record='BiggestFruit'})
 check(panel().Pic.Picture~=nil and panel().Pic:FindFirstChild('Fallback').Visible and panel().Pic.Fallback.Text=='🏆','a record without a seed shows a trophy in the picture frame')
 check(panel().Line2.Text=='congratulations!'and panel().Line1.Text=='🏆 Roy took BIGGEST FRUIT TODAY!','"took BIGGEST FRUIT TODAY!"')
 seconds(4.5)
end

-- 5. the queue ---------------------------------------------------------------------------------------------------------------------------------------
do
 boot()
 local seeds={LEG,MYTH,SEC,COS,KING}
 local first
 for i=1,12 do
  local p=pull(seeds[(i-1)%5+1]);if i==1 then first=p end
  send(p)
 end
 check(banner().Visible and gui():GetAttribute('Showing')==first.Id,'the first one shows at once')
 check(#chatLog==8,'the chat takes 8 lines in 10 s and not more ('..#chatLog..' of 12)')
 local waiting=0;local carried=0
 -- (the queue is internal: read what is on screen next)
 seconds(1.3+.1)
 local sequence={gui():GetAttribute('Showing')}
 local shown={};local lastId=nil;local guard=0
 while guard<2000 do
  local id=gui():GetAttribute('Showing')
  if id and id~=lastId then shown[#shown+1]={Id=id,Line2=panel().Line2.Text,Head=banner().Ribbon.Title.Text};lastId=id end
  UW.frames(1,1/60);guard+=1
  if not id and#shown>0 and guard>30 and not gui():GetAttribute('Showing')then local idle=true;for _=1,40 do UW.frames(1,1/60);if gui():GetAttribute('Showing')then idle=false;break end end;if idle then break end end
 end
 check(#shown<=4,'12 pulls at once: at most 4 banners in all (the one on screen and 3 waiting) ('..#shown..' shown after the first)')
 local plus=0;for _,s in ipairs(shown)do local n=s.Line2:match('%+(%d+) more');if n then plus+=tonumber(n)end end
 check(plus+#shown+1>=12 or plus>=7,'the rest is counted in "+N more" ('..plus..' merged)')
 local best=0;for _,s in ipairs(shown)do for r,word in pairs({[4]='LEGENDARY',[5]='MYTHIC',[6]='SECRET',[7]='COSMIC',[8]='KING'})do if s.Head:find(word,1,true)then best=math.max(best,r)end end end
 check(best==8,'the King pulls were not dropped (the best rarity survives a flood)')
 check(UW.frameListeners()==0 and not banner().Visible,'afterwards the client is idle again')
 -- duplicates (the same id twice) show once
 boot();local d=pull(MYTH);send(d);send(table.clone(d));send(table.clone(d))
 check(#chatLog==1 and#picShown==1,'the same announcement id three times: one banner, one chat line')
 seconds(4.6)
 -- a waiting banner that waited over 20 s is dropped
 boot();local a,b2=pull(KING),pull(LEG);send(a);R.advance(0);send(b2)
 seconds(1.0);R.advance(25)
 seconds(5)
 check(not banner().Visible,'a banner that waited more than 20 s is dropped, not shown late')
end

-- 6. sound and chat ---------------------------------------------------------------------------------------------------------------------------------
do
 boot()
 send(pull(MYTH,{UserId=me.UserId,Name='Me D'}))
 check(banner().Visible and#reveal.Calls==0,'your OWN pull shows the banner but no reveal sound (you just heard the reveal)')
 check(#chatLog==1,'... and the chat line')
 seconds(4.6)
 effects=0;send(pull(KING))
 check(banner().Visible and#reveal.Calls==0,'Effects at 0: the banner shows, nothing is asked of the sound system')
 seconds(4.6);effects=100
 send(pull(KING));check(#reveal.Calls==1,'Effects back up: the burst plays')
 seconds(4.6)
 -- debounce: two banners in a row never play two bursts within 0.25 s (they are 4 s apart anyway); a second burst for the next banner
 send(pull(SEC));send(pull(COS));seconds(4.3)
 check(bursts('Burst')==3,'one burst per banner ('..bursts('Burst')..' for 3)')
 seconds(5)
 -- chat variants
 boot();general.Parent=nil
 send(pull(LEG))
 check(#chatLog==0 and#oldChat==1 and oldChat[1].Name=='ChatMakeSystemMessage'and oldChat[1].Value.Text==Rules.Line(eventOf(pull(LEG,{Id='x'})),false):gsub('Ann%d+','Ann'..serial)or#oldChat==1,'without TextChatService channels the old chat gets a plain line ('..tostring(oldChat[1]and oldChat[1].Value.Text)..')')
 check(oldChat[1].Value.Color and sameColor(oldChat[1].Value.Color,Rules.RarityColor('Legendary')),'... in the rarity colour')
 seconds(4.6)
 general.Parent=channels;chatError=true;boot()
 send(pull(LEG));check(#chatLog==0 and#oldChat==1,'a DisplaySystemMessage that fails falls back to the old chat');chatError=false
 seconds(4.6)
 general.Parent=nil;local saved=SG.SetCore;SG.SetCore=function()error('no old chat either')end
 boot();local ok=pcall(send,pull(LEG));check(ok and banner().Visible,'no chat at all: the banner still shows, nothing throws')
 SG.SetCore=saved;general.Parent=channels
 seconds(4.6)
end

-- 7. ReducedMotion and FastMode ---------------------------------------------------------------------------------------------------------------------------
do
 W.Gui.ReducedMotionEnabled=true;boot()
 local tweens0=UW.tweensCreated
 local t0=R.clock
 send(pull(KING))
 local b=banner()
 check(UW.tweensCreated==tweens0,'ReducedMotion: no tween is created (no slide)')
 check(b.Position.Y.Offset>0 and b.Visible,'... it is on screen at its place at once (y '..b.Position.Y.Offset..')')
 check(UW.frameListeners()==0,'... and nothing runs per frame (no shine, no sparkles)')
 check(#b.Fx:GetChildren()==0 and not panel().ShinePane.Sweep.Visible,'... no sparkle and no sweep')
 seconds(3.9);check(b.Visible,'it holds the whole 4 s (visible at 3.9 s)')
 seconds(.3);check(not b.Visible and pg:GetAttribute('PullBannerBottom')==nil,'... and goes at 4 s')
 W.Gui.ReducedMotionEnabled=false
 -- FastMode: no sweep, at most 3 sparkles
 me:SetAttribute('FastMode',true);boot()
 send(pull(KING));seconds(.7)
 check(#banner().Fx:GetChildren()==3 and not panel().ShinePane.Sweep.Visible,'FastMode: 3 sparkles at most and no shine sweep ('..#banner().Fx:GetChildren()..')')
 seconds(4.5);me:SetAttribute('FastMode',nil)
 fxTier=1;boot();send(pull(KING));seconds(.7)
 check(#banner().Fx:GetChildren()==3,'a low effects budget (tier 1) is treated the same');fxTier=3
 seconds(4.5)
 me:SetAttribute('StudioPlantEffects','off');boot();send(pull(MYTH));seconds(.7)
 check(#banner().Fx:GetChildren()==3,'the owner\'s effects-off switch too');me:SetAttribute('StudioPlantEffects',nil)
 seconds(4.5)
end

-- 8. headshots -----------------------------------------------------------------------------------------------------------------------------------------
do
 boot()
 local p1=pull(LEG,{UserId=5001});send(p1);seconds(4.6)
 send(pull(MYTH,{UserId=5001}));seconds(4.6)
 check(#thumbCalls==1,'the same player twice: ONE thumbnail request (cached) ('..#thumbCalls..')')
 thumbFail[5002]=true
 send(pull(LEG,{UserId=5002}))
 check(banner().Visible and panel().Avatar.Initial.Visible and not panel().Avatar.Headshot.Visible and panel().Avatar.Initial.Text=='A','a failed request: the banner shows the player\'s initial instead')
 seconds(4.6);thumbFail[5002]=nil
 send(pull(LEG,{UserId=5002}));check(#thumbCalls==3 and panel().Avatar.Headshot.Visible,'... and the next announcement asks again and gets it')
 seconds(4.6)
 for i=1,45 do send(pull(LEG,{UserId=6000+i}));seconds(4.5)end
 local before=#thumbCalls
 send(pull(LEG,{UserId=6045}));seconds(4.6)
 check(#thumbCalls==before,'the 40 most recent players stay cached')
 send(pull(LEG,{UserId=5001}));seconds(4.6)
 check(#thumbCalls==before+1,'an old one fell out of the cache and is asked for again')
 send(pull(LEG,{UserId=0,Name='Guest'}));check(banner().Visible and panel().Avatar.Initial.Visible,'user id 0 (no account): no request, the initial shows')
 seconds(4.6)
 send(pull(LEG,{UserId=0,Name='élan'}));check(panel().Avatar.Initial.Text=='é'or panel().Avatar.Initial.Text=='É','the initial is the first CHARACTER of a name that starts with an accent ('..panel().Avatar.Initial.Text..')')
 seconds(4.6)
 send(pull(LEG,{UserId=0,Name='🌟Star'}));check(panel().Avatar.Initial.Text=='🌟','... and an emoji stays whole')
 seconds(4.6)
end

-- 9. the real HudNotices ---------------------------------------------------------------------------------------------------------------------------------
do
 boot()
 local W2=W
 local gui2=R.new('ScreenGui');gui2.Name='ChestChaseBanner';gui2.Parent=pg
 local msg=R.new('TextLabel');msg.Name='Message';msg.Text='SEED BAG FULL';msg.Size=UDim2.fromOffset(500,40);msg.Parent=gui2
 local bar=R.new('ScreenGui');bar.Name='ChestEconomyTopBar';bar.Parent=pg
 local nav=R.new('Frame');nav.Name='StationTravel';nav.Parent=bar;nav.AbsolutePosition=R.Vector2.new(400,5);nav.AbsoluteSize=R.Vector2.new(480,48)
 local sc=R.new('LocalScript');sc.Name='HudNotices';W.load('HudNotices',sc)
 seconds(.3)
 local rowsBefore=msg.Parent.Position -- the wrap puts the label into a slot
 local beforeY=msg.Position.Y.Offset
 check(beforeY>=56,'without a banner the notice row sits at the usual place (y '..beforeY..')')
 local notice=pg:GetAttribute('HudNoticeBottom')
 send(pull(MYTH));seconds(.6)
 local bannerBottom=pg:GetAttribute('PullBannerBottom')
 local afterY=msg.Position.Y.Offset
 check(afterY>=bannerBottom+8-1e-6,'while the banner shows the HUD notice row is moved below it (row at y '..afterY..', banner ends '..bannerBottom..')')
 check(pg:GetAttribute('HudNoticeBottom')>bannerBottom,'... and HudNoticeBottom (where NoticeFeed83 stacks) is below the banner too ('..tostring(pg:GetAttribute('HudNoticeBottom'))..')')
 seconds(4.2)
 check(msg.Position.Y.Offset==beforeY and pg:GetAttribute('HudNoticeBottom')==notice,'once the banner has gone the row is back at y '..beforeY)
 sc:Destroy();gui2:Destroy();bar:Destroy()
end

-- 10. hostile payloads, resize, teardown -------------------------------------------------------------------------------------------------------------
do
 boot()
 local bad={5,'x',true,{},{Kind='Pull'},{Kind='Pull',Name='x'},{Kind='Pull',Name='x',SeedId='NoSuchSeed'},{Kind='Evil',Name='x',SeedId=LEG},{Kind='Pull',Name=nil,SeedId=LEG},{Kind='Pull',Name='   ',SeedId=LEG},
  {Kind='Global',Name='x',SeedId=string.rep('a',100)}}
 for i,payload in ipairs(bad)do local ok=pcall(send,payload);check(ok,'hostile payload #'..i..' does not throw')end
 check(gui()==nil or not banner().Visible,'... and none of them shows a banner')
 send({Kind='Pull',Id='x1',UserId=7,Name='<b>Hax</b> <font color="#FF0000">RED</font>',SeedId=LEG,Odds=3})
 check(banner().Visible and panel().Line1.Text:find('<b>',1,true)==nil and panel().Line1.Text:find('<font color="#FF0000">',1,true)==nil and panel().Line1.Text:find('Hax',1,true)~=nil,'markup in a name is stripped ('..panel().Line1.Text..')')
 check(chatLog[#chatLog].Text:find('<b>',1,true)==nil and chatLog[#chatLog].Text:find('#FF0000',1,true)==nil,'... and in the chat line')
 seconds(4.6)
 -- the rarity claim is ignored: a Common seed sent with Rarity='King' is not a King banner
 send({Kind='Pull',Id='x2',UserId=7,Name='Liar',SeedId='SunflowerSeed',Rarity='King',Odds=3})
 check(banner().Ribbon.Title.Text~='KING PULL!!!!','a sent rarity is ignored (the catalog decides): "'..banner().Ribbon.Title.Text..'"')
 seconds(4.6)
 -- resize while it shows
 send(pull(MYTH));seconds(.6)
 local b=banner();local x0=b.Position.X.Offset
 view[1],view[2]=700,400;gui().AbsoluteSize=R.Vector2.new(700,400)
 check(b.Position.X.Offset~=x0 and b.Size.X.Offset<=700-16+8,'a smaller screen while it shows: it is laid out again at once (width '..b.Size.X.Offset..')')
 view[1],view[2]=1280,720;gui().AbsoluteSize=R.Vector2.new(1280,720);seconds(4.6)
 -- tutorial card: the banner moves below it
 pg:SetAttribute('TutorialCardBottom',200)
 send(pull(MYTH));seconds(.6)
 check(b.Position.Y.Offset>=200,'below the tutorial card (y '..b.Position.Y.Offset..')')
 pg:SetAttribute('TutorialCardBottom',320);seconds(.1)
 check(b.Position.Y.Offset>=320,'... and it follows the card when it moves ('..b.Position.Y.Offset..')')
 pg:SetAttribute('TutorialCardBottom',nil);seconds(4.6)
 -- teardown mid-banner
 send(pull(KING));seconds(.3)
 ctx.Script:Destroy()
 check(gui()==nil and pg:GetAttribute('PullBannerBottom')==nil and UW.frameListeners()==0,'destroying the script mid-banner removes the gui, the HUD attribute and every connection')
 check(UW.live(ctx.Remote.OnClientEvent)==0,'... and the remote listener')
 local ok=pcall(send,pull(KING));check(ok and gui()==nil,'an event after teardown is ignored')
 seconds(6);check(UW.frameListeners()==0,'(nothing left running after the old timers fire)')
 ctx.Remote:Destroy();ctx=nil
end

-- 11. a banner that cannot be drawn never blocks the next one ---------------------------------------------------------------------------------------------
do
 boot()
 local realPlace=Rules.Place;local warns=W.warns or 0
 Rules.Place=function()error('boom')end
 local ok=pcall(send,pull(LEG));Rules.Place=realPlace
 check(ok and(W.warns or 0)==warns+1,'a banner that fails to lay out is reported once and does not throw')
 check(gui()==nil or not banner().Visible,'... it is not left half-drawn on screen')
 check(pg:GetAttribute('PullBannerBottom')==nil,'... and the HUD is not left pushed down')
 seconds(1)
 send(pull(MYTH));check(banner().Visible and panel().Line1.Text:find('MYTHIC',1,true)~=nil,'the next announcement shows normally')
 seconds(4.6)
 check(UW.frameListeners()==0 and not banner().Visible,'... and the client is idle again')
end

print(('R151 client: %d checks, %d fails'):format(checks,fails))
if fails>0 then error('failures')end
print(('%d/%d checks passed'):format(checks-fails,checks))
