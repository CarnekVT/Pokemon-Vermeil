# -*- coding: utf-8 -*-
"""Command Studio: editor universal de eventos RMXP + índice de scripts Essentials.
Python 3.9+, Tkinter estándar, Ruby externo para leer/escribir .rxdata.
"""
import copy
import json
import os
import re
import shutil
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from catalog import COMMANDS, BY_CODE, DEFAULT_PARAMS, ESSENTIALS, INTERNAL, STRUCTURAL
from wizards import WIZARDS, build as wizard_build

VERSION = '0.1.0'
HERE = Path(__file__).resolve().parent
DARK = '#161a23'
SURFACE = '#222834'
BORDER = '#364254'
TEXT = '#ecf2fa'
MUTED = '#9eafc3'
CYAN = '#79dbcc'
FONT = ('Segoe UI', 10)
MONO = ('Consolas', 10)


def as_json(value):
    return json.dumps(value, indent=2, ensure_ascii=False)


def find_ruby():
    options = [shutil.which('ruby'), r'C:\Ruby34-x64\bin\ruby.exe',r'C:\Ruby33-x64\bin\ruby.exe',
               r'C:\Ruby32-x64\bin\ruby.exe',r'C:\Ruby31-x64\bin\ruby.exe']
    return next((p for p in options if p and Path(p).is_file()),'ruby')


def format_cmd(cmd):
    code=cmd['code']
    label=BY_CODE[code].title if code in BY_CODE else f'Comando {code}'
    p=cmd.get('parameters',[])
    if code in (101,401,355,655) and p:
        preview=str(p[0])
    elif code in (111,102,121,122,123,106,201):
        preview=json.dumps(p,ensure_ascii=False)[:100]
    elif p:
        preview=json.dumps(p,ensure_ascii=False)[:85]
    else:
        preview=''
    return label,preview


def script_commands(script,indent=0):
    lines=script.splitlines() or ['']
    return [{'code':355 if i==0 else 655,'indent':indent,'parameters':[line]}
            for i,line in enumerate(lines)]


def comment_commands(message,indent=0):
    lines=message.splitlines() or ['']
    return [{'code':108 if i==0 else 408,'indent':indent,'parameters':[line]}
            for i,line in enumerate(lines)]


def message_commands(message,indent=0):
    lines=message.splitlines() or ['']
    output=[]
    for start in range(0,len(lines),4):
        for index,line in enumerate(lines[start:start+4]):
            output.append({'code':101 if index==0 else 401,'indent':indent,'parameters':[line]})
    return output


def template_choices(choices,indent=0):
    if not 1<=len(choices)<=4:
        raise ValueError('RMXP admite entre 1 y 4 elecciones por bloque.')
    result=[{'code':102,'indent':indent,'parameters':[choices,0]}]
    for i,choice in enumerate(choices):
        result.append({'code':402,'indent':indent,'parameters':[i,choice]})
        result += message_commands('Elegiste: '+choice,indent+1)
    result.append({'code':404,'indent':indent,'parameters':[]})
    return result


def template_condition(expression,yes='',no='',indent=0):
    result=[{'code':111,'indent':indent,'parameters':[12,expression]}]
    result += message_commands(yes or 'La condición se cumple.',indent+1)
    if no:
        result.append({'code':411,'indent':indent,'parameters':[]})
        result += message_commands(no,indent+1)
    result.append({'code':412,'indent':indent,'parameters':[]})
    return result


def template_loop(indent=0):
    return [{'code':112,'indent':indent,'parameters':[]},
            {'code':106,'indent':indent+1,'parameters':[20]},
            {'code':113,'indent':indent+1,'parameters':[]},
            {'code':413,'indent':indent,'parameters':[]}]


def make_block(kind,a,b):
    if kind=='Condición con Else': return template_condition(a,b,'No se cumple.')
    if kind=='Elecciones': return template_choices([i.strip() for i in a.splitlines() if i.strip()])
    if kind=='Bucle': return template_loop()
    if kind=='Entrenador Essentials':
        # Script command is wrapped as a conditional to set self-switch only on victory.
        return template_condition(a or 'TrainerBattle.start(:YOUNGSTER, "Luis")',
                                 '¡Buen combate!','¡Otra vez será!')
    if kind=='Obtener Pokémon':
        return script_commands('pbAddPokemon('+ (a or ':RIOLU, 5') +')')
    if kind=='Recibir objeto':
        return script_commands('pbReceiveItem('+ (a or ':POTION, 1') +')')
    raise ValueError('Plantilla no implementada')


class CommandStudio(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f'Command Studio · RPG Maker XP / Pokémon Essentials · v{VERSION}')
        self.geometry('1320x830')
        self.minsize(1100,690)
        self.project=tk.StringVar()
        self.ruby=tk.StringVar(value=find_ruby())
        self.search=tk.StringVar()
        self.kind=tk.StringVar(value='Nativos + Essentials')
        self.selected_cmd=None
        self.map_info=[]
        self.map_id=None
        self.events=[]
        self.event_id=None
        self.page_num=0
        self.page_commands=[]
        self.method_items=[]
        self.library_rows={}
        self.save_position=tk.StringVar(value='Final de la página')
        self.status=tk.StringVar(value='Abre una carpeta de proyecto para habilitar inserción directa. La biblioteca ya está disponible.')
        self.apply_styles()
        self.make_header()
        self.tabs=ttk.Notebook(self)
        self.tabs.pack(fill='both',expand=True,padx=14,pady=(10,5))
        self.build_library()
        self.build_wizards()
        self.build_text()
        self.build_scripts()
        self.build_blocks()
        self.build_events()
        self.build_footer()
        self.search.trace_add('write',lambda *_:self.refresh_library())
        self.kind.trace_add('write',lambda *_:self.refresh_library())
        self.refresh_library()
        self.protocol('WM_DELETE_WINDOW',self.destroy)

    def apply_styles(self):
        self.configure(background=DARK)
        st=ttk.Style(self)
        st.theme_use('clam')
        st.configure('.',font=FONT,background=DARK,foreground=TEXT)
        st.configure('TFrame',background=DARK)
        st.configure('Surface.TFrame',background=SURFACE)
        st.configure('TLabel',background=DARK,foreground=TEXT)
        st.configure('Hint.TLabel',background=DARK,foreground=MUTED)
        st.configure('Title.TLabel',background=DARK,foreground=TEXT,font=('Segoe UI Semibold',18))
        st.configure('TButton',background='#344355',foreground=TEXT,padding=(12,7),borderwidth=0)
        st.map('TButton',background=[('active','#415870'),('disabled','#242a34')])
        st.configure('Accent.TButton',background='#1b776f',foreground='#ffffff')
        st.map('Accent.TButton',background=[('active','#25978d')])
        st.configure('TEntry',fieldbackground=SURFACE,foreground=TEXT,insertcolor=TEXT,padding=6)
        st.configure('TCombobox',fieldbackground=SURFACE,background=SURFACE,foreground=TEXT,arrowcolor=TEXT,padding=5)
        st.map('TCombobox',fieldbackground=[('readonly',SURFACE)],foreground=[('readonly',TEXT)])
        st.configure('TNotebook',background=DARK,borderwidth=0)
        st.configure('TNotebook.Tab',padding=(14,10),background=SURFACE,foreground=MUTED)
        st.map('TNotebook.Tab',background=[('selected','#315b60')],foreground=[('selected','#ffffff')])
        st.configure('Treeview',background=SURFACE,fieldbackground=SURFACE,foreground=TEXT,rowheight=27,borderwidth=0)
        st.configure('Treeview.Heading',background='#334052',foreground=TEXT,padding=6)
        st.map('Treeview',background=[('selected','#186d69')],foreground=[('selected','white')])
        st.configure('TLabelframe',background=DARK,foreground=TEXT)
        st.configure('TLabelframe.Label',background=DARK,foreground=TEXT)
        st.configure('TScrollbar',background='#344355',troughcolor=DARK)

    def frame(self,parent,padx=0,pady=0):
        f=ttk.Frame(parent)
        f.pack(fill='both',expand=True,padx=padx,pady=pady)
        return f

    def textbox(self,parent,height=8,mono=True):
        box=tk.Text(parent,height=height,bg=SURFACE,fg=TEXT,insertbackground=TEXT,
                    relief='flat',highlightthickness=1,highlightbackground=BORDER,
                    font=MONO if mono else FONT,wrap='word',padx=12,pady=9,
                    selectbackground='#24665f',undo=True)
        return box

    def set_text(self,w,s):
        w.delete('1.0','end')
        w.insert('1.0',s)

    def get_text(self,w): return w.get('1.0','end-1c')

    def make_header(self):
        h=ttk.Frame(self)
        h.pack(fill='x',padx=16,pady=(13,3))
        ttk.Label(h,text='COMMAND STUDIO',style='Title.TLabel').pack(side='left',padx=(0,15))
        ttk.Label(h,text='Enciclopedia + editor de eventos + Ruby',style='Hint.TLabel').pack(side='left')
        ttk.Button(h,text='Abrir proyecto…',style='Accent.TButton',command=self.open_project).pack(side='right')
        ttk.Entry(h,textvariable=self.project,width=45).pack(side='right',padx=(7,10))
        ttk.Label(h,text='Proyecto',style='Hint.TLabel').pack(side='right')
        sub=ttk.Frame(self)
        sub.pack(fill='x',padx=16)
        ttk.Label(sub,text='Ruby:',style='Hint.TLabel').pack(side='left')
        ttk.Entry(sub,textvariable=self.ruby,width=40).pack(side='left',padx=7)
        ttk.Label(sub,text='La edición de mapas requiere Ruby 3 instalado en Windows.',style='Hint.TLabel').pack(side='left')

    def build_library(self):
        tab=ttk.Frame(self.tabs)
        self.tabs.add(tab,text='  Enciclopedia  ')
        top=ttk.Frame(tab)
        top.pack(fill='x',padx=9,pady=9)
        ttk.Entry(top,textvariable=self.search,width=56).pack(side='left',fill='x',expand=True)
        ttk.Combobox(top,textvariable=self.kind,width=25,state='readonly',values=[
            'Nativos + Essentials','Solo nativos','Solo Essentials']).pack(side='left',padx=(9,0))
        pan=ttk.Panedwindow(tab,orient='horizontal')
        pan.pack(fill='both',expand=True,padx=8,pady=5)
        left=ttk.Frame(pan)
        right=ttk.Frame(pan)
        pan.add(left,weight=2)
        pan.add(right,weight=3)
        self.cmd_tree=ttk.Treeview(left,columns=('code','title','cat'),show='headings',selectmode='browse')
        for c,w in [('code',85),('title',250),('cat',175)]:
            self.cmd_tree.heading(c,text={'code':'Código','title':'Comando','cat':'Categoría'}[c])
            self.cmd_tree.column(c,width=w,stretch=(c!='code'))
        self.cmd_tree.pack(fill='both',expand=True,side='left')
        sc=ttk.Scrollbar(left,orient='vertical',command=self.cmd_tree.yview)
        sc.pack(fill='y',side='right')
        self.cmd_tree.configure(yscrollcommand=sc.set)
        self.cmd_tree.bind('<<TreeviewSelect>>',self.on_choose_library)
        self.lib_title=ttk.Label(right,text='Selecciona un comando',style='Title.TLabel')
        self.lib_title.pack(anchor='w',padx=12,pady=(7,5))
        self.lib_desc=ttk.Label(right,text='Todos los códigos del intérprete RMXP y funciones de Essentials.',
                                 wraplength=540,style='Hint.TLabel')
        self.lib_desc.pack(fill='x',padx=12,pady=(2,12))
        ttk.Label(right,text='Parámetros JSON (opcodes nativos) / Script Ruby (Essentials)').pack(anchor='w',padx=12)
        self.lib_editor=self.textbox(right,height=16)
        self.lib_editor.pack(fill='both',expand=True,padx=12,pady=8)
        ttk.Label(right,text='Los comandos estructurales se insertan con Bloques; usa ejemplos del proyecto para parámetros complejos.',
                  wraplength=530,style='Hint.TLabel').pack(anchor='w',padx=12,pady=(2,7))
        buttons=ttk.Frame(right)
        buttons.pack(fill='x',padx=12,pady=6)
        ttk.Button(buttons,text='Copiar al portapapeles',command=self.copy_selected_library).pack(side='left')
        ttk.Button(buttons,text='Insertar en evento',style='Accent.TButton',command=self.insert_library).pack(side='left',padx=8)
        ttk.Button(buttons,text='Usar muestra del evento',command=self.use_event_example).pack(side='left')

    def refresh_library(self):
        q=self.search.get().casefold().strip()
        mode=self.kind.get()
        self.cmd_tree.delete(*self.cmd_tree.get_children())
        self.library_rows={}
        if mode!='Solo Essentials':
            for c in COMMANDS:
                if q not in f'{c.title} {c.category} {c.aliases} {c.code}'.casefold():continue
                iid='native_'+str(c.code)
                self.cmd_tree.insert('', 'end', iid=iid,values=(c.code,c.title,c.category))
                self.library_rows[iid]=('native',c)
        if mode!='Solo nativos':
            for i,(title,cat,code,description) in enumerate(ESSENTIALS):
                if q not in f'{title} {cat} {code} {description}'.casefold(): continue
                iid='ess_'+str(i)
                self.cmd_tree.insert('', 'end',iid=iid,values=('Ruby',title,cat))
                self.library_rows[iid]=('ess',(title,cat,code,description))

    def on_choose_library(self,*_):
        selection=self.cmd_tree.selection()
        if not selection:return
        kind,item=self.library_rows[selection[0]]
        self.selected_cmd=(kind,item)
        if kind=='native':
            c=item
            self.lib_title.configure(text=f'{c.title} · {c.code}')
            blocked=' Requiere insertar un bloque íntegro.' if c.code in STRUCTURAL else ''
            self.lib_desc.configure(text=f'{c.category} · Alias: {c.aliases}.{blocked} '+
                                         ('Los parámetros predeterminados son ilustrativos: valida para tu proyecto.' if c.code in DEFAULT_PARAMS else 'Modifica parámetros según la especificación de este comando.'))
            if c.code==101:
                self.set_text(self.lib_editor,r'¡Hola, \PN!')
            elif c.code==108:
                self.set_text(self.lib_editor,'Nota del creador')
            elif c.code==355:
                self.set_text(self.lib_editor,'pbMessage(_INTL("¡Hola!"))')
            else:
                self.set_text(self.lib_editor,as_json(DEFAULT_PARAMS.get(c.code,[])))
        else:
            title,cat,code,desc=item
            self.lib_title.configure(text=title)
            self.lib_desc.configure(text=f'Pokémon Essentials / {cat}: {desc} Comprueba compatibilidad si usas plugins que reemplacen esta función.')
            self.set_text(self.lib_editor,code)

    def copy(self,s):
        self.clipboard_clear()
        self.clipboard_append(s)
        self.update()
        self.set_status('Copiado al portapapeles.')

    def copy_selected_library(self):
        if not self.selected_cmd:return
        typ,item=self.selected_cmd
        if typ=='ess':
            self.copy(self.get_text(self.lib_editor))
        else:
            c=item
            try:
                if c.code in (101,108,355):
                    self.copy(self.get_text(self.lib_editor))
                else:
                    params=json.loads(self.get_text(self.lib_editor))
                    self.copy(as_json({'code':c.code,'indent':0,'parameters':params}))
            except Exception as e:self.error(str(e))

    def current_native_insertion(self):
        if not self.selected_cmd: raise ValueError('Selecciona un comando del catálogo.')
        typ,item=self.selected_cmd
        if typ=='ess': return script_commands(self.get_text(self.lib_editor))
        c=item
        if c.code in STRUCTURAL:
            raise ValueError('Este código es un marcador de estructura o continuación. Abre "Bloques" para insertarlo correctamente.')
        if c.code==101:
            return message_commands(self.get_text(self.lib_editor))
        if c.code==108:
            return comment_commands(self.get_text(self.lib_editor))
        if c.code==355:
            return script_commands(self.get_text(self.lib_editor))
        params=json.loads(self.get_text(self.lib_editor))
        if not isinstance(params,list):raise ValueError('Los parámetros deben ser un Array JSON: [...].')
        if c.code not in DEFAULT_PARAMS and params==[]:
            if not messagebox.askyesno('Parámetros sin verificar',
                 f'No hay parámetros predeterminados documentados para {c.title}. ¿Insertar realmente []?'):
                raise ValueError('Inserción cancelada.')
        return [{'code':c.code,'indent':0,'parameters':params}]

    def insert_library(self):
        try:self.insert_commands(self.current_native_insertion())
        except Exception as e:self.error(str(e))

    def use_event_example(self):
        if not self.selected_cmd or self.selected_cmd[0]!='native':return
        code=self.selected_cmd[1].code
        samples=[c for c in self.page_commands if c['code']==code]
        if not samples:
            messagebox.showinfo('Sin muestras',f'No hay comandos {code} en la página abierta.');return
        self.set_text(self.lib_editor,as_json(samples[0]['parameters']))
        self.set_status(f'Muestra del comando {code} extraída del evento abierto.')

    def build_wizards(self):
        tab=ttk.Frame(self.tabs)
        self.tabs.add(tab,text='  Asistentes rápidos  ')
        f=ttk.Frame(tab)
        f.pack(fill='both',expand=True,padx=22,pady=14)
        ttk.Label(f,text='Crear comandos sin escribir parámetros JSON',style='Title.TLabel').pack(anchor='w')
        ttk.Label(f,text='Los asistentes generan datos nativos de RPG Maker XP. Los parámetros no disponibles siguen accesibles desde la Enciclopedia.',
                  style='Hint.TLabel').pack(anchor='w',pady=(5,12))
        top=ttk.Frame(f)
        top.pack(fill='x',pady=(0,8))
        self.wizard_kind=tk.StringVar(value='Esperar')
        choices=ttk.Combobox(top,textvariable=self.wizard_kind,state='readonly',values=list(WIZARDS),width=49)
        choices.pack(side='left')
        choices.bind('<<ComboboxSelected>>',lambda _:self.refresh_wizard())
        ttk.Button(top,text='Generar',command=self.preview_wizard).pack(side='left',padx=10)
        self.wizard_fields=ttk.Frame(f)
        self.wizard_fields.pack(fill='x',pady=(0,8))
        self.wizard_values={}
        ttk.Label(f,text='Comandos resultantes',style='Hint.TLabel').pack(anchor='w',pady=5)
        self.wizard_preview=self.textbox(f,height=16)
        self.wizard_preview.pack(fill='both',expand=True,pady=(0,10))
        b=ttk.Frame(f)
        b.pack(fill='x')
        ttk.Button(b,text='Copiar JSON',command=self.copy_wizard).pack(side='left')
        ttk.Button(b,text='Insertar en evento',style='Accent.TButton',
                   command=lambda:self.safe_insert(self.get_wizard)).pack(side='left',padx=8)
        self.refresh_wizard()

    def refresh_wizard(self):
        for child in self.wizard_fields.winfo_children():child.destroy()
        self.wizard_values={}
        fields=WIZARDS[self.wizard_kind.get()]
        for index,field in enumerate(fields):
            row=ttk.Frame(self.wizard_fields)
            row.pack(fill='x',pady=3)
            ttk.Label(row,text=field.name,width=43).pack(side='left')
            value=tk.StringVar(value=field.default)
            self.wizard_values[field.name]=value
            if field.options:
                widget=ttk.Combobox(row,textvariable=value,values=field.options,state='readonly',width=45)
            else:
                widget=ttk.Entry(row,textvariable=value,width=47)
            widget.pack(side='left',padx=5,fill='x',expand=True)
        self.preview_wizard()

    def get_wizard(self):
        data={key:val.get() for key,val in self.wizard_values.items()}
        return wizard_build(self.wizard_kind.get(),data)

    def preview_wizard(self):
        try:
            self.set_text(self.wizard_preview,as_json(self.get_wizard()))
        except Exception as e:self.set_text(self.wizard_preview,'ERROR: '+str(e))

    def copy_wizard(self):
        try:self.copy(as_json(self.get_wizard()))
        except Exception as e:self.error(str(e))

    def build_text(self):
        tab=ttk.Frame(self.tabs)
        self.tabs.add(tab,text='  Text Studio  ')
        wrap=ttk.Frame(tab)
        wrap.pack(fill='both',expand=True,padx=18,pady=15)
        ttk.Label(wrap,text='Editor de mensajes',style='Title.TLabel').pack(anchor='w',pady=(0,4))
        ttk.Label(wrap,text='Genera comandos 101/401 con grupos de 4 líneas. Los códigos de texto dependen de la versión de Essentials.',
                  style='Hint.TLabel').pack(anchor='w',pady=(0,13))
        self.text_body=self.textbox(wrap,height=17)
        self.text_body.pack(fill='both',expand=True)
        self.set_text(self.text_body,'¡Hola, \\PN!\nBienvenido a nuestra región.')
        b=ttk.Frame(wrap)
        b.pack(fill='x',pady=10)
        for name,code in [('Jugador','\\PN'),('Variable','\\v[1]'),('Color','\\c[2]'),('Pausa','\\wt[10]'),('Dinero','\\PM')]:
            ttk.Button(b,text=name,command=lambda value=code:self.text_body.insert('insert',value)).pack(side='left',padx=(0,5))
        self.text_preview=self.textbox(wrap,height=9)
        self.text_preview.pack(fill='both',expand=False,pady=(2,8))
        self.text_body.bind('<<Modified>>',self.update_text_preview)
        a=ttk.Frame(wrap)
        a.pack(fill='x')
        ttk.Button(a,text='Actualizar vista de comandos',command=self.update_text_preview).pack(side='left')
        ttk.Button(a,text='Copiar mensaje',command=lambda:self.copy(self.get_text(self.text_body))).pack(side='left',padx=7)
        ttk.Button(a,text='Insertar en evento',style='Accent.TButton',command=lambda:self.safe_insert(lambda:message_commands(self.get_text(self.text_body)))).pack(side='left')
        self.update_text_preview()

    def update_text_preview(self,*_):
        cmd=message_commands(self.get_text(self.text_body))
        self.set_text(self.text_preview,'\n'.join(f'{c["code"]}  {c["parameters"][0]}' for c in cmd))
        self.text_body.edit_modified(False)

    def build_scripts(self):
        tab=ttk.Frame(self.tabs)
        self.tabs.add(tab,text='  Script Studio  ')
        top=ttk.Frame(tab)
        top.pack(fill='x',padx=14,pady=12)
        ttk.Label(top,text='Explorador de métodos Ruby',style='Title.TLabel').pack(side='left')
        ttk.Button(top,text='Indexar scripts del proyecto',style='Accent.TButton',command=self.scan_scripts).pack(side='right')
        mid=ttk.Panedwindow(tab,orient='horizontal')
        mid.pack(fill='both',expand=True,padx=12,pady=6)
        left=ttk.Frame(mid)
        right=ttk.Frame(mid)
        mid.add(left,weight=2)
        mid.add(right,weight=3)
        self.script_q=tk.StringVar()
        ttk.Entry(left,textvariable=self.script_q).pack(fill='x',pady=(0,7))
        self.method_tree=ttk.Treeview(left,columns=('name','args','source'),show='headings')
        for label,w in [('name',190),('args',165),('source',260)]:
            self.method_tree.heading(label,text={'name':'Método','args':'Parámetros','source':'Archivo'}[label])
            self.method_tree.column(label,width=w)
        self.method_tree.pack(fill='both',expand=True)
        self.script_q.trace_add('write',lambda *_:self.show_methods())
        self.method_tree.bind('<<TreeviewSelect>>',self.select_method)
        ttk.Label(right,text='Script para insertar',style='Title.TLabel').pack(anchor='w',padx=10,pady=(0,9))
        self.script_body=self.textbox(right,height=20)
        self.script_body.pack(fill='both',expand=True,padx=10)
        self.set_text(self.script_body,'pbAddPokemon(:RIOLU, 5)')
        ttk.Label(right,text='El índice encuentra declaraciones def; no prueba que puedan invocarse directamente.\nVerifica el receptor, argumentos y contexto antes de insertar.',
                  style='Hint.TLabel',wraplength=530).pack(fill='x',padx=10,pady=7)
        buttons=ttk.Frame(right)
        buttons.pack(fill='x',padx=10,pady=7)
        ttk.Button(buttons,text='Copiar Ruby',command=lambda:self.copy(self.get_text(self.script_body))).pack(side='left')
        ttk.Button(buttons,text='Insertar en evento',style='Accent.TButton',
                   command=lambda:self.safe_insert(lambda:script_commands(self.get_text(self.script_body)))).pack(side='left',padx=7)

    def scan_scripts(self):
        if not self.project.get():
            self.error('Primero abre el proyecto.');return
        self.set_status('Indexando scripts Ruby...')
        self.update_idletasks()
        try:
            result=self.bridge('index')
            self.method_items=result['methods']
            self.show_methods()
            self.set_status(f'{len(self.method_items)} declaraciones encontradas en scripts y plugins.')
        except Exception as e:self.error(str(e))

    def show_methods(self):
        self.method_tree.delete(*self.method_tree.get_children())
        q=self.script_q.get().casefold().strip()
        shown=0
        for idx,m in enumerate(self.method_items):
            if q and q not in f"{m['name']} {m['args']} {m['source']}".casefold():continue
            self.method_tree.insert('','end',iid=str(idx),values=(m['name'],m['args'],m['source']))
            shown+=1
            if shown>=5000:break

    def select_method(self,*_):
        sel=self.method_tree.selection()
        if not sel:return
        m=self.method_items[int(sel[0])]
        self.set_text(self.script_body,f'# Fuente: {m["source"]}:{m["line"]}\n# Comprueba contexto y argumentos de este método.\n{m["name"]}()')

    def build_blocks(self):
        tab=ttk.Frame(self.tabs)
        self.tabs.add(tab,text='  Constructor de bloques  ')
        f=ttk.Frame(tab)
        f.pack(fill='both',expand=True,padx=22,pady=15)
        ttk.Label(f,text='Eventos completos y estructuras seguras',style='Title.TLabel').pack(anchor='w')
        ttk.Label(f,text='Genera bloques con la indentación y marcadores de cierre propios de RPG Maker XP.',
                  style='Hint.TLabel').pack(anchor='w',pady=(6,12))
        control=ttk.Frame(f)
        control.pack(fill='x',pady=6)
        self.block_type=tk.StringVar(value='Condición con Else')
        cb=ttk.Combobox(control,state='readonly',textvariable=self.block_type,values=[
            'Condición con Else','Elecciones','Bucle','Entrenador Essentials','Obtener Pokémon','Recibir objeto'],width=32)
        cb.pack(side='left')
        cb.bind('<<ComboboxSelected>>',lambda _:self.reset_block_fields())
        ttk.Label(f,text='Campo principal: condición Ruby, opciones (una por línea) o argumentos:').pack(anchor='w',pady=(8,3))
        self.block_a=self.textbox(f,height=6)
        self.block_a.pack(fill='x')
        ttk.Label(f,text='Texto que se muestra si se cumple (solo condiciones):').pack(anchor='w',pady=(8,3))
        self.block_b=self.textbox(f,height=3)
        self.block_b.pack(fill='x')
        ttk.Label(f,text='Vista previa de comandos',style='Hint.TLabel').pack(anchor='w',pady=(10,4))
        self.block_preview=self.textbox(f,height=13)
        self.block_preview.pack(fill='both',expand=True)
        b=ttk.Frame(f)
        b.pack(fill='x',pady=10)
        ttk.Button(b,text='Generar vista previa',command=self.preview_block).pack(side='left')
        ttk.Button(b,text='Copiar JSON de bloque',command=self.copy_block).pack(side='left',padx=8)
        ttk.Button(b,text='Insertar bloque',style='Accent.TButton',command=lambda:self.safe_insert(self.get_block)).pack(side='left')
        self.reset_block_fields()

    def reset_block_fields(self):
        kind=self.block_type.get()
        sample={'Condición con Else':('$game_switches[25]','¡Hola!'),
                'Elecciones':('Sí\nNo',''), 'Bucle':('',''),
                'Entrenador Essentials':('TrainerBattle.start(:YOUNGSTER, "Luis")','¡Bien hecho!'),
                'Obtener Pokémon':(':RIOLU, 5',''), 'Recibir objeto':(':POTION, 1','')}[kind]
        self.set_text(self.block_a,sample[0])
        self.set_text(self.block_b,sample[1])
        self.preview_block()

    def get_block(self):return make_block(self.block_type.get(),self.get_text(self.block_a).strip(),self.get_text(self.block_b).strip())

    def preview_block(self):
        try:
            block=self.get_block()
            out='\n'.join('  '*c['indent']+f"[{c['code']}] {format_cmd(c)[0]}  {format_cmd(c)[1]}" for c in block)
            self.set_text(self.block_preview,out)
        except Exception as e:self.set_text(self.block_preview,'ERROR: '+str(e))

    def copy_block(self):
        try:self.copy(as_json(self.get_block()))
        except Exception as e:self.error(str(e))

    def build_events(self):
        tab=ttk.Frame(self.tabs)
        self.tabs.add(tab,text='  Eventos del proyecto  ')
        nav=ttk.Frame(tab)
        nav.pack(fill='x',padx=12,pady=(10,5))
        ttk.Label(nav,text='Mapa').pack(side='left')
        self.map_choice=ttk.Combobox(nav,width=43,state='readonly')
        self.map_choice.pack(side='left',padx=6)
        self.map_choice.bind('<<ComboboxSelected>>',self.select_map)
        ttk.Label(nav,text='Página').pack(side='left',padx=(12,0))
        self.page_choice=ttk.Combobox(nav,width=6,state='readonly')
        self.page_choice.pack(side='left',padx=6)
        self.page_choice.bind('<<ComboboxSelected>>',self.select_page)
        ttk.Button(nav,text='Actualizar',command=self.reload_project).pack(side='left',padx=(6,15))
        ttk.Label(nav,text='Insertar:').pack(side='left')
        ttk.Combobox(nav,textvariable=self.save_position,state='readonly',
            values=['Final de la página','Antes del seleccionado'],width=25).pack(side='left',padx=6)
        pane=ttk.Panedwindow(tab,orient='horizontal')
        pane.pack(fill='both',expand=True,padx=10,pady=10)
        col1=ttk.Frame(pane); col2=ttk.Frame(pane); col3=ttk.Frame(pane)
        pane.add(col1,weight=1);pane.add(col2,weight=3);pane.add(col3,weight=3)
        ttk.Label(col1,text='Eventos').pack(anchor='w',pady=(0,6))
        self.events_tree=ttk.Treeview(col1,columns=('id','name'),show='headings')
        self.events_tree.heading('id',text='ID');self.events_tree.column('id',width=45,stretch=False)
        self.events_tree.heading('name',text='Nombre');self.events_tree.column('name',width=190)
        self.events_tree.pack(fill='both',expand=True)
        self.events_tree.bind('<<TreeviewSelect>>',self.select_event)
        ttk.Label(col2,text='Comandos de la página').pack(anchor='w',pady=(0,6))
        self.event_cmd_tree=ttk.Treeview(col2,columns=('id','code','label','summary'),show='headings')
        for col,title,width in [('id','#',37),('code','Cód.',45),('label','Comando',180),('summary','Parámetros',265)]:
            self.event_cmd_tree.heading(col,text=title)
            self.event_cmd_tree.column(col,width=width,stretch=(col!='id'))
        self.event_cmd_tree.pack(fill='both',expand=True)
        self.event_cmd_tree.bind('<<TreeviewSelect>>',self.select_command)
        ttk.Label(col3,text='Parámetros del comando seleccionado (JSON)').pack(anchor='w',pady=(0,6))
        self.event_edit=self.textbox(col3,height=21)
        self.event_edit.pack(fill='both',expand=True)
        b=ttk.Frame(col3)
        b.pack(fill='x',pady=8)
        ttk.Button(b,text='Guardar parámetros',style='Accent.TButton',command=self.replace_selected).pack(side='left',padx=(0,5))
        ttk.Button(b,text='Duplicar',command=self.duplicate_selected).pack(side='left',padx=5)
        ttk.Button(b,text='Borrar',command=self.delete_selected).pack(side='left',padx=5)
        ttk.Label(col3,text='Los cambios se guardan únicamente al confirmar. Cada guardado genera respaldo en Data/CommandStudioBackups.\nNo editar estructuras parciales (elecciones, condiciones o bucles).',
                  style='Hint.TLabel',wraplength=390).pack(anchor='w',pady=(6,0))

    def open_project(self):
        d=filedialog.askdirectory(title='Selecciona la carpeta raíz del proyecto RPG Maker XP')
        if not d:return
        self.project.set(d)
        self.reload_project()

    def bridge(self,action,**kwargs):
        if not self.project.get():raise ValueError('Abre primero la carpeta del proyecto RPG Maker XP.')
        ruby=self.ruby.get().strip()
        if not ruby:raise ValueError('Indica la ruta de ruby.exe.')
        request={'action':action,'project':self.project.get(),**kwargs}
        startinfo={}
        if os.name=='nt':startinfo['creationflags']=subprocess.CREATE_NO_WINDOW
        try:
            completed=subprocess.run([ruby,str(HERE/'rmxp_bridge.rb')],input=json.dumps(request,ensure_ascii=False),
                     capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60,**startinfo)
        except FileNotFoundError:
            raise RuntimeError('No encuentro Ruby. Instala Ruby 3 y escribe la ruta de ruby.exe en la barra superior.')
        except subprocess.TimeoutExpired:raise RuntimeError('La operación tardó demasiado. No se ha confirmado ningún guardado.')
        try:r=json.loads(completed.stdout)
        except json.JSONDecodeError:
            raise RuntimeError('La herramienta Ruby no respondió correctamente. '+completed.stderr[-700:])
        if not r.get('ok'):raise RuntimeError(r.get('error','Error desconocido'))
        return r

    def reload_project(self):
        try:
            self.map_info=self.bridge('maps')['maps']
            self.map_choice['values']=[f"{m['id']:03d} · {m['name']}" for m in self.map_info]
            self.map_id=None
            self.events_tree.delete(*self.events_tree.get_children())
            self.event_cmd_tree.delete(*self.event_cmd_tree.get_children())
            if self.map_info:
                self.map_choice.current(0)
                self.select_map()
            self.set_status(f'{len(self.map_info)} mapas detectados en el proyecto.')
        except Exception as e:self.error(str(e))

    def select_map(self,*_):
        ix=self.map_choice.current()
        if ix<0:return
        self.map_id=self.map_info[ix]['id']
        try:
            self.events=self.bridge('events',map_id=self.map_id)['events']
            self.events_tree.delete(*self.events_tree.get_children())
            self.page_choice.set('')
            self.event_cmd_tree.delete(*self.event_cmd_tree.get_children())
            self.event_id=None
            for ev in self.events:
                self.events_tree.insert('', 'end',iid=str(ev['id']),values=(ev['id'],ev['name']))
            if self.events:
                self.events_tree.selection_set(str(self.events[0]['id']))
                self.select_event()
        except Exception as e:self.error(str(e))

    def select_event(self,*_):
        sel=self.events_tree.selection()
        if not sel:return
        self.event_id=int(sel[0])
        ev=next((x for x in self.events if x['id']==self.event_id),None)
        if ev is None:return
        self.page_choice['values']=[str(i) for i in range(1,ev['pages']+1)]
        if ev['pages']:
            self.page_choice.current(0)
            self.select_page()
        else:self.page_commands=[];self.event_cmd_tree.delete(*self.event_cmd_tree.get_children())

    def select_page(self,*_):
        if self.event_id is None:return
        ix=self.page_choice.current()
        if ix<0:return
        self.page_num=ix
        try:
            self.page_commands=self.bridge('page',map_id=self.map_id,event_id=self.event_id,page_index=ix)['commands']
            self.event_cmd_tree.delete(*self.event_cmd_tree.get_children())
            for i,c in enumerate(self.page_commands):
                label,preview=format_cmd(c)
                self.event_cmd_tree.insert('','end',iid=str(i),values=(i,c['code'],('·  '*c['indent'])+label,preview))
            self.set_status(f'Mapa {self.map_id} · evento {self.event_id} · página {ix+1} · {len(self.page_commands)} comandos.')
        except Exception as e:self.error(str(e))

    def select_command(self,*_):
        sel=self.event_cmd_tree.selection()
        if not sel:return
        cmd=self.page_commands[int(sel[0])]
        self.set_text(self.event_edit,as_json(cmd['parameters']))

    def position(self):
        if self.save_position.get()=='Final de la página':
            return max(0,len(self.page_commands)-1),0
        sel=self.event_cmd_tree.selection()
        if not sel:raise ValueError('Selecciona una fila del evento para insertar antes de ella.')
        index=int(sel[0]); existing=self.page_commands[index]
        # To avoid breaking continuations, only allow insertion before
        # the start of a logical unit, not inside an existing multi-line script/text.
        if existing['code'] in {401,402,403,404,408,411,412,413,509,601,602,603,604,605,655}:
            raise ValueError('No se puede insertar dentro de una continuación o marcador de bloque. Elige su inicio o el final.')
        return index,existing['indent']

    def insert_commands(self,cmds):
        if self.event_id is None:raise ValueError('Selecciona un mapa, un evento y una página antes de insertar.')
        pos,base=self.position()
        if any(c['code']==0 for c in cmds):raise ValueError('No insertes el marcador de fin 0 manualmente.')
        commands=copy.deepcopy(cmds)
        for c in commands:c['indent']+=base
        result=self.bridge('modify',map_id=self.map_id,event_id=self.event_id,page_index=self.page_num,
                           operation='insert',position=pos,commands=commands)
        self.select_page()
        self.set_status(f'Insertados {len(commands)} comandos. Respaldo: {Path(result["backup"]).name}')
        messagebox.showinfo('Guardado',f'Se insertaron {len(commands)} comandos.\nRespaldo: {result["backup"]}')

    def safe_insert(self,maker):
        try:self.insert_commands(maker())
        except Exception as e:self.error(str(e))

    def do_mod(self,op,**extra):
        sel=self.event_cmd_tree.selection()
        if not sel:raise ValueError('Selecciona un comando de la página.')
        at=int(sel[0])
        cmd=self.page_commands[at]
        if op in ('delete','duplicate') and not messagebox.askyesno('Confirmar',f'{op.title()} comando {at}: {format_cmd(cmd)[0]}?'):
            return
        result=self.bridge('modify',map_id=self.map_id,event_id=self.event_id,page_index=self.page_num,
                           operation=op,position=at,**extra)
        self.select_page()
        self.set_status(f'Cambios guardados. Respaldo: {Path(result["backup"]).name}')

    def replace_selected(self):
        try:
            sel=self.event_cmd_tree.selection()
            if not sel:raise ValueError('Selecciona un comando.')
            old=self.page_commands[int(sel[0])]
            val=json.loads(self.get_text(self.event_edit))
            if not isinstance(val,list):raise ValueError('Los parámetros deben ser una lista JSON.')
            if not messagebox.askyesno('Guardar parámetros',f'¿Sobrescribir los parámetros del comando {old["code"]}?'):
                return
            self.do_mod('replace',command={'code':old['code'],'parameters':val})
        except Exception as e:self.error(str(e))

    def duplicate_selected(self):
        try:self.do_mod('duplicate')
        except Exception as e:self.error(str(e))

    def delete_selected(self):
        try:self.do_mod('delete')
        except Exception as e:self.error(str(e))

    def build_footer(self):
        f=ttk.Frame(self)
        f.pack(fill='x',padx=17,pady=(2,12))
        ttk.Label(f,textvariable=self.status,style='Hint.TLabel').pack(side='left')
        ttk.Label(f,text='BACKUP AUTOMÁTICO · SIN DEPENDENCIAS PYTHON EXTERNAS',style='Hint.TLabel').pack(side='right')

    def set_status(self,text):self.status.set(text)
    def error(self,text):
        self.set_status('Error: '+text)
        messagebox.showerror('Command Studio',text)

if __name__=='__main__':
    CommandStudio().mainloop()
