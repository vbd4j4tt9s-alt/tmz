import math
from PIL import Image,ImageDraw,ImageFont,ImageFilter
from dumpfb import render as icon
OUT='/home/user/tmz/docs/proposals/wall_notifier_R122/'
import os;os.makedirs(OUT,exist_ok=True)
BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def F(n):return ImageFont.truetype(BOLD,n)
SANS=lambda n:ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',n)
PAPER=(242,242,242);INK=(70,72,79)
# ---- new sign face (canvas from RefreshBarrier: 188x53 studs at 8 px/stud) ----
def new_face(text='10s'):
    W,H=188*8,53*8;im=Image.new('RGB',(W,H),PAPER);d=ImageDraw.Draw(im)
    sw,sh=860,320;cx,cy=W/2,(1-.52)*H;sx,sy=cx-sw/2,cy-sh/2
    m=icon('Moon',scale=2,bg=PAPER).convert('RGB').resize((300,300),Image.LANCZOS)
    im.paste(m,(int(sx),int(sy+(sh-300)/2)))
    f=F(250);d.text((sx+330,cy),text,font=f,fill=INK,anchor='lm',stroke_width=7,stroke_fill=(0,0,0))
    return im
def old_face():
    src=Image.open('/home/user/tmz/docs/proposals/strikes_wall_R112/refresh_wall.png').convert('RGB')
    return src.crop((22,87,851,716)).resize((184*5,140*5))
# ---- tiny perspective renderer: camera on the lobby floor looking +Z (no pitch, so z-planes scale uniformly) ----
IW,IH=900,620;FOV=70
def scene(old):
    cam=(0,18,-330);f=(IH/2)/math.tan(math.radians(FOV/2))
    def P(x,y,z):
        dz=z-cam[2];return (IW/2+f*(x-cam[0])/dz, IH/2-f*(y-cam[1])/dz)
    im=Image.new('RGB',(IW,IH),(70,130,220));d=ImageDraw.Draw(im)  # blue sky as in the owner's screenshot (black sky would hide the cover outline)
    # lobby floor + track ground
    def quad(pts,col):d.polygon([P(*p) for p in pts],fill=col)
    # track side walls (inner faces + tops), 48 tall, x=±89..±94
    for s in(-1,1):
        quad([(s*94,3,-100),(s*94,51,-100),(s*94,51,1500),(s*94,3,1500)],(150,150,160))
        quad([(s*89,51,-100),(s*94,51,-100),(s*94,51,1500),(s*89,51,1500)],(175,175,185))
    if old: cover=(-150,150,-15,485,-101);wall=(-92,92,3.12,143.12,-102);face=old_face()
    else: cover=(-94,94,-15,55,-101);wall=(-94,94,3.12,56.12,-102);face=new_face()
    x0,x1,y0,y1,z0=cover
    # cover: front + top (if camera above) + sides
    quad([(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0)],(0,0,0))
    if cam[1]>y1: quad([(x0,y1,z0),(x1,y1,z0),(x1,y1,1500),(x0,y1,1500)],(10,10,12))
    quad([(-340,4,-325),(340,4,-325),(340,4,-100),(-340,4,-100)],(96,160,96))
    x0,x1,y0,y1,z=wall;a=P(x0,y1,z);b=P(x1,y0,z)
    face=face.resize((int(b[0]-a[0]),int(b[1]-a[1])),Image.LANCZOS);im.paste(face,(int(a[0]),int(a[1])))
    # player for scale (5 studs) at z=-130
    pa=P(-30,4,-130);pb=P(-28,9.2,-130);d.rectangle([pa[0],pb[1],pb[0],pa[1]],fill=(200,40,40))
    return im
def label(im,title,sub):
    out=Image.new('RGB',(im.width,im.height+64),(255,255,255));out.paste(im,(0,64));d=ImageDraw.Draw(out)
    d.text((10,8),title,font=F(20),fill=(20,20,20));d.text((10,36),sub,font=SANS(14),fill=(70,70,70));return out
a=label(scene(True),'BEFORE (R112)','black cover 300 wide x 500 tall; white wall 184 x 140; hand-drawn moon + cloud')
b=label(scene(False),'AFTER (R122)','cover = track only (188 x 70, roof Y 55); wall 188 x 53; HUD Moon image')
sheet=Image.new('RGB',(a.width*2+30,a.height+120),(255,255,255));sheet.paste(a,(0,0));sheet.paste(b,(a.width+30,0))
d=ImageDraw.Draw(sheet);d.text((10,a.height+14),'Refresh night wall from the lobby (camera 18 studs up at the lobby, Z -330; red bar = 5-stud player at Z -130). APPROXIMATION:',font=SANS(15),fill=(40,40,40))
d.text((10,a.height+36),'flat-shaded boxes from the real module sizes; track side walls 48 tall at x=±89..94 from the place file; DejaVu Bold stands in for FredokaOne.',font=SANS(15),fill=(40,40,40))
sheet.save(OUT+'refresh_wall_before_after.png')
f10=new_face('10s');f3=new_face('3s');s=.55
fs=Image.new('RGB',(int(f10.width*s)*2+30,int(f10.height*s)+70),(255,255,255));d=ImageDraw.Draw(fs)
d.text((10,8),'New wall face (188 x 53 studs, canvas 1504 x 424 at 8 px/stud): HudArtwork "Moon" (same image as the HUD refresh timer) + countdown',font=F(17),fill=(20,20,20))
d.text((10,34),'Moon 300 px = 37.5 studs; digits ~280 px = 35 studs. Approximation (prepared-fallback pixels of the Moon art, DejaVu Bold for FredokaOne).',font=SANS(14),fill=(70,70,70))
fs.paste(f10.resize((int(f10.width*s),int(f10.height*s))),(0,64));fs.paste(f3.resize((int(f3.width*s),int(f3.height*s))),(int(f10.width*s)+30,64))
fs.save(OUT+'refresh_wall_face.png')
# ---- notifier card, 3x ----
K=3
def grid_bg(w,h):
    im=Image.new('RGB',(w,h),(104,150,214));d=ImageDraw.Draw(im)
    for x in range(-h,w,40*K//2):d.line([(x,0),(x+h,h)],fill=(92,136,200),width=2)
    for x in range(0,w+h,40*K//2):d.line([(x,0),(x-h,h)],fill=(92,136,200),width=2)
    return im
def rounded(size,r,fill):
    m=Image.new('L',size,0);ImageDraw.Draw(m).rounded_rectangle([0,0,size[0]-1,size[1]-1],r,fill=fill);return m
def card(new,hint='AT STORM PEAKS'):
    W,H=190*K,39*K;bg=grid_bg(W+40*K,H+20*K);ox,oy=20*K,10*K
    if not new:
        layer=Image.new('RGB',(W,H),(26,17,42));bg.paste(layer,(ox,oy),rounded((W,H),7*K,int(255*.82)))
        d=ImageDraw.Draw(bg)
        d.text((ox+W/2,oy+11*K),'THE VEILED ONE',font=F(15*K),fill=(229,205,255),anchor='mm',stroke_width=K,stroke_fill=(8,13,24))
        d.text((ox+W/2,oy+28*K),hint,font=F(10*K),fill=(201,190,225),anchor='mm',stroke_width=K,stroke_fill=(8,13,24))
        return bg
    grad=Image.new('RGB',(W,H))
    for x in range(W):
        t=x/(W-1);c=tuple(int(a+(b-a)*t) for a,b in zip((78,44,128),(22,13,40)))
        ImageDraw.Draw(grad).line([(x,0),(x,H)],fill=c)
    # glow: violet, alpha fades left->right (UIGradient transparency 0 -> .7 at .35 -> 1)
    glow=Image.new('RGB',(W,H),(196,150,255));ga=Image.new('L',(W,H))
    for x in range(W):
        t=x/(W-1);tr=.7*t/.35 if t<.35 else .7+.3*(t-.35)/.65;ImageDraw.Draw(ga).line([(x,0),(x,H)],fill=int(255*.18*(1-tr)))
    grad.paste(glow,(0,0),ga)
    bg.paste(grad,(ox,oy),rounded((W,H),8*K,int(255*.92)))
    d=ImageDraw.Draw(bg)
    d.rounded_rectangle([ox-1,oy-1,ox+W,oy+H],8*K,outline=(186,140,255),width=int(1.5*K))
    bx,by,bs=ox+4*K,oy+4*K,31*K
    d.ellipse([bx,by,bx+bs,by+bs],fill=(40,22,70),outline=(201,160,255),width=K)
    ic=icon('WeatherThunderstorm',scale=3,bg=(40,22,70)).convert('RGB').resize((bs-2*K-6,bs-2*K-6),Image.LANCZOS)
    bg.paste(ic,(bx+K+3,by+K+3),rounded(ic.size,ic.size[0]//2,255))
    cx=ox+40*K+(W-46*K)/2
    d.text((cx,oy+11.5*K),'THE VEILED ONE',font=F(13*K),fill=(236,216,255),anchor='mm',stroke_width=K,stroke_fill=(8,13,24))
    d.text((cx,oy+28*K),hint,font=F(10*K),fill=(208,196,234),anchor='mm',stroke_width=K,stroke_fill=(8,13,24))
    return bg
cs=[card(False),card(True),card(True,'CHASING YOU')]
sh=Image.new('RGB',(sum(c.width for c in cs)+40,cs[0].height+110),(255,255,255));d=ImageDraw.Draw(sh);x=0
for c,t in zip(cs,['BEFORE','AFTER','AFTER (chased)']):sh.paste(c,(x,40));d.text((x+8,10),t,font=F(18),fill=(20,20,20));x+=c.width+20
d.text((8,cs[0].height+50),'Bottom-right event notifier at 3x (190 x 39 px card, same position/size as before). Icon = existing HudArtwork "WeatherThunderstorm" (prepared fallback pixels).',font=SANS(14),fill=(60,60,60))
d.text((8,cs[0].height+72),'APPROXIMATION: DejaVu Bold stands in for FredokaOne (wider, so sizes are drawn smaller); GardenTextFit picks 16 px for the title in-game.',font=SANS(14),fill=(60,60,60))
sh.save(OUT+'notifier_before_after.png')
print('ok')
