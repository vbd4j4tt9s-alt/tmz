-- R120: pass cards in the reference style. Wide card: emblem left, title + description right,
-- bottom row [Gift | Gems | Robux]. Banner: "DOUBLE Your SPEED  x1 > x2". Wiring lives in GamePassClient.
local RS=game:GetService('ReplicatedStorage')
local Art=require(RS.PremiumShopArt);local Bright=require(RS.BrightUI);local Catalog=require(RS.MechCatalog)
local B={};local C=Color3.fromRGB
B.Copy={Growth={Title='x2 Growth',Detail='Plants grow x2 faster!'},Speed={Title='x2 Speed',Detail='Train x2 speed!'}}
local function buttons(card,pass)
 Art.Button(card,'GiftPass',Art.Colors.Gift,'Gift');Art.SetCaption(card.GiftPass,'')
 card.GiftPass:SetAttribute('AccessibleLabel','Gift '..pass.Name)
 Art.Button(card,'GemPerk',Art.Colors.Gem,'Gem');Art.SetCaption(card.GemPerk,tostring(Catalog.PassGemPrices[pass.Key]))
 Art.Button(card,'RobuxPass',Art.Colors.Robux,'Robux');Art.SetCaption(card.RobuxPass,'Unavailable',false)
end
function B.Create(parent,pass,order)
 local growth=pass.Key=='Growth'
 local card=Art.Card(parent,pass.Key,growth and{C(255,90,200),C(255,214,70)}or{C(255,252,170),C(255,222,40),C(255,168,24)})
 card.LayoutOrder=order;card:SetAttribute('PassKey',pass.Key)
 if growth then card.Fill.Color=Bright.Rainbow;card.Fill.Rotation=20 end
 local stage=Art.Frame(card,'IconStage',nil,1);stage.ZIndex=2
 if growth then Art.Clock(stage)else Art.Coin(stage,'Bolt')end
 local copy=B.Copy[pass.Key]or{Title=pass.Name,Detail=pass.Description}
 Art.Text(card,'Title',copy.Title,30).ZIndex=4
 local detail=Art.Text(card,'Detail',copy.Detail,24);detail.ZIndex=4;detail.TextWrapped=true
 local tag=Art.Text(card,'Permanent','PERMANENT',13,C(255,248,190));tag.ZIndex=4
 buttons(card,pass)
 require(RS.GuiShine).Attach(card,false)
 return card
end
function B.Layout(card,w,h,button,k)
 local pad=math.max(6,math.floor(10*k))
 local rowY=h-pad-button
 local stageSide=math.min(rowY-pad,math.floor(w*.36))
 card.IconStage.Position=UDim2.fromOffset(pad,pad+math.floor((rowY-pad-stageSide)/2));card.IconStage.Size=UDim2.fromOffset(stageSide,stageSide)
 card.LightRays.Position=UDim2.fromOffset(pad+stageSide/2,pad+(rowY-pad)/2);card.LightRays.Size=UDim2.fromOffset(stageSide*2,stageSide*2)
 local tx=pad*2+stageSide;local tw=w-tx-pad
 local titleH=math.floor(math.max(20,34*k))
 card.Title.Position=UDim2.fromOffset(tx,pad);card.Title.Size=UDim2.fromOffset(tw,titleH);Art.SetTextSize(card.Title,math.floor(titleH*.92),14)
 local tagH=math.floor(math.max(14,18*k))
 local detailY=pad+titleH+2;local detailH=rowY-detailY-tagH-4
 card.Detail.Position=UDim2.fromOffset(tx,detailY);card.Detail.Size=UDim2.fromOffset(tw,detailH);Art.SetTextSize(card.Detail,math.floor(math.min(detailH*.42,28*k)),11)
 card.Permanent.Position=UDim2.fromOffset(tx,rowY-tagH-2);card.Permanent.Size=UDim2.fromOffset(tw,tagH);Art.SetTextSize(card.Permanent,math.floor(tagH*.85),9)
 local g=math.max(4,math.floor(6*k))
 card.GiftPass.Position=UDim2.fromOffset(pad,rowY);card.GiftPass.Size=UDim2.fromOffset(button,button)
 local rest=w-pad*2-button-g*2;local gemW=math.floor(rest*(w<300 and .47 or .38))
 card.GemPerk.Position=UDim2.fromOffset(pad+button+g,rowY);card.GemPerk.Size=UDim2.fromOffset(gemW,button)
 card.RobuxPass.Position=UDim2.fromOffset(pad+button+g*2+gemW,rowY);card.RobuxPass.Size=UDim2.fromOffset(rest-gemW,button)
 if card.GemPerk.Visible==false then
  card.RobuxPass.Position=card.GemPerk.Position;card.RobuxPass.Size=UDim2.fromOffset(rest+g,button)
 end
 for _,b in ipairs({card.GiftPass,card.GemPerk,card.RobuxPass})do Art.Fit(b)end
end
-- Full-width "DOUBLE Your SPEED" banner for the Speed pass.
function B.CreateBanner(parent,pass)
 local card=Art.Card(parent,'SpeedPassBanner',{C(120,232,255),C(40,190,250),C(20,140,236)})
 card:SetAttribute('PassKey',pass.Key)
 card.LightRays.ZIndex=1
 local pile=Art.Pile(card,'Bolt',5);pile.ZIndex=2
 local title=Art.Text(card,'Title','Your SPEED',30);title.ZIndex=4
 local double=Art.Text(card,'Double','DOUBLE',30,C(70,255,60));double.ZIndex=5
 local x1=Art.Text(card,'From','x1',60);x1.ZIndex=4
 local arrow=Art.Triangle(card);arrow.ZIndex=4
 local x2=Art.Text(card,'To','x2',72,C(255,226,40));x2.ZIndex=4
 buttons(card,pass)
 require(RS.GuiShine).Attach(card,false)
 return card
end
local function measure(text,size)
 local ok,v=pcall(function()return game:GetService('TextService'):GetTextSize(text,size,require(RS.GardenTheme).Font,Vector2.new(4000,400))end)
 return ok and v and v.X or #text*size*.55
end
function B.LayoutBanner(card,w,h,button,k)
 local pad=math.max(6,math.floor(10*k));local g=math.max(4,math.floor(6*k))
 local titleH=math.floor(math.max(22,36*k))
 local titleSize=math.floor((titleH-3)/1.15)
 -- "DOUBLE" (green) and "Your SPEED" (white) side by side, centred as one title.
 local fullW=measure('DOUBLE Your SPEED',titleSize)
 if fullW>w-pad*2-16 then titleSize=math.max(14,math.floor(titleSize*(w-pad*2-16)/fullW))end
 local first=measure('DOUBLE',titleSize);local space=measure(' ',titleSize);local rest=measure('Your SPEED',titleSize)
 local x=math.floor((w-(first+space+rest))/2)
 card.Double.TextXAlignment=Enum.TextXAlignment.Left;card.Title.TextXAlignment=Enum.TextXAlignment.Left
 card.Double.Position=UDim2.fromOffset(x,pad);card.Double.Size=UDim2.fromOffset(first+10,titleH);Art.SetTextSize(card.Double,titleSize,titleSize)
 card.Title.Position=UDim2.fromOffset(x+first+space,pad);card.Title.Size=UDim2.fromOffset(rest+10,titleH);Art.SetTextSize(card.Title,titleSize,titleSize)
 local narrow=w<460
 local buyW=narrow and math.floor(w*.42)or math.floor(math.min(w*.3,260))
 local midY=pad+titleH+4;local midH=h-midY-pad
 local buyX=w-pad-buyW
 -- Right column: Robux on top, then [Gift | Gems].
 local stack=button*2+g;local by=midY+math.max(0,math.floor((midH-stack)/2))
 card.RobuxPass.Position=UDim2.fromOffset(buyX,by);card.RobuxPass.Size=UDim2.fromOffset(buyW,button)
 card.GiftPass.Position=UDim2.fromOffset(buyX,by+button+g);card.GiftPass.Size=UDim2.fromOffset(button,button)
 card.GemPerk.Position=UDim2.fromOffset(buyX+button+g,by+button+g);card.GemPerk.Size=UDim2.fromOffset(buyW-button-g,button)
 if card.GemPerk.Visible==false then card.RobuxPass.Size=UDim2.fromOffset(buyW,button*2+g)end
 for _,b in ipairs({card.GiftPass,card.GemPerk,card.RobuxPass})do Art.Fit(b)end
 local pileSide=math.min(midH,math.floor(w*.2))
 card.BundleArtwork.Position=UDim2.fromOffset(pad,h-pad-pileSide);card.BundleArtwork.Size=UDim2.fromOffset(pileSide,pileSide)
 card.LightRays.Position=UDim2.fromOffset(w*.42,midY+midH/2);card.LightRays.Size=UDim2.fromOffset(w*.9,w*.9)
 -- x1 > x2 centred between the pile and the buy column.
 local left=narrow and pad or pad*2+pileSide;local right=buyX-g
 local bigH=math.floor(math.min(midH*.95,90*k));local span=right-left
 local fromW=math.floor(span*.32);local arrowW=math.floor(math.min(bigH*.45,span*.14));local toW=math.floor(span*.4)
 local bx=left+math.floor((span-fromW-arrowW-toW-g*2)/2)
 local y=midY+math.floor((midH-bigH)/2)
 card.From.Position=UDim2.fromOffset(bx,y);card.From.Size=UDim2.fromOffset(fromW,bigH);Art.SetTextSize(card.From,math.floor(bigH*.8),16)
 card.Arrow.Position=UDim2.fromOffset(bx+fromW+g,y+bigH/2-arrowW);card.Arrow.Size=UDim2.fromOffset(arrowW,arrowW*2)
 card.To.Position=UDim2.fromOffset(bx+fromW+arrowW+g*2,y-math.floor(bigH*.08));card.To.Size=UDim2.fromOffset(toW,math.floor(bigH*1.12));Art.SetTextSize(card.To,math.floor(bigH*.95),18)
 card.BundleArtwork.Visible=not narrow
end
return B
