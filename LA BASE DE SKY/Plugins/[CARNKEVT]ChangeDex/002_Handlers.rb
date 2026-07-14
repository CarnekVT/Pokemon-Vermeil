#===============================================================================
# 002_Handlers.rb - Integración con el motor
#===============================================================================
ItemHandlers::UseInField.add(:CHANGEDEX, proc { |item|
  VermeilChangeDex.open
  next true
})

MenuHandlers.add(:debug_menu, :changedex, {
  "name"        => _INTL("Vermeil ChangeDex"),
  "parent"      => :main,
  "description" => _INTL("Visualizador de cambios de PBS."),
  "effect"      => proc {
    VermeilChangeDex.open
    next false
  }
})