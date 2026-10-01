-- R120: reference-style bundle card: bright gradient + rays, a growing pile of icons, a big outlined
-- amount and a bottom row [Gems price | Robux price]. Purchase wiring stays in GamePassClient.
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
 Art.Button(c,'GemBundle',Art.Colors.Gem,'Gem')
 Art.Button(c,'RobuxBundle',Art.Colors.Robux,'Robux')
 Art.SetCaption(c.GemBundle,tostring(row.GemPrice));Art.SetCaption(c.RobuxBundle,'Unavailable',false)
 require(RS.GuiShine).Attach(c,false)
 return c
end
-- w,h: card pixels; button: price-button height; k: scale.
function B.Layout(c,w,h,button,k)
 local pad=math.max(5,math.floor(8*k))
 local rowY=h-pad-button
 local gemW=math.floor((w-pad*3)*.36)
 c.GemBundle.Position=UDim2.fromOffset(pad,rowY);c.GemBundle.Size=UDim2.fromOffset(gemW,button)
 c.RobuxBundle.Position=UDim2.fromOffset(pad*2+gemW,rowY);c.RobuxBundle.Size=UDim2.fromOffset(w-pad*3-gemW,button)
 Art.Fit(c.GemBundle);Art.Fit(c.RobuxBundle)
 local amountH=math.floor(math.max(24,36*k))
 c.Amount.Position=UDim2.fromOffset(pad,rowY-amountH-2);c.Amount.Size=UDim2.fromOffset(w-pad*2,amountH);Art.SetTextSize(c.Amount,math.floor(amountH*.9),12)
 local top=pad;local artH=rowY-amountH-2-top+math.floor(amountH*.35)
 local side=math.min(artH,w-pad*2)
 c.BundleArtwork.Position=UDim2.fromOffset((w-side)/2,top);c.BundleArtwork.Size=UDim2.fromOffset(side,side)
 c.LightRays.Position=UDim2.fromOffset(w/2,top+side/2);c.LightRays.Size=UDim2.fromOffset(side*1.9,side*1.9)
end
return B
