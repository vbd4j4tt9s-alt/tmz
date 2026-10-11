"""R156 preview: makes the SCRATCH copy of src/ReplicatedStorage/TitleScreen104.lua that has Style B, the rotating "tip:" line that floats in the middle band between the logo /
pack art and Click to play!. src/ is NOT touched: this writes OUT.lua (the patched copy the preview runs) and OUT.diff (what the real change would be). Every replacement must match
exactly once.
Usage: python3 patch_title156.py <repo> <out.lua> <out.diff>"""
import difflib
import sys

repo, out_lua, out_diff = sys.argv[1:4]
src_path = repo + '/src/ReplicatedStorage/TitleScreen104.lua'
src = open(src_path, encoding='utf-8').read()
s = src


def sub(old, new):
    global s
    assert s.count(old) == 1, 'patch anchor not found exactly once: ' + old[:60]
    s = s.replace(old, new)


# 1. Layout: the tip floats vertically centred in the gap between the bottom of the logo (the pack art is inside the logo's box) and the top of the button. The gap is made at least
#    tipHeight + 20 tall (10 px of air above and below the line, which holds its +-5% pulse and 1.5 px bob). On a PC and a portrait phone the gap is already bigger, so the logo, the pack
#    and the button do not move; only a landscape phone's logo gets a little smaller (443 px wide, was 477) to make the room.
sub("""function T.Layout(width,height)
 width=math.max(width,1);height=math.max(height,1)
 local buttonHeight=math.min(58,math.max(48,height*.085))
 local bottom=math.max(20,math.min(46,height*.06))
 local buttonY=height-bottom-buttonHeight/2
 local logoWidth=math.min(1160,width*.91,(height-bottom-buttonHeight-50)*1.7768)
 logoWidth=math.max(1,logoWidth)
 local logoHeight=logoWidth/1.7768
 local logoY=math.min(height*.43,buttonY-buttonHeight/2-24-logoHeight/2)
 logoY=math.max(logoHeight/2+8,logoY)
 return {LogoWidth=logoWidth,LogoHeight=logoHeight,LogoY=logoY,ButtonY=buttonY,
  ButtonWidth=math.max(1,math.min(300,width-40)),ButtonHeight=buttonHeight}
end""", """function T.Layout(width,height)
 width=math.max(width,1);height=math.max(height,1)
 local buttonHeight=math.min(58,math.max(48,height*.085))
 local bottom=math.max(20,math.min(46,height*.06))
 local buttonY=height-bottom-buttonHeight/2
 -- R156: the tip line floats in the middle of the gap between the logo (with the pack) and the button: one line on a PC / landscape phone, two on a portrait phone.
 -- The gap is kept at least tipGap = the line's height + 20 px (10 px of air each side: the pulse and the bob stay inside it).
 local tipSize=math.clamp(math.floor(height*.03),16,32)
 local tipHeight=math.ceil(tipSize*1.15*(width<520 and 2 or 1))+4
 local tipGap=tipHeight+20
 local buttonTop=buttonY-buttonHeight/2
 local logoWidth=math.min(1160,width*.91,(height-bottom-buttonHeight-26-tipGap)*1.7768)
 logoWidth=math.max(1,logoWidth)
 local logoHeight=logoWidth/1.7768
 local logoY=math.min(height*.43,buttonTop-tipGap-logoHeight/2)
 logoY=math.max(logoHeight/2+8,logoY)
 return {LogoWidth=logoWidth,LogoHeight=logoHeight,LogoY=logoY,ButtonY=buttonY,
  ButtonWidth=math.max(1,math.min(300,width-40)),ButtonHeight=buttonHeight,
  TipY=(logoY+logoHeight/2+buttonTop)/2,TipWidth=math.max(1,math.min(780,width-48)),TipHeight=tipHeight,TipSize=tipSize}
end""")

# 2. The label (with a UIScale for the pulse), positioned with the layout, and the rotation / pulse / bob in the frame step.
sub("""  local layout
  local function resize()
   local size=group.AbsoluteSize;layout=T.Layout(size.X,size.Y)
   visual.Size=UDim2.fromOffset(layout.LogoWidth,layout.LogoHeight)
   button.Size=UDim2.fromOffset(layout.ButtonWidth,layout.ButtonHeight)
   button.Position=UDim2.fromOffset(size.X/2,layout.ButtonY)
  end
  connect(group:GetPropertyChangedSignal('AbsoluteSize'),resize);resize()
""", """  local layout
  -- R156 (owner: "tips in the starting screen"; Style B, then "in the middle", "a new tip every 10 s", "jumps around minimally like the minecraft one", highlighted words): one tip line
  -- floating between the logo and Click to play!. A new tip every Tips.Interval s (a fade out / in), a gentle splash pulse (+-Tips.PulseAmount in size, a full breath every Tips.PulsePeriod s)
  -- and a very small bob (Tips.BobPixels). Reduced Motion: no fade, no pulse, no bob (the text just changes). The list, its timings and the highlight mini-markup are
  -- ReplicatedStorage.TitleTips156 (one line per tip). A missing / broken list just leaves the line out; it never blocks the title.
  local tipLabel,tipStroke,tipScale,tips,tipOrder,tipIndex,tipClock,pulseClock
  local function resize()
   local size=group.AbsoluteSize;layout=T.Layout(size.X,size.Y)
   visual.Size=UDim2.fromOffset(layout.LogoWidth,layout.LogoHeight)
   button.Size=UDim2.fromOffset(layout.ButtonWidth,layout.ButtonHeight)
   button.Position=UDim2.fromOffset(size.X/2,layout.ButtonY)
   if tipLabel then
    tipLabel.Size=UDim2.fromOffset(layout.TipWidth,layout.TipHeight)
    tipLabel.Position=UDim2.fromOffset(size.X/2,layout.TipY)
    tipLabel:FindFirstChildOfClass('UITextSizeConstraint').MaxTextSize=layout.TipSize
   end
  end
  connect(group:GetPropertyChangedSignal('AbsoluteSize'),resize);resize()
  task.spawn(function()
   local good,list=pcall(function()return require(RS:WaitForChild('TitleTips156',10))end)
   if dead or not good or type(list)~='table'or#list.Tips==0 then return end
   tips=list;tipOrder=T.TipOrder or tips.Order(Random.new());tipIndex=1;tipClock=0;pulseClock=0
   tipLabel=make('TextLabel',group,{Name='TipLine',AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,Text=tips.Line(tipOrder[1]),RichText=true,
    Font=Enum.Font.FredokaOne,TextScaled=true,TextWrapped=true,TextColor3=RGB(255,255,242),TextXAlignment=Enum.TextXAlignment.Center,Active=false})
   make('UITextSizeConstraint',tipLabel,{MaxTextSize=26,MinTextSize=11})
   tipStroke=make('UIStroke',tipLabel,{Thickness=2,Color=RGB(23,37,16),LineJoinMode=Enum.LineJoinMode.Round})
   tipScale=make('UIScale',tipLabel,{Scale=1})
   resize()
  end)
""")

sub("""   visual.Position=UDim2.fromOffset(group.AbsoluteSize.X/2,layout.LogoY+(1-reveal)*14)
""", """   visual.Position=UDim2.fromOffset(group.AbsoluteSize.X/2,layout.LogoY+(1-reveal)*14)
   if tipLabel and phase~='Leaving'then
    tipClock+=dt;pulseClock+=dt
    if tipClock>=tips.Interval then tipClock-=tips.Interval;tipIndex=tipIndex%#tipOrder+1;tipLabel.Text=tips.Line(tipOrder[tipIndex])end
    -- fade in over Fade s, hold, fade out over the last Fade s (the text changes while it is invisible); Reduced Motion: no fade, the text just changes
    local alpha=reduced and 1 or math.min(1,tipClock/tips.Fade,(tips.Interval-tipClock)/tips.Fade)
    tipLabel.TextTransparency=1-alpha;tipStroke.Transparency=1-alpha
    -- the splash pulse (about the label's centre) and the small bob; none with Reduced Motion
    tipScale.Scale=reduced and 1 or 1+tips.PulseAmount*math.sin(pulseClock*math.pi*2/tips.PulsePeriod)
    tipLabel.Position=UDim2.fromOffset(group.AbsoluteSize.X/2,layout.TipY+(reduced and 0 or tips.BobPixels*math.sin(pulseClock*math.pi*2/tips.BobPeriod)))
   end
""")

open(out_lua, 'w', encoding='utf-8').write(s)
diff = ''.join(difflib.unified_diff(src.splitlines(True), s.splitlines(True), 'a/src/ReplicatedStorage/TitleScreen104.lua', 'b/src/ReplicatedStorage/TitleScreen104.lua'))
open(out_diff, 'w', encoding='utf-8').write(diff)
print('patched: %d lines -> %d lines' % (src.count('\n'), s.count('\n')))
