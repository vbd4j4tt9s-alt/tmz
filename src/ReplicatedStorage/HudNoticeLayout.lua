-- One coordinate system and reserved rows for transient notices. No measured text overlap guesses.
local L={}
function L.Calculate(width,height,top,flags)
 if flags.Modal then
  local chosen=flags.Banner and'Banner'or flags.Feedback and'Feedback'or flags.Shovel and'Shovel'or flags.Run and'Run'
  local single={};if chosen then single[chosen]=true end;flags=single
 end
 local compact=height<480;local gap=compact and 3 or 6
 local y=math.max(top+8,compact and(width<740 and 120 or 44)or 56);local result={};local maxWidth=math.max(120,compact and width*.44 or width-24)
 local function row(name,h,w,font)
  result[name]={X=width/2,Y=y,Width=math.min(maxWidth,w),Height=h,Font=font};y+=h+gap
 end
 if flags.Biome then row('Biome',compact and 40 or 46,240,34)end -- R153: B (text only) is 37 to 44 px high and at most ~150 wide; the row used to be 94 / 58 x 490 for the box
 if flags.Run then row('Run',compact and 30 or 42,420,compact and 26 or 34)end
 if flags.Banner then row('Banner',compact and 34 or 44,680,compact and 15 or 18)end
 if flags.Feedback then row('Feedback',compact and 34 or 40,540,compact and 14 or 17)end
 if flags.Shovel then row('Shovel',compact and 34 or 40,540,compact and 14 or 17)end
 result.Bottom=y;return result
end
return L
