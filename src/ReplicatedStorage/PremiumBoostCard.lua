-- R120: pass cards in the reference style. Wide card: emblem left, title + description right,
-- bottom row [Gems | Robux]. Wiring lives in GamePassClient.
-- R122: no gift button, no Robux glyph ("300 Robux"), and the SPEED "DOUBLE Your SPEED" banner was removed.
local RS=game:GetService('ReplicatedStorage')
local Art=require(RS.PremiumShopArt);local Bright=require(RS.BrightUI);local Catalog=require(RS.MechCatalog)
local B={};local C=Color3.fromRGB
-- R153: the 4 Leaf Clover pass (2x luck on every pack). Its picture is CloverIcon153 (the pass's own Roblox icon, else the owner's clover drawn on the client, else shapes) on a soft glow so the
-- green stands out on the sky-blue card. A pass whose id is 0 (CloverPassId set to 0) has no Robux button: the card says so and the Gem button takes the whole row (Layout).
B.Copy={Growth={Title='x2 Growth',Detail='Plants grow 2x faster!'},Speed={Title='x2 Speed',Detail='Train with 2x speed!'},Clover={Title='x2 Luck',Detail='x2 luck on EVERY pack u open!'}}
local function buttons(card,pass)
 Art.Button(card,'GemPerk',Art.Colors.Gem,'Gem');Art.SetCaption(card.GemPerk,tostring(Catalog.PassGemPrices[pass.Key]))
 Art.Button(card,'RobuxPass',Art.Colors.Robux);Art.SetCaption(card.RobuxPass,'Unavailable',false)
end
function B.Create(parent,pass,order)
 local growth=pass.Key=='Growth';local clover=pass.Key=='Clover'
 local card=Art.Card(parent,pass.Key,growth and{C(255,90,200),C(255,214,70)}or clover and{C(200,250,255),C(92,214,238),C(44,148,214)}or{C(255,252,170),C(255,222,40),C(255,168,24)})
 card.LayoutOrder=order;card:SetAttribute('PassKey',pass.Key)
 if growth then card.Fill.Color=Bright.Rainbow;card.Fill.Rotation=20 end
 local stage=Art.Frame(card,'IconStage',nil,1);stage.ZIndex=2
 if growth then Art.Clock(stage)
 elseif clover then
  local glow=Art.Frame(stage,'Glow',Color3.new(1,1,1),.5);glow.AnchorPoint=Vector2.new(.5,.5);glow.Position=UDim2.fromScale(.5,.5);glow.Size=UDim2.fromScale(.94,.94);Art.Corner(glow,UDim.new(.5,0))
  local icon=require(RS.CloverIcon153).Attach(stage);icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5);icon.Size=UDim2.fromScale(.9,.9)
 else Art.Coin(stage,'Bolt')end
 local copy=B.Copy[pass.Key]or{Title=pass.Name,Detail=pass.Description}
 Art.Text(card,'Title',copy.Title,30).ZIndex=4
 local detail=Art.Text(card,'Detail',copy.Detail,24);detail.ZIndex=4;detail.TextWrapped=true
 local noRobux=pass.IdAttribute~=nil and require(RS.GamePassCatalog).RobuxSoon(pass)
 local tag=Art.Text(card,'Permanent',noRobux and'ROBUX SOON'or'PERMANENT',13,C(255,248,190));tag.ZIndex=4
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
 local rest=w-pad*2-g;local gemW=math.floor(rest*(w<300 and .45 or .4))
 card.GemPerk.Position=UDim2.fromOffset(pad,rowY);card.GemPerk.Size=UDim2.fromOffset(gemW,button)
 card.RobuxPass.Position=UDim2.fromOffset(pad+gemW+g,rowY);card.RobuxPass.Size=UDim2.fromOffset(rest-gemW,button)
 if card.GemPerk.Visible==false then
  card.RobuxPass.Position=card.GemPerk.Position;card.RobuxPass.Size=UDim2.fromOffset(rest+g,button)
 elseif card.RobuxPass.Visible==false then card.GemPerk.Size=UDim2.fromOffset(rest+g,button) end -- R153: no Robux button (pass id 0)
 for _,b in ipairs({card.GemPerk,card.RobuxPass})do Art.Fit(b)end
end
return B
