-- R71: the final treadmill introduction is informational, never a training requirement.
local G={Version=1,Bits={Begin=1,Pack=2,Seed=4,Train=8,Plant=16,Harvest=32,Sell=64,Cash=128}}
G.Steps={
 {Text='Steal this pack',Target='Pack'},
 {Text='Run back to safety!',Target='Safety'},
 {Text='Click to open your pack'},
 {Text='Plant your seed',Target='Garden'},
 {Text='Wait for it to grow',Target='Garden'},
 {Text='Harvest your crop',Target='Garden'},
 {Text='Sell your crop',Target='Market'},
 {Text='Hover or tap to collect cash'},
 {Text='Treadmills give speed to reach rarer packs.',Target='Treadmill',Informational=true,Seconds=6},
}
local order={{'Pack',1},{'Seed',3},{'Plant',4},{'Harvest',5},{'Sell',7},{'Cash',8},{'Train',9}}
function G.Read(saved)
 if type(saved)~='table'then return {Version=1,Mask=1,Done=false}end
 local mask=saved.Mask
 if saved.Version~=1 or type(mask)~='number'or mask%1~=0 or mask<0 or mask>255 or type(saved.Done)~='boolean'then return nil end
 return {Version=1,Mask=bit32.bor(mask,1),Done=saved.Done}
end
function G.Step(state)
 if state.Done then return 0 end
 for _,row in ipairs(order)do if bit32.band(state.Mask,G.Bits[row[1]])==0 then return row[2]end end
 return 0
end
function G.Event(state,event)
 if event=='Train'then return false end
 local bit=G.Bits[event];if not bit or state.Done or bit32.band(state.Mask,bit)~=0 then return false end
 if event=='Cash'and bit32.band(state.Mask,G.Bits.Sell)==0 then return false end
 state.Mask=bit32.bor(state.Mask,bit)
 if G.Step(state)==0 then state.Done=true end
 return true
end
function G.Action(state,action)
 if action=='TreadmillInfo'and G.Step(state)==9 then state.Mask=bit32.bor(state.Mask,G.Bits.Train);state.Done=true;return true end
 if action=='Replay'then state.Mask=1;state.Done=false;return true end
 if action=='Skip'then state.Done=true;return true end
 return false
end
function G.Layout(w,h,step)
 local width=math.min(304,math.max(190,w-112));local compact=w<700
 return {X=w-width-12,Y=h<480 and 116 or 76,Width=width,Height=step==9 and(compact and 68 or 56)or(compact and 50 or 46),Font=compact and 17 or 20}
end
return G
