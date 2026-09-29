-- Shared announcement copy; no user string can inject RichText markup.
local N={}
N.Emojis={Common='🌱',Uncommon='🍀',Rare='💠',Epic='⚡',Legendary='🌟',Mythic='🔥',Secret='👁️',Cosmic='🌌',King='👑'}
function N.Rarity(name)return(N.Emojis[name]or'✨')..' '..name end
function N.Escape(s)return tostring(s or''):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;')end
function N.Color(text,c)
 local function byte(n)return math.clamp(math.floor(n*255+.5),0,255)end
 return string.format('<font color="#%02X%02X%02X">%s</font>',byte(c.R),byte(c.G),byte(c.B),N.Escape(text))
end
local colors={[1]=Color3.fromRGB(115,245,131),[6]=Color3.fromRGB(58,230,157),[2]=Color3.fromRGB(255,190,88),[3]=Color3.fromRGB(133,225,255),[4]=Color3.fromRGB(255,126,76),[5]=Color3.fromRGB(208,148,255),[7]=Color3.fromRGB(162,187,255)}
function N.Pack(m)
 local count=math.max(1,math.floor(tonumber(m.Count)or 1));local prefix=count>1 and(count..' ')or'A '
 local name=m.Text..(count>1 and's'or'')
 local emoji=(tonumber(m.Size)or 1)>7 and'📏'or m.Mutation=='Diamond'and'💎'or m.Mutation=='Gold'and'✨'or N.Emojis[m.Tier]or'✨'
 return emoji..' '..prefix..N.Color(name,m.Color or Color3.new(1,1,1))..' spawned in '..N.Color(m.Biome,colors[m.Stage]or Color3.fromRGB(175,220,255))..'!'
end
function N.Arrival()return '🌑 '..N.Color('He has arrived...',Color3.fromRGB(221,195,255))..'  '..N.Color('Void Pack',Color3.fromRGB(184,141,255))..' awaits in '..N.Color('Storm Peaks',colors[7])..'.'end
function N.Weather(m)
 local W=require(script.Parent.WeatherTraits);local trait=W.Key(m.Trait);local row=W.Traits[trait]
 local names={};local function add(n,singular,plural)
  n=math.max(0,math.floor(tonumber(n)or 0));if n>0 then table.insert(names,n..' '..(n==1 and singular or plural))end
 end
 add(m.Plants,'plant','plants');add(m.Fruits,'fruit','fruits');add(m.Packs,'pack','packs')
 local subject=#names>0 and table.concat(names,', ')or(math.max(1,math.floor(tonumber(m.Count)or 1))..' items')
 local place=''
 if m.Scope=='Owned'then subject='Your '..subject
 elseif m.Scope=='World'then local biomes={[1]='Forest',[6]='Jungle',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[7]='Storm Peaks'};local name=biomes[m.Stage];if name then place=' in '..N.Color(name,colors[m.Stage])end end
 return N.Color(subject,Color3.new(1,1,1))..place..' became '..N.Color(W.Display(trait),row.Color or Color3.new(1,1,1))..'!'
end
return N
