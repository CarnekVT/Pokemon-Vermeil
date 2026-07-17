class Battle::Scene
  alias _zbox_ebui_zfix_pbInitSprites pbInitSprites
  def pbInitSprites
    _zbox_ebui_zfix_pbInitSprites
    @sprites["enhancedUI"].z += 9999 if @sprites["enhancedUI"]
    @sprites["leftarrow"].z += 9999 if @sprites["leftarrow"]
    @sprites["rightarrow"].z += 9999 if @sprites["rightarrow"]
    @sprites["enhancedUIPrompts"].z += 9999 if @sprites["enhancedUIPrompts"]
    @sprites.keys.each do |key|
      next unless key =~ /\A(info_icon|ball_icon)\d+\z/
      @sprites[key].z += 9999
      8.times do |i|
        okey = "#{key}_outline#{i}"
        @sprites[okey].z += 9999 if @sprites[okey]
      end
    end
  end
end
