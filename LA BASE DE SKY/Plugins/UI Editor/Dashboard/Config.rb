
class ConfigPanel < UI::Options
  def initialize
    super(in_load_screen = false, menu = :ui_editor_menu)
  end

  def get_all_options(menu = :ui_editor_menu)
    return super(menu)
  end

   def update_input
    
    old_theme = Settings_UI_Editor::VISUAL_SETTINGS[:active_theme]
    
    
    old_index = @sprites[:options_list].index 
    
    ret = super 
    
    new_theme = Settings_UI_Editor::VISUAL_SETTINGS[:active_theme]

    
    if old_theme != new_theme
      
      invalidate_pages_cache 
      

      @options = get_all_options(@menu)
      @sprites[:options_list].options = @options
      

      @sprites[:options_list].index = [old_index, @options.length - 1].min
      
          
      refresh 
    end
    
    return ret
  end
end


# Pestaña Principal del Editor
PageHandlers.add(:ui_editor_menu, :main, {
  :name  => proc { next _INTL("General") },
  :order => 10,
  :description => proc { next _INTL("Ajustes básicos del Editor.") }
})

# Pestaña de Visuales
PageHandlers.add(:ui_editor_menu, :ui_editor_visuals, {
  :name  => proc { next _INTL("Apariencia") },
  :order => 20,
  :description => proc { next _INTL("Cambia cómo se ve el editor mientras trabajas.") }
})
#===============================================================================
# CONFIGURACIÓN GENERAL
#===============================================================================

MenuHandlers.add(:ui_editor_menu, :report_format, {
  "page"        => :main,
  "name"        => _INTL("Formato de Reporte"),
  "type"        => :array,
  "parameters"  => proc { Settings_UI_Editor::FORMAT_ARCHIVE_HISTORY.keys.map { |k| k.to_s } },
  "description" => _INTL("Elige el formato del archivo de historial."),

  
  "get_proc"    => proc { 
    val = $Settings_UI_Editor.report_format
    next Settings_UI_Editor::FORMAT_ARCHIVE_HISTORY.keys.index(val) || Settings_UI_Editor::FORMAT_ARCHIVE_HISTORY.keys.index(:txt)
  },

  "set_proc"    => proc { |value, _screen|
    
    new_format = Settings_UI_Editor::FORMAT_ARCHIVE_HISTORY.keys[value]
    $Settings_UI_Editor.report_format = new_format
    UI_Editor::SaveSystem.guardar
  }
})


#===============================================================================
# CONFIGURACIÓN VISUAL
#===============================================================================

# --- SELECTOR DE TEMA ---
MenuHandlers.add(:ui_editor_menu, :grid_size, {
  "page"        => :ui_editor_visuals,
  "name"        => _INTL("Tamaño de Rejilla"),
  "type"        => :array,
  "parameters"  => proc { [_INTL("OFF"), "8px", "16px", "32px"] },
  "description" => _INTL("Determina el ajuste de la rejilla de precisión. \n 
                          Por defecto, se muestran lineas que seccionan ."),
  "get_proc"    => proc { 
    case $Settings_UI_Editor.grid_size
    when 8 then 1; when 16 then 2; when 32 then 3; else 0; end
  },
  "set_proc"    => proc { |value, _screen|
    sizes = [0, 8, 16, 32]
    $Settings_UI_Editor.grid_size = sizes[value]
    UI_Editor::SaveSystem.guardar
  }
})

MenuHandlers.add(:ui_editor_menu, :theme_selector, {
  "page"        => :ui_editor_visuals,
  "name"        => _INTL("Tema de Iluminación"),
  "order"       => 10,
  "type"        => :array,
  "parameters"  => proc { Settings_UI_Editor::SELECTION_THEMES_UI.keys.map { |k| k.to_s.downcase } },
  "description" => _INTL("Elige el estilo de resaltado para el objeto seleccionado."),
  "get_proc"    => proc { 
    next Settings_UI_Editor::SELECTION_THEMES_UI.keys.index($Settings_UI_Editor.active_theme) 
  },
  "set_proc"    => proc { |value, screen|
    $Settings_UI_Editor.active_theme = Settings_UI_Editor::SELECTION_THEMES_UI.keys[value]

    UI_Editor::SaveSystem.guardar
  }
})

# --- SLIDERS RGB (Solo aparecen si el tema es CUSTOM) ---
[:Red, :Green, :Blue, :Gray].each_with_index do |color, index|
  MenuHandlers.add(:ui_editor_menu, "custom_#{color.downcase}".to_sym, {
    "page"        => :ui_editor_visuals,
    "name"        => _INTL("  > Tono: {1}", color),
    "order"       => 20 + index,
    "type"        => :number_slider,
    "parameters"  => [-255, 255, 1],
    "condition"   => proc { next UI_Editor.settings.active_theme == :CUSTOM },
    "description" => _INTL("Ajusta el componente {1} del tono personalizado.", color),
    "get_proc"    => proc { next $Settings_UI_Editor.custom_tone[index] },
    "set_proc"    => proc { |value, screen|
      $Settings_UI_Editor.custom_tone[index] = value
      UI_Editor::SaveSystem.guardar
    }
  })
end

# --- OPACIDAD DEL FONDO ---
MenuHandlers.add(:ui_editor_menu, :background_opacity, {
  "page"        => :ui_editor_visuals,
  "name"        => _INTL("Opacidad Fondo"),
  "order"       => 30,
  "type"        => :number_slider,
  "parameters"  => [0, 255, 1],
  "description" => _INTL("Ajusta qué tanto se oscurece la pantalla al entrar en modo edición."),
  "get_proc"    => proc { next $Settings_UI_Editor.bg_dim_opacity },
  "set_proc"    => proc { |value, _screen|
    $Settings_UI_Editor.bg_dim_opacity = value
    UI_Editor::SaveSystem.guardar
    
  }
})