import re,json,sys
s=open('/home/user/tmz/src/ReplicatedStorage/ArtworkFallbackData89.lua').read()
enc=dict(re.findall(r'\["(\w+)"\]="([0-9a-f]+)"',s))
def spec(kind):
    b=bytes.fromhex(enc[kind]);at=0
    def byte():
        nonlocal at;v=b[at];at+=1;return v
    w,h,n=byte(),byte(),byte();pal=[(byte(),byte(),byte()) for _ in range(n)]
    cnt=byte()+byte()*256;strips=[]
    for _ in range(cnt):
        x,y,ww,k=byte(),byte(),byte(),byte();keys=[]
        for j in range(k):
            t,i,a=byte(),byte(),byte();c=pal[i];keys.append((t/255,)+c+(a,))
        strips.append((x,y,ww,keys))
    return w,h,strips
from PIL import Image
def render(kind,scale=4,bg=(40,30,60)):
    w,h,strips=spec(kind)
    im=Image.new('RGBA',(w*scale,h*scale),bg+(255,))
    px=im.load()
    for x,y,ww,keys in strips:
        for X in range(int(ww*scale)):
            t=(X+.5)/(ww*scale)
            # interpolate
            k0=keys[0];k1=keys[-1]
            for a,bk in zip(keys,keys[1:]):
                if a[0]<=t<=bk[0]: k0,k1=a,bk;break
            u=0 if k1[0]==k0[0] else (t-k0[0])/(k1[0]-k0[0]); u=max(0,min(1,u))
            c=[k0[i]+(k1[i]-k0[i])*u for i in range(1,5)]
            for Y in range(scale):
                xx=int(x*scale)+X;yy=y*scale+Y
                if 0<=xx<w*scale and 0<=yy<h*scale:
                    o=px[xx,yy];al=c[3]/255
                    px[xx,yy]=tuple(int(o[i]*(1-al)+c[i]*al) for i in range(3))+(255,)
    return im
if __name__=='__main__':
    kinds=sys.argv[1:] or sorted(enc)
    ims=[render(k) for k in kinds]
    W=sum(i.width for i in ims)+10*len(ims);H=max(i.height for i in ims)
    sheet=Image.new('RGBA',(W,H+20),(255,255,255,255));x=0
    from PIL import ImageDraw;d=ImageDraw.Draw(sheet)
    for k,i in zip(kinds,ims): sheet.paste(i,(x,20));d.text((x,2),k,fill=(0,0,0));x+=i.width+10
    sheet.save('sheet.png');print(sorted(enc))
