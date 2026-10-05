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
-- R131: "🎁 Sunny gave you Frosted Golden Apple!"
function N.Gift(giver,item)return '🎁 '..N.Color(tostring(giver),Color3.fromRGB(147,255,69))..' gave you '..N.Color(tostring(item),Color3.fromRGB(255,229,71))..'!'end
-- R152 (owner: "add more personality to the texts"): in Verity's voice, she is the one who trades a Void Pack for a Verity Pack (VerityConfig).
function N.Arrival()return '🌑 '..N.Color('Eek! The Darkened is here...',Color3.fromRGB(221,195,255))..'  '..N.Color('Two Void Packs',Color3.fromRGB(184,141,255))..' await in '..N.Color('Storm Peaks',colors[7])..'. '..N.Color('Verity',Color3.fromRGB(255,206,64))..' wants one!'end
-- R122: nobody stole a Void Pack for three refreshes, so the remaining packs changed.
function N.VoidShift()return '🌌 '..N.Color('The void shifts...',Color3.fromRGB(221,195,255))..'  The '..N.Color('Void Packs',Color3.fromRGB(184,141,255))..' in '..N.Color('Storm Peaks',colors[7])..' changed.'end
-- R127 (owner): an owner weather notice names the plant that changed ("Your Moonberry plant", "A fruit on your
-- Watermelon", "Your Apple, Moonberry and 2 more plants"). Items are MutationGlow127 items; nil when there are none.
function N.PlantSubject(items,packs)
 if type(items)~='table'or #items==0 then return nil end
 local Names=require(script.Parent.GardenDisplayNames);local catalog=require(script.Parent.PlantCatalog)
 local order,by={},{}
 for _,item in ipairs(items)do
  local def=catalog[item.SeedId];if def then
   local row=by[item.SeedId];if not row then row={Id=item.SeedId,Def=def,Plants=0,Fruits=0};by[item.SeedId]=row;table.insert(order,row)end
   if item.Plant then row.Plants+=1 end;row.Fruits+=type(item.Fruits)=='table'and #item.Fruits or 0
  end
 end
 if #order==0 then return nil end
 local function plant(row)return Names.Plant(row.Id,row.Def.Name)end
 local text
 if #order==1 then
  local row=order[1];local name=plant(row)
  if row.Plants>0 and row.Fruits>0 then
   text=(row.Plants==1 and'Your '..name..' plant'or'Your '..row.Plants..' '..name..' plants')..' and '..row.Fruits..(row.Fruits==1 and' fruit'or' fruits')
  elseif row.Plants>0 then text=row.Plants==1 and'Your '..name..' plant'or'Your '..row.Plants..' '..name..' plants'
  elseif row.Fruits==1 then text='A fruit on your '..name
  else text=row.Fruits..' fruits on your '..name end
 elseif #order==2 then text='Your '..plant(order[1])..' and '..plant(order[2])
 else text='Your '..plant(order[1])..', '..plant(order[2])..' and '..(#order-2)..' more plants' end
 local p=math.max(0,math.floor(tonumber(packs)or 0));if p>0 then text..=(p==1 and', and a held pack'or', and '..p..' held packs')end
 return text
end
function N.Weather(m)
 local W=require(script.Parent.WeatherTraits);local trait=W.Key(m.Trait);local row=W.Traits[trait]
 local names={};local function add(n,singular,plural)
  n=math.max(0,math.floor(tonumber(n)or 0));if n>0 then table.insert(names,n..' '..(n==1 and singular or plural))end
 end
 add(m.Plants,'plant','plants');add(m.Fruits,'fruit','fruits');add(m.Packs,'pack','packs')
 local subject=#names>0 and table.concat(names,', ')or(math.max(1,math.floor(tonumber(m.Count)or 1))..' items')
 local place=''
 local named=m.Scope=='Owned'and N.PlantSubject(m.Items,m.Packs)
 if named then subject=named
 elseif m.Scope=='Owned'then subject='Your '..subject
 elseif m.Scope=='World'then local biomes={[1]='Forest',[6]='Jungle',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[7]='Storm Peaks'};local name=biomes[m.Stage];if name then place=' in '..N.Color(name,colors[m.Stage])end end
 return(named and'🌈 'or'')..N.Color(subject,Color3.new(1,1,1))..place..' became '..N.Color(W.Display(trait),row.Color or Color3.new(1,1,1))..'!'
end
return N
