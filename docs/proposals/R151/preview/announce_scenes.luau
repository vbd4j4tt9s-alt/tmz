--!nocheck
-- R151 previews (not a test): runs the REAL PullAnnouncerClient (and the real HudNotices for the notice row) under the Roblox mock, sends it announcements and prints one
-- line per scene: SCENE <name> <crop x y w h> <scale> <json of the GUI tree>. run_announce_preview.sh draws them with render_gui.mjs (headless Chromium) and make_sheet.py
-- lays the sheet out. Global: VIEW = 'desktop' (1280x720) | 'phone' (844x390, landscape) | 'portrait' (390x844).
-- Preview-only stand-ins: the seed picture is a drawn seed (the game shows the 3D model), the headshot is a drawn face (the game shows the player's Roblox headshot),
-- tweens settle at once and sounds are silent. The sparkles and the shine are caught half a second into the banner.
local W=require('./world');local R=W.R;local dump=require('./dump_tree')
local V3,RGB=R.Vector3.new,R.Color3.fromRGB
local VW,VH=1280,720
if VIEW=='phone'then VW,VH=844,390 elseif VIEW=='portrait'then VW,VH=390,844 end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.DisplayName='Me D';me.UserId=1;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
W.service('SoundService')
if VIEW~='desktop'then W.UIS.TouchEnabled=true;W.UIS.MouseEnabled=false end
W.Gui.GetInsetArea=function()return {Min=R.Vector2.new(0,0),Width=VW,Height=VH}end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(VW,VH)end;return o end;W.env.Instance=R.Instance end
local Rules=W.module('PullAnnounceRules');local Packs=W.module('SeedPackRules')
local function frame(parent,name,x,y,w,h,color,radius)
 local f=R.Instance.new('Frame');f.Name=name;f.BackgroundColor3=color;f.BorderSizePixel=0
 f.Position=R.UDim2.fromScale(x,y);f.Size=R.UDim2.fromScale(w,h);f.Parent=parent
 if radius then local c=R.Instance.new('UICorner');c.CornerRadius=R.UDim.new(radius,0);c.Parent=f end;return f
end
-- a drawn seed: a plump body in the rarity colour with a highlight and a little sprout
W.stub('ItemPictures',{Show=function(holder,tool)
 local color=Rules.RarityColor(Packs.GetRarity(tool:GetAttribute('SeedId')))
 local gold=tool:GetAttribute('Mutation')=='Gold'
 local base=gold and RGB(255,206,72)or color
 local body=frame(holder,'Seed',.2,.26,.6,.66,base:Lerp(RGB(255,255,255),.1),.5)
 local g=R.Instance.new('UIGradient');g.Color=R.ColorSequence.new(RGB(255,255,255),RGB(150,150,165));g.Rotation=90;g.Parent=body
 frame(body,'Shine',.22,.16,.22,.3,RGB(255,255,255),.5).BackgroundTransparency=.55
 frame(holder,'Stem',.47,.08,.08,.26,RGB(70,160,72),.5)
 local leaf=frame(holder,'Leaf',.54,.1,.26,.14,RGB(96,188,88),.5);leaf.Rotation=-25
end,Clear=function()end,Warm=function()end})
W.stub('RarityRevealAudio',{Preload=function()end,Burst=function()end,Play=function()return true end});W.stub('AudioMixer',{Get=function()return 100 end,Route=function()end})
W.stub('ClientFxBudget',{Get=function()return 3 end})
function Players.GetUserThumbnailAsync(_,id)return 'preview://face/'..id,true end
local TCS=W.service('TextChatService')
local channels=R.new('Folder');channels.Name='TextChannels';channels.Parent=TCS
local general=R.new('Folder');general.Name='RBXGeneral';general.Parent=channels;general.DisplaySystemMessage=function()end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local remote=R.new('RemoteEvent');remote.Name='PullAnnounce151';remote.OnClientEvent=R.signal();remote.Parent=remotes
-- a stand-in for the game's top bar (BASE / TRACK) and one notice row, so the banner is seen where it really sits
local hud=R.new('ScreenGui');hud.Name='ChestEconomyTopBar';hud.Parent=pg
local travel=R.new('Frame');travel.Name='StationTravel';travel.AnchorPoint=R.Vector2.new(.5,0);travel.Position=R.UDim2.fromOffset(VW/2,5);travel.Size=R.UDim2.fromOffset(math.min(420,VW-30),48)
travel.BackgroundTransparency=1;travel.AbsolutePosition=R.Vector2.new(VW/2-math.min(420,VW-30)/2,5);travel.AbsoluteSize=R.Vector2.new(math.min(420,VW-30),48);travel.Parent=hud
for i,label in ipairs({'BASE','TRACK','🎁 DAILY'})do
 local b=R.Instance.new('TextLabel');b.Name='Btn'..i;b.Text=label;b.Font=R.Enum.Font.GothamBlack;b.TextSize=15;b.TextColor3=RGB(255,255,255);b.TextStrokeColor3=RGB(10,14,28);b.TextStrokeTransparency=.3;b.BackgroundColor3=RGB(76,112,190);b.BorderSizePixel=0
 b.Size=R.UDim2.new(1/3,-8,1,0);b.Position=R.UDim2.new((i-1)/3,4,0,0);local c=R.Instance.new('UICorner');c.CornerRadius=R.UDim.new(.3,0);c.Parent=b;b.Parent=travel
end
local noticeGui=R.new('ScreenGui');noticeGui.Name='ChestChaseBanner';noticeGui.Parent=pg
local notice=R.new('TextLabel');notice.Name='Message';notice.Text='🌱 Plant ready in your garden!';notice.Font=R.Enum.Font.FredokaOne;notice.TextSize=20;notice.TextColor3=RGB(255,255,255)
notice.TextStrokeColor3=RGB(0,0,0);notice.TextStrokeTransparency=.3;notice.BackgroundTransparency=.45;notice.BackgroundColor3=RGB(20,26,48);local nc=R.Instance.new('UICorner');nc.CornerRadius=R.UDim.new(.3,0);nc.Parent=notice;notice.Size=R.UDim2.fromOffset(420,40);notice.Visible=false;notice.Parent=noticeGui
W.load('HudNotices',(function()local s=R.new('LocalScript');s.Name='HudNotices';return s end)())
local script=R.new('LocalScript');script.Name='PullAnnouncerClient'
W.load('PullAnnouncerClient',script)
W.frames(3,1/60)
local KING;for _,spec in ipairs(Packs.SeedDesigns)do if spec.id~='VeritySeed'and Packs.GetRarity(spec.id)=='King'then KING=spec.id;break end end
local function seed(rarity)for _,spec in ipairs(Packs.SeedDesigns)do if spec.id~='VeritySeed'and Packs.GetRarity(spec.id)==rarity then return spec.id end end end
local serial=0
local function send(kind,seedId,extra)
 serial+=1
 local p={Kind=kind,Id='pv-'..serial,UserId=100+serial,Name=({'Ava','Max','Zoe','Kai','Mia','Leo'})[serial%6+1],SeedId=seedId,Odds=800,Size=1.3,Mutation='None'}
 for k,v in pairs(extra or{})do p[k]=v end
 remote.OnClientEvent:Fire(p)
end
local function banner()local g=pg:FindFirstChild('PullAnnouncer');return g and g:FindFirstChild('Banner'),g end
-- the preview's headshot: a round face with eyes and a smile in the avatar ring (the game shows the real Roblox headshot there)
local faces={RGB(255,205,160),RGB(224,172,125),RGB(141,98,66),RGB(255,224,189)}
local function drawFace()
 local b=banner();local avatar=b and b.Panel.Avatar;local shot=avatar and avatar:FindFirstChild('Headshot')
 if not shot or not shot.Visible or shot:FindFirstChild('Eye1')then return end
 shot.BackgroundTransparency=0;shot.BackgroundColor3=faces[serial%#faces+1]
 local hair=frame(shot,'Hair',.0,.0,1,.34,RGB(60,40,28),.5);hair.ZIndex=5
 frame(shot,'Eye1',.28,.46,.12,.12,RGB(30,30,40),.5).ZIndex=5;frame(shot,'Eye2',.6,.46,.12,.12,RGB(30,30,40),.5).ZIndex=5
 local smile=frame(shot,'Smile',.32,.68,.36,.1,RGB(150,50,50),.5);smile.ZIndex=5
 shot.Image=''
end
local function emit(name,guis,crop,scale)
 local parts={}
 for _,g in ipairs(guis)do local json=dump(g,VW,VH);parts[#parts+1]=json:match('^{"canvas":%[[^%]]*%],"kids":%[(.*)%]}$')end
 local merged='{"canvas":['..VW..','..VH..'],"kids":['..table.concat(parts,',')..']}'
 print(string.format('SCENE %s %d %d %d %d %s %s',name,crop[1],crop[2],crop[3],crop[4],tostring(scale),merged))
end
local function cropOf(extraBelow)
 local b=banner();local x,y=b.Position.X.Offset,b.Position.Y.Offset;local w,h=b.Size.X.Offset,b.Size.Y.Offset
 local pad=14
 return {math.max(0,math.floor(x-pad)),math.max(0,math.floor(y-pad)),math.floor(w+2*pad),math.floor(h+2*pad+(extraBelow or 0))}
end
local function scene(name,kind,seedId,extra,opts)
 opts=opts or{}
 notice.Visible=opts.Notice==true;travel.Visible=opts.Notice==true
 send(kind,seedId,extra);drawFace();W.frames(33,1/60);drawFace()
 local b,g=banner()
 local guis={g}
 if opts.Notice then guis={hud,noticeGui,g}end
 emit(name,guis,opts.Crop or cropOf(),opts.Scale or(VIEW=='desktop'and 2 or 2))
 for _=1,28 do R.advance(.25)end;W.frames(5,1/60) -- (the mock runs a task started inside a step at the next step: quarter seconds let the whole hold / slide-out / next-banner chain play)
end
scene('legendary','Pull',seed('Legendary'),{Odds=250})
scene('mythic','Pull',seed('Mythic'),{Odds=800})
scene('secret','Pull',seed('Secret'),{Odds=12500})
scene('cosmic','Pull',seed('Cosmic'),{Odds=240000})
scene('king','Pull',KING,{Odds=1e6,Mutation='Gold'})
scene('global','Global',seed('Secret'),{Odds=12500,Name='Nova'})
scene('record','Record',seed('Mythic'),{Record='BestPull',Name='Rex'})
-- in place: the whole screen with the top bar and a notice row that the banner pushed down
scene('context','Pull',seed('Mythic'),{Odds=800},{Notice=true,Crop={0,0,VW,math.min(VH,VIEW=='portrait'and 300 or 250)},Scale=VIEW=='desktop'and 1 or 1.5})
