--!nocheck
-- R153, the 4 Leaf Clover PICTURE (CloverIcon153 + CloverPassImage153, drawn through the game's one embedded-image decoder EmbeddedImage153) on the Roblox mock with the real modules.
--  1. the embedded picture: size, alpha, clean edges, the checksum (and an independent decode of the same module in Python: run_clover.sh compares the ADLER line), tamper / truncation errors, ticks
--  2. the source priority of every Attach: the pass's own Roblox icon (SetInfo -> rbxassetid://, once IsLoaded) > the drawn picture (EditableImage, Ensure) > the plain shapes / emoji
--  3. no EditableImage leak: one per client however many Attaches, destroyed when the last Attach lets go / when the pass icon is everywhere / when a draw half fails; a failed draw keeps the shapes
--  4. slices (the decode yields), a Release mid-decode cancels it, the real engine path (AssetService.CreateEditableImage + WritePixelsBuffer + Content.fromObject) with its arguments
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
W.env.bit32=bit32
local Icon=W.module('CloverIcon153');local Data=W.module('CloverPassImage153');local Emb=W.module('EmbeddedImage153')
local function adler(b)local a,s=1,0;for i=0,buffer.len(b)-1 do a=(a+buffer.readu8(b,i))%65521;s=(s+a)%65521 end;return s*65536+a end
-- 1. the picture ------------------------------------------------------------------------------------------------------------------------------------
check(Data.Key=='CloverPass153'and Data.Width==128 and Data.Height==128 and Data.Colors<=256 and Data.Bytes==Data.Colors*3+2*128*128,'the module is a 128x128 palette picture (key CloverPass153, '..Data.Colors..' colours, '..Data.Bytes..' bytes of stream)')
do
 local ticks=0
 local w,h,rgba=Emb.Decode(Data,function()ticks+=1 end)
 check(w==128 and h==128 and buffer.len(rgba)==128*128*4,'Decode: 128 x 128, '..buffer.len(rgba)..' bytes of RGBA')
 check(ticks>=8,'... in slices: it ticks while it works ('..ticks..' ticks)')
 local _,_,again=Emb.Decode(Data)
 check(adler(again)==adler(rgba),'... and without ticks the result is the same')
 print('ADLER '..adler(rgba))
 local function px(x,y)local o=(y*128+x)*4;return buffer.readu8(rgba,o),buffer.readu8(rgba,o+1),buffer.readu8(rgba,o+2),buffer.readu8(rgba,o+3)end
 local _,_,_,a1=px(0,0);local _,_,_,a2=px(127,0);local _,_,_,a3=px(0,127);local _,_,_,a4=px(127,127)
 check(a1==0 and a2==0 and a3==0 and a4==0,'the four corners are transparent (alpha 0)')
 local _,_,_,ac=px(64,64);check(ac==255,'the middle of the clover is solid (alpha 255)')
 local clear,solid,soft,minX,maxX,minY,maxY=0,0,0,128,-1,128,-1
 local dirty=0;local softGreen=0
 for y=0,127 do for x=0,127 do
  local r,g,b,a=px(x,y)
  if a==0 then clear+=1;if not(r==24 and g==110 and b==36)then dirty+=1 end
  else
   if a==255 then solid+=1 else soft+=1;if g>r and g>b then softGreen+=1 end end
   minX=math.min(minX,x);maxX=math.max(maxX,x);minY=math.min(minY,y);maxY=math.max(maxY,y)
  end
 end end
 check(solid>6000 and solid<12000,'about half of the pixels are the clover ('..solid..' solid, '..soft..' soft-edged, '..clear..' clear)')
 check(minX>=2 and maxX<=125 and minY>=1 and maxY<=126,'it sits inside the picture with a margin (x '..minX..'..'..maxX..', y '..minY..'..'..maxY..')')
 check(dirty==0,'every clear pixel carries one dark green, so filtering bleeds green into the edge (never black, never white)')
 check(soft>60 and softGreen==soft,'the soft edge pixels (premultiplied-correct resize) are all green-dominant: no grey / white fringe ('..softGreen..' / '..soft..')')
 local r,g,b=px(64,40);check(g>r and g>b and g>100,'a pixel inside a leaf is green ('..r..','..g..','..b..')')
end
do
 local bad=table.clone(Data);bad.Data=table.clone(Data.Data)
 local s=bad.Data[2];bad.Data[2]=s:sub(1,10)..(s:sub(11,11)=='A'and'B'or'A')..s:sub(12)
 check(not pcall(Emb.Decode,bad),'one changed character in the data: Decode errors (checksum or inflate)')
 local short=table.clone(Data);short.Data={table.concat(Data.Data):sub(1,2000)}
 check(not pcall(Emb.Decode,short),'a truncated stream: Decode errors')
 local wrong=table.clone(Data);wrong.Bytes=Data.Bytes+1
 check(not pcall(Emb.Decode,wrong),'a stream length that does not fit the header: Decode errors')
 local bigger=table.clone(Data);bigger.Width=100000
 check(not pcall(Emb.Decode,bigger),'an absurd size: Decode errors before it allocates anything')
 local wrongSum=table.clone(Data);wrongSum.Check=Data.Check+1
 local ok,why=pcall(Emb.Decode,wrongSum);check(not ok and tostring(why):find('checksum',1,true)~=nil,'a wrong Check: "checksum" error ('..tostring(why)..')')
end
do
 check(Icon.Decode==nil and Icon.Hooks.Create==nil and Icon.Hooks.Content==nil,'CloverIcon153 has no decoder of its own and no engine hooks: the picture goes through EmbeddedImage153')
end
-- hooks ------------------------------------------------------------------------------------------------------------------------------------------------
local created,warns={},0
local function hooks(opts)
 opts=opts or{}
 Emb.Hooks.Create=function(w,h,rgba)
  if opts.CreateError then error(opts.CreateError)end
  if opts.CreateNil then return nil end
  local o={W=w,H=h,Data=rgba,Destroyed=false};function o.Destroy(self)self.Destroyed=true end;created[#created+1]=o;return o
 end
 Emb.Hooks.Content=function(image)if opts.ContentError then error('content failed')end;return {Image=image} end
 Emb.Hooks.None={None=true}
 Emb.Hooks.Spawn=opts.Spawn or function(f)f()end
 Emb.Hooks.Wait=opts.Wait or function()end
 Icon.Hooks.Preload=function()end
end
local function live()local n=0;for _,o in ipairs(created)do if not o.Destroyed then n+=1 end end;return n end
local function fresh()Icon.Reset();table.clear(created);Emb.SliceSeconds=.004;hooks()end
local function frame()return R.new('Frame')end
local function parts(root)return root:FindFirstChild('Fallback'),root:FindFirstChild('Embedded'),root:FindFirstChild('PassIcon')end
-- 2. priority ------------------------------------------------------------------------------------------------------------------------------------
fresh()
do
 local root=Icon.Attach(frame())
 local fb,emb,pass=parts(root)
 check(Icon.Source(root)=='fallback'and fb.Visible==true and emb.Visible==false and pass==nil,'a new Attach: the plain clover (shapes) shows, nothing is loaded')
 local imageLabels=0;for _,d in ipairs(fb:GetDescendants())do if d:IsA('ImageLabel')then imageLabels+=1 end end
 check(#fb:GetDescendants()>=20 and imageLabels==0,'the plain clover is drawn with UI shapes only ('..#fb:GetDescendants()..' frames, no image)')
 check(#created==0 and Emb.Status().Pictures==0,'nothing is drawn until Ensure (lazy: the shop opens, the luck row appears)')
 Icon.Ensure()
 check(#created==1 and created[1].W==128 and created[1].H==128 and buffer.len(created[1].Data)==65536,'Ensure draws the picture: one EditableImage, 128 x 128, 65536 bytes of RGBA')
 check(Icon.Source(root)=='embedded'and emb.Visible==true and fb.Visible==false,'... and the Attach switched to it')
 check(emb.ImageContent and emb.ImageContent.Image==created[1],'... the label shows that image (Content of the EditableImage)')
 check(emb.ScaleType==R.Enum.ScaleType.Fit and emb.BackgroundTransparency==1,'... fitted, no background')
 Icon.Ensure();check(#created==1,'Ensure again changes nothing')
 for _=1,50 do Icon.Attach(frame())end
 check(#created==1 and live()==1 and Emb.Status().Pictures==1,'50 more Attaches share the one image (still 1 EditableImage)')
 local late=Icon.Attach(frame());check(Icon.Source(late)=='embedded','an Attach made after it is wanted shows it at once')
 check(Icon.SetInfo({IconImageAssetId=3333333333,PriceInRobux=999})==true,'SetInfo takes the info table with an IconImageAssetId (ids above 2^31 too)')
 local _,_,p1=parts(root)
 check(p1~=nil and p1.Image=='rbxassetid://3333333333','every Attach got a PassIcon: rbxassetid://3333333333 (exactly: '..tostring(p1 and p1.Image)..')')
 check(Icon.Source(root)=='embedded'and p1.Visible==false,'... the drawn picture stays until the pass icon has LOADED')
 check(Icon.SetInfo({IconImageAssetId=3333333333})==true,'the same info twice')
 local n=0;for _,c in ipairs(root:GetChildren())do if c.Name=='PassIcon'then n+=1 end end;check(n==1,'... adds no second PassIcon')
 p1.IsLoaded=true
 check(Icon.Source(root)=='pass'and p1.Visible==true and emb.Visible==false and fb.Visible==false,'once IsLoaded: the pass icon shows (it beats the drawn picture and the shapes)')
 check(Icon.Source(late)=='embedded','... the other Attaches follow when THEIR icon has loaded')
 check(live()==1,'(the drawn picture is still needed by the Attaches whose icon is not loaded)')
end
-- the pass icon everywhere: the drawn picture is destroyed
fresh()
do
 local a,b=Icon.Attach(frame()),Icon.Attach(frame())
 Icon.Ensure();check(live()==1,'(drawn)')
 Icon.SetInfo({IconImageAssetId=555})
 local _,_,pa=parts(a);local _,_,pb=parts(b)
 pa.IsLoaded=true;check(live()==1 and Icon.Source(a)=='pass'and Icon.Source(b)=='embedded','one pass icon loaded of two: the drawn picture stays for the other')
 pb.IsLoaded=true;check(live()==0 and created[1].Destroyed==true and Emb.Status().Pictures==0,'the pass icon loaded everywhere: the last one lets go and the drawn picture is destroyed (nothing alive)')
 check(Icon.Source(a)=='pass'and Icon.Source(b)=='pass','... and both still show the pass icon')
 check(select(2,parts(a)).Visible==false,'... the embedded label is hidden')
 local c=Icon.Attach(frame());local _,_,pc=parts(c)
 check(pc~=nil and pc.IsLoaded~=true,'a new Attach has its own pass icon label, not loaded yet')
 check(#created==2 and Icon.Source(c)=='embedded','... somebody asked for the picture and its pass icon is not loaded: it is drawn again for that one (2 made, 1 destroyed so far)')
 check(live()==1,'... 1 alive')
end
-- Ensure never draws when the pass icon already shows everywhere
fresh()
do
 local a=Icon.Attach(frame());Icon.SetInfo({IconImageAssetId=777});local _,_,p=parts(a);p.IsLoaded=true
 Icon.Ensure();check(#created==0,'the pass icon already shows: Ensure draws nothing')
 local b=Icon.Attach(frame());check(#created==1 and Icon.Source(b)=='embedded','... until an Attach whose pass icon is not loaded needs it')
end
-- the order does not matter: info first, then the Attach
fresh()
do
 Icon.SetInfo({IconImageAssetId=888})
 local a=Icon.Attach(frame());local _,_,p=parts(a)
 check(p~=nil and p.Image=='rbxassetid://888','info before the Attach: the Attach gets its PassIcon at once')
 check(Icon.Source(a)=='fallback','... and shows the shapes until something loads')
 Icon.Ensure();check(Icon.Source(a)=='embedded','... the drawn picture while the pass icon loads')
 p.IsLoaded=true;check(Icon.Source(a)=='pass','... then the pass icon')
 p.IsLoaded=false;check(Icon.Source(a)~='pass','(an icon that stops being loaded is not shown)')
end
-- junk info
fresh()
do
 local a=Icon.Attach(frame())
 for _,junk in ipairs({{},{IconImageAssetId=0},{IconImageAssetId=-4},{IconImageAssetId=1.5},{IconImageAssetId='x'},{IconImageAssetId=1e300},{IconImageAssetId=false},{IconImageAssetId={}},5,'s',true})do
  check(Icon.SetInfo(junk)==false,'SetInfo ignores '..R.typeof(junk)..' '..(type(junk)=='table'and tostring(junk.IconImageAssetId)or tostring(junk)))
 end
 check(Icon.SetInfo(nil)==false,'SetInfo(nil) is ignored');local _,_,p=parts(a);check(p==nil and Icon.Stats().PassId==nil,'... and made no PassIcon')
 check(Icon.SetInfo({IconImageAssetId='123'})==true and select(3,parts(a))~=nil and select(3,parts(a)).Image=='rbxassetid://123','a numeric string is read as a number')
end
-- 3. failures and leaks ---------------------------------------------------------------------------------------------------------------------------
fresh();hooks({CreateError='no memory'})
do
 local a=Icon.Attach(frame());Icon.Ensure()
 check(Icon.Source(a)=='fallback'and a:GetAttribute('EmbeddedRoute')=='fallback'and#created==0 and Emb.Status().Failed==1,'a draw that errors: the route is "fallback", the shapes stay, nothing was made')
 local b=Icon.Attach(frame());check(Icon.Source(b)=='fallback'and#created==0,'... a later Attach gets the same answer at once (no second try for the same picture)')
 Icon.Release();check(Emb.Status().Pictures==0,'... and letting go forgets the failure (a later Ensure tries again)')
 hooks();Icon.Ensure();local c=Icon.Attach(frame());check(#created==1 and Icon.Source(c)=='embedded','after that, with the engine working: the picture is drawn')
end
fresh();hooks({CreateNil=true})
do local a=Icon.Attach(frame());Icon.Ensure();check(Icon.Source(a)=='fallback'and Emb.Status().Failed==1,'a draw that returns no image: failed, the shapes stay')end
fresh();hooks({ContentError=true})
do
 local a=Icon.Attach(frame());Icon.Ensure()
 check(Icon.Source(a)=='fallback'and a:GetAttribute('EmbeddedRoute')=='fallback','a Content that cannot be made: the shapes stay')
 check(#created==1 and live()==1,'... the image just made stays alive only until the label lets go')
 Icon.Release();check(live()==0,'... Release destroys it (no leak)')
end
fresh()
do
 local a=Icon.Attach(frame());Icon.Ensure()
 Icon.Release();check(live()==0 and Icon.Source(a)=='fallback','Release destroys the image and the Attach falls back to the shapes')
 check(select(2,parts(a)).Visible==false and a:GetAttribute('Showing')==false,'... the embedded label is hidden')
 Icon.Release();check(#created==1 and live()==0,'Release twice destroys nothing twice')
 Icon.Ensure();check(#created==2 and live()==1 and Icon.Source(a)=='embedded','Ensure after a Release draws it again')
 Icon.Reset();check(live()==0 and Emb.Status().Pictures==0,'Reset (a fresh client for the tests): nothing left alive')
end
-- the Attach frame is destroyed: EmbeddedImage153 lets go of it by itself
fresh()
do
 local holder=frame();local a=Icon.Attach(holder);Icon.Ensure();check(live()==1,'(drawn)')
 select(2,parts(a)):Destroy();check(live()==0,'the Embedded label is destroyed: the image is destroyed with its last user')
end
-- 4. slices, cancel, the real engine path ---------------------------------------------------------------------------------------------------------
fresh()
do
 local yields=0;local co
 hooks({Spawn=function(f)co=coroutine.create(f);local ok,e=coroutine.resume(co);if not ok then error(e,0)end end,Wait=function()yields+=1;coroutine.yield()end})
 Emb.SliceSeconds=-1 -- every tick is "out of time": the decode yields at each one
 local a=Icon.Attach(frame());Icon.Ensure()
 check(Emb.Status().Pending==1 and#created==0 and coroutine.status(co)=='suspended'and Icon.Source(a)=='fallback','the decode yields (the game keeps running between slices): pending, nothing made yet, the shapes show')
 local steps=0;while coroutine.status(co)~='dead'and steps<1000 do steps+=1;coroutine.resume(co)end
 check(yields>=8 and Emb.Status().Ready==1 and#created==1,'... it finishes after '..yields..' slices and the picture is made once')
 check(Icon.Source(a)=='embedded','... and shown')
 Icon.Reset();Emb.SliceSeconds=-1;table.clear(created)
 local a2=Icon.Attach(frame());Icon.Ensure();coroutine.resume(co);coroutine.resume(co)
 check(Emb.Status().Pending==1,'(a second decode, two slices in)')
 Icon.Release()
 local steps2=0;while coroutine.status(co)~='dead'and steps2<1000 do steps2+=1;coroutine.resume(co)end
 check(#created==0 and Emb.Status().Pictures==0 and Icon.Source(a2)=='fallback','Release in the middle of the decode: nothing is ever made, nothing is kept, the shapes show')
 Emb.SliceSeconds=.004
end
-- the real engine path: AssetService:CreateEditableImage + WritePixelsBuffer + Content.fromObject
fresh()
Emb.Hooks.Create=nil;Emb.Hooks.Content=nil;Emb.Hooks.None=nil;Emb.Hooks.Spawn=function(f)f()end
do
 local AS=W.service('AssetService');local made={};local contents=0
 function AS.CreateEditableImage(_,opts)
  local o={Size=opts.Size,Writes={},Destroyed=false}
  function o.WritePixelsBuffer(self,pos,size,buf)self.Writes[#self.Writes+1]={pos,size,buf}end
  function o.Destroy(self)self.Destroyed=true end
  made[#made+1]=o;return o
 end
 W.env.Content={fromObject=function(o)contents+=1;return {Object=o}end,none={None=true}}
 local a=Icon.Attach(frame());Icon.Ensure();check(Icon.Source(a)=='embedded','the real path draws')
 local img=made[1]
 check(#made==1 and img.Size.X==128 and img.Size.Y==128,'CreateEditableImage({Size = 128 x 128}), once')
 check(#img.Writes==1 and img.Writes[1][1].X==0 and img.Writes[1][1].Y==0 and img.Writes[1][2].X==128 and img.Writes[1][2].Y==128 and buffer.len(img.Writes[1][3])==65536,'WritePixelsBuffer(Vector2.zero, 128 x 128, 65536 bytes), once')
 check(contents==1 and select(2,parts(a)).ImageContent.Object==img,'Content.fromObject(image) is what the label shows (made once for every Attach)')
 Icon.Release();check(img.Destroyed==true and select(2,parts(a)).ImageContent.None==true,'Release destroys the EditableImage and puts Content.none on the label')
 function AS.CreateEditableImage(_,opts)local o={Destroyed=false};function o.WritePixelsBuffer()error('write failed')end;function o.Destroy(self)self.Destroyed=true end;made[#made+1]=o;return o end
 local before=#made;Icon.Reset();local b=Icon.Attach(frame());Icon.Ensure()
 check(Icon.Source(b)=='fallback'and made[before+1].Destroyed==true,'a WritePixelsBuffer that fails: the image is destroyed (no leak), the shapes stay')
 AS.CreateEditableImage=nil;Icon.Reset();local c=Icon.Attach(frame());Icon.Ensure()
 check(Icon.Source(c)=='fallback'and Emb.Status().Failed==1,'no CreateEditableImage (Image APIs off): the shapes stay, quietly')
 Icon.Reset()
end
-- the emoji fallback if even the shapes cannot be made
fresh()
do
 local emblems=W.module('PremiumEmblems');local oldDraw=emblems.Draw;emblems.Draw=function()error('boom')end
 local ok,root=pcall(Icon.Attach,frame())
 check(ok and root~=nil,'a broken PremiumEmblems does not break an Attach')
 if ok then local label=root.Fallback:FindFirstChild('Emoji');check(label~=nil and label.Text=='🍀','... the last fallback is the 🍀 emoji')end
 emblems.Draw=oldDraw
end
Icon.Reset()
check(live()==0,'at the end nothing is alive')
print(string.format('R153 clover icon: %d checks, %d failures',checks,fails))
if fails>0 then error('failed')end
