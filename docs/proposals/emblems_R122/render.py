from PIL import Image, ImageDraw
import math,collections
rows=collections.OrderedDict()
for l in open('frames.txt'):
    p=l.rstrip('\n').split(';')
    if len(p)<12: continue
    rows.setdefault(p[0],[]).append(p)
def col(s):return tuple(int(float(x)) for x in s.split(','))
def frame_img(W,H,f,px):
    _,name,x,y,w,h,rot,c,tr,corner,stroke,grad=f
    x,y,w,h,rot,tr=map(float,(x,y,w,h,rot,tr))
    fw,fh=max(1,int(w*px)),max(1,int(h*px))
    tile=Image.new('RGBA',(fw,fh),(0,0,0,0))
    if grad:
        a,b=[col(t) for t in grad.split('|')]
        for j in range(fh):
            t=j/max(1,fh-1);cc=tuple(int(a[k]+(b[k]-a[k])*t) for k in range(3))
            ImageDraw.Draw(tile).line([(0,j),(fw,j)],fill=cc+(255,))
    else:
        tile.paste(col(c)+(int(255*(1-tr)),),[0,0,fw,fh])
    mask=Image.new('L',(fw,fh),0);md=ImageDraw.Draw(mask)
    if corner=='1':md.rounded_rectangle([0,0,fw-1,fh-1],radius=min(fw,fh)//2,fill=255)
    else:md.rectangle([0,0,fw-1,fh-1],fill=255)
    tile.putalpha(Image.composite(tile.split()[3],Image.new('L',(fw,fh),0),mask))
    if stroke:
        sw=max(1,int(px/20))
        d=ImageDraw.Draw(tile)
        if corner=='1':d.rounded_rectangle([0,0,fw-1,fh-1],radius=min(fw,fh)//2,outline=col(stroke)+(255,),width=sw)
        else:d.rectangle([0,0,fw-1,fh-1],outline=col(stroke)+(255,),width=sw)
    tile=tile.rotate(-rot,expand=True,resample=Image.BICUBIC)
    cx,cy=(x+w/2)*px,(y+h/2)*px
    return tile,(int(cx-tile.width/2),int(cy-tile.height/2))
big=160
out=Image.new('RGBA',(len(rows)*(big+20)+20,big+120),(40,44,80,255))
d=ImageDraw.Draw(out)
for i,(rar,fs) in enumerate(rows.items()):
    im=Image.new('RGBA',(big,big),(0,0,0,0))
    for f in fs:
        t,pos=frame_img(big,big,f,big);im.alpha_composite(t,dest=(max(-t.width,pos[0]),max(-t.height,pos[1]))) if pos[0]>=0 and pos[1]>=0 else im.alpha_composite(t.crop((max(0,-pos[0]),max(0,-pos[1]),t.width,t.height)),dest=(max(0,pos[0]),max(0,pos[1])))
    X=20+i*(big+20);out.alpha_composite(im,dest=(X,10))
    for k,sz in enumerate((20,12)):
        sm=im.resize((sz,sz),Image.LANCZOS);out.alpha_composite(sm,dest=(X+20+k*40,big+30))
    d.text((X,big+70),rar,fill=(255,255,255,255))
out.save('emblems.png')
print('ok')
