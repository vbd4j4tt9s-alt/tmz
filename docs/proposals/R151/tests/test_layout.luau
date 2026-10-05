--!nocheck
-- R151 layout of the pull announcement banner: the REAL PullAnnouncerClient on the Roblox mock, measured with UW.rects (the way Roblox lays a GUI out), on every screen of the
-- R123 / R150 layout tests (26 screens; touch with and without the on-screen controls), for the three looks (a pull in this server, a pull in another server, a record) with a
-- typical sentence and the WORST one (24 wide letters for a name, the longest seed name, 1/1.67B, a Diamond coat, a heavy weight, "+5 more"):
--  * the banner is inside the screen with the 8 px margin (ribbon and outline included), centred, and never wider than the notice rows
--  * it sits at the first notice row (HudNoticeLayout) or lower, clear of every HudLayout box (status stack, wallets, hotbar, menu wheel, thumb zones, owner tools)
--  * the notice rows (every flag on) start below it while it shows, with the 8 px gap, so nothing overlaps
--  * the avatar, the two text lines and the seed picture are inside the panel and never overlap each other or the ribbon
--  * every text fits its box (conservative Montserrat Black widths): the sentence (2 lines at the smallest size), the small line, the ribbon
--  * a tutorial card above pushes the banner below it
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=W.module('PullAnnounceRules');local Packs=W.module('SeedPackRules');local L=W.module('HudLayout');local Notice=W.module('HudNoticeLayout')
local Enum,UDim2=R.Enum,R.UDim2
local Players=W.service('Players')
local me=R.new('Player');me.Name='Me';me.DisplayName='Me D';me.UserId=1000;me.Parent=Players;Players.LocalPlayer=me
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=me
W.service('SoundService')
local view={1280,720}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(view[1],view[2])end;return o end;W.env.Instance=R.Instance end
W.stub('ItemPictures',{Show=function()end,Clear=function()end,Warm=function()end})
W.stub('RarityRevealAudio',{Preload=function()end,Burst=function()end,Play=function()return true end});W.stub('AudioMixer',{Get=function()return 100 end,Route=function()end})
W.stub('ClientFxBudget',{Get=function()return 3 end})
function Players.GetUserThumbnailAsync(_,id)return 'rbxthumb://'..id,true end
W.service('TextChatService');W.service('StarterGui').SetCore=function()end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
-- ui_world's line counter cuts an over-long word at a BYTE (it errors inside an emoji); this one cuts at a character
function UW.lines(text,size,maxW)
 local lines,line=1,''
 for word in text:gmatch('%S+')do
  local candidate=line==''and word or line..' '..word
  if UW.width(candidate,size)<=maxW then line=candidate
  else
   if line~=''then lines+=1 end
   line=word
   while UW.width(line,size)>maxW and utf8.len(line)>1 do
    lines+=1;local count=utf8.len(line);local cut=math.max(1,math.floor(count*maxW/UW.width(line,size)))
    line=line:sub(utf8.offset(line,cut+1))
   end
  end
 end
 return lines
end
local ctx
local function boot()
 if ctx then ctx.Script:Destroy();ctx.Remote:Destroy()end
 local remote=R.new('RemoteEvent');remote.Name='PullAnnounce151';remote.OnClientEvent=R.signal();remote.Parent=remotes
 local script=R.new('LocalScript');script.Name='PullAnnouncerClient';W.load('PullAnnouncerClient',script)
 ctx={Script=script,Remote=remote}
end
local serial=0
local function seconds(s)UW.seconds(s,1/60)end
-- the TouchGui the way HudLayout.Controls reads it
local touchGui=R.new('ScreenGui');touchGui.Name='TouchGui';touchGui.Enabled=false;touchGui.Parent=pg
local thumb=R.new('Frame');thumb.Name='ThumbstickFrame';thumb.Parent=touchGui
local jump=R.new('Frame');jump.Name='JumpButton';jump.Parent=touchGui
local function controls(w,h)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-90-20,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-60-120,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
local function placeControls(ctl)
 touchGui.Enabled=ctl~=nil
 if ctl then
  thumb.AbsolutePosition=R.Vector2.new(ctl.Joystick.X,ctl.Joystick.Y);thumb.AbsoluteSize=R.Vector2.new(ctl.Joystick.W,ctl.Joystick.H)
  jump.AbsolutePosition=R.Vector2.new(ctl.Jump.X,ctl.Jump.Y);jump.AbsoluteSize=R.Vector2.new(ctl.Jump.W,ctl.Jump.H)
 end
end
local views={}
for _,v in ipairs({{1920,1080},{1366,768},{1280,720},{1024,768},{800,600},{1280,540},{960,480},{700,400}})do views[#views+1]={v[1],v[2],false}end
for _,v in ipairs({{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{800,360},{1024,768},{1180,820},{1366,1024},{320,568},{375,667},{390,844},{430,932},{360,740},{768,1024},{820,1180}})do views[#views+1]={v[1],v[2],true}end
-- the longest seed display name
local longest,longestSeed='',nil
for _,spec in ipairs(Packs.SeedDesigns)do local info=Rules.SeedInfo(spec.id);if info and#info.Name>#longest and Packs.GetRarity(spec.id)~='Common'then longest,longestSeed=info.Name,spec.id end end
local function seedOf(rarity)for _,spec in ipairs(Packs.SeedDesigns)do if spec.id~='VeritySeed'and Packs.GetRarity(spec.id)==rarity then return spec.id end end end
local cases={
 {Name='typical pull',Payload={Kind='Pull',Name='Ann',SeedId=seedOf('Mythic'),Odds=800,Size=1.2,Mutation='None'}},
 {Name='worst pull',Payload={Kind='Pull',Name=string.rep('W',24),SeedId=longestSeed,Odds=1.67e9,Size=123.456,Mutation='Diamond'}},
 {Name='emoji name',Payload={Kind='Pull',Name=string.rep('🌟',24),SeedId=seedOf('King'),Odds=1e12,Size=900,Mutation='Gold'}},
 {Name='typical other server',Payload={Kind='Global',Name='Ann',SeedId=seedOf('Secret'),Odds=1000,Size=1}},
 {Name='worst other server',Payload={Kind='Global',Name=string.rep('M',24),SeedId=longestSeed,Odds=1.67e9,Size=123.456,Mutation='Diamond'}},
 {Name='typical record',Payload={Kind='Record',Name='Ann',Record='BestPull',SeedId=seedOf('Mythic'),Odds=800,Size=2}},
 {Name='worst record',Payload={Kind='Record',Name=string.rep('W',24),Record='BiggestFruit',SeedId=longestSeed,Odds=1.67e9,Size=123.456}},
 {Name='worst record, long key',Payload={Kind='Record',Name=string.rep('W',24),Record='LongestRunningRecordKeys',SeedId=longestSeed,Size=123.456}},
}
check(longestSeed~=nil and#longest>=10,'the longest seed name in the catalog is "'..longest..'"')
local function ov(a,b,pad)pad=pad or 0;return a.X<b.X+b.W-pad and a.X+a.W>b.X+pad and a.Y<b.Y+b.H-pad and a.Y+a.H>b.Y+pad end
local function box(e)return {X=e.X,Y=e.Y,W=e.W,H=e.H}end
local function inside(a,b,tol)tol=tol or .5;return a.X>=b.X-tol and a.Y>=b.Y-tol and a.X+a.W<=b.X+b.W+tol and a.Y+a.H<=b.Y+b.H+tol end
local tested,smallest={},{}
local topBar={X=0,Y=0,W=0,H=0}
for _,v in ipairs(views)do
 local w,h,touch=v[1],v[2],v[3]
 for _,ctl in ipairs(touch and{false,true}or{false})do
  view[1],view[2]=w,h;W.UIS.TouchEnabled=touch;placeControls(ctl and controls(w,h)or nil)
  local tag=string.format('%s %dx%d%s',touch and'TOUCH'or'PC',w,h,ctl and' ctl'or'')
  local m=L.Read(R.Vector2.new(w,h),touch,ctl and controls(w,h)or nil)
  local boxes=L.HudBoxes(m,w,h,false)
  for _,case in ipairs(cases)do
   boot()
   serial+=1;local payload=table.clone(case.Payload);payload.Id='L-'..serial;payload.UserId=3000+serial
   ctx.Remote.OnClientEvent:Fire(payload)
   seconds(.6)
   local g=pg:FindFirstChild('PullAnnouncer')
   local ctag=tag..' '..case.Name
   if check(g~=nil and g.Banner.Visible,ctag..': the banner shows')then
    local list,by=UW.rects(g,w,h)
    local b=by['PullAnnouncer.Banner'];local pn=by['PullAnnouncer.Banner.Panel']
    local e=Rules.Event(payload.Kind,payload)
    local variant=Rules.Variant(e);local mt=Rules.Metrics(w,h,variant)
    -- screen
    check(b.X>=8-mt.Box and b.Y>=0 and b.X+b.W<=w-8+mt.Box and b.Y+b.H<=h-4,ctag..string.format(': the banner is on screen with the 8 px margin (panel %.0f..%.0f x %.0f..%.0f of %dx%d)',pn.X,pn.X+pn.W,pn.Y,pn.Y+pn.H,w,h))
    check(pn.X>=8 and pn.X+pn.W<=w-8 and pn.Y>=8,ctag..': the panel keeps 8 px from every edge')
    check(math.abs(pn.X+pn.W/2-w/2)<=1,ctag..': centred')
    check(pn.W<=(h<480 and math.max(200,w*.44)or w-24)+.5,ctag..string.format(': no wider than the notice rows (%.0f)',pn.W))
    check(math.abs(pn.W-mt.Width)<.5 and math.abs(pn.H-mt.Height)<.5,ctag..': the panel is the size Rules.Metrics says')
    -- where it sits
    local top=0;local first=Notice.Calculate(w,h,top,{}).Bottom
    local ribbonTop=pn.Y-mt.Overhang
    check(ribbonTop>=first-.5,ctag..string.format(': at or below the first notice row (banner top %.0f, row %.0f)',ribbonTop,first))
    local rb={X=pn.X,Y=ribbonTop,W=pn.W,H=pn.H+mt.Overhang}
    local overSoft={}
    for _,hb in ipairs(boxes)do
     if Rules.SoftBoxes[hb.N]then if ov(rb,hb,0)then overSoft[#overSoft+1]=hb.N end
     else check(not ov(rb,hb,0),ctag..': clear of HUD box '..hb.N)end
    end
    -- the balances and the status stack (soft boxes) are only covered when dodging them would put the banner low on a portrait phone
    check(#overSoft==0 or(touch and h>w and pn.Y+pn.H<=h*.3+(h<480 and 0 or 0)+200),ctag..': covers '..table.concat(overSoft,',')..' only on a portrait phone, near the top')
    if #overSoft>0 then check(touch and h>w,ctag..': ... (portrait phones only)')end
    -- the notice rows start below it
    local bottom=pg:GetAttribute('PullBannerBottom')
    check(type(bottom)=='number'and bottom>=pn.Y+pn.H-.5 and bottom<=pn.Y+pn.H+mt.Box+.5,ctag..string.format(': PullBannerBottom (%s) is the banner\'s bottom (%.0f)',tostring(bottom),pn.Y+pn.H))
    local flagsets={{Biome=true,Run=true,Banner=true,Feedback=true,Shovel=true},{Banner=true},{Biome=true},{}}
    for i,flags in ipairs(flagsets)do
     local rows=Notice.Calculate(w,h,math.max(top,bottom),flags)
     for name,row in pairs(rows)do if type(row)=='table'then
      check(row.Y>=bottom+8-1e-6,ctag..string.format(': notice row %s (flags %d) starts below the banner (%.0f vs %.0f + 8)',name,i,row.Y,bottom))
      check(not ov({X=row.X-row.Width/2,Y=row.Y,W=row.Width,H=row.Height},rb,0),ctag..': notice row '..name..' does not overlap the banner')
     end end
     check(rows.Bottom>=bottom+8,ctag..': the notice stack ends below the banner')
    end
    -- parts
    local base='PullAnnouncer.Banner.Panel.'
    local avatar,line1,line2,pic=by[base..'Avatar'],by[base..'Line1'],by[base..'Line2'],by[base..'Pic']
    local ribbon=by['PullAnnouncer.Banner.Ribbon']
    local parts={}
    if avatar and avatar.Visible then parts.Avatar=avatar end
    if pic and pic.Visible then parts.Pic=pic end
    parts.Line1=line1;parts.Line2=line2
    local panelBox={X=pn.X,Y=pn.Y,W=pn.W,H=pn.H}
    for name,p in pairs(parts)do check(inside(p,panelBox,.5),ctag..': '..name..string.format(' is inside the panel (%.0f,%.0f %.0fx%.0f)',p.X-pn.X,p.Y-pn.Y,p.W,p.H))end
    local names={};for name in pairs(parts)do names[#names+1]=name end;table.sort(names)
    for i=1,#names do for j=i+1,#names do check(not ov(parts[names[i]],parts[names[j]],.5),ctag..': '..names[i]..' and '..names[j]..' do not overlap')end end
    check(line1.RW>=60 and line1.RH>=18,ctag..string.format(': the sentence has room (%.0f x %.0f)',line1.RW,line1.RH))
    if variant=='Full'then
     check(ribbon and ribbon.Visible,ctag..': the ribbon shows')
     if ribbon and ribbon.Visible then
      check(ribbon.X>=pn.X and ribbon.X+ribbon.W<=pn.X+pn.W and ribbon.Y>=ribbonTop-.5 and ribbon.Y+ribbon.H<=pn.Y+ribbon.H,ctag..': the ribbon is inside the banner width and above / on the panel top')
      check(not ov(ribbon,line1,0)and not ov(ribbon,line2,0)and(not parts.Pic or not ov(ribbon,parts.Pic,0))and(not parts.Avatar or not ov(ribbon,parts.Avatar,0)),ctag..': the ribbon touches no text, picture or avatar')
     end
    else check(not ribbon.Visible,ctag..': the small banner has no ribbon')end
    -- texts
    local gl=g.Banner.Panel
    local okc,ok1,s1,lines1=pcall(UW.fit,gl.Line1,{W=line1.RW,H=line1.RH});if not okc then print('ERR',ctag,gl.Line1.Text,ok1);ok1,s1,lines1=false,0,0 end
    check(ok1,ctag..string.format(': the sentence fits (size %d, %d line(s), box %.0fx%.0f): %s',s1,lines1,line1.RW,line1.RH,gl.Line1.Text:gsub('<[^>]+>','')))
    check(s1>=mt.L1Min,ctag..': ... at least at the smallest size ('..s1..' >= '..mt.L1Min..')')
    local w2=UW.width(Rules.Subline(e,0,mt.Short),mt.L2Size);local w3=UW.width(Rules.Subline(e,5,mt.Short),mt.L2Size)
    check(w2<=line2.RW+.5,ctag..string.format(': the small line fits in one line (%.0f of %.0f px)',w2,line2.RW))
    if case.Name:find('typical',1,true)then check(w3<=line2.RW+.5,ctag..string.format(': ... and with "+5 more" (%.0f of %.0f px)',w3,line2.RW))end -- (the worst cases are cut with an ellipsis: TextTruncate.AtEnd)
    if variant=='Full'then
     local ok3,s3=UW.fit(g.Banner.Ribbon.Title,{W=ribbon.RW-30,H=ribbon.RH})
     check(ok3,ctag..': the ribbon title fits ('..g.Banner.Ribbon.Title.Text..' at '..tostring(s3)..')')
    end
    tested[ctag]=true
    local key=variant..(mt.Compact and' compact'or' ')
    smallest[key]=math.min(smallest[key]or 1e9,pn.W)
   end
  end
 end
end
local n=0;for _ in pairs(tested)do n+=1 end
check(n>=26*#cases,'every screen x look was measured ('..n..' cases)')

-- a tutorial card above pushes the banner below it, on every screen
for _,v in ipairs(views)do
 local w,h,touch=v[1],v[2],v[3];view[1],view[2]=w,h;W.UIS.TouchEnabled=touch;placeControls(nil)
 boot();pg:SetAttribute('TutorialCardBottom',math.floor(h*.3))
 ctx.Remote.OnClientEvent:Fire({Kind='Pull',Id='T-'..w..'x'..h,UserId=1,Name='Ann',SeedId=seedOf('Mythic'),Odds=800})
 seconds(.6)
 local g=pg:FindFirstChild('PullAnnouncer');local list,by=UW.rects(g,w,h);local pn=by['PullAnnouncer.Banner.Panel']
 local mt=Rules.Metrics(w,h,'Full')
 check(pn.Y-mt.Overhang>=math.floor(h*.3)+8-.5,string.format('%dx%d: the banner clears a tutorial card ending at y %d (banner top %.0f)',w,h,math.floor(h*.3),pn.Y-mt.Overhang))
 pg:SetAttribute('TutorialCardBottom',nil)
end
ctx.Script:Destroy()

print(('R151 layout: %d checks, %d fails'):format(checks,fails))
if fails>0 then error('failures')end
print(('%d/%d checks passed'):format(checks-fails,checks))
