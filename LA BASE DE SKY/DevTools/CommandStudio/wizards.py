"""Guided RMXP commands. Native opcodes are data, not evaluated Ruby."""
from dataclasses import dataclass

@dataclass(frozen=True)
class Field:
    name: str
    default: str
    options: tuple = ()

WIZARDS = {
 'Esperar': [Field('Fotogramas','20')],
 'Controlar interruptores': [Field('Desde ID','1'),Field('Hasta ID','1'),Field('Estado','Encendido',('Encendido','Apagado'))],
 'Controlar variable (valor constante)': [Field('ID variable','1'),Field('Operación','Asignar',('Asignar','Sumar','Restar','Multiplicar','Dividir','Módulo')), Field('Valor','1')],
 'Interruptor local': [Field('Letra','A',('A','B','C','D')),Field('Estado','Encendido',('Encendido','Apagado'))],
 'Transferir jugador': [Field('ID mapa destino','1'),Field('Coordenada X','10'),Field('Coordenada Y','10'),Field('Dirección','Mantener',('Mantener','Abajo','Izquierda','Derecha','Arriba')),Field('Transición','Normal',('Normal','Sin fundido'))],
 'Reproducir BGM': [Field('Archivo (sin extensión)',''),Field('Volumen 0–100','80'),Field('Pitch 50–150','100')],
 'Reproducir BGS': [Field('Archivo (sin extensión)',''),Field('Volumen 0–100','80'),Field('Pitch 50–150','100')],
 'Reproducir ME': [Field('Archivo (sin extensión)',''),Field('Volumen 0–100','80'),Field('Pitch 50–150','100')],
 'Reproducir SE': [Field('Archivo (sin extensión)',''),Field('Volumen 0–100','80'),Field('Pitch 50–150','100')],
 'Cambiar tono de pantalla': [Field('Rojo -255…255','0'),Field('Verde -255…255','0'),Field('Azul -255…255','0'),Field('Gris 0…255','0'),Field('Fotogramas','20')],
 'Destello de pantalla': [Field('Rojo 0–255','255'),Field('Verde 0–255','255'),Field('Azul 0–255','255'),Field('Opacidad 0–255','160'),Field('Fotogramas','20')],
 'Sacudir pantalla': [Field('Fuerza','5'),Field('Velocidad','5'),Field('Fotogramas','20')],
 'Mostrar animación': [Field('Objetivo (-1 jugador, 0 este evento, ID otro)','0'),Field('ID animación','1')],
 'Etiqueta': [Field('Nombre','Inicio')],
 'Saltar a etiqueta': [Field('Nombre','Inicio')],
 'Llamar evento común': [Field('ID de evento común','1')],
 'Modificar dinero': [Field('Acción','Sumar',('Sumar','Restar')),Field('Cantidad','100')],
 'Cambiar objetos de base RPG Maker XP': [Field('ID del objeto','1'),Field('Acción','Añadir',('Añadir','Quitar')),Field('Cantidad','1')],
 'Comentario': [Field('Comentario','Nota de diseño')],
 'Mensaje': [Field('Texto','¡Hola, \\PN!')],
 'Script Ruby': [Field('Script','pbHealAll')],
}


def as_int(d,key,lo=None,hi=None):
    try: x=int(d[key].strip())
    except (KeyError,ValueError):raise ValueError(f'{key}: escribe un número entero.')
    if lo is not None and x<lo or hi is not None and x>hi:
        raise ValueError(f'{key}: número fuera del rango permitido ({lo} a {hi}).')
    return x


def code(num,params):return [{'code':num,'indent':0,'parameters':params}]


def build(name, data):
    v=lambda i,lo=None,hi=None:as_int(data,WIZARDS[name][i].name,lo,hi)
    d=lambda i:data[WIZARDS[name][i].name]
    if name=='Esperar':return code(106,[v(0,0,999999)])
    if name=='Controlar interruptores':
        x,y=v(0,1),v(1,1)
        if x>y:raise ValueError('El ID inicial debe ser menor o igual al final.')
        return code(121,[x,y,0 if d(2)=='Encendido' else 1])
    if name=='Controlar variable (valor constante)':
        return code(122,[v(0,1),v(0,1),('Asignar','Sumar','Restar','Multiplicar','Dividir','Módulo').index(d(1)),0,v(2)])
    if name=='Interruptor local':
        return code(123,[d(0),0 if d(1)=='Encendido' else 1])
    if name=='Transferir jugador':
        direct={'Mantener':0,'Abajo':2,'Izquierda':4,'Derecha':6,'Arriba':8}[d(3)]
        return code(201,[0,v(0,1,999),v(1,0),v(2,0),direct,0 if d(4)=='Normal' else 1])
    if name in ('Reproducir BGM','Reproducir BGS','Reproducir ME','Reproducir SE'):
        num={'Reproducir BGM':241,'Reproducir BGS':245,'Reproducir ME':249,'Reproducir SE':250}[name]
        return code(num,[{'__class':'RPG::AudioFile','name':d(0),'volume':v(1,0,100),'pitch':v(2,50,150)}])
    if name=='Cambiar tono de pantalla':
        return code(223,[{'__class':'Tone','values':[v(0,-255,255),v(1,-255,255),v(2,-255,255),v(3,0,255)]},v(4,0)])
    if name=='Destello de pantalla':
        return code(224,[{'__class':'Color','values':[v(0,0,255),v(1,0,255),v(2,0,255),v(3,0,255)]},v(4,0)])
    if name=='Sacudir pantalla':return code(225,[v(0,0),v(1,0),v(2,0)])
    if name=='Mostrar animación':return code(207,[v(0,-1),v(1,1)])
    if name=='Etiqueta':return code(118,[d(0)])
    if name=='Saltar a etiqueta':return code(119,[d(0)])
    if name=='Llamar evento común':return code(117,[v(0,1)])
    if name=='Modificar dinero':return code(125,[0 if d(0)=='Sumar' else 1,0,v(1,0)])
    if name=='Cambiar objetos de base RPG Maker XP':return code(126,[v(0,1),0 if d(1)=='Añadir' else 1,0,v(2,0)])
    if name=='Comentario':
        return [{'code':108 if i==0 else 408,'indent':0,'parameters':[line]}
                for i,line in enumerate(d(0).splitlines() or [''])]
    if name=='Mensaje':
        lines=d(0).splitlines() or ['']
        return [{'code':101 if k==0 else 401,'indent':0,'parameters':[line]}
                for offset in range(0,len(lines),4)
                for k,line in enumerate(lines[offset:offset+4])]
    if name=='Script Ruby':
        return [{'code':355 if i==0 else 655,'indent':0,'parameters':[line]}
                for i,line in enumerate(d(0).splitlines() or [''])]
    raise ValueError('Asistente desconocido')
