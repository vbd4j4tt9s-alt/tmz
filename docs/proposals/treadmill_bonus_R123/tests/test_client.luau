--!nocheck
-- R123 TreadmillBonusClient under the Roblox mock (real client script, TreadmillBonusRules, SeedPackRules, HudLayout).
-- Server replies are scripted; ItemPictures / audio modules are recording stubs.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
getmetatable(R.Vector2.new(0,0)).__mul=function(a,b)return R.Vector2.new(a.X*b,a.Y*b)end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.UserId=1;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local char=R.new('Model');char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.Position=R.Vector3.new(0,3,0);root.Parent=char
local head=R.new('Part');head.Name='Head';head.Position=R.Vector3.new(0,4.5,0);head.Parent=char
W.service('SoundService')
local Rules=W.module('TreadmillBonusRules')
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local remote=R.new('RemoteFunction');remote.Name=Rules.RemoteName;remote.Parent=remotes
local reply;local invoked=0
function remote.InvokeServer(_,...)invoked+=1;check(select('#',...)==0,'client sends no arguments')
 if reply and reply.Ok then me:SetAttribute(Rules.Attr.Ready,reply.Ready)end -- the server republishes before replying
 return reply end
-- Stubs (recording) -------------------------------------------------------------------------------------
local shown={};W.stub('ItemPictures',{Show=function(holder,tool)shown[#shown+1]={Holder=holder,Stage=tool:GetAttribute('Stage'),Variant=tool:GetAttribute('BagVariant')}end,Clear=function()end})
local played={};W.stub('InteractionAudio',{Asset=function(k)return k=='MenuClick'and'rbxassetid://116737765668953'or nil end,Play=function(k)played[#played+1]=k;return true end})
local reveals={};W.stub('RarityRevealAudio',{Preload=function()end,Play=function(k)reveals[#reveals+1]=k;return true end})
W.stub('AudioMixer',{Route=function()end})
local ticks={};W.stub('SoundTiming',{Play=function(s)ticks[#ticks+1]={At=R.clock,Pitch=s.PlaybackSpeed}end})
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class=='Sound'then o.IsLoaded=true;function o.Stop()end;function o.Play()end end;return o end;W.env.Instance=R.Instance end
local script=R.new('LocalScript');script.Name='TreadmillBonusClient'
W.load('TreadmillBonusClient',script)
local hud=pg:FindFirstChild('TreadmillBonusHud');local overlay=pg:FindFirstChild('TreadmillBonusRoll');local bar=pg:FindFirstChild('TreadmillBonusProgress')
check(hud and overlay and bar,'GUIs created')
local button=hud.BonusRollButton
local function set(k,v)me:SetAttribute(Rules.Attr[k],v)end
-- 1. Button --------------------------------------------------------------------------------------------
set('Ready',0);check(button.Visible==false,'no roll ready: button hidden')
set('Ready',1);check(button.Visible==true,'1 ready: button shows')
check(button.CountBadge.Visible==false,'1 ready: no count badge')
set('Ready',2);check(button.CountBadge.Visible==true and button.CountBadge.Count.Text=='2','2 ready: badge shows 2')
W.frames(2);check(button.Size.X.Offset>=150 and button.Size.Y.Offset>=44,'button is a full touch target ('..button.Size.X.Offset..'x'..button.Size.Y.Offset..')')
-- 2. Progress bar over the player while on the treadmill --------------------------------------------------
set('Ready',0);set('Interval',360);set('DueAt',R.clock+222);me:SetAttribute('TreadmillTraining',true)
W.frames(20,1/60)
check(bar.Enabled==true and bar.Adornee==root,'bar shows over the player while training')
local label=bar.Back.Label.Text
check(label:find('Next roll 3:4')~=nil,'bar text counts down: '..label)
check(bar.StudsOffsetWorldSpace.Y>5,'bar sits above the head, clear of speed popups')
local fill=bar.Back.Fill.Size.X.Scale;check(math.abs(fill-(1-222/360))<.02,'bar fill = progress ('..fill..')')
set('Ready',2);set('DueAt',nil);W.frames(20,1/60)
check(bar.Back.Label.Text:find('2 rolls ready')~=nil,'at the cap the bar says claim: '..bar.Back.Label.Text)
me:SetAttribute('TreadmillTraining',false);W.frames(20,1/60);check(bar.Enabled==false,'bar hides off the treadmill')
-- 3. Click -> server result -> strip lands on it ---------------------------------------------------------
set('Ready',2)
local function spinTo(res,label2)
 reply=res;table.clear(ticks);table.clear(shown);table.clear(reveals);table.clear(played)
 local before=invoked;button.Activated:Fire()
 check(invoked==before+1,label2..': one server request per click')
 check(overlay.Enabled==true,label2..': roll overlay opens')
 local panel=overlay.Panel;local window=panel.StripWindow;window.AbsoluteSize=R.Vector2.new(576,144)
 local strip=window.Strip;local cards={};for _,c in ipairs(strip:GetChildren())do cards[tonumber(c.Name:match('%d+'))]=c end
 check(#cards==Rules.Strip.Count,label2..': strip has '..#cards..' cards')
 local win=cards[Rules.Strip.Win]
 check(win and win.Rarity.Text==string.upper(res.Rarity),label2..': winning card is the server result ('..tostring(win and win.Rarity.Text)..')')
 check(panel.Odds.Text:find('Common 43.5%%')and panel.Odds.Text:find('Legendary 2%%')and panel.Odds.Text:find('Mythic 0.5%%')and panel.Odds.Text:find('Secret 0.1%%'),label2..': odds list shows every rarity % (R124 odds)')
 check(panel.Actions.Skip.Visible==true and panel.Actions.Close.Visible==false,label2..': SKIP while spinning')
 local start=R.clock;local frames=0
 while panel.Actions.Skip.Visible and frames<2000 do W.frames(1,1/60);frames+=1 end
 local took=R.clock-start
 local center=576/2;local x=strip.Position.X.Offset+win.Position.X.Offset+Rules.Strip.CardWidth/2
 check(math.abs(x-center)<Rules.Strip.CardWidth/2,label2..string.format(': stops with the winner under the marker (%.1f px off)',x-center))
 check(panel.Actions.Close.Visible==true,label2..': CLOSE after the stop')
 -- R124 layout: rows stacked (result above the buttons), the visible buttons centred as a group.
 local function bottom(x)return x.Position.Y.Offset+x.Size.Y.Offset end
 check(bottom(panel.Result)<=panel.Actions.Position.Y.Offset,label2..': result text ends above the buttons')
 check(bottom(panel.Odds)<=panel.Result.Position.Y.Offset and panel:FindFirstChild('Pool')==nil,label2..': odds / result rows do not overlap; no "Packs from" line')
 check(bottom(panel.Actions)<=panel.Size.Y.Offset,label2..': buttons inside the panel')
 local shownButtons={};for _,b in ipairs(panel.Actions:GetChildren())do if b:IsA('TextButton')and b.Visible then shownButtons[#shownButtons+1]=b end end
 local lo,hi=math.huge,-math.huge
 for _,b in ipairs(shownButtons)do lo=math.min(lo,b.Position.X.Offset);hi=math.max(hi,b.Position.X.Offset+b.Size.X.Offset);check(b.Position.X.Scale==.5,label2..': button anchored to the centre')end
 check(math.abs(lo+hi)<1,label2..string.format(': %d button(s) centred (%.1f .. %.1f)',#shownButtons,lo,hi))
 return took,panel,win,cards
end
local took,panel,win=spinTo({Ok=true,Stage=6,Variant='Pack03',Rarity='Rare',Label='Jungle Seed Pack',Pool='1,6',Ready=1},'Rare')
check(took>=Rules.Strip.Duration-.05 and took<=Rules.Strip.Duration+.1,'full spin takes ~'..Rules.Strip.Duration..' s ('..took..')')
local passed=Rules.Strip.Win-1
check(#ticks>=passed*.8 and #ticks<=passed,'a click per card passing the marker: '..#ticks..' of '..passed)
local maxRate=0
for i=2,#ticks do local gap=ticks[i].At-ticks[i-1].At;check(gap>=1/30-1e-6,'ticks never faster than 30/s');if gap>0 then maxRate=math.max(maxRate,1/gap)end end
check(ticks[#ticks].Pitch>ticks[1].Pitch,'tick pitch rises as the strip slows')
check(#shown>=Rules.Strip.Count,'cards use pack pictures (ItemPictures) from the pool')
local poolOk=true;for _,s in ipairs(shown)do if s.Stage~=1 and s.Stage~=6 and not(s.Variant=='EclipseReliquary'and s.Stage==7)then poolOk=false end end
check(poolOk,'filler cards only from the published pool (Forest/Jungle)')
check(panel.Result.Text:find('RARE')~=nil,'result text: '..panel.Result.Text)
check(#reveals==0 and win:FindFirstChild('BorderGlow')==nil and panel:FindFirstChild('Flash')==nil,'Rare: no border light-up / fanfare')
check(win:FindFirstChild('Design')==nil,'Rare card has no special design')
check(table.find(played,'KaChing')~=nil,'Rare: normal reveal sound')
panel.Actions.Close.Activated:Fire();check(overlay.Enabled==false,'CLOSE hides the overlay')
-- Legendary: flash + glow + fanfare
set('Ready',1)
took,panel,win=spinTo({Ok=true,Stage=1,Variant='Pack05',Rarity='Legendary',Label='Forest Seed Pack',Pool='1',Ready=0},'Legendary')
check(#reveals>0 and table.find(played,'GemClaim')~=nil,'Legendary: fanfare sounds')
check(win:FindFirstChild('BorderGlow')~=nil and win.Picture:FindFirstChild('Glow')==nil,'Legendary: light-up on the card border, not over the picture')
check(panel:FindFirstChild('Flash')==nil and panel:FindFirstChildOfClass('UIStroke').Thickness>=4,'Legendary: no full-panel flash; the panel border lights up')
local rays=0;for _,c in ipairs(win.Design:GetChildren())do if c.Name:find('^Ray')then rays+=1 end end
check(rays==6 and win.Design:FindFirstChild('Stud1')~=nil,'Legendary card design: sunburst + gold corner studs')
check(panel.Actions.Again.Visible==false,'no ROLL AGAIN when none are ready')
panel.Actions.Close.Activated:Fire()
-- Secret = the Void Pack: SECRET card with the starfield design and the border light-up.
set('Ready',1)
took,panel,win=spinTo({Ok=true,Stage=7,Variant='EclipseReliquary',Rarity='Secret',Label='Void Pack',Pool='1',Ready=0},'Secret')
check(win.Biome.Text=='Void Pack'and win.Design:FindFirstChild('Star1')~=nil and win.Design:FindFirstChild('Nebula')~=nil,'Secret card: Void Pack label, starfield design')
check(win:FindFirstChild('BorderGlow')~=nil and #reveals>0,'Secret: border light-up + fanfare')
panel.Actions.Close.Activated:Fire()
check(panel:FindFirstChildOfClass('UIStroke').Thickness==3,'panel border back to normal after close')
-- SKIP and ReducedMotion
set('Ready',1);reply={Ok=true,Stage=1,Variant='Pack06',Rarity='Mythic',Label='Forest Seed Pack',Pool='1',Ready=0}
button.Activated:Fire();W.frames(5,1/60);overlay.Panel.Actions.Skip.Activated:Fire()
check(overlay.Panel.Actions.Close.Visible and overlay.Panel.Result.Text:find('MYTHIC'),'SKIP jumps to the result')
overlay.Panel.Actions.Close.Activated:Fire()
W.Gui.ReducedMotionEnabled=true;set('Ready',1)
took=spinTo({Ok=true,Stage=1,Variant='Pack01',Rarity='Common',Label='Forest Seed Pack',Pool='1',Ready=0},'ReducedMotion')
check(took<=Rules.Strip.ReducedDuration+.1,'ReducedMotion: short spin ('..took..' s)')
overlay.Panel.Actions.Close.Activated:Fire();W.Gui.ReducedMotionEnabled=false
-- 4. Server refusal: no overlay, message on the button ------------------------------------------------------
set('Ready',1);reply={Error='SEED BAG FULL! Make room - your roll stays ready.',Ready=1}
button.Activated:Fire()
check(overlay.Enabled==false and button.Sub.Text:find('SEED BAG FULL'),'refusal shown on the button: '..button.Sub.Text)
reply={Ok=true,Stage=99,Variant=nil};R.advance(3);button.Activated:Fire()
check(overlay.Enabled==false,'malformed reply ignored')
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
