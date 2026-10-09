-- R156 PREVIEW DRAFT (not in src/): the one list the title screen's rotating "tip:" line reads. To add a tip the owner adds one line to Tips.
-- Kind: 'howto' = a real, checked game fact (the proposal's title_tips.md names the source file of each), 'lore' = a teasing / ominous line, 'egg' = an easter egg the
-- owner plans (written as he gave it). Lore and egg lines state no mechanics. Voice: lowercase, "you" / "your" written in full, 3rd-grade words, about 8 words or fewer, the game's own words
-- (pack, seed, King, Mythic, steal, treadmill, shovel, bat, keeper, market, fruit, garden, the darkened ...); an emoji only now and then.
-- Highlights: a tiny mini-markup in Text, turned into RichText by T.Rich:  {y}word{/y} = yellow (#FFE14D),  {g}word{/g} = green (the title's PACK green, #77E542).
-- Pick 1-2 key words per tip; the rest stays white with the title's dark outline. (Plain RichText is not used in the list, so a stray "<" can never break a line.)
local T={Interval=10,Fade=.4,Prefix='tip:',PrefixColor='#C8D9E8',
 PulseAmount=.05,PulsePeriod=.5,   -- the Minecraft-style splash pulse: the line breathes +-5% in size, a full breath every 0.5 s (none with Reduced Motion)
 BobPixels=1.5,BobPeriod=1.9,      -- and bobs up and down by 1.5 px, slowly (none with Reduced Motion)
 Colors={y='#FFE14D',g='#77E542'}}
T.Tips={
 {Kind='howto',Text='{y}rare packs{/y} = {g}better seeds{/g}'},
 {Kind='howto',Text='{y}mythic packs{/y} give the most {g}King{/g} seeds 👑'},
 {Kind='howto',Text='every {y}10th pack{/y} you open is {g}lucky{/g}! 🍀'},
 {Kind='howto',Text='{y}boots{/y} give biome packs more {g}luck{/g}'},
 {Kind='howto',Text='click or tap a pack {y}5 times{/y} to open it'},
 {Kind='howto',Text='hold {y}E{/y} to {g}steal{/g} a pack'},
 {Kind='howto',Text='dig holes with your {y}shovel{/y} to trip {g}pack thieves{/g}'},
 {Kind='howto',Text='the {y}shovel{/y} can remove plants in your {g}garden{/g}'},
 {Kind='howto',Text='hit thieves with your {y}bat{/y} to {g}drop their pack{/g}'},
 {Kind='howto',Text='click soil with a {y}seed{/y} to {g}plant{/g} it 🌱'},
 {Kind='howto',Text='plants {g}grow{/g} even when you\'re {y}gone{/y}'},
 {Kind='howto',Text='{y}weather{/y} can make your plants {g}worth more{/g}'},
 {Kind='howto',Text='{y}gold{/y} fruit sells x3, {g}diamond{/g} fruit x6 💎'},
 {Kind='howto',Text='sell your {y}fruit{/y} at the {g}market{/g}'},
 {Kind='howto',Text='{y}fruit of the hour{/y} sells for up to {g}x3{/g}'},
 {Kind='howto',Text='walk on a {y}treadmill{/y} to get {g}faster{/g} ⚡'},
 {Kind='howto',Text='{y}friends{/y} in your server help you get {g}faster{/g}'},
 {Kind='howto',Text='{y}keeper{/y} signs show the {g}speed you need{/g}'},
 {Kind='howto',Text='play to unlock a {y}mystery pack{/y} {g}each day{/g}'},
 {Kind='lore',Text='beware {y}the darkened{/y}'},
 {Kind='lore',Text='when the {y}lights go out{/y}... run'},
 {Kind='lore',Text='are you faster than {y}the darkened{/y}?'},
 {Kind='lore',Text='something waits at the end of {y}storm peaks{/y}'},
 {Kind='egg',Text='dont look into the {y}pyramid{/y}'},
}
-- The mini-markup as RichText: text is escaped first, then {y}..{/y} / {g}..{/g} become coloured <font> runs. An unknown {x} is left as written.
function T.Rich(text)
 text=text:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')
 text=text:gsub('{(%a)}',function(c)local color=T.Colors[c];return color and('<font color="'..color..'">')or nil end)
 return(text:gsub('{/(%a)}',function(c)return T.Colors[c]and'</font>'or nil end))
end
-- The text without the mini-markup (for a plain label, an accessible name, a length check).
function T.Plain(text)
 return(text:gsub('{/?%a}',''))
end
-- A fresh random order of the tips (every tip once before any repeats); `random` = a Random (or anything with NextInteger(a,b)). The first tip of a visit is random.
function T.Order(random)
 local order={}
 for i=1,#T.Tips do order[i]=i end
 for i=#order,2,-1 do local j=random:NextInteger(1,i);order[i],order[j]=order[j],order[i] end
 return order
end
-- The line as shown: the pale "tip:" then the tip with its highlights (RichText).
function T.Line(index)
 local tip=T.Tips[index]
 return tip and('<font color="'..T.PrefixColor..'">'..T.Prefix..'</font> '..T.Rich(tip.Text))or''
end
return T
