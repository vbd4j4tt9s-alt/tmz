--!nocheck
-- R153 biome notifier, option B (text only; owner's pick from docs/proposals/R153): no box, no medallion, no logo; a small white lowercase "entering" over the biome's Title Case name in its own
-- colour, each with a solid dark UIStroke and an offset dark copy as the soft shadow; sizes per screen (pc / portrait / landscape phone); 2.4 s (fade in 0.3 s with a 6 px settle, fully shown until
-- 1.8 s, fade out over 0.6 s); Reduced Motion = fade only; the reserved HudNoticeLayout row is B's height (46 / 40 px); HudNotices (the real script) places it; the contrast of every biome colour.
-- (R125's medallion / R124's plain-Frame title tests that used to live here are gone with the box.)
local W=require('./world');local R=W.R
local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.CharacterAdded=R.signal();me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
-- all seven biomes in a row along +Z (Forest -> Jungle -> Desert -> Snow -> Lava -> Crystal -> Storm Peaks), 200 studs each
local order={1,6,2,3,4,5,7};local starts={}
for i,id in ipairs(order)do starts[id]=(i-1)*200;map:SetAttribute('BiomeStartZ_'..id,(i-1)*200);map:SetAttribute('BiomeEndZ_'..id,i*200)end
local char=R.new('Model');char.Parent=W.workspace;me.Character=char
local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=CF(0,3,190);root.Parent=char
local hum=R.new('Humanoid');hum.Health=100;hum.WalkSpeed=16;hum.MoveDirection=V3(0,0,1);hum.Parent=char
local function screen(w,h)W.Gui.GetInsetArea=function()return {Min=R.Vector2.new(0,0),Width=w,Height=h}end end
screen(1280,720)
local scriptInst=R.new('LocalScript')
W.load('BiomeEntryNotifier',scriptInst)
local gui=pg:FindFirstChild('BiomeEntryUI');local group=gui and gui:FindFirstChild('BiomeTitle')
local Styles=W.module('BiomeTitleStyle');local Notice=W.module('HudNoticeLayout');local Mood=W.module('BiomeMood')
-- 1. what it is made of: two lines of text, nothing else ---------------------------------------------------------------------------------------------------------------------------------------------
check(gui and gui.ClassName=='ScreenGui'and gui.ScreenInsets.Name=='CoreUISafeInsets','BiomeEntryUI keeps its name and the phone safe area')
check(group and group.ClassName=='Frame'and group.BackgroundTransparency==1,'BiomeTitle is a see-through Frame (HudNotices finds it by name)')
local caption,title=group:FindFirstChild('Caption',true),group:FindFirstChild('BiomeName',true)
local capShade,titleShade=group:FindFirstChild('CaptionShadow',true),group:FindFirstChild('NameShadow',true)
local count={};for _,d in ipairs(group:GetDescendants())do count[d.ClassName]=(count[d.ClassName]or 0)+1 end
check(count.TextLabel==4 and count.UIStroke==4 and count.Frame==1,'BiomeTitle holds one transparent Content frame, 4 TextLabels (2 lines + 2 shadow copies) and 4 UIStrokes')
local extra={};for cls,n in pairs(count)do if cls~='TextLabel'and cls~='UIStroke'and cls~='Frame'then extra[#extra+1]=cls..'x'..n end end
check(#extra==0,'nothing else: no box, medallion (CanvasGroup), logo (ImageLabel), gradient, corner, scale, sparkle ('..table.concat(extra,',')..')')
local opaque=0;for _,d in ipairs(group:GetDescendants())do if d:IsA('Frame')and d.BackgroundTransparency<1 then opaque+=1 end end
check(opaque==0 and group.BackgroundTransparency==1,'no filled box anywhere')
check(not group:FindFirstChildOfClass('UIScale')and not group:FindFirstChild('BiomeBadge',true)and not group:FindFirstChild('BiomeLogo',true)and not group:FindFirstChild('SoftRibbon',true),'no UIScale, BiomeBadge, BiomeLogo or SoftRibbon')
local src=W.B['BiomeEntryNotifier']
check(not src:find('BiomeArtwork')and not src:find('BiomeIconData')and not src:find('CanvasGroup')and not src:find('ImageLabel'),'the script no longer touches BiomeArtwork / BiomeIconData / CanvasGroup / ImageLabel')
local first=src:match('^[^\n]*');check(first:sub(1,2)=='do'and first:find('R152: start once the whole game has arrived',1,true)~=nil,'line 1 is still the load guard')
-- 2. the words ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
for id,st in pairs(Styles)do
 check(st.Label and st.Label:match('^%u%l+$')or st.Label and st.Label:match('^%u%l+ %u%l+$'),('biome %d Label is Title Case (%s)'):format(id,tostring(st.Label)))
 check(st.Label:upper()==st.Name,('biome %d Label is its Name in Title Case (%s / %s)'):format(id,st.Label,st.Name))
end
local function dist(a,b)return math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B)end
local function lin(c)return c<=.03928 and c/12.92 or((c+.055)/1.055)^2.4 end
local function lum(c)return .2126*lin(c.R)+.7152*lin(c.G)+.0722*lin(c.B)end
local function ratio(a,b)local la,lb=lum(a),lum(b);if la<lb then la,lb=lb,la end;return(la+.05)/(lb+.05)end
-- walk into <stage> from just before its border (respawn first so the gate is fresh) and return the frame the title appeared in
local function enter(stage)
 me.CharacterAdded:Fire(char);hum.MoveDirection=V3(0,0,1);local z=starts[stage]-8;root.CFrame=CF(0,3,z);W.frames(10)
 for _=1,90 do z+=16/60;root.CFrame=CF(0,3,z);W.frames(1);if group.Visible then return true end end
 return false
end
local function stage(n)return Styles[n]end
local contrastRows={}
-- sky colours the biomes really have (BiomeMood Air / Decay) and the extremes: white cloud, grey cloud, night, thunder, mid grey, slate blue sky, dusk
local skies={{'white cloud',R.Color3.fromRGB(255,255,255)},{'grey cloud',R.Color3.fromRGB(172,178,192)},{'night',R.Color3.fromRGB(10,12,20)},{'thunder',R.Color3.fromRGB(60,66,80)},
 {'mid grey',R.Color3.fromRGB(110,110,110)},{'slate sky',R.Color3.fromRGB(70,104,176)},{'dusk',R.Color3.fromRGB(50,34,62)}}
for id,p in pairs(Mood.Profiles)do skies[#skies+1]={p.Name..' air',p.Air.Color};skies[#skies+1]={p.Name..' horizon',p.Air.Decay}end
for _,id in ipairs(order)do
 check(enter(id),('walking into biome %d shows the title'):format(id))
 W.frames(40) -- 0.67 s: fully shown
 local st=stage(id)
 check(title.Text==st.Label and titleShade.Text==st.Label,('biome %d: the name reads "%s"'):format(id,st.Label))
 check(dist(title.TextColor3,st.Color)<1e-6,('biome %d: the name is in the biome colour (BiomeTitleStyle)'):format(id))
 check(caption.Text=='entering'and capShade.Text=='entering'and caption.Text==caption.Text:lower(),'"entering" in lowercase above the name')
 check(dist(caption.TextColor3,R.Color3.new(1,1,1))<1e-6 and caption.TextTransparency<=.15,'"entering" is white (at most 15% see-through)')
 check(caption.Position.Y.Offset<title.Position.Y.Offset and caption.Position.Y.Offset+caption.Size.Y.Offset<=title.Position.Y.Offset+1,'"entering" sits above the name')
 -- stroke + shadow
 local capEdge,nameEdge=caption:FindFirstChild('Edge'),title:FindFirstChild('Edge')
 check(capEdge and nameEdge and capEdge.ClassName=='UIStroke'and nameEdge.ClassName=='UIStroke','the name and "entering" each have a UIStroke')
 check(nameEdge.Thickness>=1.5 and nameEdge.Thickness<=2.5 and capEdge.Thickness>=1.2 and capEdge.Thickness<=2.5,('stroke about 2 px on the name (%.2f) and on "entering" (%.2f)'):format(nameEdge.Thickness,capEdge.Thickness))
 check(nameEdge.Transparency==0 and capEdge.Transparency==0 and lum(nameEdge.Color)<.02 and lum(capEdge.Color)<.02,'the strokes are solid and dark')
 local nShadow,cShadow=titleShade,capShade
 for _,pair in ipairs({{title,nShadow},{caption,cShadow}})do
  local main,sh=pair[1],pair[2]
  check(lum(sh.TextColor3)<.02 and sh.TextTransparency>0 and sh.TextTransparency<1,'the shadow copy is dark at partial transparency ('..sh.TextTransparency..')')
  check(sh.Position.Y.Offset-main.Position.Y.Offset>=1 and sh.Position.Y.Offset-main.Position.Y.Offset<=4 and sh.Position.X.Offset==main.Position.X.Offset,'the shadow copy sits 1 to 4 px below its line')
  check(sh.ZIndex<main.ZIndex and sh.TextSize==main.TextSize and sh.Font==main.Font,'under its line, same size and font')
  local e=sh:FindFirstChild('Edge');check(e and e.Thickness==main:FindFirstChild('Edge').Thickness and e.Transparency>0 and e.Transparency<1,'the shadow copy has the same stroke, partly see-through')
 end
 -- contrast of the real colours: fill vs edge, and edge or fill vs every sky
 local fill,edge=title.TextColor3,nameEdge.Color
 local worstSky,worst='',1e9
 for _,s in ipairs(skies)do local best=math.max(ratio(fill,s[2]),ratio(edge,s[2]));if best<worst then worst,worstSky=best,s[1]end end
 contrastRows[#contrastRows+1]=('%-12s fill/edge %.1f:1, worst sky %s %.1f:1'):format(st.Label,ratio(fill,edge),worstSky,worst)
 check(ratio(fill,edge)>=4.5,('%s: fill vs dark edge at least 4.5:1 (%.1f)'):format(st.Label,ratio(fill,edge)))
 check(worst>=3,('%s: against every sky tried (%d), the edge or the fill separates it at least 3:1 (worst %s %.2f)'):format(st.Label,#skies,worstSky,worst))
end
-- 3. sizes per screen --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local specs={{'PC 1280x720',1280,720,143,44,24,12,46},{'landscape phone 844x390',844,346,113,37,19,11,40},{'portrait phone 390x844',390,800,125,39,21,11,46}}
for _,sp in ipairs(specs)do
 screen(sp[2],sp[3]);check(enter(7),sp[1]..': Storm Peaks shows');W.frames(30)
 local gw,gh=group.Size.X.Offset,group.Size.Y.Offset
 check(math.abs(gw-sp[4])<=sp[4]*.1,('%s: width %d about %d'):format(sp[1],gw,sp[4]))
 check(gh==sp[5],('%s: height %d is %d'):format(sp[1],gh,sp[5]))
 check(title.TextSize==sp[6] and caption.TextSize==sp[7],('%s: name %d px, "entering" %d px'):format(sp[1],title.TextSize,caption.TextSize))
 local row=Notice.Calculate(sp[2],sp[3],0,{Biome=true}).Biome
 check(row.Height==sp[8] and row.Height>=gh and row.Width>=gw+8,('%s: reserved row %d x %d holds the %d x %d text'):format(sp[1],row.Width,row.Height,gw,gh))
 check(group.Position.X.Offset==row.X and group.Position.Y.Offset==row.Y and group.AnchorPoint.X==.5 and group.AnchorPoint.Y==0,sp[1]..': it starts in its HudNotices row (top centre)')
 -- the whole name block stays inside the row's width and the screen
 check(group.Position.X.Offset-gw/2>=0 and group.Position.X.Offset+gw/2<=sp[2],sp[1]..': on screen')
end
-- every screen of the layout harness: the words fit the reserved row, in every biome name length (longest "Storm Peaks"), and the row is smaller than the old 94 / 58 px
local views={{1920,1080},{1366,768},{1280,720},{1024,768},{800,600},{1280,540},{960,480},{700,400},{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{800,360},{1180,820},{1366,1024},{320,568},{375,667},{390,844},{430,932},{360,740},{768,1024},{820,1180}}
local classes={}
for _,v in ipairs(views)do
 local sw,sh=v[1],v[2]-36 -- the safe area is under the 36 px top bar
 screen(sw,sh);check(enter(7),('%dx%d: Storm Peaks shows'):format(sw,sh));W.frames(30)
 local row=Notice.Calculate(sw,sh,0,{Biome=true}).Biome
 local gw,gh=group.Size.X.Offset,group.Size.Y.Offset
 check(gh<=row.Height-1 and gw<=row.Width-8,('%dx%d: %d x %d text in a %d x %d row'):format(sw,sh,gw,gh,row.Width,row.Height))
 check(row.Height<(sh<480 and 58 or 94),('%dx%d: the row shrank'):format(sw,sh))
 classes[title.TextSize]=(classes[title.TextSize]or 0)+1
 check(group.Position.X.Offset-gw/2>=0 and group.Position.X.Offset+gw/2<=sw,('%dx%d: on screen'):format(sw,sh))
end
check(classes[24]and classes[21]and classes[19],'all three size classes occur over the screens (pc '..tostring(classes[24])..', portrait '..tostring(classes[21])..', landscape '..tostring(classes[19])..')')
screen(1280,720)
-- 4. the reserved row and what stacks under it -------------------------------------------------------------------------------------------------------------------------------------------------------
for _,v in ipairs({{1280,720,46,6},{844,346,40,3},{390,800,46,6},{1920,1080,46,6}})do
 local a=Notice.Calculate(v[1],v[2],0,{Biome=true,Run=true,Banner=true})
 local b=Notice.Calculate(v[1],v[2],0,{Run=true,Banner=true})
 check(a.Biome.Height==v[3],('%dx%d: the Biome row is %d px high'):format(v[1],v[2],v[3]))
 check(a.Run.Y==a.Biome.Y+a.Biome.Height+v[4]and b.Run.Y==a.Biome.Y,('%dx%d: the Run notice sits %d px under the Biome row (and takes its place without it)'):format(v[1],v[2],v[4]))
 check(a.Bottom-b.Bottom==v[3]+v[4],('%dx%d: the stack grows by %d px only'):format(v[1],v[2],v[3]+v[4]))
 check(a.Biome.Width<=240 and a.Biome.Width>=140,('%dx%d: the row is %d px wide (not 490)'):format(v[1],v[2],a.Biome.Width))
end
-- 5. timing and motion (PC, Storm Peaks and Jungle, Reduced Motion off) -----------------------------------------------------------------------------------------------------------------------------
local content=group:FindFirstChild('Content')
local function run(stageId,seconds)
 local samples={};me.CharacterAdded:Fire(char);hum.MoveDirection=V3(0,0,1);local z=starts[stageId]-8;root.CFrame=CF(0,3,z);W.frames(10);local t0
 for _=1,60*8 do
  z+=16/60;root.CFrame=CF(0,3,z);W.frames(1)
  if group.Visible and not t0 then t0=R.clock end
  if t0 then
   local gx,gy=group.Position.X.Offset,group.Position.Y.Offset
   samples[#samples+1]={T=R.clock-t0,Name=title.TextTransparency,Cap=caption.TextTransparency,Edge=title:FindFirstChild('Edge').Transparency,Shade=titleShade.TextTransparency,CapEdge=caption:FindFirstChild('Edge').Transparency,
    X=content.Position.X.Offset,Y=content.Position.Y.Offset,Visible=group.Visible,G=gx..','..gy,S=group.Size.X.Offset..','..group.Size.Y.Offset,Rot=title.Rotation}
   if not group.Visible and R.clock-t0>seconds then break end
  end
 end
 return samples
end
local function at(samples,t)for _,s in ipairs(samples)do if s.T>=t then return s end end end
screen(1280,720);local samples=run(6,3.5)
local s0=samples[1]
check(s0 and s0.T<.03 and s0.Name>.9 and s0.Y<=-5,('starts see-through and 6 px up (name %.2f, y %d)'):format(s0 and s0.Name or-1,s0 and s0.Y or 0))
check(at(samples,.1).Name>.4 and at(samples,.1).Name<.8,'fading in at 0.1 s ('..at(samples,.1).Name..')')
check(at(samples,.35).Name<.01 and at(samples,.35).Y==0,'fully shown, settled, at 0.35 s')
local maxHold,minHold=0,1;for _,s in ipairs(samples)do if s.T>=.31 and s.T<=1.78 then maxHold=math.max(maxHold,s.Name,s.Cap-.08,s.Edge,s.CapEdge);minHold=math.min(minHold,s.Name)end end
check(maxHold<.01,'fully shown from 0.3 s to 1.8 s (the "entering" at its own 8%, the strokes solid)')
check(at(samples,1.78).Name<.01 and at(samples,2.1).Name>.1 and at(samples,2.1).Name<.95 and at(samples,2.1).Visible,'fading out at 2.1 s ('..at(samples,2.1).Name..')')
check(at(samples,2.1).Edge>.1 and at(samples,2.1).Shade>.5 and at(samples,2.1).CapEdge>.1,'strokes and shadows fade with the words')
local gone;for _,s in ipairs(samples)do if not s.Visible then gone=s.T;break end end
check(gone and gone>=2.38 and gone<=2.45,('gone after 2.4 s (%.3f)'):format(gone or-1))
check(at(samples,2.3).Visible and at(samples,2.3).Name>.7,'still (just) there at 2.3 s')
local monoIn,monoOut,moved=true,true,false;local prevY,prevN=nil,nil
for _,s in ipairs(samples)do
 if s.T<.3 then if prevN and s.Name>prevN+1e-9 then monoIn=false end;if prevY and s.Y<prevY then monoIn=false end;prevY,prevN=s.Y,s.Name end
 if s.T>.3 and s.Y~=0 then moved=true end
 if s.X~=0 or s.Rot~=0 or s.S~=samples[1].S or s.G~=samples[1].G then moved=true end
end
local prev=0;for _,s in ipairs(samples)do if s.T>=1.8 and s.Visible then if s.Name<prev-1e-9 then monoOut=false end;prev=s.Name end end
check(monoIn and monoOut,'one smooth fade in (and settle down), one smooth fade out')
check(not moved,'after the 6 px settle nothing moves: no slide, rise, pop, rotation or resize; the group never leaves its place')
check(at(samples,.0).Y==-6 or at(samples,.0).Y==-5,'the settle is 6 px')
-- a second crossing shows it again at full strength
screen(1280,720);check(enter(2),'second crossing shows it again');W.frames(30)
check(title.TextTransparency<.01 and caption.TextTransparency<.09 and title:FindFirstChild('Edge').Transparency==0 and titleShade.TextTransparency>.4 and titleShade.TextTransparency<.6,'second show back at full strength')
-- 6. Reduced Motion: fade only ----------------------------------------------------------------------------------------------------------------------------------------------------------------------
W.Gui.ReducedMotionEnabled=true
local rs=run(3,3.5)
local ry=true;for _,s in ipairs(rs)do if s.Y~=0 or s.X~=0 then ry=false end end
check(ry,'Reduced Motion: the words never move (no settle)')
check(rs[1].Name>.9 and at(rs,.35).Name<.01 and at(rs,2.1).Name>.1 and at(rs,2.1).Name<.95,'Reduced Motion: it still fades in and out on the same clock')
local rg;for _,s in ipairs(rs)do if not s.Visible then rg=s.T;break end end
check(rg and rg>=2.38 and rg<=2.45,'Reduced Motion: gone after 2.4 s')
W.Gui.ReducedMotionEnabled=false
-- 7. when it fires, and when it does not (unchanged behaviour) -------------------------------------------------------------------------------------------------------------------------------------
-- spawning inside a biome, a teleport, walking sideways or back: no title; turning back / dying / respawning dismisses it
me.CharacterAdded:Fire(char);W.frames(5);root.CFrame=CF(0,3,250);hum.MoveDirection=V3(0,0,0);W.frames(30)
check(not group.Visible,'spawning inside a biome shows nothing')
root.CFrame=CF(0,3,610);W.frames(40) -- teleport into Snow
check(not group.Visible,'a teleport shows nothing')
me.CharacterAdded:Fire(char);hum.MoveDirection=V3(0,0,-1);root.CFrame=CF(0,3,205);W.frames(10);local z=205
for _=1,60 do z-=16/60;root.CFrame=CF(0,3,z);W.frames(1)end
check(not group.Visible,'walking back over a border shows nothing')
enter(4);W.frames(20);check(group.Visible,'(a normal crossing shows it)')
hum.MoveDirection=V3(0,0,-1);z=root.CFrame.Position.Z;for _=1,30 do z-=16/60;root.CFrame=CF(0,3,z);W.frames(1)end;W.frames(30)
check(not group.Visible,'turning back dismisses it (it fades over 0.45 s)')
enter(4);W.frames(200);check(not group.Visible,'(it ran its 2.4 s)')
hum.MoveDirection=V3(0,0,1);z=root.CFrame.Position.Z;for _=1,60*6 do z+=16/60;root.CFrame=CF(0,3,z);W.frames(1);if group.Visible then break end end
check(not group.Visible,'walking on inside the same biome does not show it again')
enter(4);W.frames(20);check(group.Visible,'(shown again)')
hum.Health=0;W.frames(80)
check(not group.Visible,'dying dismisses it')
hum.Health=100;enter(5);W.frames(20);me.CharacterAdded:Fire(char);W.frames(2)
check(not group.Visible,'a respawn hides it at once')
-- 8. the real HudNotices places it in its row and the other notices sit under it --------------------------------------------------------------------------------------------------------------------
screen(1280,720)
W.load('HudNotices',R.new('LocalScript'))
local biome=gui:FindFirstChild('BiomeTitle',true)
check(enter(7),'(Storm Peaks again, with HudNotices running)');W.frames(30)
local slot=biome.Parent
check(slot and slot.Name=='NoticeSlot','HudNotices wraps the group in its NoticeSlot as it always did')
local row=Notice.Calculate(1280,720,0,{Biome=true}).Biome
check(biome.Position.X.Offset==row.X and biome.Position.Y.Offset==row.Y and biome.Size.Y.Offset<=row.Height and biome.AnchorPoint.Y==0 and biome.AnchorPoint.X==.5,
 ('HudNotices puts it at the top centre (%d, %d), 46 px row, text %d px high'):format(biome.Position.X.Offset,biome.Position.Y.Offset,biome.Size.Y.Offset))
check(biome.Size.Y.Offset==44 and pg:GetAttribute('HudNoticeBottom')==row.Y+46+6,'HudNoticeBottom is 52 px under the row top (was 100 px): '..tostring(pg:GetAttribute('HudNoticeBottom')))
-- a run warning showing together with it sits right under it (and, without the biome title, takes its place)
local runGui=R.new('ScreenGui');runGui.Name='ChestRunAlertUI';runGui.Parent=pg
local run=R.new('TextLabel');run.Name='RunWarning';run.Text='Run!';run.Visible=true;run.Parent=runGui
W.frames(20)
check(run.Position.Y.Offset==row.Y+46+6 and run.Position.Y.Offset>=biome.Position.Y.Offset+biome.Size.Y.Offset,('the run warning sits under the biome text, not 94 px under the top (y %d)'):format(run.Position.Y.Offset))
W.frames(200)
check(not biome.Visible and run.Position.Y.Offset==row.Y,'when the biome title is gone the run warning moves up into its place')
check(biome:GetAttribute('NoticeFit')~=nil and biome.Size.X.Offset<240,'HudNotices still writes NoticeFit; nothing reads it, the size stays the notifier\'s own')
print(table.concat(contrastRows,'\n'))
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
