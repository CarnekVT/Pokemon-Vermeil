#===============================================================================
# Mystery Gift system
# By Maruno
#===============================================================================
# This url is the location of an example Mystery Gift file.
# You should change it to your file's url once you upload it.
#===============================================================================
module MysteryGift
  URL = "https://pastebin.com/raw/tupastebin"   # Cambia esta URL por la de tu archivo de regalos misteriosos
  TYPE_POKEMON         = 0
  TYPE_ITEM_BUNDLE     = -1   # gift[2] = [[item_id, qty], ...]
  TYPE_POKEMON_BUNDLE  = -2   # gift[2] = [Pokemon, ...]
  TYPE_MIXED_BUNDLE    = -3   # gift[2] = { items: [[item_id, qty], ...], pokemon: [Pokemon, ...] }
end

#===============================================================================
# Creating a new Mystery Gift for the Master file, and editing an existing one.
#===============================================================================
# type: 0=Pokémon; -1=objetos; -2=Pokémon múltiples; -3=mixto; >0=item único (cantidad).
def pbMysteryGiftNormalizeMixedContent(content)
  return { items: [], pokemon: [] } if !content.is_a?(Hash)
  items = content[:items] || content["items"] || []
  pokemon = content[:pokemon] || content["pokemon"] || []
  return { items: items, pokemon: pokemon }
end

def pbMysteryGiftAvailablePokemonSlots
  slots = Settings::MAX_PARTY_SIZE - $player.party_count
  slots = 0 if slots < 0
  $PokemonStorage.boxes.each do |box|
    box.length.times { |i| slots += 1 if box[i].nil? }
  end
  return slots
end

def pbMysteryGiftCanStorePokemonCount?(count)
  return false if !count.is_a?(Integer) || count <= 0
  return pbMysteryGiftAvailablePokemonSlots >= count
end
def pbMysteryGiftContentSummary(gift)
  return "???" if !gift.is_a?(Array) || gift.length < 3
  if gift[2].is_a?(Pokemon)
    return gift[2].speciesName
  elsif gift[1] == MysteryGift::TYPE_ITEM_BUNDLE && gift[2].is_a?(Array)
    parts = gift[2].filter_map do |entry|
      next if !entry.is_a?(Array) || entry.length < 2
      item_data = GameData::Item.try_get(entry[0])
      next if !item_data
      _INTL("{1} x{2}", item_data.name, entry[1])
    end
    return parts.join(", ")
  elsif gift[1] == MysteryGift::TYPE_POKEMON_BUNDLE && gift[2].is_a?(Array)
    return gift[2].filter_map { |p| p.speciesName if p.is_a?(Pokemon) }.join(", ")
  elsif gift[1] == MysteryGift::TYPE_MIXED_BUNDLE
    content = pbMysteryGiftNormalizeMixedContent(gift[2])
    parts = []
    content[:items].each do |entry|
      next if !entry.is_a?(Array) || entry.length < 2
      item_data = GameData::Item.try_get(entry[0])
      parts.push(_INTL("{1} x{2}", item_data.name, entry[1])) if item_data
    end
    content[:pokemon].each { |p| parts.push(p.speciesName) if p.is_a?(Pokemon) }
    return parts.join(", ")
  elsif gift[1].is_a?(Integer) && gift[1] > 0
    item_data = GameData::Item.try_get(gift[2])
    return _INTL("{1} x{2}", item_data.name, gift[1]) if item_data
  elsif gift[2].is_a?(Hash)
    return gift[2][:name].to_s
  end
  return "???"
end

def pbMysteryGiftBundlePokemonSummary(pokemon_list)
  return _INTL("(vacío)") if !pokemon_list.is_a?(Array) || pokemon_list.empty?
  return pokemon_list.filter_map { |p| p.name if p.is_a?(Pokemon) }.join("\n")
end

def pbEditMysteryGiftPokemonBundle(pokemon_list)
  pokemon_list = pokemon_list.select { |p| p.is_a?(Pokemon) }.map(&:clone)
  loop do
    summary = pbMysteryGiftBundlePokemonSummary(pokemon_list)
    cmd = pbMessage(
      _INTL("Contenido del paquete:\n{1}", summary),
      [_INTL("Añadir Pokémon"),
       _INTL("Quitar Pokémon"),
       _INTL("Terminar"),
       _INTL("Cancelar")], -1
    )
    case cmd
    when 0
      pkmn = pbChoosePokemonFromPartyOrPC(1, 2, proc { |p| !p.egg? })
      next if !pkmn
      pokemon_list.push(pkmn.clone)
    when 1
      if pokemon_list.empty?
        pbMessage(_INTL("No hay Pokémon en el paquete."))
        next
      end
      remove_cmds = pokemon_list.map.with_index { |p, i| _INTL("{1}: {2}", i + 1, p.name) }
      remove_cmds.push(_INTL("Cancelar"))
      pick = pbMessage(_INTL("¿Qué Pokémon quieres quitar?"), remove_cmds, -1)
      next if pick < 0 || pick >= pokemon_list.length
      pokemon_list.delete_at(pick)
    when 2
      if pokemon_list.empty?
        pbMessage(_INTL("El paquete debe incluir al menos un Pokémon."))
      else
        return pokemon_list
      end
    when 3, -1
      return nil
    end
  end
end

def pbEditMysteryGiftMixedBundle(content)
  content = pbMysteryGiftNormalizeMixedContent(content)
  content[:pokemon] = content[:pokemon].select { |p| p.is_a?(Pokemon) }.map(&:clone)
  content[:items] = content[:items].map { |entry| [entry[0], entry[1]] }
  loop do
    summary = _INTL("Objetos:\n{1}\n\nPokémon:\n{2}",
                    pbMysteryGiftBundleItemsSummary(content[:items]),
                    pbMysteryGiftBundlePokemonSummary(content[:pokemon]))
    cmd = pbMessage(
      summary,
      [_INTL("Añadir objeto"),
       _INTL("Quitar objeto"),
       _INTL("Añadir Pokémon"),
       _INTL("Quitar Pokémon"),
       _INTL("Terminar"),
       _INTL("Cancelar")], -1
    )
    case cmd
    when 0
      new_item = pbChooseItemList
      next if !new_item
      params = ChooseNumberParams.new
      params.setRange(1, Settings::BAG_MAX_PER_SLOT)
      params.setDefaultValue(1)
      params.setCancelValue(0)
      qty = pbMessageChooseNumber(
        _INTL("Elige la cantidad de {1}.", GameData::Item.get(new_item).name), params
      )
      next if qty <= 0
      content[:items].push([new_item, qty])
    when 1
      if content[:items].empty?
        pbMessage(_INTL("No hay objetos en el paquete."))
        next
      end
      remove_cmds = content[:items].map.with_index do |entry, i|
        item_data = GameData::Item.get(entry[0])
        _INTL("{1}: {2} x{3}", i + 1, item_data.name, entry[1])
      end
      remove_cmds.push(_INTL("Cancelar"))
      pick = pbMessage(_INTL("¿Qué objeto quieres quitar?"), remove_cmds, -1)
      next if pick < 0 || pick >= content[:items].length
      content[:items].delete_at(pick)
    when 2
      pkmn = pbChoosePokemonFromPartyOrPC(1, 2, proc { |p| !p.egg? })
      next if !pkmn
      content[:pokemon].push(pkmn.clone)
    when 3
      if content[:pokemon].empty?
        pbMessage(_INTL("No hay Pokémon en el paquete."))
        next
      end
      remove_cmds = content[:pokemon].map.with_index { |p, i| _INTL("{1}: {2}", i + 1, p.name) }
      remove_cmds.push(_INTL("Cancelar"))
      pick = pbMessage(_INTL("¿Qué Pokémon quieres quitar?"), remove_cmds, -1)
      next if pick < 0 || pick >= content[:pokemon].length
      content[:pokemon].delete_at(pick)
    when 4
      if content[:items].empty? && content[:pokemon].empty?
        pbMessage(_INTL("El paquete debe incluir al menos un objeto o un Pokémon."))
      else
        return content
      end
    when 5, -1
      return nil
    end
  end
end

def pbEditMysteryGiftBundleItems(items)
  items = items.map { |entry| [entry[0], entry[1]] }
  loop do
    summary = pbMysteryGiftBundleItemsSummary(items)
    cmd = pbMessage(
      _INTL("Contenido del paquete:\n{1}", summary),
      [_INTL("Añadir objeto"),
       _INTL("Quitar objeto"),
       _INTL("Terminar"),
       _INTL("Cancelar")], -1
    )
    case cmd
    when 0   # Añadir
      new_item = pbChooseItemList
      next if !new_item
      params = ChooseNumberParams.new
      params.setRange(1, Settings::BAG_MAX_PER_SLOT)
      params.setDefaultValue(1)
      params.setCancelValue(0)
      qty = pbMessageChooseNumber(
        _INTL("Elige la cantidad de {1}.", GameData::Item.get(new_item).name), params
      )
      next if qty <= 0
      items.push([new_item, qty])
    when 1   # Quitar
      if items.empty?
        pbMessage(_INTL("No hay objetos en el paquete."))
        next
      end
      remove_cmds = items.map.with_index do |entry, i|
        item_data = GameData::Item.get(entry[0])
        _INTL("{1}: {2} x{3}", i + 1, item_data.name, entry[1])
      end
      remove_cmds.push(_INTL("Cancelar"))
      pick = pbMessage(_INTL("¿Qué objeto quieres quitar?"), remove_cmds, -1)
      next if pick < 0 || pick >= items.length
      items.delete_at(pick)
    when 2   # Terminar
      if items.empty?
        pbMessage(_INTL("El paquete debe incluir al menos un objeto."))
      else
        return items
      end
    when 3, -1
      return nil
    end
  end
end

def pbMysteryGiftBundleItemsSummary(items)
  return _INTL("(vacío)") if !items.is_a?(Array) || items.empty?
  return items.map do |entry|
    item_data = GameData::Item.get(entry[0])
    _INTL("{1} x{2}", item_data.name, entry[1])
  end.join("\n")
end

def pbMysteryGiftAnnounceItem(item, qty)
  itm = GameData::Item.get(item)
  itemname = (qty > 1) ? itm.portion_name_plural : itm.portion_name
  if item == :DNASPLICERS
    pbMessage("\\me[Item get]" + _INTL("¡Has obtenido \\c[1]{1}\\c[0]!", itemname) + "\\wtnp[40]")
  elsif itm.is_machine?
    if qty > 1
      pbMessage("\\me[Machine get]" + _INTL("¡Has obtenido {1} \\c[1]{2} {3}\\c[0]!",
                                            qty, itemname, GameData::Move.get(itm.move).name) + "\\wtnp[70]")
    else
      pbMessage("\\me[Machine get]" + _INTL("¡Has obtenido \\c[1]{1} {2}\\c[0]!", itemname,
                                            GameData::Move.get(itm.move).name) + "\\wtnp[70]")
    end
  elsif qty > 1
    pbMessage("\\me[Item get]" + _INTL("¡Has obtenido {1} \\c[1]{2}\\c[0]!", qty, itemname) + "\\wtnp[40]")
  elsif itemname.starts_with_vowel?
    pbMessage("\\me[Item get]" + _INTL("¡Has obtenido \\c[1]{1}\\c[0]!", itemname) + "\\wtnp[40]")
  else
    pbMessage("\\me[Item get]" + _INTL("¡Has obtenido \\c[1]{1}\\c[0]!", itemname) + "\\wtnp[40]")
  end
end

def pbEditMysteryGift(type, item, id = 0, giftname = "", password = nil)
  begin
    if type == MysteryGift::TYPE_POKEMON   # Pokémon
      commands = [_INTL("Regalo Misterioso"),
                  _INTL("Lugar lejano")]
      commands.push(item.obtain_text) if item.obtain_text && !item.obtain_text.empty?
      commands.push(_INTL("[Custom]"))
      loop do
        command = pbMessage(
          _INTL("Elige una frase sobre el lugar donde se ha obtenido ese Pokémon."),
          commands, -1
        )
        if command < 0
          return nil if pbConfirmMessage(_INTL("¿Dejar de agregar este regalo?"))
        elsif command < commands.length - 1
          item.obtain_text = commands[command]
          break
        elsif command == commands.length - 1
          obtainname = pbMessageFreeText(_INTL("Introduce una frase."), "", false, 30)
          if obtainname != ""
            item.obtain_text = obtainname
            break
          end
          return nil if pbConfirmMessage(_INTL("¿Dejar de agregar este regalo?"))
        end
      end
    elsif type == MysteryGift::TYPE_ITEM_BUNDLE   # Paquete de objetos
      if id != 0 && pbConfirmMessage(_INTL("¿Quieres modificar los objetos del paquete?"))
        item = pbEditMysteryGiftBundleItems(item)
        return nil if !item
      elsif !item.is_a?(Array) || item.empty?
        item = pbEditMysteryGiftBundleItems([])
        return nil if !item
      end
    elsif type == MysteryGift::TYPE_POKEMON_BUNDLE   # Paquete de Pokémon
      if id != 0 && pbConfirmMessage(_INTL("¿Quieres modificar los Pokémon del paquete?"))
        item = pbEditMysteryGiftPokemonBundle(item)
        return nil if !item
      elsif !item.is_a?(Array) || item.empty?
        item = pbEditMysteryGiftPokemonBundle([])
        return nil if !item
      end
    elsif type == MysteryGift::TYPE_MIXED_BUNDLE   # Paquete mixto
      content = pbMysteryGiftNormalizeMixedContent(item)
      if id != 0 && pbConfirmMessage(_INTL("¿Quieres modificar el contenido del paquete?"))
        item = pbEditMysteryGiftMixedBundle(content)
        return nil if !item
      elsif content[:items].empty? && content[:pokemon].empty?
        item = pbEditMysteryGiftMixedBundle({ items: [], pokemon: [] })
        return nil if !item
      else
        item = content
      end
    elsif type > 0   # Item
      params = ChooseNumberParams.new
      params.setRange(1, 99_999)
      params.setDefaultValue(type)
      params.setCancelValue(0)
      loop do
        newtype = pbMessageChooseNumber(_INTL("Elige la cantidad de {1}.",
                                              GameData::Item.get(item).name), params)
        if newtype == 0
          return nil if pbConfirmMessage(_INTL("¿Dejar de editar este regalo?"))
        else
          type = newtype
          break
        end
      end
    end
    if id == 0
      master = []
      idlist = []
      if FileTest.exist?("MysteryGiftMaster.txt")
        master = IO.read("MysteryGiftMaster.txt")
        master = pbMysteryGiftDecrypt(master)
      end
      master.each do |i|
        idlist.push(i[0])
      end
      params = ChooseNumberParams.new
      params.setRange(0, 99_999)
      params.setDefaultValue(id)
      params.setCancelValue(0)
      loop do
        newid = pbMessageChooseNumber(_INTL("Elige un ID único para este regalo."), params)
        if newid == 0
          return nil if pbConfirmMessage(_INTL("¿Dejar de editar este regalo?"))
        elsif idlist.include?(newid)
          pbMessage(_INTL("Ese ID ya está en uso por un Regalo Misterioso."))
        else
          id = newid
          break
        end
      end
    end
    loop do
      newgiftname = pbMessageFreeText(_INTL("Introduce un nombre para el regalo."), giftname, false, 250)
      if newgiftname != ""
        giftname = newgiftname
        break
      end
      return nil if pbConfirmMessage(_INTL("¿Dejar de editar este regalo?"))
    end
    # Pedir si el regalo tendrá contraseña
    has_password = pbConfirmMessage(_INTL("¿Quieres que este regalo requiera una contraseña?"))
    if has_password
      loop do
        new_password = pbMessageFreeText(_INTL("Introduce una contraseña de 8 caracteres."), "", false, 8)
        if new_password.length == 8
          password = new_password
          break
        else
          pbMessage(_INTL("La contraseña debe tener exactamente 8 caracteres."))
        end
      end
    end
    return [id, type, item, giftname, password]
  rescue
    pbMessage(_INTL("No se puede agregar el regalo."))
    return nil
  end
end

def pbCreateMysteryGift(type, item)
  gift = pbEditMysteryGift(type, item)
  pbSaveMysteryGiftToMaster(gift)
end

def pbCreateMysteryGiftBundle
  items = pbEditMysteryGiftBundleItems([])
  return if !items
  pbSaveMysteryGiftToMaster(pbEditMysteryGift(MysteryGift::TYPE_ITEM_BUNDLE, items))
end

def pbCreateMysteryGiftPokemonBundle
  pokemon = pbEditMysteryGiftPokemonBundle([])
  return if !pokemon
  pbSaveMysteryGiftToMaster(pbEditMysteryGift(MysteryGift::TYPE_POKEMON_BUNDLE, pokemon))
end

def pbCreateMysteryGiftMixedBundle
  content = pbEditMysteryGiftMixedBundle({ items: [], pokemon: [] })
  return if !content
  pbSaveMysteryGiftToMaster(pbEditMysteryGift(MysteryGift::TYPE_MIXED_BUNDLE, content))
end

def pbSaveMysteryGiftToMaster(gift)
  if gift
    begin
      if FileTest.exist?("MysteryGiftMaster.txt")
        master = IO.read("MysteryGiftMaster.txt")
        master = pbMysteryGiftDecrypt(master)
        master.push(gift)
      else
        master = [gift]
      end
      string = pbMysteryGiftEncrypt(master)
      File.open("MysteryGiftMaster.txt", "wb") { |f| f.write(string) }
      pbMessage(_INTL("El regalo se ha guardado en MysteryGiftMaster.txt."))
    rescue
      pbMessage(_INTL("No se ha podido guardar el regalo en MysteryGiftMaster.txt."))
    end
  else
    pbMessage(_INTL("No se ha creado el regalo."))
  end
end

#===============================================================================
# Debug option for managing gifts in the Master file and exporting them to a
# file to be uploaded.
#===============================================================================
def pbManageMysteryGifts
  if !FileTest.exist?("MysteryGiftMaster.txt")
    pbMessage(_INTL("No se encuentra el archivo \"MysteryGiftMaster.txt\" con los Regalos Misteriosos. No has creado ningún regalo."))
    pbMessage(_INTL("Puedes crear Regalos tanto de Pokémon como de Objetos. Para los Pokémon, elige la opción Debug que aparece al seleccionarlos en tu equipo o en el PC. Para los Objetos, elige la opción Debug que aparece al seleccionarlos en la Mochila."))
    pbMessage(_INTL("Una vez creados de ese modo, podrás encontrarlos aquí para gestionarlos y subirlos a Internet."))
    return
  end
  # Load all gifts from the Master file.
  master = IO.read("MysteryGiftMaster.txt")
  master = pbMysteryGiftDecrypt(master)
  if !master || !master.is_a?(Array) || master.length == 0
    pbMessage(_INTL("No hay Regalos Misteriosos definidos en el archivo \"MysteryGiftMaster.txt\". No has creado ninguno."))
    pbMessage(_INTL("Puedes crear Regalos tanto de Pokémon como de Objetos. Para los Pokémon, elige la opción Debug que aparece al seleccionarlos en tu equipo o en el PC. Para los Objetos, elige la opción Debug que aparece al seleccionarlos en la Mochila."))
    pbMessage(_INTL("Una vez creados de ese modo, podrás encontrarlos aquí para gestionarlos y subirlos a Internet."))
    return
  end
  pbMessage(_INTL("Archivo \"MysteryGiftMaster.txt\" leído correctamente con los Regalos Misteriosos."))
  # Download all gifts from online
  msgwindow = pbCreateMessageWindow
  pbMessageDisplay(msgwindow, _INTL("Buscando ahora regalos misteriosos en el enlace en línea..."))
  begin
    online = pbDownloadToString(MysteryGift::URL)
  rescue MKXPError
    online = nil
    pbMessage(_INTL("Parece que no tienes conexión a Internet, por lo que no se han podido buscar los regalos.\\wtnp[20]"))
    return
  end
  pbDisposeMessageWindow(msgwindow)
  if nil_or_empty?(online)
    pbMessage(_INTL("No se han encontrado Regalos Misteriosos en el enlace de Internet tras la descarga. Parece que está vacío.\\wtnp[20]"))
    online = []
  else
    gifts = pbMysteryGiftDecrypt(online, false)
    if !gifts.is_a?(Array) || gifts.empty?
      pbMessage(_INTL("Se ha descargado el enlace, pero no contiene regalos válidos. Comprueba que el Pastebin tenga solo el contenido de MysteryGift.txt.\\wtnp[20]"))
      online = []
    else
      pbMessage(_INTL("Se han encontrado Regalos Misteriosos en el enlace de Internet.\\wtnp[20]"))
      t = []
      gifts.each { |gift| t.push(gift[0]) }
      online = t
    end
  end
  # Show list of all gifts.
  command = 0
  loop do
    commands = pbRefreshMGCommands(master, online)
    command = pbMysteryGiftMessage(
      _INTL("Regalos Misteriosos. [X] = ya publicado en internet."), commands, -1, command
    )
    # Gift chosen
    if command == -1 || command == commands.length - 1   # Cancel
      break
    elsif command == commands.length - 4   # Export selected to file
      begin
        newfile = []
        master.each do |gift|
          newfile.push(gift) if online.include?(gift[0])
        end
        string = pbMysteryGiftEncrypt(newfile, false)
        File.open("MysteryGift.txt", "wb") { |f| f.write(string) }
        pbMessage(_INTL("Los regalos que has marcado con una X se han guardado en el archivo MysteryGift.txt."))
        pbMessage(_INTL("Ahora debes subir el contenido del archivo MysteryGift.txt a tu enlace de Internet (por ejemplo en la web de Pastebin) para que puedan ser descargados."))
      rescue
        pbMessage(_INTL("No se han podido guardar los datos en el archivo MysteryGift.txt. Inténtalo de nuevo."))
      end
    elsif command == commands.length - 3   # Borrar los regalos recibidos
      if pbConfirmMessage(_INTL("¿Quieres eliminar el registro de tu jugador de regalos misteriosos? Esto hará que puedas recibirlos todos de nuevo."))
        $player.mystery_gifts = []
        pbMessage(_INTL("Has eliminado correctamente los regalos recibidos."))

      end
    elsif command == commands.length - 2   # A gift
      pbMessage(_INTL("Este menú sirve para gestionar los Regalos Misteriosos."))
      pbMessage(_INTL("Los regalos marcados con una X al entrar en el menú son los que están en internet. El resto son los que están en el archivo \"MysteryGiftMaster.txt\"."))
      pbMessage(_INTL("Ten en cuenta que lo que busca es que en Internet haya un regalo con la misma ID que ese que has elegido. El contenido puede ser distinto, pero si comparten ID aparecerá igualmente marcado."))
      pbMessage(_INTL("Hay dos formas de crear un regalo de la nada: si es un Pokémon, selecciónalo en tu equipo o en el PC y elige la opción Debug. Ahí dentro verás la opción de convertirlo en Regalo Misterioso."))
      pbMessage(_INTL("Lo ideal es que edites un poco el Pokémon antes de crearlo y después elijas esta opción."))
      pbMessage(_INTL("La otra forma de crear los regalos es a partir de un objeto. Añádete el item que te interese desde el modo Debug a la mochila. Después, selecciona ese item dentro de la mochila y elige la opcion Debug y después Hacer Regalo Mist., y sigue los pasos que se indican."))
      pbMessage(_INTL("Una vez creados, al entrar en este menú verás que aparecen aquí, ya que se han guardado en el archivo \"MysteryGiftMaster.txt\"."))
      pbMessage(_INTL("En este menú, marca y desmarca los que quieras y después dale a \"Exportar elegidos\" para escribir los seleccionados en el archivo \"MysteryGift.txt\", que es un archivo distinto, y así poder subirlos a internet."))
      pbMessage(_INTL("Una vez hecho eso, copia y pega el contenido del archivo \"MysteryGift.txt\" en el enlace que hayas creado."))
      pbMessage(_INTL("Puedes usar servicios como la web de Pastebin para subir ahí tus regalos y que así tus jugadores puedan descargarlos."))
      pbMessage(_INTL("Recuerda que debes poner la URL de tu Pastebin en el script \"UI_MysteryGift\" dentro de los scripts del juego, a los que se accede desde el editor."))
      pbMessage(_INTL("Puedes encontrarlo rápidamente si entras en el editor de scripts, pulsas \"cntrl + shift + F\" y escribes \"module MysteryGift\"."))
      pbMessage(_INTL("¡IMPORTANTE! En el archivo \"MysteryGiftMaster.txt\" se pueden leer todos los datos de tus regalos y sus contraseñas. Te recomiendo que lo elimines de la carpeta del juego cuando lo vayas a compartir, para que nadie tenga acceso al mismo."))
    elsif command >= 0 && command < commands.length - 4   # A gift
      cmd = 0
      loop do
        commands = pbRefreshMGCommands(master, online)
        gift = master[command]
        cmds = [_INTL("Marcar/Desmarcar regalo"),
                _INTL("Editar el regalo"),
                _INTL("Recibir el regalo"),
                _INTL("Eliminar el regalo"),
                _INTL("Cancelar")]
        ontext = ["[  ]", "[X]"][(online.include?(gift[0])) ? 1 : 0]
        header = _INTL("{1} #{2}: {3}", ontext, gift[0], gift[3])
        detail = pbMysteryGiftGiftDetail(gift)
        msg = detail.empty? ? header : "#{header}\n#{detail}"
        cmd = pbMysteryGiftMessage(msg, cmds, -1, cmd)
        case cmd
        when -1, cmds.length - 1
          break
        when 0   # Toggle on/offline
          if online.include?(gift[0])
            online.delete(gift[0])
          else
            online.push(gift[0])
          end
        when 1   # Edit
          password = gift[4] || nil
          newgift = pbEditMysteryGift(gift[1], gift[2], gift[0], gift[3], password)
          master[command] = newgift if newgift
        when 2   # Receive
          if !$player
            pbMessage(_INTL("No hay ninguna partida guardada cargada. No se puede recibir ningún regalo."))
            next
          end
          replaced = false
          $player.mystery_gifts.length.times do |i|
            if $player.mystery_gifts[i][0] == gift[0]
              $player.mystery_gifts[i] = gift
              replaced = true
            end
          end
          $player.mystery_gifts.push(gift) if !replaced
          pbReceiveMysteryGift(gift[0])
        when 3   # Delete
          if pbConfirmMessage(_INTL("¿Estás seguro de que quieres borrar este regalo? Se eliminará del archivo \"MysteryGiftMaster.txt\"."))
            master.delete_at(command)
            begin
              newfile = []
              master.each do |gift|
                newfile.push(gift)
              end
              string = pbMysteryGiftEncrypt(newfile)
              File.open("MysteryGiftMaster.txt", "wb") { |f| f.write(string) }
              pbMessage(_INTL("El regalo se ha eliminado correctamente del archivo \"MysteryGiftMaster.txt\"."))  
            rescue
              pbMessage(_INTL("No se han podido guardar los datos en el archivo \"MysteryGiftMaster.txt\". Inténtalo de nuevo."))
            end
          end
          break
        end
      end
    end
  end
end

def pbMysteryGiftShowCommands(msgwindow, commands, cmdIfCancel = 0, defaultCmd = 0, &block)
  return 0 if !commands || commands.empty?

  max_width = Graphics.width - 16
  cmdwindow = Window_AdvancedCommandPokemon.new(commands, max_width)
  cmdwindow.z = 99999
  cmdwindow.visible = true
  cmdwindow.resizeToFit(commands, max_width)
  cmdwindow.width = max_width if cmdwindow.width > max_width
  cmdwindow.x = 8
  cmdwindow.height = [cmdwindow.height, msgwindow.y].min
  cmdwindow.y = msgwindow.y - cmdwindow.height
  if cmdwindow.y < 0
    cmdwindow.y = 0
    cmdwindow.height = [cmdwindow.height, msgwindow.y].min
  end
  cmdwindow.index = defaultCmd
  command = 0
  loop do
    Graphics.update
    Input.update
    msgwindow&.update
    cmdwindow.update
    yield if block_given?
    if Input.trigger?(Input::BACK)
      if cmdIfCancel > 0
        command = cmdIfCancel - 1
        break
      elsif cmdIfCancel < 0
        command = cmdIfCancel
        break
      end
    end
    if Input.trigger?(Input::USE)
      command = cmdwindow.index
      break
    end
    pbUpdateSceneMap
  end
  ret = command
  cmdwindow.dispose
  Input.update
  return ret
end

def pbMysteryGiftMessage(message, commands, cmdIfCancel = 0, defaultCmd = 0, &block)
  ret = 0
  msgwindow = pbCreateMessageWindow(nil)
  if commands
    ret = pbMessageDisplay(msgwindow, message, true,
      proc { |msgwndw|
        pbMysteryGiftShowCommands(msgwndw, commands, cmdIfCancel, defaultCmd, &block)
      }, &block)
  else
    pbMessageDisplay(msgwindow, message, &block)
  end
  pbDisposeMessageWindow(msgwindow)
  Input.update
  return ret
end

def pbMysteryGiftGiftDetail(gift)
  summary = pbMysteryGiftContentSummary(gift)
  return "" if summary.empty? || summary == "???"
  return _INTL("Contenido: {1}", summary)
end

def pbRefreshMGCommands(master, online)
  commands = []
  master.each do |gift|
    ontext = ["[  ]", "[X]"][(online.include?(gift[0])) ? 1 : 0]
    commands.push(_INTL("{1} #{2}: {3}", ontext, gift[0], gift[3]))
  end
  commands.push(_INTL("-> Exportar elegidos a archivo"))
  commands.push(_INTL("-> Eliminar regalos del jugador"))
  commands.push(_INTL("-> Ayuda sobre cómo funciona"))
  commands.push(_INTL("Cancelar"))
  return commands
end

#===============================================================================
# Downloads all available Mystery Gifts that haven't been downloaded yet.
#===============================================================================
# Called from the Continue/New Game screen.
def pbDownloadMysteryGift(trainer)
  sprites = {}
  @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  @viewport.z = 99999
  addBackgroundPlane(sprites, "background", "mysterygift_bg", @viewport)
  pbFadeInAndShow(sprites)
  pbBGMPlay("Regalo Misterioso", 70)
  loop do
    # Menú de opciones: regalos con contraseña o sin contraseña
    command = pbMessage("Elige qué tipo de Regalo Misterioso descargar.", [
          _INTL("Sin contraseña"),
          _INTL("Con contraseña"),
          _INTL("Cancelar")
      ], -1)
    case command
    when 0
      # Buscar regalos sin contraseña (el flujo original)
      pbDownloadGiftWithoutPassword(trainer)
    when 1
      # Buscar regalos con contraseña
      pbDownloadGiftWithPassword(trainer)
    when 2, -1
      break
    end
  end
  pbBGMFade(1.0)
  pbFadeOutAndHide(sprites)
  pbDisposeSpriteHash(sprites)
  @viewport.dispose
end




def pbMysteryGiftPendingFromOnline(trainer, data)
  return nil if nil_or_empty?(data)
  online = pbMysteryGiftDecrypt(data, false)
  if !online.is_a?(Array) || online.empty?
    pbMessage(_INTL("Se ha descargado el enlace, pero no contiene regalos válidos. Comprueba que el Pastebin tenga solo el contenido de MysteryGift.txt."))
    return nil
  end
  pending = []
  online.each do |gift|
    notgot = true
    trainer.mystery_gifts.each do |j|
      notgot = false if j[0] == gift[0]
    end
    pending.push(gift) if notgot
  end
  if pending.empty?
    pbMessage(_INTL("No hay nuevos regalos disponibles. Es posible que ya los hayas descargado antes. En el menú de gestión (F9), usa \"Eliminar regalos del jugador\" para poder volver a descargarlos."))
    return nil
  end
  return pending
end

def pbDownloadGiftWithoutPassword(trainer)
  # Descargar la lista de regalos desde el servidor usando la URL correcta
  pbMessage(_INTL("Buscando regalos en línea...\\wtnp[20]"))
  begin
    data = pbDownloadToString(MysteryGift::URL)
  rescue MKXPError
    pbMessage(_INTL("Parece que no tienes conexión a Internet, No se pueden buscar regalos."))
    return
  end
  if !data
    pbMessage(_INTL("No se pudo descargar la lista de regalos."))
    return
  end
  pending = pbMysteryGiftPendingFromOnline(trainer, data)
  return if !pending

  # Filtrar solo los regalos que no tienen contraseña
  gifts_without_password = pending.select { |gift| gift.length == 4 || (gift.length == 5 && (gift[4].nil? || gift[4].empty?)) }
  # Verificar si hay regalos sin contraseña disponibles
  if gifts_without_password.empty?
    pbMessage(_INTL("Hay regalos en línea, pero todos requieren contraseña. Elige \"Con contraseña\" al descargar."))
    return
  end
  # Mostrar al jugador la lista de regalos disponibles sin contraseña
  commands = []
  gifts_without_password.each do |gift|
    commands.push(_INTL("{1}", gift[3]))  # gift[3] es el nombre del regalo, gift[0] es el ID
  end
  commands.push(_INTL("Cancelar"))
  # El jugador elige un regalo para descargar
  command = pbMessage(_INTL("Elige un regalo para descargar."), commands, -1)
  if command < 0 || command >= gifts_without_password.length
    pbMessage(_INTL("No se ha descargado ningún regalo."))
    return
  end
  selected_gift = gifts_without_password[command]
  # Entregar el regalo al jugador
  pbReceiveGiftAnimation(selected_gift, trainer)
end



def pbDownloadGiftWithPassword(trainer)
  # Pedir al jugador la contraseña
  password = pbMessageFreeText(_INTL("Introduce la contraseña de 8 caracteres."), "", false, 8)
  if password.length != 8
    pbMessage(_INTL("La contraseña debe tener exactamente 8 caracteres."))
    return
  end
  pbMessage(_INTL("Buscando regalos con la contraseña indicada...\\wtnp[20]"))
  # Descargar la lista de regalos desde el servidor usando la URL
  begin
  data = pbDownloadToString(MysteryGift::URL)
  rescue MKXPError
    pbMessage(_INTL("Parece que no tienes conexión a Internet, No se pueden buscar regalos."))
    return
  end
  if !data
    pbMessage(_INTL("No se pudo descargar la lista de regalos."))
    pbMessage(_INTL("Parece que hay problemas para establecer la conexión a Internet."))
    return
  end
  pending = pbMysteryGiftPendingFromOnline(trainer, data)
  return if !pending

  # Buscar el regalo que coincida con la contraseña
  gift_found = nil
  regalos_pass = []
  pending.each do |gift|
    if gift.length == 5 && gift[4] == password  # gift[4] es la contraseña
      regalos_pass.push(gift)
      gift_found = gift
      # break
    end
  end
  # Verificar si se encontró un regalo con la contraseña proporcionada
  if gift_found.nil?
    pbMessage(_INTL("No se ha encontrado ningún regalo con esa contraseña."))
  else
    commands = []
    regalos_pass.each do |gift|
      commands.push(_INTL("{1}", gift[3]))  # gift[3] es el nombre del regalo, gift[0] es el ID
    end
    commands.push(_INTL("Cancelar"))
    # El jugador elige un regalo para descargar
    command = pbMessage(_INTL("Elige un regalo para descargar."), commands, -1)
    if command < 0 || command >= regalos_pass.length
      pbMessage(_INTL("No se ha descargado ningún regalo."))
      return
    end
    selected_gift = regalos_pass[command]
    # Entregar el regalo al jugador
    pbReceiveGiftAnimation(selected_gift, trainer)
  end
end


def pbMysteryGiftPrepareForSave(gft)
  return if !gft.is_a?(Array) || gft.length < 3
  case gft[1]
  when MysteryGift::TYPE_POKEMON
    gft[2] = create_hash_from_pkmn(gft[2]) if gft[2].is_a?(Pokemon)
  when MysteryGift::TYPE_POKEMON_BUNDLE
    return if !gft[2].is_a?(Array)
    gft[2] = gft[2].map { |p| p.is_a?(Pokemon) ? create_hash_from_pkmn(p) : p }
  when MysteryGift::TYPE_MIXED_BUNDLE
    content = pbMysteryGiftNormalizeMixedContent(gft[2])
    content[:pokemon] = content[:pokemon].map { |p| p.is_a?(Pokemon) ? create_hash_from_pkmn(p) : p }
    gft[2] = content
  end
end

def pbMysteryGiftRestoreFromSave(gft)
  return if !gft.is_a?(Array) || gft.length < 3
  case gft[1]
  when MysteryGift::TYPE_POKEMON
    gft[2] = create_pkmn_from_hash(gft[2]) if gft[2].is_a?(Hash)
  when MysteryGift::TYPE_POKEMON_BUNDLE
    return if !gft[2].is_a?(Array)
    gft[2] = gft[2].map { |p| p.is_a?(Hash) ? create_pkmn_from_hash(p) : p }
  when MysteryGift::TYPE_ITEM_BUNDLE
    return if !gft[2].is_a?(Array)
    gft[2].each do |entry|
      next if !entry.is_a?(Array) || entry.length < 2
      item_data = GameData::Item.try_get(entry[0])
      entry[0] = item_data.id if item_data
    end
  when MysteryGift::TYPE_MIXED_BUNDLE
    content = pbMysteryGiftNormalizeMixedContent(gft[2])
    content[:items].each do |entry|
      next if !entry.is_a?(Array) || entry.length < 2
      item_data = GameData::Item.try_get(entry[0])
      entry[0] = item_data.id if item_data
    end
    content[:pokemon] = content[:pokemon].map { |p| p.is_a?(Hash) ? create_pkmn_from_hash(p) : p }
    gft[2] = content
  else
    if gft[1].is_a?(Integer) && gft[1] > 0
      item_data = GameData::Item.try_get(gft[2])
      gft[2] = item_data.id if item_data
    end
  end
end

def pbMysteryGiftAnimationSubject(gift)
  case gift[1]
  when MysteryGift::TYPE_POKEMON
    return [:pokemon, gift[2]] if gift[2].is_a?(Pokemon)
  when MysteryGift::TYPE_POKEMON_BUNDLE
    list = gift[2]
    return [:pokemon, list[0]] if list.is_a?(Array) && list[0].is_a?(Pokemon)
  when MysteryGift::TYPE_MIXED_BUNDLE
    content = pbMysteryGiftNormalizeMixedContent(gift[2])
    return [:pokemon, content[:pokemon][0]] if content[:pokemon][0].is_a?(Pokemon)
    return [:item, content[:items][0][0]] if content[:items][0].is_a?(Array)
  when MysteryGift::TYPE_ITEM_BUNDLE
    list = gift[2]
    return [:item, list[0][0]] if list.is_a?(Array) && list[0].is_a?(Array)
  else
    return [:item, gift[2]] if gift[1].is_a?(Integer) && gift[1] > 0
  end
  return [:item, :POKEBALL]
end

def pbMysteryGiftDeliverPokemon(pokemon, show_pokedex: true)
  return false if !pokemon.is_a?(Pokemon)
  return false if !pbMysteryGiftCanStorePokemonCount?(1)
  was_owned = $player.owned?(pokemon.species)
  return false if !pbAddPokemonSilent(pokemon)
  pbMessage(_INTL("¡{1} recibió {2}!", $player.name, pokemon.name) + "\\me[Pkmn get]\\wtnp[80]")
  if show_pokedex && Settings::SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN && !was_owned &&
     $player.has_pokedex && $player.pokedex.species_in_unlocked_dex?(pokemon.species)
    pbMessage(_INTL("Los datos de {1} se han añadido a la Pokédex.", pokemon.name))
    $player.pokedex.register_last_seen(pokemon)
    pbFadeOutIn do
      scene = PokemonPokedexInfo_Scene.new
      screen = PokemonPokedexInfoScreen.new(scene)
      screen.pbDexEntry(pokemon.species)
    end
  end
  return true
end

def pbMysteryGiftDeliverItems(items)
  return false if !items.is_a?(Array) || items.empty?
  items.each do |entry|
    next if !entry.is_a?(Array) || entry.length < 2
    return false if !$bag.can_add?(entry[0], entry[1])
  end
  items.each do |entry|
    next if !entry.is_a?(Array) || entry.length < 2
    $bag.add(entry[0], entry[1])
    pbMysteryGiftAnnounceItem(entry[0], entry[1])
  end
  return true
end

def pbMysteryGiftDeliverPokemonList(pokemon_list)
  pokemon_list = pokemon_list.select { |p| p.is_a?(Pokemon) }
  return true if pokemon_list.empty?
  return false if !pbMysteryGiftCanStorePokemonCount?(pokemon_list.length)
  pokemon_list.each do |pokemon|
    return false if !pbMysteryGiftDeliverPokemon(pokemon)
  end
  return true
end

def pbMysteryGiftDeliverMixedBundle(content)
  content = pbMysteryGiftNormalizeMixedContent(content)
  return false if content[:items].empty? && content[:pokemon].empty?
  return false if !pbMysteryGiftDeliverItems(content[:items])
  return false if !pbMysteryGiftDeliverPokemonList(content[:pokemon])
  return true
end

# Función para manejar la animación al recibir un regalo (puede ser sin o con contraseña)
def pbReceiveGiftAnimation(gift, trainer)
  subject_type, subject = pbMysteryGiftAnimationSubject(gift)
  if subject_type == :pokemon
    sprite = PokemonSprite.new(@viewport)
    sprite.setOffset(PictureOrigin::CENTER)
    sprite.setPokemonBitmap(subject)
    sprite.x = Graphics.width / 2
    sprite.y = -sprite.bitmap.height / 2
  else
    sprite = ItemIconSprite.new(0, 0, subject, @viewport)
    sprite.x = Graphics.width / 2
    sprite.y = -sprite.height / 2
  end
  timer_start = System.uptime
  start_y = sprite.y
  loop do
    sprite.y = lerp(start_y, Graphics.height / 2 + 30, 1.5, timer_start, System.uptime)
    Graphics.update
    Input.update
    sprite.update
    break if sprite.y >= Graphics.height / 2  + 30
  end
  pbMEPlay("Battle capture success")
  pbWait(3.0) {Graphics.update; sprite.update}
  pbMessage(_INTL("¡Se ha recibido el regalo!") + "\1") {Graphics.update; sprite.update}
  pbMessage(_INTL("Por favor, recoge tu regalo del repartidor de cualquier Centro Pokémon.")) {Graphics.update; sprite.update}
  gift_to_store = pbMysteryGiftPrepareGiftForDelivery(gift) || gift
  trainer.mystery_gifts.push(gift_to_store)
  timer_start = System.uptime
  loop do
    sprite.opacity = lerp(255, 0, 1.5, timer_start, System.uptime)
    Graphics.update
    Input.update
    sprite.update
    break if sprite.opacity <= 0
  end
  sprite.dispose
end


#===============================================================================
# Converts an array of gifts into a string and back.
#===============================================================================
def pbMysteryGiftEncrypt(gift, master = true)
  gift.each { |gft| pbMysteryGiftPrepareForSave(gft) }
  if Settings::ENCRIPTAR_REGALOS_MISTERIOSOS_EN_MASTER || !master
    ret = [Zlib::Deflate.deflate(Marshal.dump(gift))].pack("m")
  else
    ret = gift.inspect
  end
  return ret
end

def pbMysteryGiftDecrypt(gift, master = true)
  return [] if nil_or_empty?(gift)
  gift = gift.strip
  ret = nil
  use_encrypted = Settings::ENCRIPTAR_REGALOS_MISTERIOSOS_EN_MASTER || !master
  if use_encrypted
    begin
      encoded = gift.gsub(/\s+/, "")
      decoded = encoded.unpack("m")[0]
      ret = Marshal.load(Zlib::Inflate.inflate(decoded)) if decoded && !decoded.empty?
    rescue Zlib::Error, ArgumentError, TypeError, EOFError
      ret = nil
    end
  end
  if ret.nil? && master && !Settings::ENCRIPTAR_REGALOS_MISTERIOSOS_EN_MASTER
    begin
      ret = eval(gift)
    rescue
      ret = nil
    end
  end
  if ret.nil? && master && gift.start_with?("[")
    begin
      ret = eval(gift)
    rescue
      ret = nil
    end
  end
  return [] if !ret.is_a?(Array)
  ret.each { |gft| pbMysteryGiftRestoreFromSave(gft) }
  return ret
end

def pbMysteryGiftNormalizeItemEntry(entry)
  return nil if !entry.is_a?(Array) || entry.length < 2
  item_data = GameData::Item.try_get(entry[0])
  return nil if !item_data
  qty = entry[1].to_i
  return nil if qty <= 0
  return [item_data.id, qty]
end

def pbMysteryGiftNormalizeItemList(items)
  return [] if !items.is_a?(Array)
  return items.filter_map { |entry| pbMysteryGiftNormalizeItemEntry(entry) }
end

def pbMysteryGiftNormalizePokemonEntry(entry)
  return entry if entry.is_a?(Pokemon)
  return create_pkmn_from_hash(entry) if entry.is_a?(Hash)
  return nil
end

def pbMysteryGiftNormalizePokemonList(pokemon_list)
  return [] if !pokemon_list.is_a?(Array)
  return pokemon_list.filter_map { |entry| pbMysteryGiftNormalizePokemonEntry(entry) }
end

def pbMysteryGiftResolveGiftType(gift)
  return nil if !gift.is_a?(Array) || gift.length < 3
  type = gift[1]
  type = type.to_i if type.is_a?(String) && type =~ /\A-?\d+\z/
  return type if [MysteryGift::TYPE_POKEMON, MysteryGift::TYPE_ITEM_BUNDLE,
                  MysteryGift::TYPE_POKEMON_BUNDLE, MysteryGift::TYPE_MIXED_BUNDLE].include?(type)
  if gift[2].is_a?(Hash) && (gift[2][:items] || gift[2]["items"] || gift[2][:pokemon] || gift[2]["pokemon"])
    return MysteryGift::TYPE_MIXED_BUNDLE
  end
  if gift[2].is_a?(Array) && !gift[2].empty?
    return MysteryGift::TYPE_ITEM_BUNDLE if gift[2][0].is_a?(Array)
    return MysteryGift::TYPE_POKEMON_BUNDLE if gift[2][0].is_a?(Pokemon) || gift[2][0].is_a?(Hash)
  end
  return MysteryGift::TYPE_POKEMON if gift[2].is_a?(Pokemon) || gift[2].is_a?(Hash)
  return :single_item if type.is_a?(Integer) && type > 0
  return nil
end

def pbMysteryGiftPrepareGiftForDelivery(gift)
  return nil if !gift.is_a?(Array) || gift.length < 3
  gift = gift.clone
  gift_type = pbMysteryGiftResolveGiftType(gift)
  case gift_type
  when MysteryGift::TYPE_POKEMON
    gift[1] = MysteryGift::TYPE_POKEMON
    gift[2] = pbMysteryGiftNormalizePokemonEntry(gift[2])
    return nil if gift[2].nil?
  when MysteryGift::TYPE_ITEM_BUNDLE
    gift[1] = MysteryGift::TYPE_ITEM_BUNDLE
    gift[2] = pbMysteryGiftNormalizeItemList(gift[2])
    return nil if gift[2].empty?
  when MysteryGift::TYPE_POKEMON_BUNDLE
    gift[1] = MysteryGift::TYPE_POKEMON_BUNDLE
    gift[2] = pbMysteryGiftNormalizePokemonList(gift[2])
    return nil if gift[2].empty?
  when MysteryGift::TYPE_MIXED_BUNDLE
    content = pbMysteryGiftNormalizeMixedContent(gift[2])
    content[:items] = pbMysteryGiftNormalizeItemList(content[:items])
    content[:pokemon] = pbMysteryGiftNormalizePokemonList(content[:pokemon])
    return nil if content[:items].empty? && content[:pokemon].empty?
    gift[1] = MysteryGift::TYPE_MIXED_BUNDLE
    gift[2] = content
  when :single_item
    item_data = GameData::Item.try_get(gift[2])
    return nil if !item_data || !gift[1].is_a?(Integer) || gift[1] <= 0
    gift[2] = item_data.id
  else
    return nil
  end
  return gift
end

#===============================================================================
# Collecting a Mystery Gift from the deliveryman.
#===============================================================================
def pbNextMysteryGiftID
  $player.mystery_gifts.each do |i|
    return i[0] if i.length > 1
  end
  return 0
end

def pbReceiveMysteryGift(id)
  index = -1
  $player.mystery_gifts.length.times do |i|
    if $player.mystery_gifts[i][0] == id && $player.mystery_gifts[i].length > 1
      index = i
      break
    end
  end
  if index == -1
    pbMessage(_INTL("No se han encontrado regalos sin reclamar con la ID {1}.", id))
    return false
  end
  gift_raw = $player.mystery_gifts[index]
  pbMysteryGiftRestoreFromSave(gift_raw)
  gift = pbMysteryGiftPrepareGiftForDelivery(gift_raw)
  if !gift
    pbMessage(_INTL("No se ha podido leer el contenido del regalo."))
    return false
  end
  delivered = false
  case pbMysteryGiftResolveGiftType(gift)
  when MysteryGift::TYPE_POKEMON
    delivered = pbMysteryGiftDeliverPokemon(gift[2])
  when MysteryGift::TYPE_POKEMON_BUNDLE
    delivered = pbMysteryGiftDeliverPokemonList(gift[2])
  when MysteryGift::TYPE_ITEM_BUNDLE
    delivered = pbMysteryGiftDeliverItems(gift[2])
  when MysteryGift::TYPE_MIXED_BUNDLE
    delivered = pbMysteryGiftDeliverMixedBundle(gift[2])
  when :single_item
    delivered = pbMysteryGiftDeliverItems([[gift[2], gift[1]]])
  end
  if delivered
    $player.mystery_gifts[index] = [id]
    return true
  end
  pbMessage(_INTL("No se ha podido entregar el regalo. Comprueba que tengas espacio en la Mochila y en las Cajas del PC."))
  return false
end

#===============================================================================
# Converts a Pokémon into a hash.
#===============================================================================
def create_hash_from_pkmn(pokemon)
  # Creamos un array con las IDs de los movs.
  movs_array = []
  for i in pokemon.moves
    movs_array.push(i.id)
  end
  owner_id = pokemon.owner.id
  owner_name = pokemon.owner.name
  owner_gender = pokemon.owner.gender
  return {
    species: pokemon.species,
    nivel: pokemon.level,
    nombre: pokemon.name,
    forma: pokemon.form,
    felicidad: pokemon.happiness,
    pokeball: pokemon.poke_ball,
    genero: pokemon.gender,
    naturaleza: pokemon.nature.id,
    ivs: pokemon.iv,
    evs: pokemon.ev,
    habilidad: pokemon.ability.id,
    movimientos: movs_array,
    item: pokemon.item.id,
    cinta_aplicada: pokemon.ribbons,
    steps_to_hatch: pokemon.steps_to_hatch,
    shiny: pokemon.shiny?,
    super_shiny: pokemon.super_shiny?,
    cool: pokemon.cool,
    beauty: pokemon.beauty,
    cute: pokemon.cute,
    smart: pokemon.smart,
    tough: pokemon.tough,
    sheen: pokemon.sheen,
    pokerus: pokemon.pokerus,
    owner_id: owner_id,
    owner_name: owner_name,
    owner_gender: owner_gender,
    obtain_method: pokemon.obtain_method,
    obtain_map: pokemon.obtain_map,
    obtain_text: pokemon.obtain_text,
    obtain_level: pokemon.obtain_level,
    hatched_map: pokemon.hatched_map,
    fused: pokemon.fused,
    personalID: pokemon.personalID,
    ready_to_evolve: pokemon.ready_to_evolve,
    cannot_store: pokemon.cannot_store,
    cannot_release: pokemon.cannot_release,
    cannot_trade: pokemon.cannot_trade,
    scale: pokemon.scale,
    memento: pokemon.memento,
    spot_hash: pokemon.spot_hash,
    shiny_leaf: pokemon.shiny_leaf,
  }
end

#===============================================================================
# Converts a hash into a Pokémon.
#===============================================================================
def create_pkmn_from_hash(poke_hash)
  pokemon = Pokemon.new(poke_hash[:species],poke_hash[:nivel].to_i)
  pokemon.name = poke_hash[:nombre]
  pokemon.form = poke_hash[:forma]
  pokemon.happiness = poke_hash[:felicidad]
  pokemon.poke_ball = poke_hash[:pokeball]
  pokemon.gender = poke_hash[:genero]
  pokemon.nature = poke_hash[:naturaleza]
  pokemon.iv = poke_hash[:ivs]
  pokemon.ev = poke_hash[:evs]
  pokemon.ability = poke_hash[:habilidad]
  pokemon.moves = poke_hash[:movimientos]
  pokemon.item = poke_hash[:item]
  pokemon.ribbons = poke_hash[:cinta_aplicada]
  pokemon.steps_to_hatch = poke_hash[:steps_to_hatch]
  pokemon.shiny = poke_hash[:shiny]
  pokemon.super_shiny = poke_hash[:super_shiny]
  pokemon.moves = poke_hash[:moves]
  pokemon.cool = poke_hash[:cool]
  pokemon.beauty = poke_hash[:beauty]
  pokemon.cute = poke_hash[:cute]
  pokemon.smart = poke_hash[:smart]
  pokemon.tough = poke_hash[:tough]
  pokemon.sheen = poke_hash[:sheen]
  pokemon.pokerus = poke_hash[:pokerus]
  pokemon.owner.id = poke_hash[:owner_id]
  pokemon.owner.name = poke_hash[:owner_name]
  pokemon.owner.gender = poke_hash[:owner_gender]
  pokemon.obtain_method = poke_hash[:obtain_method]
  pokemon.obtain_map = poke_hash[:obtain_map]
  pokemon.obtain_text = poke_hash[:obtain_text]
  pokemon.obtain_level = poke_hash[:obtain_level]
  pokemon.hatched_map = poke_hash[:hatched_map]
  pokemon.fused = poke_hash[:fused]
  pokemon.personalID = poke_hash[:personalID]
  pokemon.ready_to_evolve = poke_hash[:ready_to_evolve]
  pokemon.cannot_store = poke_hash[:cannot_store]
  pokemon.cannot_release = poke_hash[:cannot_release]
  pokemon.cannot_trade = poke_hash[:cannot_trade]
  pokemon&.scale = poke_hash[:scale] if pokemon&.respond_to?(:scale)
  pokemon&.memento = poke_hash[:memento] if pokemon&.respond_to?(:memento)
  pokemon&.spot_hash = poke_hash[:spot_hash] if pokemon&.respond_to?(:spot_hash)
  pokemon&.shiny_leaf = poke_hash[:shiny_leaf] if pokemon&.respond_to?(:shiny_leaf)
  pokemon&.calc_stats if pokemon&.respond_to?(:calc_stats)
  return pokemon
end