# encoding: UTF-8
# Command Studio external-only Ruby bridge. Never load this file in RGSS/RPG Maker XP.
require 'json'
require 'zlib'
require 'fileutils'
require 'time'

# Marshal.load needs the Ruby classes referenced by the original project.
# Dynamic creation is limited to the RPG namespace. We keep every untouched
# object in memory so events may be edited without reconstructing map tables.
module RPG
  module AutoClass
    def const_missing(name)
      klass = Class.new
      klass.extend(RPG::AutoClass)
      const_set(name, klass)
    end
  end
  extend AutoClass
end

# Marshal.load resolves class paths internally without calling const_missing;
# predeclare known RPG Maker XP classes and nested types.
%w[
 Map MapInfo Event Event::Page Event::Page::Condition Event::Page::Graphic
 EventCommand MoveCommand MoveRoute AudioFile System System::Words
 Actor Class Skill Item Weapon Armor Enemy Troop Troop::Page Troop::Page::Condition
 State Animation Animation::Frame Animation::Timing Tileset CommonEvent
].each do |path|
  scope=RPG
  path.split('::').each { |piece| scope=scope.const_get(piece) }
end

['Table', 'Color', 'Tone'].each do |name|
  Object.const_set(name, Class.new do
    def self._load(bytes)
      obj = allocate
      obj.instance_variable_set(:@raw_commandstudio_bytes, bytes)
      obj
    end
    def _dump(_level)
      @raw_commandstudio_bytes
    end
  end)
end

# Scripts can reference custom classes from plugins. Never guess their
# definitions when writing: error out rather than corrupting the project.
def load_rxdata(file)
  Marshal.load(File.binread(file))
rescue ArgumentError, NameError, TypeError => e
  raise "No se pudo abrir #{File.basename(file)}: #{e.message}. Este proyecto puede incluir clases personalizadas."
end

def json_text(obj)
  bytes=obj.to_s.dup
  utf=bytes.dup.force_encoding(Encoding::UTF_8)
  return utf if utf.valid_encoding?
  # Classic XP projects may hold messages as Windows-1252 bytes.
  bytes.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8,
    invalid: :replace, undef: :replace)
rescue
  obj.to_s.dup.force_encoding(Encoding::UTF_8).scrub
end

def encode_param(obj, depth=0)
  return '(anidación excesiva)' if depth > 20
  case obj
  when NilClass, TrueClass, FalseClass, Integer, Float then obj
  when String then json_text(obj)
  when Symbol then { '__symbol' => obj.to_s }
  when Array then obj.map { |a| encode_param(a,depth+1) }
  when Hash then obj.map { |k,v| [encode_param(k,depth+1),encode_param(v,depth+1)] }.to_h
  else
    case obj.class.name
    when 'Tone','Color'
      bytes = obj.instance_variable_get(:@raw_commandstudio_bytes)
      { '__class'=>obj.class.name, 'values'=> bytes.unpack('E4') }
    when 'Table'
      { '__class'=>'Table', 'description'=>'datos binarios (no editables)' }
    else
      iv = {}
      obj.instance_variables.each do |key|
        iv[key.to_s.sub(/^@/,'')] = encode_param(obj.instance_variable_get(key),depth+1)
      end
      { '__class'=>obj.class.name, **iv }
    end
  end
end

def decode_param(value)
  case value
  when Array then value.map { |x| decode_param(x) }
  when Hash
    if value.key?('__symbol')
      value.fetch('__symbol').to_sym
    elsif value.key?('__class')
      name=value.fetch('__class')
      if ['Tone','Color'].include?(name)
        arr = value.fetch('values')
        raise 'Color/Tone requiere 4 componentes numéricos' unless arr.is_a?(Array) && arr.size==4 && arr.all? { |v| v.is_a?(Numeric) }
        obj = Object.const_get(name)._load(arr.map(&:to_f).pack('E4'))
        return obj
      end
      raise "Clase no permitida: #{name}" unless name.match?(/\ARPG::[A-Za-z][A-Za-z0-9_]*\z/)
      klass = RPG.const_get(name.sub('RPG::',''))
      inst=klass.allocate
      value.each do |key,v|
        next if key=='__class'
        raise 'Atributo de clase inválido' unless key.match?(/\A[A-Za-z][A-Za-z0-9_]*\z/)
        inst.instance_variable_set("@#{key}",decode_param(v))
      end
      inst
    else
      value.each_with_object({}) { |(k,v),h| h[k.dup.force_encoding(Encoding::BINARY)] = decode_param(v) }
    end
  when String then value.dup.force_encoding(Encoding::BINARY)
  when NilClass, TrueClass, FalseClass, Integer, Float then value
  else raise 'Tipo JSON no permitido'
  end
end

def get_data_dir(project)
  path=File.expand_path(project)
  data=File.join(path,'Data')
  raise 'Elige la carpeta principal del proyecto, que contiene Data/' unless File.directory?(data)
  data
end

def map_file(data,id)
  id=Integer(id)
  raise 'ID de mapa fuera de rango' unless id>=1 && id<=999
  path=File.join(data,format('Map%03d.rxdata',id))
  raise "No existe #{File.basename(path)}" unless File.file?(path)
  path
end

def event_command(code,indent,params)
  x=RPG.const_get(:EventCommand).allocate
  x.instance_variable_set(:@code,code)
  x.instance_variable_set(:@indent,indent)
  x.instance_variable_set(:@parameters,params)
  x
end

def commands_of(page)
  page.instance_variable_get(:@list) || []
end

def describe_command(cmd)
  { 'code'=>cmd.instance_variable_get(:@code),
    'indent'=>cmd.instance_variable_get(:@indent),
    'parameters'=>encode_param(cmd.instance_variable_get(:@parameters)) }
end

def events_map(map)
  map.instance_variable_get(:@events) || {}
end

def overview(data)
  infos=File.join(data,'MapInfos.rxdata')
  names = File.file?(infos) ? load_rxdata(infos) : {}
  Dir.glob(File.join(data,'Map[0-9][0-9][0-9].rxdata')).sort.map do |f|
    id=File.basename(f)[3,3].to_i
    info=names[id]
    {'id'=>id,'name'=>info ? json_text(info.instance_variable_get(:@name)) : "Mapa #{id}"}
  end
end

def get_event_list(data,id)
  map=load_rxdata(map_file(data,id))
  events_map(map).sort_by { |eid,_| eid }.map do |eid,ev|
    pages=(ev.instance_variable_get(:@pages)||[])
    {'id'=>eid,'name'=>json_text(ev.instance_variable_get(:@name)),
     'x'=>ev.instance_variable_get(:@x), 'y'=>ev.instance_variable_get(:@y),
     'pages'=>pages.size}
  end
end

def get_page(data,id,event_id,page_i)
  map=load_rxdata(map_file(data,id))
  ev=events_map(map)[Integer(event_id)]
  raise 'Evento no encontrado' unless ev
  page=(ev.instance_variable_get(:@pages)||[])[Integer(page_i)]
  raise 'Página no encontrada' unless page
  {'commands'=>commands_of(page).map { |cmd| describe_command(cmd) }}
end

def save_map(data,id,map)
  target=map_file(data,id)
  backup_dir=File.join(data,'CommandStudioBackups')
  FileUtils.mkdir_p(backup_dir)
  stamp=Time.now.strftime('%Y%m%d_%H%M%S_%6N')
  backup=File.join(backup_dir,"#{File.basename(target,'.rxdata')}_#{stamp}.rxdata")
  FileUtils.cp(target,backup)
  serialized=Marshal.dump(map)
  tempfile=target+".commandstudio_#{Process.pid}.tmp"
  begin
    File.binwrite(tempfile,serialized)
    # Verify the newly generated file can at least be unmarshalled.
    Marshal.load(File.binread(tempfile))
    File.rename(tempfile,target)
  ensure
    File.delete(tempfile) if File.exist?(tempfile)
  end
  backup
end

def modify(data,request)
  id=Integer(request.fetch('map_id'))
  map=load_rxdata(map_file(data,id))
  event=events_map(map)[Integer(request.fetch('event_id'))]
  raise 'Evento no encontrado' unless event
  page=(event.instance_variable_get(:@pages)||[])[Integer(request.fetch('page_index'))]
  raise 'Página no encontrada' unless page
  commands=commands_of(page)
  op=request.fetch('operation')
  if op=='insert'
    new_commands=request.fetch('commands').map do |raw|
      code=Integer(raw.fetch('code'))
      indent=Integer(raw.fetch('indent'))
      raise 'Código fuera de rango' unless code.between?(0,9999)
      raise 'Indentación fuera de rango' unless indent.between?(0,60)
      params=decode_param(raw.fetch('parameters'))
      raise 'Parámetros deben ser Array' unless params.is_a?(Array)
      event_command(code,indent,params)
    end
    raise 'Bloque vacío o demasiado grande' unless new_commands.length.between?(1,500)
    at=Integer(request.fetch('position'))
    at=[[at,0].max, commands.size].min
    # Always insert before the sole final terminator.
    if commands.last && commands.last.instance_variable_get(:@code)==0
      at=[at,commands.size-1].min
    end
    commands.insert(at,*new_commands)
  elsif op=='delete'
    at=Integer(request.fetch('position'))
    raise 'Comando inválido' unless at.between?(0,commands.size-1)
    code=commands[at].instance_variable_get(:@code)
    raise 'No se puede borrar el terminador final' if code==0 && at==commands.size-1
    # Avoid silently breaking branch structures.
    raise 'No se permite borrar marcadores estructurales aislados' if [102,111,112,301,402,403,404,411,412,413,601,602,603,604].include?(code)
    commands.delete_at(at)
  elsif op=='duplicate'
    at=Integer(request.fetch('position'))
    raise 'Comando inválido' unless at.between?(0,commands.size-1)
    code=commands[at].instance_variable_get(:@code)
    raise 'No se puede duplicar un marcador de estructura/continuación aislado' if [0,101,102,111,112,209,301,401,402,403,404,411,412,413,509,601,602,603,604,655].include?(code)
    commands.insert(at+1,Marshal.load(Marshal.dump(commands[at])))
  elsif op=='replace'
    at=Integer(request.fetch('position'))
    raise 'Comando inválido' unless at.between?(0,commands.size-1)
    old=commands[at]
    code=old.instance_variable_get(:@code)
    raise 'Para editar estructuras, usa plantillas completas' if [0,102,111,112,301,402,403,404,411,412,413,601,602,603,604].include?(code)
    raw=request.fetch('command')
    new_code=Integer(raw.fetch('code'))
    raise 'No se puede cambiar el tipo de comando aquí' unless new_code==code
    params=decode_param(raw.fetch('parameters'))
    raise 'Parámetros deben ser una lista' unless params.is_a?(Array)
    old.instance_variable_set(:@parameters,params)
  else
    raise "Operación no soportada: #{op}"
  end
  # XP commands must have one final end marker.
  commands << event_command(0,0,[]) if commands.empty? || commands.last.instance_variable_get(:@code)!=0
  page.instance_variable_set(:@list,commands)
  {'backup'=>save_map(data,id,map),'commands'=>commands.size}
end

def index_scripts(data,project)
  entries=[]
  files=Dir.glob(File.join(project,'**','*.rb'),File::FNM_CASEFOLD)
  files.reject! { |f| f.include?('CommandStudioBackups') || f.include?('.git') }
  files.first(15000).each do |f|
    next unless File.file?(f) && File.size(f) < 2_500_000
    begin
      parse_methods(File.binread(f),f.delete_prefix(project+File::SEPARATOR),entries)
    rescue => e
      next
    end
  end
  scripts=File.join(data,'Scripts.rxdata')
  if File.file?(scripts)
    begin
      load_rxdata(scripts).each do |line|
        next unless line.is_a?(Array) && line.size>=3
        begin
          source=Zlib::Inflate.inflate(line[2])
          parse_methods(source,"Scripts.rxdata / #{json_text(line[1])}",entries)
        rescue Zlib::Error
        end
      end
    rescue => e
      # Some Essentials builds use loose scripts only.
    end
  end
  entries.uniq { |x| [x['source'],x['name'],x['line']] }.first(65000)
end

def parse_methods(src,file,out)
  src.force_encoding('UTF-8').scrub.each_line.with_index(1) do |line,num|
    m=line.match(/^\s*def\s+(?:(?:self|[A-Za-z_]\w*)\.)?([a-zA-Z_]\w*[!?=]?)\s*(?:\(([^)]*)\)|([^#\n]*))/)
    next unless m
    name=m[1]
    args=(m[2] || m[3] || '').strip
    next if name=='initialize' || name.start_with?('__')
    out << {'name'=>name,'args'=>args[0,160],'source'=>file,'line'=>num} if out.size < 70000
  end
end

def main
  req=JSON.parse(STDIN.read)
  project=File.expand_path(req.fetch('project'))
  data=get_data_dir(project)
  result=case req.fetch('action')
  when 'maps' then {'maps'=>overview(data)}
  when 'events' then {'events'=>get_event_list(data,req.fetch('map_id'))}
  when 'page' then get_page(data,req.fetch('map_id'),req.fetch('event_id'),req.fetch('page_index'))
  when 'modify' then modify(data,req)
  when 'index' then {'methods'=>index_scripts(data,project)}
  else raise 'Acción desconocida'
  end
  STDOUT.write(JSON.generate({'ok'=>true,**result}))
rescue Exception => e
  STDERR.puts(e.full_message(highlight:false)) if ENV['COMMAND_STUDIO_DEBUG']=='1'
  STDOUT.write(JSON.generate({'ok'=>false,'error'=>json_text(e.message)}))
  exit 2
end
main
