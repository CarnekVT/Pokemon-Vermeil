# frozen_string_literal: true
# Single right-side trainer layout and controlled EBDX camera framing.
# Never choose the left based on free screen area. Multi-battle bounds include
# every opposing Pokemon, and the camera slides to preserve screen visibility.
module VermeilTrainerSideLanes
  def bss_camera_visible_span(sprite)
    return nil unless sprite && !(sprite.disposed? rescue true) && sprite.bitmap
    rect=(sprite.src_rect rescue nil)
    width=rect && rect.width.to_f>0 ? rect.width.to_f : sprite.bitmap.width.to_f
    zoom=(sprite.zoom_x rescue 1.0).to_f.abs
    zoom=1.0 if zoom<0.01
    left=sprite.x.to_f-(sprite.ox rescue width/2.0).to_f*zoom
    [left,left+width*zoom]
  rescue StandardError
    nil
  end

  def bss_camera_foe_bounds
    return [] unless @battle && @sprites.is_a?(Hash)
    @battle.battlers.each_index.filter_map do |index|
      next unless index.odd?
      actor=@sprites["pokemon_#{index}"]
      # Opponents are initially hidden until send-out; their positions are
      # still needed to stage the trainer correctly BEFORE his first frame.
      next unless actor
      battler=(@battle.battlers[index] rescue nil)
      next if battler && (battler.fainted? rescue false)
      bss_camera_visible_span(actor)
    end
  end

  def bss_camera_trainer_side_x(trainer, _trainer_index=0)
    actor=bss_camera_visible_span(trainer)
    foes=bss_camera_foe_bounds
    return nil unless actor && !foes.empty?
    width=actor[1]-actor[0]
    origin=trainer.x.to_f-actor[0]
    # STRICTLY RIGHT of the whole team, never a fallback to the left.
    foes.map(&:last).max+14.0+origin
  rescue StandardError
    nil
  end

  def bss_camera_trainer_overlaps_foe?(trainer)
    actor=bss_camera_visible_span(trainer)
    return false unless actor
    bss_camera_foe_bounds.any? { |foe| actor[0]<foe[1]+8 && actor[1]>foe[0]-8 }
  end

  def bss_camera_park_trainer(trainer,index,continuous=false)
    return unless trainer && (trainer.visible rescue false)
    return unless continuous || bss_camera_trainer_overlaps_foe?(trainer)
    target=bss_camera_trainer_side_x(trainer,index)
    return unless target
    trainer.x=target if trainer.respond_to?(:x=)
  rescue StandardError
  end

  # Camera tween uses MAIN as an ABSOLUTE source, not the prior zoomed frame.
  # This small leftward world pan opens space on the right for the trainer.
  def bss_camera_begin_right_focus
    return unless @vector && @vector.respond_to?(:get) &&
                  respond_to?(:vermeil_cinema_base_vector)
    base=vermeil_cinema_base_vector
    return unless base.is_a?(Array) && base.length>=6
    trainer=(@sprites["trainer_1"] rescue nil)
    bounds=bss_camera_visible_span(trainer)
    foes=bss_camera_foe_bounds
    overflow=0.0
    if bounds && !foes.empty?
      overflow=[foes.map(&:last).max+14.0+(bounds[1]-bounds[0])-
                Graphics.width.to_f+18.0,0.0].max
    end
    pan=[[((overflow+25.0)/0.65),30.0].max,55.0].min
    target=base.clone
    target[0]-=pan
    target[4]*=1.12
    target[5]*=1.12
    @bss_right_camera_from=@vector.get.clone
    @bss_right_camera_to=target
    @bss_right_camera_started=Time.now.to_f
    @bss_right_camera_return=false
  rescue StandardError => e
    BSS064.log("Trainer focus camera: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss_camera_release_right_focus
    return unless @vector && @vector.respond_to?(:get) &&
                  respond_to?(:vermeil_cinema_base_vector)
    @bss_right_camera_from=@vector.get.clone
    @bss_right_camera_to=vermeil_cinema_base_vector
    @bss_right_camera_started=Time.now.to_f
    @bss_right_camera_return=true
    @bss_nds_trainer_staged=false
  end

  def bss_camera_right_focus_tick
    return unless @vector && @bss_right_camera_to && @bss_right_camera_from
    return if @bss070_ebdx_bas_frame || @bas_runtime_playback_depth.to_i>0
    t=[[(Time.now.to_f-@bss_right_camera_started.to_f)/0.40,0.0].max,1.0].min
    ease=t*t*(3.0-2.0*t)
    from=@bss_right_camera_from; to=@bss_right_camera_to
    shot=6.times.map { |i| from[i].to_f+(to[i].to_f-from[i].to_f)*ease }
    @vector.snap(shot) if @vector.respond_to?(:snap)
    # Script camera lease must agree with the actual shot; otherwise its
    # director restores the old camera next frame and produces a visible snap.
    if @vermeil_cinema_script_depth.to_i>0
      @vermeil_cinema_script_camera_hold=shot.clone
    end
    room=@bss070_ebdx_room
    room.update if room && !(room.disposed? rescue true)
    if t>=1.0
      @bss_right_camera_to=nil
      @bss_right_camera_from=nil
      @bss_right_camera_started=nil
      @bss_right_camera_return=false
    end
  rescue StandardError => e
    BSS064.log("Trainer right focus tick: #{e.class}: #{e.message}") if defined?(BSS064)
    @bss_right_camera_to=nil
  end

  def bss_camera_relayer_trainers
    result=super
    return result if @bss_nds_intro_active
    return result if respond_to?(:inPartyAnimation?) && (inPartyAnimation? rescue false)
    return result unless @battle && @battle.respond_to?(:opponent) && @battle.opponent
    @battle.opponent.each_index do |index|
      actor=@sprites["trainer_#{index+1}"]
      continuous=@bss_nds_trainer_staged || @bss_dialogue_cinema_active
      bss_camera_park_trainer(actor,index,continuous)
      next unless actor && (actor.visible rescue false)
      foe=@sprites["pokemon_#{2*index+1}"]
      foe_z=(foe && !(foe.disposed? rescue true)) ? foe.z.to_i : 50
      actor.z=[actor.z.to_i,foe_z+2,150+index].max if actor.respond_to?(:z=)
    end
    result
  rescue StandardError=>e
    BSS064.log("Trainer right relayer: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end

  def pbUpdate(*args,&block)
    result=super
    bss_camera_right_focus_tick
    if @sprites && @battle &&
       !(respond_to?(:inPartyAnimation?) && (inPartyAnimation? rescue false))
      if @bss_nds_trainer_staged || @bss_dialogue_cinema_active
        (@battle.opponent || []).each_index do |i|
          bss_camera_park_trainer(@sprites["trainer_#{i+1}"],i,true)
        end
      end
      if @bss_dialogue_cinema_active
        bss_camera_park_trainer(@sprites["midbattle_speaker"],0,true)
      end
    end
    result
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(VermeilTrainerSideLanes)
  Battle::Scene.prepend(VermeilTrainerSideLanes)
end
