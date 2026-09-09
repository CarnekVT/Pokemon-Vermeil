# frozen_string_literal: true

require "fileutils"
require_relative "png"

# Copia las imágenes del juego a la carpeta de salida. Los sprites de Pokémon y
# de entrenadores son tiras de fotogramas animados: se copian tal cual y se
# guarda [lado, nº fotogramas] para que la web los anime con CSS.
module Assets
  module_function

  # @return [Hash] {
  #   icons:    { ID => [lado, n] },   # animados en la web
  #   front:    { ID => [lado, n] },
  #   trainers: { TIPO => [lado, n] },
  #   items:    Set<ID>
  # }
  def copy(out, data, sprites:)
    game = Dir.pwd
    img = File.join(out, "img")
    FileUtils.mkdir_p(img)

    manifest = { icons: {}, front: {}, trainers: {}, items: [], type_sheet: copy_type_sheet(game, img, data) }
    return manifest unless sprites

    species = data[:species].values
    manifest[:icons] = copy_sprites(species, File.join(game, "Graphics", "Pokemon", "Icons"), File.join(img, "icons"))
    manifest[:front] = copy_sprites(species, File.join(game, "Graphics", "Pokemon", "Front"), File.join(img, "front"))
    manifest[:trainers] = copy_trainer_sprites(data[:trainers].values, File.join(game, "Graphics", "Trainers"), File.join(img, "trainers"))
    manifest[:items] = copy_items(data[:items].keys, File.join(game, "Graphics", "Items"), File.join(img, "items"))
    manifest
  end

  # ---------------------------------------------------------------------------

  # La hoja de iconos de tipo del juego (Graphics/UI/types.png): una columna de
  # iconos apilados. Cada icono ocupa toda la anchura; su altura sale de dividir
  # la hoja entre el nº de filas de tipo (mayor IconPosition + 1).
  def copy_type_sheet(game, img, data)
    src = File.join(game, "Graphics", "UI", "types.png")
    return nil unless File.exist?(src)

    FileUtils.cp(src, File.join(img, "types.png"))
    w, height = PNG.dimensions(src)
    rows = (data[:types].values.map { |t| t[:icon_position].to_i }.max || 0) + 1
    { w: w, row_h: (height.to_f / rows).round, rows: rows }
  end

  # Para cada especie/forma copia <ID>.png cayendo a la especie base si la forma
  # no tiene gráfico propio. Devuelve { ID => [lado, nº fotogramas] }.
  def copy_sprites(species, src_dir, dest_dir)
    FileUtils.mkdir_p(dest_dir)
    out = {}
    species.each do |s|
      names = []
      names << "#{s[:species]}_#{s[:form]}" if s[:form].to_i.positive?
      names << s[:species]
      src = names.map { |n| File.join(src_dir, "#{n}.png") }.find { |p| File.exist?(p) }
      next unless src

      FileUtils.cp(src, File.join(dest_dir, "#{s[:id]}.png"))
      out[s[:id]] = PNG.frames(src)
    end
    out
  end

  def copy_trainer_sprites(trainers, src_dir, dest_dir)
    FileUtils.mkdir_p(dest_dir)
    out = {}
    trainers.map { |t| t[:trainer_type] }.uniq.each do |type|
      src = File.join(src_dir, "#{type}.png")
      next unless File.exist?(src)

      FileUtils.cp(src, File.join(dest_dir, "#{type}.png"))
      out[type] = PNG.frames(src)
    end
    out
  end

  def copy_items(ids, src_dir, dest_dir)
    FileUtils.mkdir_p(dest_dir)
    done = []
    ids.each do |id|
      src = File.join(src_dir, "#{id}.png")
      next unless File.exist?(src)

      FileUtils.cp(src, File.join(dest_dir, "#{id}.png"))
      done << id.to_s
    end
    done
  end
end
