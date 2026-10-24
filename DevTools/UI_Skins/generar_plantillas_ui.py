#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera un kit editable de skins PNG exactos para Pokémon Vermeil (640x480).
Requisitos: pip install pillow
Ejecución: python generar_plantillas_ui.py
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import json, math, zipfile, random

BASE = Path(__file__).resolve().parent / 'Vermeil_UI_Skin_Kit'
P_ROOT = BASE / 'Graphics' / 'UI' / 'Vermeil' / 'NewPokedex'
N_ROOT = BASE / 'Graphics' / 'UI' / 'Vermeil' / 'ResearchNotebook'
GUIDES = BASE / 'Plantillas_con_guias'
PREV = BASE / 'Vista_previa'
for p in [P_ROOT, N_ROOT, GUIDES/'NewPokedex', GUIDES/'ResearchNotebook', PREV]: p.mkdir(parents=True,exist_ok=True)

DEX = {
    'background':(640,480,0,0),'header':(256,44,24,12),'list_panel':(326,420,286,24),
    'portrait_panel':(256,256,24,56),'counter_panel':(256,48,24,320),
    'list_row':(326,36,286,44),'list_row_selected':(326,36,286,44),
    'scrollbar_track':(6,420,615,32),'entry_page':(640,480,0,0),
    'area_page':(640,480,0,0),'forms_page':(640,480,0,0)
}
NOTE = {
    'background':(640,480,0,0),'focus_panel':(294,368,14,62),
    'grid_panel':(306,348,320,76),'detail_panel':(306,365,320,61),
    'grid_cell':(58,63,325,76),'grid_cell_selected':(58,63,325,76),
    'cover':(628,387,6,55),'pages':(628,387,6,55),
    'tab_arcane':(149,37,318,8),'tab_golden':(149,37,471,8)
}

def rgba(hexcode, a=255):
    c=hexcode.lstrip('#'); return tuple(int(c[i:i+2],16) for i in (0,2,4))+(a,)
def canvas(w,h,color=(0,0,0,0)):return Image.new('RGBA',(w,h),color)
def rr(im,box,r,fill,outline=None,width=1): ImageDraw.Draw(im).rounded_rectangle(box,radius=r,fill=fill,outline=outline,width=width)
def ln(im,xy,fill,width=1):ImageDraw.Draw(im).line(xy,fill=fill,width=width)
def elliptical(im,box,fill=None,outline=None,width=1):ImageDraw.Draw(im).ellipse(box,fill=fill,outline=outline,width=width)
def polygon(im,xy,fill):ImageDraw.Draw(im).polygon(xy,fill=fill)
def gradient(w,h,a,b):
    im=canvas(w,h); px=im.load()
    for y in range(h):
        f=y/max(h-1,1)
        c=tuple(int(a[i]*(1-f)+b[i]*f) for i in range(4))
        for x in range(w):px[x,y]=c
    return im

def decorate_tech(im,spacing=32,alpha=32):
    w,h=im.size;d=ImageDraw.Draw(im)
    for x in range(0,w,spacing): d.line((x,0,x,h), fill=(91,133,161,alpha),width=1)
    for y in range(0,h,spacing): d.line((0,y,w,y), fill=(91,133,161,alpha),width=1)
    for x,y in [(25,35),(w-25,35),(25,h-25),(w-25,h-25)]:
        d.line((x-5,y,x+5,y),fill=(117,181,207,90),width=1)
        d.line((x,y-5,x,y+5),fill=(117,181,207,90),width=1)

def save(group,key,im):
    lookup,root = (DEX,P_ROOT) if group=='NewPokedex' else (NOTE,N_ROOT)
    w,h,*_=lookup[key]
    assert im.size==(w,h),(key,im.size,(w,h))
    im.save(root/f'{key}.png',optimize=True)
    # Guías son independientes. No usar en el videojuego.
    gi=im.copy().convert('RGBA');layer=canvas(w,h);dr=ImageDraw.Draw(layer)
    for gx in range(0,w,32): dr.line((gx,0,gx,h), fill=(20,196,238,80))
    for gy in range(0,h,32): dr.line((0,gy,w,gy), fill=(20,196,238,80))
    dr.rectangle((0,0,w-1,h-1),outline=(238,61,102,230),width=2)
    dr.line((w//2-10,h//2,w//2+10,h//2),fill=(238,61,102,190),width=1)
    dr.line((w//2,h//2-10,w//2,h//2+10),fill=(238,61,102,190),width=1)
    gi=Image.alpha_composite(gi,layer)
    gi.save(GUIDES/group/f'{key}__GUIA.png',optimize=True)

# ------------------------------------------------------------------
# NUEVA POKÉDEX — dispositivo técnico, colores minerales y coral
# ------------------------------------------------------------------
im=gradient(640,480,rgba('#101824'),rgba('#1d2c3d'))
decorate_tech(im,36,19)
# Borde de cámara, líneas y diagonales asimétricas; no incluir texto
polygon(im,[(0,0),(165,0),(0,143)],rgba('#263e53',135))
polygon(im,[(640,480),(450,480),(640,300)],rgba('#273d50',170))
ln(im,[(12,470),(140,470),(156,454)],rgba('#e35d66',190),3)
ln(im,[(490,14),(619,14),(628,23)],rgba('#58b9c7',120),2)
elliptical(im,(7,382,150,526),outline=rgba('#5c8baf',50),width=2)
rr(im,(8,8,631,471),15,None,rgba('#789cba',95),2)
save('NewPokedex','background',im)

im=canvas(256,44)
rr(im,(0,0,255,43),8,rgba('#263b50'),rgba('#6095b2',180),1)
rr(im,(3,3,252,39),5,rgba('#182837'))
ln(im,[(11,41),(126,41)],rgba('#e35d66'),3)
polygon(im,[(225,2),(253,2),(253,29)],rgba('#e35d66',130))
save('NewPokedex','header',im)

im=canvas(326,420)
rr(im,(0,0,325,419),11,rgba('#182735',235),rgba('#59829b',145),2)
rr(im,(6,6,319,413),8,rgba('#14212f',200))
ln(im,[(12,18),(314,18)],rgba('#83b3c4',130),1)
ln(im,[(12,416),(124,416)],rgba('#e35d66',170),2)
save('NewPokedex','list_panel',im)

im=canvas(256,256)
rr(im,(0,0,255,255),12,rgba('#131f30',54),rgba('#8ec7dc',205),2)
rr(im,(7,7,248,248),9,None,rgba('#628ca3',120),1)
for radius in (73,99):elliptical(im,(128-radius,128-radius,128+radius,128+radius),outline=rgba('#a1d1de',35 if radius==99 else 48),width=2)
for x,y in [(14,14),(234,14),(14,234),(234,234)]:
    ln(im,[(x,y+8),(x,y),(x+8,y)],rgba('#e35d66',180),2)
ln(im,[(33,233),(96,233)],rgba('#87bbcb',140),2)
save('NewPokedex','portrait_panel',im)

im=canvas(256,48)
rr(im,(0,0,255,47),7,rgba('#1b2e40'),rgba('#648fa7',135),1)
rr(im,(5,4,250,43),5,rgba('#162432'))
ln(im,[(6,4),(6,44)],rgba('#e35d66',225),3)
ln(im,[(218,39),(244,39)],rgba('#67b4c3',175),2)
save('NewPokedex','counter_panel',im)

for name,sel in [('list_row',False),('list_row_selected',True)]:
    im=canvas(326,36)
    rr(im,(1,1,324,34),5,rgba('#32495c',230) if sel else rgba('#294153',95),rgba('#e35d66',240) if sel else rgba('#5d859d',75),2 if sel else 1)
    if sel:
        ln(im,[(3,5),(3,31)],rgba('#e96f75'),4)
        polygon(im,[(310,10),(320,18),(310,26)],rgba('#e96f75',230))
    else: ln(im,[(18,34),(289,34)],rgba('#7da3bc',35),1)
    save('NewPokedex',name,im)

im=canvas(6,420)
rr(im,(0,0,5,419),3,rgba('#142532'),rgba('#628aa3',120),1)
ln(im,[(3,8),(3,411)],rgba('#9ebfcc',70),1)
save('NewPokedex','scrollbar_track',im)

# Páginas de información, localización y formas. La zona del Pokémon queda
# transparente para mantener el sprite del juego independiente del PNG.
for key in ('entry_page','area_page','forms_page'):
    im=gradient(640,480,rgba('#121d2d'),rgba('#202e3e'))
    decorate_tech(im,40,16)
    rr(im,(8,8,631,471),11,None,rgba('#608fa9',125),2)
    rr(im,(14,12,624,50),8,rgba('#283b4c'),rgba('#6a9fba',100),1)
    ln(im,[(14,53),(626,53)],rgba('#e35d66',190),2)
    rr(im,(299,62,622,315),10,rgba('#162534',210),rgba('#7898af',120),1)
    rr(im,(18,323,624,457),8,rgba('#182b3b',230),rgba('#6d9caf',135),1)
    if key=='forms_page':
        rr(im,(318,24,628,424),9,rgba('#1c293a',230),rgba('#6895aa',120),1)
    if key=='area_page':
        rr(im,(24,65,616,377),8,rgba('#192f3e',160),rgba('#6b9eaf',140),1)
    else:
        # Solo marcos, hueco transparentado en imagen de información/formas.
        p=im.load()
        for yy in range(56,312):
            for xx in range(24,280):p[xx,yy]=(0,0,0,0)
        rr(im,(20,52,284,316),11,None,rgba('#83b3c7',215),3)
        ln(im,[(24,312),(107,312)],rgba('#e35d66',215),3)
    save('NewPokedex',key,im)

# ------------------------------------------------------------------
# LIBRETA — cuero, papel editorial e instrumental académico
# ------------------------------------------------------------------
N_BG=rgba('#e9dcbf')
im=gradient(640,480,rgba('#30221b'),rgba('#1a1515'))
rr(im,(5,52,635,442),13,rgba('#7e573b'),rgba('#bc9861',140),2)
rr(im,(10,57,630,436),8,rgba('#e9dec2'),rgba('#fff5db',190),1)
# Dos páginas suaves, centro cosido
rr(im,(13,60,308,432),5,rgba('#f0e5c9'),rgba('#bd9f6e',145),1)
rr(im,(314,60,626,432),5,rgba('#f5ebd5'),rgba('#bd9f6e',145),1)
for yy in range(81,412,31):
    ln(im,[(24,yy),(299,yy)],rgba('#b9a27b',51))
    ln(im,[(326,yy),(616,yy)],rgba('#b9a27b',44))
for dx in range(-2,3):ln(im,[(311+dx,61),(311+dx,431)],rgba('#74583e', 80-abs(dx)*15),1)
# Barra de título y pie cuero, pequeñas cantoneras
rr(im,(0,0,639,54),2,rgba('#30221f'))
rr(im,(0,442,639,479),2,rgba('#30221f'))
ln(im,[(15,50),(624,50)],rgba('#aa874d',150),2)
ln(im,[(15,443),(624,443)],rgba('#aa874d',150),2)
for xx in (18,621):
    for yy in (16,459):elliptical(im,(xx-3,yy-3,xx+3,yy+3),fill=rgba('#c1a46c',210))
save('ResearchNotebook','background',im)

im=canvas(294,368)
rr(im,(0,0,293,367),11,rgba('#f0e7d0',235),rgba('#8b7253',165),2)
rr(im,(5,5,288,362),8,None,rgba('#c3ae8b',130),1)
for yy in range(54,310,33):ln(im,[(14,yy),(280,yy)],rgba('#ad9672',55))
# detalles esquinas y bajo el retrato
ln(im,[(12,45),(75,45)],rgba('#c3a16e',180),2)
ln(im,[(110,254),(183,254)],rgba('#b78d52',150),2)
save('ResearchNotebook','focus_panel',im)

im=canvas(306,348)
rr(im,(0,0,305,347),9,rgba('#e5d7b7',90),rgba('#b09a77',120),2)
rr(im,(5,5,300,342),7,None,rgba('#fff5d9',115),1)
save('ResearchNotebook','grid_panel',im)

im=canvas(306,365)
rr(im,(0,0,305,364),11,rgba('#f6ecd6',230),rgba('#a9926e',150),2)
rr(im,(8,8,297,356),9,None,rgba('#cdbb97',145),1)
for yy in range(44,344,26):ln(im,[(15,yy),(290,yy)],rgba('#bda981',45))
save('ResearchNotebook','detail_panel',im)

for key,selected in [('grid_cell',False),('grid_cell_selected',True)]:
    im=canvas(58,63)
    rr(im,(0,0,57,62),6,rgba('#f8f0db',240) if selected else rgba('#e9ddc4',185),rgba('#a88756',235) if selected else rgba('#ac9975',130),2 if selected else 1)
    rr(im,(4,4,53,58),5,None,rgba('#fff9e7',140),1)
    if selected:
        ln(im,[(5,60),(52,60)],rgba('#ba8956',235),3)
        elliptical(im,(47,6,53,12),fill=rgba('#ba8956',250))
    save('ResearchNotebook',key,im)

# Libreta cerrada. El texto no viene horneado: lo renderiza el juego.
im=gradient(628,387,rgba('#5e4030'),rgba('#241918'))
rr(im,(1,1,626,385),13,rgba('#3a2926',235),rgba('#b6925a',220),3)
rr(im,(8,8,620,379),10,None,rgba('#9c7750',175),2)
rr(im,(18,13,39,371),3,rgba('#1c181c'),rgba('#9c7652',150),1)
for yy in range(21,364,12):elliptical(im,(27,yy,30,yy+3),fill=rgba('#a88157',170))
rr(im,(176,92,451,220),12,rgba('#684832'),rgba('#c9a675',195),2)
rr(im,(184,100,443,212),8,rgba('#372a28'),rgba('#b99560',155),2)
elliptical(im,(253,238,375,360),outline=rgba('#bf995f',120),width=3)
elliptical(im,(279,264,349,334),outline=rgba('#bf995f',90),width=2)
for x,y in [(12,12),(615,12),(12,373),(615,373)]:
    elliptical(im,(x-3,y-3,x+3,y+3),fill=rgba('#cca671'))
save('ResearchNotebook','cover',im)

im=gradient(628,387,rgba('#d3bd93'),rgba('#eadaaf'))
rr(im,(4,4,622,382),9,rgba('#f4e8ca'),rgba('#bba479',130),1)
for yy in range(35,375,28):
    ln(im,[(12,yy),(298,yy)],rgba('#b7a47d',52))
    ln(im,[(320,yy),(613,yy)],rgba('#b7a47d',52))
rr(im,(303,6,310,382),3,rgba('#ad956d',115))
for x in range(619,625,2):ln(im,[(x,8),(x,374)],rgba('#a9926a',70),1)
save('ResearchNotebook','pages',im)

for key,color in [('tab_arcane','#7c658f'),('tab_golden','#a37c33')]:
    im=canvas(149,37)
    rr(im,(0,0,148,36),7,rgba(color,235),rgba('#f2e1bd',110),1)
    rr(im,(4,4,144,32),5,rgba('#302521',65))
    ln(im,[(11,33),(138,33)],rgba(color,255),3)
    save('ResearchNotebook',key,im)

# ------------------------------------------------------------------
# Documentación y montajes ilustrativos (no se ejecutan dentro del juego)
# ------------------------------------------------------------------
all_layouts={
  'canvas':{'width':640,'height':480,'scale':'1:1','unit':'px'},
  'NewPokedex':{name:{'width':w,'height':h,'x':x,'y':y,'file':f'Graphics/UI/Vermeil/NewPokedex/{name}.png'} for name,(w,h,x,y) in DEX.items()},
  'ResearchNotebook':{name:{'width':w,'height':h,'x':x,'y':y,'file':f'Graphics/UI/Vermeil/ResearchNotebook/{name}.png'} for name,(w,h,x,y) in NOTE.items()},
  'guidance':{'NewPokedex': 'entry_page y forms_page dejan el retrato x=24..279, y=56..311 transparente. No hornear nombres, especies, mapas ni contadores.', 'ResearchNotebook':'El texto se dibuja en el juego. grid_cell* debe conservar área central legible. cover y pages son hojas de 628x387.'}
}
(BASE/'MEDIDAS_Y_CAPAS.json').write_text(json.dumps(all_layouts,ensure_ascii=False,indent=2),encoding='utf-8')
(BASE/'LEEME_EDITAR.md').write_text('''# Kit de skins UI — Pokémon Vermeil\n\nDos sistemas independientes de PNGs editables, diseñados para pantalla **640 × 480 px**, sin reescalar.\n\n## Cómo instalar\n1. Copia **la carpeta Graphics** de este ZIP a la carpeta raíz de `LA BASE DE SKY` de tu proyecto.\n2. Los PNGs deben quedar exactamente en `Graphics/UI/Vermeil/NewPokedex/` y `Graphics/UI/Vermeil/ResearchNotebook/`.\n3. Abre la Pokédex o Libreta. Si el PNG existe y mide lo indicado, se carga en lugar del dibujo de respaldo.\n4. Para cambiar un gráfico edita su PNG en Photoshop, Clip Studio o software similar, guarda **PNG RGBA**, y vuelve a abrir la pantalla.\n\n## Qué archivos editar\n**NewPokedex**: `background` fondo global; `header` cabecera; `portrait_panel` recuadro de Pokémon; `list_panel`, `list_row`, `list_row_selected` lista; `counter_panel` contadores; `scrollbar_track`; `entry_page`, `area_page`, `forms_page` páginas.\n\n**ResearchNotebook**: `background` papel abierto; `focus_panel` ficha focal; `grid_panel` base de casillas; `detail_panel` investigación; `grid_cell`, `grid_cell_selected`; `cover` tapa; `pages` hojas de animación; `tab_arcane`, `tab_golden` pestañas.\n\n## Reglas de composición\n- Edita los **PNG dentro de Graphics** (sin texto fijo: los nombres, números, estados, Pokémon, localizaciones y estadísticas se dibujan en ejecución).\n- Las imágenes en **Plantillas_con_guias** son referencias visuales con cuadrícula cada 32 px, **NO** las copies al juego.\n- Todos los PNG usan la resolución exacta registrada en **MEDIDAS_Y_CAPAS.json**. Un tamaño erróneo hace que el motor use su diseño de respaldo.\n- `entry_page` y `forms_page` deben conservar el hueco alpha transparente x=24..279, y=56..311 para el sprite del Pokémon.\n- El código tiene un interruptor: `NewPokedexConfig::CONFIG[:use_custom_ui]` y `ResearchNotebook::Settings::USE_CUSTOM_UI`.\n- Puedes sustituir solo los componentes que quieras. El resto mantiene su fallback.\n- No incluyas los nombres de Pokémon ni otras cifras dentro de los PNG: cambian según el progreso, idioma y forma.\n\n## Notas\n- `list_row*` mide 326×36 y se repite 10 veces.\n- `grid_cell*` mide 58×63 y se repite hasta 25 veces.\n- La tapa de la Libreta (`cover`) y sus páginas de animación (`pages`) miden **628×387**.\n- La paleta es sugerida y totalmente editable: técnica oscura para Pokédex, papel/cuero para Libreta.\n- Volver a abrir la pantalla recarga los PNG modificados. No hace falta alterar los JSON de especies o habilidades.\n- Los PNG son ilustrativos; su apariencia final dentro del juego dependerá de sprites, fonts y capas de la versión de Essentials.\n''',encoding='utf-8')

# Mockups: se muestran texturas instaladas con una pequeña representación de
# tipografía dinámica. No se utilizan para el juego.
fontpaths=['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf','/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf']
fontpath=next((f for f in fontpaths if Path(f).exists()),None)
def font(size,bold=False):
    path = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else fontpath
    return ImageFont.truetype(path,size) if path and Path(path).exists() else ImageFont.load_default()
def put(im,xy,text,size,fill,bold=False):ImageDraw.Draw(im).text(xy,text,font=font(size,bold),fill=fill)
def overlay_asset(dst,root,key,x,y):
    dst.alpha_composite(Image.open(root/f'{key}.png').convert('RGBA'),(x,y))

p=Image.open(P_ROOT/'background.png').convert('RGBA')
for key,x,y in [('header',24,12),('list_panel',286,24),('counter_panel',24,320),('portrait_panel',24,56)]:overlay_asset(p,P_ROOT,key,x,y)
put(p,(37,23),'POKÉDEX PAYU',16,(243,231,239,255),True)
for i,(num,name) in enumerate([(1,'BULBASAUR'),(2,'IVYSAUR'),(3,'VENUSAUR'),(4,'CHARMANDER'),(5,'CHARMELEON'),(6,'CHARIZARD'),(7,'SQUIRTLE'),(8,'WARTORTLE'),(9,'BLASTOISE')]):
    y=44+i*40
    overlay_asset(p,P_ROOT,'list_row_selected' if i==2 else 'list_row',286,y)
    put(p,(303,y+8),f'{num:03d}',12,(174,196,203,255))
    put(p,(354,y+7),name,13,(233,240,243,255),i==2)
put(p,(60,80),'VISTA DE ESPECIE',13,(183,200,209,255))
put(p,(92,173),'POKÉMON',21,(134,178,198,190),True)
put(p,(40,332),'VISTOS: 34/66',13,(230,233,240,255),True)
put(p,(40,351),'OBTENIDOS: 22/66',13,(230,233,240,255),True)
put(p,(26,454),'FLECHAS: EXPLORAR     C: FICHA     D: ORDENAR     X: SALIR',10,(193,210,222,255))
p.save(PREV/'01_Pokedex_ejemplo.png')

n=Image.open(N_ROOT/'background.png').convert('RGBA')
for key,x,y in [('focus_panel',14,62),('grid_panel',320,76),('tab_arcane',318,8),('tab_golden',471,8)]:overlay_asset(n,N_ROOT,key,x,y)
put(n,(23,15),'LIBRETA DE INVESTIGACIÓN',18,(244,233,205,255),True)
put(n,(328,18),'ARCANAS',13,(252,241,229,255),True)
put(n,(487,18),'ÁUREO',13,(252,241,229,255),True)
put(n,(30,76),'#014',13,(90,70,55,255),True)
put(n,(87,76),'INVESTIGACIÓN',17,(90,70,55,255),True)
put(n,(102,175),'ESPECIE',24,(151,126,100,255),True)
put(n,(30,343),'HABILIDAD ARCANA',14,(94,70,133,255),True)
put(n,(30,369),'????',19,(96,80,61,255))
for i in range(25):
    row,col=divmod(i,5)
    x,y=325+col*61,76+row*66
    overlay_asset(n,N_ROOT,'grid_cell_selected' if i==4 else 'grid_cell',x,y)
    put(n,(x+11,y+8),f'{i+1:03d}',10,(124,103,77,255))
put(n,(21,450),'C: VER FICHA   |   Z: CAMBIAR SECCIÓN',11,(238,224,194,255))
n.save(PREV/'02_Libreta_ejemplo.png')

bundle=Path(__file__).resolve().parent/'Vermeil_UI_Skin_Kit.zip'
with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for item in BASE.rglob('*'):
        if item.is_file():z.write(item,Path('Vermeil_UI_Skin_Kit')/item.relative_to(BASE))
    z.write(Path(__file__),Path('Vermeil_UI_Skin_Kit')/'generar_plantillas_ui.py')
print('LISTO',bundle,'archivos png:',len(list(BASE.rglob('*.png'))),'total KB:',round(bundle.stat().st_size/1024))