-- R120: reference-style bundle card: bright gradient + rays, a growing pile of icons, a big outlined
-- amount and a bottom row [Gift | Gems price | Robux price]. Purchase wiring stays in GamePassClient.
-- R121: purple gift button (gift version of the product) left of the prices, like the reference.
local RS=game:GetService('ReplicatedStorage');local Art=require(RS.PremiumShopArt)
local B={};local C=Color3.fromRGB
B.Colors={Speed={C(140,236,255),C(46,178,252),C(28,112,226)},Cash={C(170,255,120),C(62,214,72),C(26,150,52)}}
-- Display amounts the reference way: $30B, +250K SPEED.
function B.AmountText(row)
 local n=row.Amount;local text
 if n>=1000 and n<1000000 then text=(string.format('%.1f',n/1000):gsub('%.0$',''))..'K'
 else text=require(RS.CashNumbers).Compact(n)end
 return row.Kind=='Cash'and('$'..text)or('+'..text..' SPEED')
end
function B.Create(parent,row,index)
 local cash=row.Kind=='Cash'
 local c=Art.Card(parent,row.Key..'Bundle',B.Colors[row.Kind])
 c:SetAttribute('BundleKey',row.Key);c.LayoutOrder=index
 local art=Art.Pile(c,cash and'Money'or'Bolt',index);art.ZIndex=2
 local amount=Art.Text(c,'Amount',B.AmountText(row),28);amount.ZIndex=4
 B.GiftButton(c,'GiftBundle','Gift '..row.Name)
 Art.Button(c,'GemBundle',Art.Colors.Gem,'Gem')
 Art.Button(c,'RobuxBundle',Art.Colors.Robux,'Robux')
 Art.SetCaption(c.GemBundle,tostring(row.GemPrice));Art.SetCaption(c.RobuxBundle,'Unavailable',false)
 require(RS.GuiShine).Attach(c,false)
 return c
end
-- Square purple gift button with a "SOON" tag shown while its gift product id is not set.
function B.GiftButton(parent,name,label)
 local b=Art.Button(parent,name,Art.Colors.Gift,'Gift');Art.SetCaption(b,'')
 b:SetAttribute('AccessibleLabel',label)
 local soon=Art.Text(b,'Soon','SOON',11,Color3.fromRGB(255,255,255));soon.ZIndex=(b.ZIndex or 5)+9;soon.Visible=false
 soon.AnchorPoint=Vector2.new(.5,1);soon.Position=UDim2.new(.5,0,1,-1);soon.Size=UDim2.fromScale(1,.36)
 return b
end
-- ready=false: grey + SOON (gift product id not set yet).
function B.SetGiftState(b,ready)
 local key=ready and'Ready'or'Soon'
 if b:GetAttribute('GiftState')~=key then
  b:SetAttribute('GiftState',key);Art.SetCaption(b,'',true,ready and Art.Colors.Gift or Art.Colors.Off)
  b.Soon.Visible=not ready
 end
end
-- w,h: card pixels; button: price-button height; k: scale.
function B.Layout(c,w,h,button,k)
 local pad=math.max(5,math.floor(8*k))
 local rowY=h-pad-button
 local g=math.max(3,math.floor(pad*.6))
 c.GiftBundle.Position=UDim2.fromOffset(pad,rowY);c.GiftBundle.Size=UDim2.fromOffset(button,button)
 local x=pad+button+g;local rest=w-x-pad-g
 if w<190 then
  -- Narrow cards (2 per row on phones): [Gift | Robux] along the bottom, Gems price just above.
  c.RobuxBundle.Position=UDim2.fromOffset(x,rowY);c.RobuxBundle.Size=UDim2.fromOffset(rest+g,button)
  rowY-=button+g
  c.GemBundle.Position=UDim2.fromOffset(pad,rowY);c.GemBundle.Size=UDim2.fromOffset(w-pad*2,button)
 else
  local gemW=math.floor(rest*.4)
  c.GemBundle.Position=UDim2.fromOffset(x,rowY);c.GemBundle.Size=UDim2.fromOffset(gemW,button)
  c.RobuxBundle.Position=UDim2.fromOffset(x+gemW+g,rowY);c.RobuxBundle.Size=UDim2.fromOffset(rest-gemW,button)
 end
 Art.Fit(c.GiftBundle);Art.Fit(c.GemBundle);Art.Fit(c.RobuxBundle)
 Art.SetTextSize(c.GiftBundle.Soon,math.max(8,math.floor(button*.26)),7)
 local amountH=math.floor(math.max(24,36*k))
 c.Amount.Position=UDim2.fromOffset(pad,rowY-amountH-2);c.Amount.Size=UDim2.fromOffset(w-pad*2,amountH);Art.SetTextSize(c.Amount,math.floor(amountH*.9),12)
 local top=pad;local artH=rowY-amountH-2-top+math.floor(amountH*.35)
 local side=math.min(artH,w-pad*2)
 c.BundleArtwork.Position=UDim2.fromOffset((w-side)/2,top);c.BundleArtwork.Size=UDim2.fromOffset(side,side)
 c.LightRays.Position=UDim2.fromOffset(w/2,top+side/2);c.LightRays.Size=UDim2.fromOffset(side*1.9,side*1.9)
end
return B
