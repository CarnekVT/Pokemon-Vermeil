#===============================================================================
# Battle Scene Studio v0.8.1 - regression guards
#===============================================================================
module BSS081SceneGuards
  def bss081_sync_background_filter
    return unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    native=@sprites["battle_bg"] rescue nil
    room=@bss070_ebdx_room rescue nil
    return if !native || !room || (room.disposed? rescue true) || !native.respond_to?(:color)
    rs=room.instance_variable_get(:@sprites) rescue nil
    return if !rs.is_a?(Hash)
    c=native.color rescue nil
    return if !c
    ["bg","void"].each do |key|
      sp=rs[key] rescue nil
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:color=)
      begin
        sp.color=Color.new(c.red,c.green,c.blue,c.alpha)
      rescue
      end
    end
  rescue
  end

  def pbUpdate(*args,&block)
    ret=super
    bss081_sync_background_filter
    ret
  end
end
begin
  Battle::Scene.prepend(BSS081SceneGuards) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS081SceneGuards)
rescue => e
  BSS064.log("BSS081 guard install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
