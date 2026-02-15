#===============================================================================
#
#===============================================================================
class PokemonSystem
  #-----------------------------------------------------------------------------
  def reapply_all_options
    @force_set_options = true
    all_options = self.instance_variables.map { |val| val.to_s.gsub("@", "").to_sym }
    all_options.each do |option|
      next if option == :force_set_options
      self.send((option.to_s + "=").to_sym, self.send(option))
    end
    @force_set_options = false
  end
end
