-- R120: one scrolling shop page. Pure pixel layout (no Roblox layout objects), so the client,
-- the offline tests and the PNG renders all use the same numbers.
-- Frame(): panel + quick-jump column inside the ScreenGui's safe area (CoreUISafeInsets, so the
-- Roblox top bar is already excluded). Touch controls are kept clear when HudLayout reports them.
-- Content(): every section and card rect in scroll-canvas coordinates.
local L={}
local function overlaps(a,b,pad)
 pad=pad or 0
 return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad
end
L.Overlaps=overlaps
L.Sections={
 {Key='Featured',Page='Packs',Title='FEATURED',Label='Featured'},
 {Key='Passes',Page='Passes',Title='PASSES',Label='Passes'},
 {Key='Speed',Page='Speed',Title='SPEED',Label='Speed'},
 {Key='Money',Page='Cash',Title='MONEY',Label='Money'},
 {Key='Gems',Page='Gems',Title='GEMS',Label='Gems'},
}
-- Legacy PremiumPage values (old tab names) -> section key.
L.PageSection={Packs='Featured',Featured='Featured',Passes='Passes',Perks='Passes',Speed='Speed',Cash='Money',Money='Money',Gems='Gems'}
local function round(v)return math.floor(v+.5)end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
-- Header and font scale from the panel size.
local function scale(pw,ph)return clamp(math.min(pw/900,ph/560),.6,1.1)end
L.Scale=scale

-- view: gui size; touch: TouchEnabled; controls: HudLayout.Controls() result or nil.
function L.Frame(w,h,touch,controls)
 local n=#L.Sections
 local portrait=h>w
 local m=(touch or h<500)and 8 or 16
 local thumb=controls and controls.Joystick;local jump=controls and controls.Jump
 local best
 local function consider(c)
  -- Never cover a native thumb control.
  for _,zone in ipairs({thumb,jump})do
   if zone and(overlaps(c.Panel,zone,4)or overlaps(c.Column,zone,4))then return end
  end
  if c.Panel.X<0 or c.Panel.Y<0 or c.Panel.X+c.Panel.W>w or c.Panel.Y+c.Panel.H>h then return end
  if c.Column.X<0 or c.Column.Y<0 or c.Column.X+c.Column.W>w or c.Column.Y+c.Column.H>h then return end
  if overlaps(c.Panel,c.Column,2)then return end
  c.Score=c.Panel.W*c.Panel.H*(c.Labels and 1.08 or 1)*(c.Button>=44 and 1 or .8)
  if not best or c.Score>best.Score then best=c end
 end
 if portrait then
  -- Jump buttons become a row along the top edge of the panel.
  local gap=6
  local bw=math.min(84,math.floor((w-2*m-gap*(n-1))/n))
  local bh=bw>=58 and 56 or 46
  local bottom=h-m
  for _,zone in ipairs({thumb,jump})do if zone then bottom=math.min(bottom,zone.Y-8)end end
  local rowY=m;local py=rowY+bh+8
  local pw=math.min(w-2*m,720);local px=round((w-pw)/2)
  local rowW=n*bw+(n-1)*gap
  consider({Mode='Row',Labels=bh>=56,Button=math.min(bw,bh),ButtonW=bw,ButtonH=bh,Gap=gap,
   Panel={X=px,Y=py,W=pw,H=math.min(bottom-py,1000)},Column={X=round((w-rowW)/2),Y=rowY,W=rowW,H=bh}})
 else
  local gap=touch and 6 or 8
  local maxW=math.min(1100,w*(touch and .80 or .75));local maxH=760
  local left=m
  if thumb then left=math.max(left,thumb.X+thumb.W+8)end
  for s=touch and 64 or 84,40,-2 do
   local bw=touch and s or round(s*1.1);local bh=s
   local colH=n*bh+(n-1)*gap
   local spots={}
   -- (a) column tight to the right of a centred panel, (b) at the right edge, (c) just left of the jump button.
   spots[#spots+1]='beside'
   spots[#spots+1]=w-m-bw
   if jump then spots[#spots+1]=jump.X-8-bw end
   -- (d) touch: panel + column as one block, as wide as the controls allow, centred.
   if touch then spots[#spots+1]='block'end
   for _,spot in ipairs(spots)do
    local pw,cx,px
    if spot=='beside'then
     pw=math.min(maxW,w-2*m-2*(bw+gap+4))
     px=round((w-pw)/2);cx=px+pw+gap+4
    elseif spot=='block'then
     local limit=w-m
     if jump then limit=math.min(limit,jump.X-8)end
     pw=math.min(maxW,limit-bw-gap-4-left)
     px=math.max(left,round((w-(pw+gap+4+bw))/2))
     if px+pw+gap+4+bw>limit then px=limit-bw-gap-4-pw end
     cx=px+pw+gap+4
    else
     cx=spot;pw=math.min(maxW,cx-gap-4-left)
    end
    if pw>=220 then
     px=px or math.max(left,math.min(round((w-pw)/2),cx-gap-4-pw))
     if px<left then px=left;pw=math.min(pw,cx-gap-4-px)end
     local top,bottom=m,h-m
     local panelRect={X=px,Y=top,W=pw,H=0}
     -- The panel stops above a thumb control it would otherwise sit over.
     for _,zone in ipairs({thumb,jump})do
      if zone and px<zone.X+zone.W+4 and px+pw>zone.X-4 then bottom=math.min(bottom,zone.Y-8)end
     end
     local ph=math.min(maxH,bottom-top)
     local py=top+math.max(0,round((bottom-top-ph)/2))
     panelRect.Y=py;panelRect.H=ph
     -- Column starts under the header like the reference, moving up when it would not fit.
     local k=scale(pw,ph);local header=L.HeaderHeight(k)
     local cy=py+header
     local colBottom=h-m
     if jump and cx<jump.X+jump.W+4 and cx+bw>jump.X-4 then colBottom=math.min(colBottom,jump.Y-8)end
     if cy+colH>colBottom then cy=math.max(m,colBottom-colH)end
     if ph>=200 and cy+colH<=colBottom then
      consider({Mode='Column',Labels=bh>=50,Button=math.min(bw,bh),ButtonW=bw,ButtonH=bh,Gap=gap,Panel=panelRect,Column={X=cx,Y=cy,W=bw,H=colH}})
     end
    end
   end
  end
 end
 if not best then
  -- Last resort (tiny or odd screens): keep everything on screen, controls permitting.
  local bw=40;local gap=4;local colH=n*bw+(n-1)*gap
  local pw=math.max(160,w-2*m-bw-gap);local ph=math.max(160,h-2*m)
  best={Mode='Column',Labels=false,Button=bw,ButtonW=bw,ButtonH=bw,Gap=gap,Panel={X=m,Y=m,W=pw,H=ph},Column={X=m+pw+gap,Y=m,W=bw,H=colH},Fallback=true}
 end
 local f=best;local k=scale(f.Panel.W,f.Panel.H)
 f.K=k;f.Header=L.HeaderHeight(k);f.Portrait=portrait;f.Margin=m
 f.Body={X=f.Panel.X,Y=f.Panel.Y+f.Header,W=f.Panel.W,H=f.Panel.H-f.Header}
 local buttons={}
 for i=1,n do
  if f.Mode=='Row'then buttons[i]={X=f.Column.X+(i-1)*(f.ButtonW+f.Gap),Y=f.Column.Y,W=f.ButtonW,H=f.ButtonH}
  else buttons[i]={X=f.Column.X,Y=f.Column.Y+(i-1)*(f.ButtonH+f.Gap),W=f.ButtonW,H=f.ButtonH}end
 end
 f.Buttons=buttons
 return f
end
function L.HeaderHeight(k)return round(clamp(64*k,40,68))end

-- Scroll content. width = scroll frame width (scrollbar excluded); k = font/size scale.
function L.Content(width,k,counts)
 counts=counts or{}
 local pad=round(clamp(10*k,6,12));local gap=round(clamp(10*k,6,12))
 local inner=width-pad*2
 local y=pad;local out={Pad=pad,Gap=gap,Width=width,Inner=inner,K=k,Sections={},Cards={}}
 local function header(key,title)
  local h=round(clamp(44*k,30,48))
  out.Cards[key..'Header']={X=pad,Y=y,W=inner,H=h};y+=h+math.floor(gap/2)
 end
 local function section(key)out.Sections[key]=y end
 local button=round(clamp(42*k,30,46))
 out.Button=button
 -- FEATURED: the limited Mech pack banner. No section title (like the reference).
 section('Featured')
 -- Wide: preview | 6 tiles in a row, buttons under the tiles. Medium: preview | 3x2 tiles, buttons full width.
 -- Narrow (portrait): stacked.
 local mode=inner>=640 and'Wide'or inner>=300 and'Medium'or'Narrow'
 local wide=mode~='Narrow'
 local fp=round(clamp(10*k,6,12))
 local titleH=mode=='Narrow'and round(clamp(60*k,44,64))or round(clamp(46*k,30,52))
 local tg=round(clamp(6*k,4,8));local cg=tg
 local f={Wide=wide,Mode=mode,Pad=fp,TitleH=titleH}
 local function buyRow(x,rowY,width,chipsShare)
  local chipsW=math.floor(width*chipsShare)
  local cw=math.floor((chipsW-cg*2)/3)
  f.Chips={};for i=1,3 do f.Chips[i]={X=x+(i-1)*(cw+cg),Y=rowY,W=cw,H=button}end
  local buyX=x+cw*3+cg*3;local buyW=x+width-buyX
  local gw=math.floor((buyW-cg)*.4)
  f.Gem={X=buyX,Y=rowY,W=gw,H=button};f.Robux={X=buyX+gw+cg,Y=rowY,W=buyW-gw-cg,H=button}
 end
 -- R155: under the buy row, the Mech pack's coat line ("Gold 4.5% / Diamond 0.5% coat") and the limited event's countdown: side by side (wide / medium), stacked (narrow).
 -- Returns the row's bottom (the card's height follows it).
 local noteH=round(clamp(20*k,15,24))
 local function noteRow(y,stacked)
  local w=inner-fp*2
  if stacked then
   f.Coat={X=fp,Y=y,W=w,H=noteH};f.Timer={X=fp,Y=y+noteH+2,W=w,H=noteH};return y+noteH*2+2
  end
  local cw=math.floor(w*.5)
  f.Coat={X=fp,Y=y,W=cw,H=noteH};f.Timer={X=fp+cw+tg,Y=y,W=w-cw-tg,H=noteH};return y+noteH
 end
 if mode=='Wide'then
  local previewW=round(inner*.30)
  local tilesW=inner-previewW-fp*3
  local tw=math.floor((tilesW-tg*5)/6);local th=round(tw*1.28)
  local midY=fp+titleH+4
  f.Preview={X=fp,Y=midY-6,W=previewW,H=th+6+button+8}
  f.Tiles={};for i=1,6 do f.Tiles[i]={X=fp*2+previewW+(i-1)*(tw+tg),Y=midY,W=tw,H=th}end
  local rowY=midY+th+8
  buyRow(fp*2+previewW,rowY,tilesW,.46)
  f.H=noteRow(rowY+button+4,false)+fp
 elseif mode=='Medium'then
  local previewW=round(inner*.32)
  local tilesW=inner-previewW-fp*3
  local tw=math.floor((tilesW-tg*2)/3);local th=round(math.min(tw*.82,96*k+20))
  local midY=fp+titleH+2
  f.Preview={X=fp,Y=midY,W=previewW,H=th*2+tg}
  f.Tiles={};for i=1,6 do local c=(i-1)%3;local r=math.floor((i-1)/3);f.Tiles[i]={X=fp*2+previewW+c*(tw+tg),Y=midY+r*(th+tg),W=tw,H=th}end
  local rowY=midY+th*2+tg+8
  buyRow(fp,rowY,inner-fp*2,.5)
  f.H=noteRow(rowY+button+4,false)+fp
 else
  local previewH=round(clamp(inner*.3,90,140))
  f.Preview={X=fp,Y=fp+titleH,W=inner-fp*2,H=previewH}
  local cols=3;local tw=math.floor((inner-fp*2-tg*(cols-1))/cols);local th=round(tw*.9)
  local ty=fp+titleH+previewH+6
  f.Tiles={};for i=1,6 do local c=(i-1)%cols;local r=math.floor((i-1)/cols);f.Tiles[i]={X=fp+c*(tw+tg),Y=ty+r*(th+tg),W=tw,H=th}end
  local rowY=ty+2*th+tg+8
  local cw=math.floor((inner-fp*2-tg*2)/3)
  f.Chips={};for i=1,3 do f.Chips[i]={X=fp+(i-1)*(cw+tg),Y=rowY,W=cw,H=button}end
  local buyY=rowY+button+tg;local gw=math.floor((inner-fp*2-tg)*.42)
  f.Gem={X=fp,Y=buyY,W=gw,H=button};f.Robux={X=fp+gw+tg,Y=buyY,W=inner-fp*2-gw-tg,H=button}
  f.H=noteRow(buyY+button+4,true)+fp
 end
 out.Featured=f
 out.Cards.Featured={X=pad,Y=y,W=inner,H=f.H};y+=f.H+gap
 -- PASSES: two wide cards per row (one per row when narrow).
 section('Passes');header('Passes','PASSES')
 local passCount=counts.Passes or 2
 local pcols=inner>=360 and 2 or 1
 local pw=math.floor((inner-gap*(pcols-1))/pcols)
 local ph=round(clamp(pw*(pcols==2 and .52 or .46),132,230))
 out.PassCards={}
 for i=1,passCount do
  local c=(i-1)%pcols;local r=math.floor((i-1)/pcols)
  out.PassCards[i]={X=pad+c*(pw+gap),Y=y+r*(ph+gap),W=pw,H=ph}
 end
 y+=math.ceil(passCount/pcols)*(ph+gap)
 -- SPEED: the five bundles (R122: the "DOUBLE your SPEED" boost banner was removed).
 section('Speed');header('Speed','SPEED')
 local function bundles(kind,count)
  count=count or 5
  local list={}
  local cols=inner>=520 and 3 or 2
  local cw=math.floor((inner-gap*(cols-1))/cols)
  local ch=round(clamp(cw*(cols==3 and .74 or .82),124,250))
  local i=1;local rowY=y
  while i<=count do
   local left=count-i+1
   -- Last row of two goes wide; a lone last card spans the row.
   local inRow=math.min(cols,left)
   if cols==3 and left==2 then inRow=2 end
   local w=math.floor((inner-gap*(inRow-1))/inRow)
   local h=inRow<cols and round(ch*1.06)or ch
   for j=1,inRow do list[i]={X=pad+(j-1)*(w+gap),Y=rowY,W=w,H=h};i+=1 end
   rowY+=h+gap
  end
  y=rowY;out[kind..'Cards']=list
 end
 bundles('Speed',counts.Speed)
 -- MONEY
 section('Money');header('Money','MONEY')
 bundles('Money',counts.Money)
 -- GEMS: cash -> gems converter and the index tip.
 section('Gems');header('Gems','GEMS')
 local gwide=inner>=540
 local gemH=gwide and round(clamp(150*k,124,190))or round(clamp(250*k,214,300))
 out.Cards.Convert={X=pad,Y=y,W=inner,H=gemH,Wide=gwide};y+=gemH+gap
 local earnH=round(clamp(70*k,58,90))
 out.Cards.Earn={X=pad,Y=y,W=inner,H=earnH};y+=earnH+pad
 out.Height=y
 return out
end
-- Canvas Y for a section, kept inside the scroll range.
function L.Target(content,key,viewHeight)
 if key=='Featured'then return 0 end
 local y=math.max(0,(content.Sections[key]or 0)-math.floor(content.Gap/2))
 return math.max(0,math.min(y,math.max(0,content.Height-viewHeight)))
end
-- Section shown at a canvas Y (the reading line sits 30% down the view).
function L.Current(content,canvasY,viewHeight,pinned)
 local maxY=math.max(0,content.Height-viewHeight)
 if pinned and canvasY>=maxY-2 then
  local top=content.Sections[pinned]
  if top and top>=canvasY-2 and top<canvasY+viewHeight then return pinned end
 end
 local line=canvasY+viewHeight*.3;local current='Featured'
 for _,s in ipairs(L.Sections)do if content.Sections[s.Key]<=line then current=s.Key end end
 if canvasY>=maxY-2 and maxY>0 then
  -- At the very bottom the last section is the one being read.
  local last=L.Sections[#L.Sections].Key
  if content.Sections[last]<canvasY+viewHeight then current=last end
 end
 return current
end
return L
