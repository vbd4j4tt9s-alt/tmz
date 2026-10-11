--!nocheck
-- R153 (owner: "for the bonus roll pack replace that gift icon with the pack and make the colour of the button pair with the image"): the owner's pack picture embedded as data
-- (BonusPackImage153), decoded and drawn by EmbeddedImage153 (EditableImage, cached per picture, released when unused), the plain drawn stand-in (BonusGiftArt.PackIcon), and the
-- real TreadmillBonusClient wiring: the picture on the HUD button and on the roll screen's ribbon, the fallbacks (picture still decoding, Image API off, a bad stream), the colours
-- of the button, and nothing left behind. The REAL modules on the Roblox mock; the engine's EditableImage / Content are the Hooks.
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local EI=W.module('EmbeddedImage153');local D=W.module('BonusPackImage153');local Art=W.module('BonusGiftArt')
local function near3(c,r,g,b,tol)tol=tol or 1.5;return math.abs(c.R*255-r)<=tol and math.abs(c.G*255-g)<=tol and math.abs(c.B*255-b)<=tol end
-- 1. The data module ----------------------------------------------------------------------------------------------------------------------------------------------------
local text=0;for _,chunk in ipairs(D.Data)do text+=#chunk end
check(D.Key=='BonusPack153' and D.Width==112 and D.Height==112 and D.Colors==256,'data: key, 112 x 112, 256 colours')
check(D.Bytes==256*3+112*112*2,'data: Bytes = palette + indices + alpha ('..D.Bytes..')')
check(text<=16000 and text>=4000,'data: the base64 text is small ('..text..' characters, under 20 KB with its header)')
-- 2. Decode: the right size and alpha ---------------------------------------------------------------------------------------------------------------------------
local ticks=0
local w,h,rgba=EI.Decode(D,function()ticks+=1 end)
check(w==112 and h==112 and buffer.len(rgba)==112*112*4,'decode: 112 x 112, '..buffer.len(rgba)..' bytes of RGBA')
check(ticks>=5,'decode: it calls the yield hook as it works, so the caller can slice it ('..ticks..' ticks)')
local function px(x,y)local o=(y*w+x)*4;return buffer.readu8(rgba,o),buffer.readu8(rgba,o+1),buffer.readu8(rgba,o+2),buffer.readu8(rgba,o+3)end
local opaque,partial,clear,green,yellow=0,0,0,0,0;local x0,y0,x1,y1=w,h,-1,-1
local edgeLum,edgeN,inLum,inN=0,0,0,0
for y=0,h-1 do for x=0,w-1 do
 local r,g,b,a=px(x,y);local lum=(r*.3+g*.59+b*.11)
 if a==255 then opaque+=1;inLum+=lum;inN+=1 elseif a==0 then clear+=1 else partial+=1;edgeLum+=lum;edgeN+=1 end
 if a>0 then x0=math.min(x0,x);x1=math.max(x1,x);y0=math.min(y0,y);y1=math.max(y1,y)end
 if a==255 and g>r+30 and g>b+30 then green+=1 end
 if a==255 and r>200 and g>150 and b<90 then yellow+=1 end
end end
check(select(4,px(0,0))==0 and select(4,px(111,0))==0 and select(4,px(0,111))==0 and select(4,px(111,111))==0,'decode: the four corners are transparent')
check(select(4,px(56,56))==255,'decode: the middle is opaque')
check(opaque>=6000 and clear>=3500 and partial>=300 and partial<=1500,'decode: solid '..opaque..' / see-through '..clear..' / soft edge '..partial..' pixels')
check(x0>=1 and y0>=1 and x1<=110 and y1<=110 and x1-x0>=75 and y1-y0>=100,'decode: the pack fills the picture and stays off its border ('..x0..','..y0..' - '..x1..','..y1..')')
check(green>=opaque*.3 and yellow>=opaque*.15,'decode: it is green (the bag) and yellow (the "?" and the seals): '..green..' green, '..yellow..' yellow of '..opaque)
local r,g,b=px(56,56);check(r>=230 and g>=190 and b<=90,'decode: the middle of the "?" is yellow ('..r..','..g..','..b..')')
check(edgeN>0 and edgeLum/edgeN>=inLum/inN*.55,'decode: no dark fringe on the soft edge (edge brightness '..math.floor(edgeLum/edgeN)..' vs '..math.floor(inLum/inN)..' inside)')
-- transparent pixels next to the picture carry its colour (bilinear scaling on screen never mixes in black)
local bleedOk,bleedChecked=true,0
for y=1,h-2 do for x=1,w-2 do
 local _,_,_,a=px(x,y)
 if a==0 then
  local r0,g0,b0=px(x,y);local found,match=false,false
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local r1,g1,b1,a1=px(x+d[1],y+d[2])
   if a1>0 then found=true;if r1==r0 and g1==g0 and b1==b0 then match=true end end
  end
  if found then bleedChecked+=1;if not match then bleedOk=false end end
 end
end end
check(bleedOk and bleedChecked>200,'decode: transparent pixels beside the picture carry the colour of the nearest solid one ('..bleedChecked..' checked)')
-- corrupt data is refused, never drawn
local function copy(t)local c={};for k,v in pairs(t)do c[k]=v end;return c end
local bad=copy(D);bad.Data=table.clone(D.Data);bad.Data[3]=string.sub(D.Data[3],1,40)..(string.sub(D.Data[3],41,41)=='A'and'B'or'A')..string.sub(D.Data[3],42)
check(not pcall(EI.Decode,bad),'decode: one changed character is refused (inflate error or checksum)')
local wrong=copy(D);wrong.Bytes=D.Bytes+1;check(not pcall(EI.Decode,wrong),'decode: a wrong announced size is refused')
local small=copy(D);small.Width=64;check(not pcall(EI.Decode,small),'decode: a size that does not match the data is refused')
local cut=copy(D);cut.Data={D.Data[1],D.Data[2]};check(not pcall(EI.Decode,cut),'decode: a truncated stream is refused')
check(not pcall(EI.Decode,nil) and not pcall(EI.Decode,{}),'decode: nil / empty data is refused')
-- 3. Show / Release with the engine's hooks -----------------------------------------------------------------------------------------------------------------------
local made,contents,destroyed,queue={},{},0,{}
local mode={Fail=false,ContentFail=false,Defer=false}
EI.Hooks.Create=function(cw,ch,buf)if mode.Fail then error('no EditableImage')end;local o={W=cw,H=ch,Len=buffer.len(buf)};function o.Destroy()destroyed+=1;o.Dead=true end;made[#made+1]=o;return o end
EI.Hooks.Content=function(o)if mode.ContentFail then error('no Content')end;local c={Of=o};contents[#contents+1]=c;return c end
EI.Hooks.Spawn=function(fn)if mode.Defer then queue[#queue+1]=fn else fn()end end
EI.Hooks.Wait=function()end;EI.Hooks.None={Name='no content'}
local screen=R.new('Frame')
local function newLabel()local l=R.new('ImageLabel');l.Parent=screen;return l end -- (a label with no parent is never painted)
local routes={}
local l1,l2=newLabel(),newLabel()
local r1=EI.Show(l1,D,function(route)routes[#routes+1]='1:'..route end)
check(r1=='image' and l1:GetAttribute('ImageRoute')=='image' and routes[1]=='1:image','show: the picture is drawn into the label ('..tostring(r1)..')')
check(#made==1 and made[1].W==112 and made[1].H==112 and made[1].Len==112*112*4,'show: one EditableImage, 112 x 112, '..tostring(made[1] and made[1].Len)..' bytes')
check(l1.ImageContent==contents[1] and contents[1].Of==made[1],'show: the label\'s ImageContent is that image')
local r2=EI.Show(l2,D,function(route)routes[#routes+1]='2:'..route end)
check(r2=='image' and #made==1 and l2.ImageContent==contents[2] and contents[2].Of==made[1],'show: a second label shares the same EditableImage (cached per picture, one copy in memory)')
local st=EI.Status();check(st.Pictures==1 and st.Users==2 and st.Ready==1 and st.Failed==0 and st.Pending==0,'status: 1 picture, 2 users, ready')
EI.Show(l1,D,function(route)routes[#routes+1]='1b:'..route end)
check(#made==1 and EI.Status().Users==2,'show: the same label again changes nothing (no second image, no second user)')
EI.Release(l1)
check(made[1].Dead~=true and EI.Status().Users==1 and l2.ImageContent==contents[2],'release: the other label keeps the picture')
EI.Release(l2)
check(made[1].Dead==true and destroyed==1 and EI.Status().Pictures==0,'release: the last one lets go: the EditableImage is destroyed and the cache entry dropped')
check(l1.ImageContent~=contents[1] and l2.ImageContent~=contents[2],'release: the labels no longer point at the destroyed image')
EI.Release(l1);check(destroyed==1,'release: releasing twice does nothing')
-- shown again after a release: a new image
local l3=newLabel();EI.Show(l3,D);check(#made==2 and made[2].Dead~=true,'show: after everything was released a new Show draws a new image');EI.Release(l3)
-- failure: the Image API is off
mode.Fail=true;routes={}
local lf=newLabel();local rf=EI.Show(lf,D,function(route)routes[#routes+1]=route end)
check(rf=='fallback' and lf:GetAttribute('ImageRoute')=='fallback' and routes[1]=='fallback' and EI.Status().Failed==1,'fallback: no EditableImage -> the label says fallback ('..tostring(rf)..')')
local lf2=newLabel();local rf2=EI.Show(lf2,D,function(route)routes[#routes+1]=route end)
check(rf2=='fallback' and routes[2]=='fallback' and #made==2,'fallback: a label that comes later is told at once, nothing is tried again')
EI.Release(lf);EI.Release(lf2);check(EI.Status().Pictures==0,'fallback: released, nothing is left')
mode.Fail=false
-- failure: the content cannot be applied
mode.ContentFail=true;routes={}
local lc=newLabel();local rc=EI.Show(lc,D,function(route)routes[#routes+1]=route end)
check(rc=='fallback' and routes[#routes]=='fallback','fallback: an image that cannot become Content -> fallback')
EI.Release(lc);mode.ContentFail=false;check(EI.Status().Pictures==0 and made[#made].Dead==true,'fallback: ... released, and the image that was made is destroyed')
-- failure: a bad stream
local ls=newLabel();routes={};local rs=EI.Show(ls,bad,function(route)routes[#routes+1]=route end)
check(rs=='fallback' and routes[1]=='fallback','fallback: a bad stream -> fallback (Key '..tostring(bad.Key)..')')
EI.Release(ls)
local nokey=copy(D);nokey.Key=nil;local lk=newLabel();check(EI.Show(lk,nokey)=='fallback','fallback: data without a key -> fallback')
check(EI.Status().Pictures==0,'fallback: nothing cached for it')
-- pending: the label waits; letting go while it decodes means no image is ever made
mode.Defer=true;queue={};routes={}
local madeBefore=#made
local lp=newLabel();local rp=EI.Show(lp,D,function(route)routes[#routes+1]=route end)
check(rp=='pending' and lp:GetAttribute('ImageRoute')=='pending' and #routes==0 and EI.Status().Pending==1,'pending: the label waits for the decode')
for _,fn in ipairs(queue)do fn()end;queue={}
check(lp:GetAttribute('ImageRoute')=='image' and routes[1]=='image' and #made==madeBefore+1,'pending: when it is decoded the picture arrives')
EI.Release(lp)
local lq=newLabel();EI.Show(lq,D);EI.Release(lq)
check(EI.Status().Pending==1,'pending: let go while decoding: the entry waits for its thread')
madeBefore=#made;for _,fn in ipairs(queue)do fn()end;queue={}
check(#made==madeBefore and EI.Status().Pictures==0,'pending: ... which then makes no image at all, and drops the entry')
mode.Defer=false
-- a destroyed label lets go by itself
local ld=newLabel();EI.Show(ld,D);local usersBefore=EI.Status().Users
if ld.Destroying and ld.Destroying.Fire then ld.Destroying:Fire();check(EI.Status().Users==usersBefore-1 and EI.Status().Pictures==0,'release: a label that is destroyed lets go by itself')
else check(true,'release: (this mock has no Destroying signal on a label)');EI.Release(ld)end
-- 4. The plain pack made of frames --------------------------------------------------------------------------------------------------------------------------------
do
 local holder=R.new('Frame');local icon=Art.PackIcon(holder,'Icon',36)
 check(icon.Root.Name=='Icon' and icon.Root.Size.X.Offset==36 and icon.Root.AnchorPoint.X==.5,'icon: a 36 px square, anchored at its middle (rotates about it like the old gift)')
 check(icon.Picture:IsA('ImageLabel') and icon.Picture.Visible==false and icon.Picture.ScaleType==R.Enum.ScaleType.Fit,'icon: an ImageLabel, hidden until a picture is drawn into it')
 local drawn=icon.Drawn
 check(drawn.Body and drawn.SealTop and drawn.SealBottom and drawn.Mark,'icon: the stand-in has a body, two seals and a mark')
 check(drawn.Mark.Text=='?' and near3(drawn.Mark.TextColor3,252,220,41),'icon: a yellow "?"')
 local seal=drawn.SealTop:FindFirstChildOfClass('UIGradient');check(near3(seal.Color.A,252,220,41)and near3(seal.Color.B,231,152,2),'icon: gold seals')
 local body=drawn.Body:FindFirstChildOfClass('UIGradient');check(near3(body.Color.B,38,152,56)and body.Color.A.G>body.Color.A.R,'icon: a green body')
 check(drawn.SealTop.Position.Y.Scale<drawn.Body.Position.Y.Scale and drawn.SealBottom.Position.Y.Scale>drawn.Body.Position.Y.Scale,'icon: a seal above and a seal below the body')
 local count=0;for _ in ipairs(icon.Root:GetDescendants())do count+=1 end
 check(count<=24,'icon: the stand-in is small ('..count..' instances)')
end
-- 5. The real client: the button and the roll screen show the picture, and the fallbacks ----------------------------------------------------------------------------------
local function boot(opts)
 local C=UW.boot(opts);UW.frames(3,1/60);return C
end
local function allKids(root)local out={};for _,d in ipairs(root:GetDescendants())do out[#out+1]=d end;return out end
do
 local C=boot({imagePending=true})
 local face,ribbon=C.Button.Face,C.Overlay.Panel.Ribbon
 check(C.Image.Created[1]==nil and #C.Image.Queue==1,'client: the picture is decoded on its own thread, never in the script\'s start-up')
 check(face.Icon.Picture.Visible==false and face.Icon.Drawn~=nil and face.Icon.Drawn.Parent==face.Icon and face.Icon.Drawn.Mark.Text=='?','client: until it arrives the button shows the plain pack')
 check(ribbon.Pack.Picture.Visible==false and ribbon.Pack.Drawn.Parent==ribbon.Pack,'client: and so does the roll screen\'s ribbon')
 C.Image.Run()
 check(#C.Image.Created==1 and C.Image.Created[1].W==112 and C.Image.Created[1].H==112,'client: one EditableImage for both icons ('..#C.Image.Created..')')
 check(face.Icon.Picture.Visible==true and face.Icon.Picture:GetAttribute('ImageRoute')=='image' and face.Icon.Picture.ImageContent~=nil,'client: the button shows the picture')
 check(ribbon.Pack.Picture.Visible==true and ribbon.Pack.Picture:GetAttribute('ImageRoute')=='image','client: the ribbon shows it too')
 check(face.Icon:FindFirstChild('Drawn')==nil and ribbon.Pack:FindFirstChild('Drawn')==nil,'client: the plain pack is gone once the picture is there (no instances kept for nothing)')
 check(C.EI.Status().Pictures==1 and C.EI.Status().Users==2 and C.EI.Status().Ready==1,'client: the picture is cached once, used twice')
 -- the ring of wiggles and pops still reaches the icon
 C.Me:SetAttribute('TreadmillTraining',true);C.set('Interval',360);C.set('Ready',1);UW.frames(3,1/60)
 UW.seconds(5,1/60);check(C.Button.Visible==true,'client: the button with the picture works as before')
 -- nothing leaks: the roll screen opens and closes 12 times, the picture is not made again
 C.Reply={Ok=true,Stage=1,Variant='Pack01',Rarity='Common',Label='Forest Seed Pack',Pool='1',Ready=1}
 for i=1,12 do C.set('Ready',1);UW.frames(1,1/60);C.Button.Activated:Fire();UW.seconds(6,1/60);C.Overlay.Panel.Actions.Close.Activated:Fire();UW.seconds(.5,1/60)end
 check(#C.Image.Created==1 and C.Image.Created[1].Destroyed~=true,'client: 12 rolls: still the one image, never destroyed or made again')
 C.Me:SetAttribute('TreadmillTraining',nil);C.set('Ready',0);UW.frames(3,1/60)
 C.Script.Destroying:Fire()
 check(C.Image.Created[1].Destroyed==true and C.EI.Status().Pictures==0 and C.EI.Status().Users==0,'client: when the script goes away the EditableImage is destroyed and nothing is cached')
end
do
 local C=boot({imageFail=true})
 local face,ribbon=C.Button.Face,C.Overlay.Panel.Ribbon
 check(#C.Image.Created==0 and face.Icon.Picture.Visible==false and face.Icon.Drawn.Parent==face.Icon,'client: Image API off: the button keeps the plain pack')
 check(face.Icon.Picture:GetAttribute('ImageRoute')=='fallback' and ribbon.Pack.Picture:GetAttribute('ImageRoute')=='fallback' and ribbon.Pack.Drawn.Parent==ribbon.Pack,'client: ... and so does the ribbon (route: fallback)')
 check(face.Icon.Drawn.Mark.Text=='?' and near3(face.Icon.Drawn.Mark.TextColor3,252,220,41),'client: the fallback is a green pack with a yellow "?"')
 C.Me:SetAttribute('TreadmillTraining',true);C.set('Interval',360);C.set('Ready',1);UW.frames(3,1/60)
 check(C.Button.Visible==true and face.Title.Text=='BONUS READY!','client: the button works with the fallback')
 C.Script.Destroying:Fire();check(C.EI.Status().Pictures==0,'client: fallback: nothing left after teardown')
end
-- 6. The colours of the button -------------------------------------------------------------------------------------------------------------------------------------------
do
 local C=boot({});local face,button=C.Button.Face,C.Button
 local function lipColor()return button.Lip.BackgroundColor3 end
 local function strokeOf(frame)return frame:FindFirstChildOfClass('UIStroke')end
 -- ready: bright pack green, gold outline
 C.Me:SetAttribute('TreadmillTraining',nil);C.set('Interval',360);C.set('Ready',1);UW.frames(3,1/60)
 local readyGradient=face:FindFirstChildOfClass('UIGradient')
 check(near3(readyGradient.Color.A[2].V,46,172,66,2.5),'colours: ready: the face is the pack\'s bright green (the candy gradient\'s body colour)')
 local fs,ls=strokeOf(face),strokeOf(button.Lip)
 check(near3(fs.Color,244,195,35)and near3(ls.Color,176,112,10),'colours: the face outline is the seals\' gold, the lip\'s a darker gold')
 check(face.Title.TextStrokeColor3.G>face.Title.TextStrokeColor3.R and face.Title.TextStrokeTransparency==0,'colours: white text with a dark green stroke')
 local readyLip=lipColor()
 check(readyLip.G>readyLip.R and readyLip.G>readyLip.B,'colours: ready: the lip is green')
 -- charging: deeper green, yellow fill
 C.set('Ready',0);C.Me:SetAttribute('TreadmillTraining',true);C.set('DueAt',R.clock+200);UW.frames(20,1/60)
 local chargeLip=lipColor()
 check(chargeLip.G>chargeLip.R and chargeLip.G>chargeLip.B and chargeLip.G<readyLip.G,'colours: charging: a deeper green than ready ('..math.floor(chargeLip.G*255)..' vs '..math.floor(readyLip.G*255)..')')
 local fg=face.FillClip.Fill:FindFirstChildOfClass('UIGradient')
 check(near3(fg.Color.A,252,220,41)and near3(fg.Color.B,231,152,2),'colours: the charge fill is the pack\'s yellow')
 check(near3(strokeOf(face).Color,244,195,35),'colours: the gold outline stays in every phase')
 -- almost: the fill turns orange / red, everything else stays
 C.set('DueAt',R.clock+10);UW.frames(20,1/60)
 check(near3(fg.Color.A,255,132,70)and near3(fg.Color.B,222,60,34),'colours: the last 30 s: orange / red fill')
 check(face.Title.TextColor3.R==1 and face.Title.TextColor3.G==1 and face.Title.TextColor3.B==1,'colours: ... the text stays white (readable on yellow, green and red)')
 -- contrast: white on the dark green stroke over the pack's colours
 local function lum(c)local function f(v)return v<=.03928 and v/12.92 or((v+.055)/1.055)^2.4 end;return .2126*f(c.R)+.7152*f(c.G)+.0722*f(c.B)end
 local function contrast(a,b)local la,lb=lum(a),lum(b);if la<lb then la,lb=lb,la end;return(la+.05)/(lb+.05)end
 check(contrast(face.Title.TextColor3,face.Title.TextStrokeColor3)>=7,'colours: white against its dark green stroke: contrast '..string.format('%.1f',contrast(face.Title.TextColor3,face.Title.TextStrokeColor3))..' (7 or more)')
 check(contrast(face.Title.TextColor3,R.Color3.fromRGB(26,122,46))>=4.5,'colours: white against the charging green: contrast '..string.format('%.1f',contrast(face.Title.TextColor3,R.Color3.fromRGB(26,122,46))))
 C.Script.Destroying:Fire()
end
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
