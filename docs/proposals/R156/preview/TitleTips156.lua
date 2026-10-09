-- R156 PREVIEW DRAFT (not in src/): the one list the title screen's rotating "tip:" line reads. To add a tip the owner adds one line to Tips.
-- Kind: 'howto' = a real, checked game fact (the proposal's title_tips.md names the source file of each), 'lore' = a teasing / ominous line, 'egg' = an easter egg the
-- owner plans (written as he gave it). Lore and egg lines state no mechanics. Voice: lowercase, u / ur, short; an emoji only now and then.
local T={Interval=5,Fade=.35,Prefix='tip:'}
T.Tips={
 {Kind='howto',Text='rarer packs give higher loot'},
 {Kind='howto',Text='mythic packs give the best chance at a king seed 👑'},
 {Kind='howto',Text='every 10th pack u open is lucky: x1.5 luck 🍀'},
 {Kind='howto',Text='boots make ur biome packs luckier'},
 {Kind='howto',Text='click or tap a pack 5 times to open it'},
 {Kind='howto',Text='hold E (or tap and hold) to steal a pack'},
 {Kind='howto',Text='shovel holes on the track make pack carriers drop their pack'},
 {Kind='howto',Text='the shovel can remove a plant from ur garden too'},
 {Kind='howto',Text='swing the bat: it knocks players back and a carrier drops the pack'},
 {Kind='howto',Text='click the soil with a seed to plant it 🌱'},
 {Kind='howto',Text='plants keep growing while ur offline'},
 {Kind='howto',Text='weather can mutate ur plants for x2 / x3 / x5 fruit'},
 {Kind='howto',Text='gold fruit sells for x3, diamond fruit for x6 💎'},
 {Kind='howto',Text='sell ur crops at the market'},
 {Kind='howto',Text='the fruit of the hour sells for x1.5 to x3 at the market'},
 {Kind='howto',Text='hop on a treadmill to get faster ⚡'},
 {Kind='howto',Text='each friend in ur server adds +10% to ur treadmill gains (3 max)'},
 {Kind='howto',Text='the sign over each keeper shows the speed u need to outrun it'},
 {Kind='howto',Text='stay 15 minutes to unlock today\'s mystery pack at ur base'},
 {Kind='lore',Text='beware the darkened'},
 {Kind='lore',Text='when the lights go out... run'},
 {Kind='lore',Text='the darkened\'s sign says ∞. good luck'},
 {Kind='lore',Text='something waits at the end of storm peaks...'},
 {Kind='egg',Text='dont look into the pyramid'},
}
-- A fresh random order of the tips (every tip once before any repeats); `random` = a Random (or anything with NextInteger(a,b)). The first tip of a visit is random.
function T.Order(random)
 local order={}
 for i=1,#T.Tips do order[i]=i end
 for i=#order,2,-1 do local j=random:NextInteger(1,i);order[i],order[j]=order[j],order[i] end
 return order
end
-- The line as shown: the green "tip:" then the text (RichText).
function T.Line(index)
 local tip=T.Tips[index]
 return tip and ('<font color="#77E542">'..T.Prefix..'</font> '..tip.Text)or''
end
return T
