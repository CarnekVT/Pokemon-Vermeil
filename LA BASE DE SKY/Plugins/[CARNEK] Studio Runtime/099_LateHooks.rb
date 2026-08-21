#===============================================================================
# Late hooks
#===============================================================================
def carnek_studio_refresh_sources
  CarnekStudio::SourceCatalog.refresh_input! if defined?(CarnekStudio::SourceCatalog)
end

if defined?(EventHandlers)
  EventHandlers.add(:on_game_start, :carnek_studio_config, proc {
    CarnekStudio.apply_plugin_config
    carnek_studio_refresh_sources
  })
else
  CarnekStudio.apply_plugin_config
  carnek_studio_refresh_sources
end
