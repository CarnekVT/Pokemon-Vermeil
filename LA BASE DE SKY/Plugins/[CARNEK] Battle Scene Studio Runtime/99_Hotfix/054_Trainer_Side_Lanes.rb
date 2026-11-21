# frozen_string_literal: true
# Single owner for the opposing TRAINER's right-hand lane. Animated Trainer
# Intros owns the animation frames; this module owns only the final X position
# and an EBDX camera shot. Never slide or reanchor the trainer each frame.
module VermeilTrainerSideLanes
  TRAINER_GAP = 14.0
  TRAINER_MARGIN = 12.0

  def pbInitSprites(*args,&block)
    @bss_right_camera_active=false
    @bss_right_camera_returning=false
    @bss_right_camera_from=nil
    @bss_right_camera_to=nil
    @bss_nds_trainer_staged=false
    @bss_trainer_cleanup_started=nil
    @bss_trainer_placed={}
    super
  end

  def bss_camera_visible_span(sprite)
    return nil unless sprite && !(sprite.disposed? rescue true) && sprite.bitmap
    rect=(sprite.src_rect rescue nil)
    width=rect && rect.width.to_f>0 ? rect.width.to_f : sprite.bitmap.width.to_f
    width=1.0 if width<=0
    zoom=(sprite.zoom_x rescue 1.0).to_f.abs
    zoom=1.0 if zoom<0.01
    left=sprite.x.to_f-(sprite.ox rescue width/2.0).to_f*zoom
    [left,left+width*zoom]
  rescue StandardError
    nil
  end

  def bss_camera_foe_bounds
    return [] unless @sprites && @battle
    @battle.battlers.each_index.filter_map do |idx|
      next unless idx.odd?
      sprite=@sprites["pokemon_#{idx}"]
      bss_camera_visible_span(sprite)
    end
  end

  # Final anchor is always to the RIGHT, and never beyond the screen edge.
  # The EBDX shot moves the opponents left first if there is not enough space.
  def bss_camera_trainer_side_x(actor,_index=0)
    current=bss_camera_visible_span(actor)
    return nil unless current
    width=current[1]-current[0]
    origin=actor.x.to_f-current[0]
    foes=bss_camera_foe_bounds
    desired=foes.empty? ? Graphics.width.to_f-width+origin-TRAINER_MARGIN :
                         foes.map(&:last).max+TRAINER_GAP+origin
    max_x=Graphics.width.to_f-TRAINER_MARGIN-width+origin
    min_x=Graphics.width.to_f/2.0+origin
    [[desired,min_x].max,max_x].min
  rescue StandardError
    nil
  end

  # Calculate EBDX camera travel from the ACTUAL opponent and trainer sizes,
  # not a fixed shift. It is a bounded absolute shot from the unchanged MAIN.
  def bss_camera_begin_right_focus
    return unless @vector && respond_to?(:vermeil_cinema_base_vector)
    base=vermeil_cinema_base_vector
    return unless base.is_a?(Array) && base.length>=6
    foes=bss_camera_foe_bounds
    trainer=@sprites["trainer_1"] if @sprites
    span=bss_camera_visible_span(trainer)
    if foes.empty? || !span
      @bss_right_camera_active=false
      return
    end
    width=span[1]-span[0]
    overflow=[foes.map(&:last).max+TRAINER_GAP+width+
              TRAINER_MARGIN-Graphics.width.to_f,0.0].max
    pan=[[overflow/0.65+16.0,20.0].max,125.0].min
    target=base.clone
    target[0]-=pan
    # Zoom gives the EBDX room enough overscan for this lateral pan.
    target[4]*=1.08
    target[5]*=1.08
    @bss_right_camera_active=true
    @bss_right_camera_from=@vector.get.clone
    @bss_right_camera_to=target
    @bss_right_camera_started=Time.now.to_f
  rescue StandardError => e
    BSS064.log("Trainer right camera setup: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss_camera_release_right_focus
    return unless @bss_right_camera_active && @vector &&
                  respond_to?(:vermeil_cinema_base_vector)
    @bss_right_camera_from=@vector.get.clone
    @bss_right_camera_to=vermeil_cinema_base_vector
    @bss_right_camera_started=Time.now.to_f
    @bss_right_camera_returning=true
  end

  def bss_camera_right_focus_tick
    return unless @bss_right_camera_active && @vector && @bss_right_camera_to
    return if @bss070_ebdx_bas_frame || @bas_runtime_playback_depth.to_i>0
    t=[[(Time.now.to_f-@bss_right_camera_started.to_f)/0.44,0.0].max,1.0].min
    ease=t*t*(3.0-2.0*t)
    from=@bss_right_camera_from
    dest=@bss_right_camera_to
    shot=6.times.map { |i| from[i].to_f+(dest[i].to_f-from[i].to_f)*ease }
    @vector.snap(shot) if @vector.respond_to?(:snap)
    if @vermeil_cinema_script_depth.to_i>0
      @vermeil_cinema_script_camera_hold=shot.clone
    end
    room=@bss070_ebdx_room
    room.update if room && !(room.disposed? rescue true)
    if defined?(BSS103WorldSpaceBattlers)
      BSS103WorldSpaceBattlers.instance_method(:bss070_ebdx_apply_world_alignment).bind(self).call
    end
    if t>=1.0 && @bss_right_camera_returning
      @bss_right_camera_active=false
      @bss_right_camera_returning=false
      @bss_nds_trainer_staged=false
      @vermeil_cinema_home_hold=true
    end
  rescue StandardError => e
    BSS064.log("Trainer right camera: #{e.class}: #{e.message}") if defined?(BSS064)
    @bss_right_camera_active=false
  end

  # A scripted trainer stays in the wide right-hand shot until its dialogue
  # ends. If no speech takes over, retire the trainer at the first command
  # with the SAME fade/return semantics; never leave the zoom stuck.
  def bss_camera_trainer_cleanup_tick
    return unless @bss_nds_trainer_staged
    return if @bss_dialogue_cinema_active ||
              @vermeil_cinema_script_depth.to_i>0 ||
              @vermeil_cinema_trainer_intro_depth.to_i>0 ||
              @bss087_end_battle_lock
    return unless @vermeil_cinema_first_command_reached
    unless @bss_trainer_cleanup_started
      @bss_trainer_cleanup_started=Time.now.to_f
      bss_camera_release_right_focus
    end
    t=[[(Time.now.to_f-@bss_trainer_cleanup_started)/0.30,0.0].max,1.0].min
    ease=t*t*(3.0-2.0*t)
    if @battle && @battle.respond_to?(:opponent) && @battle.opponent
      @battle.opponent.each_index do |i|
        sp=@sprites["trainer_#{i+1}"]
        next unless sp && !(sp.disposed? rescue true)
        sp.opacity=(255.0*(1.0-ease)).round if sp.respond_to?(:opacity=)
        sp.visible=false if t>=1.0 && sp.respond_to?(:visible=)
      end
    end
    @bss_trainer_cleanup_started=nil if t>=1.0
    @bss_nds_trainer_staged=false if t>=1.0
  end

  # The camera lease is applied before the generic cinematic director.
  # No second clock or camera sweep is allowed to fight this composition.
  def bss070_ebdx_tick(advance_camera=true,align=true)
    bss_camera_trainer_cleanup_tick if @bss_nds_trainer_staged
    if @bss_right_camera_active
      bss_camera_right_focus_tick
      return super(false,align)
    end
    super
  end

  def bss_camera_park_trainer(actor,index,force=false)
    return unless actor && (actor.visible rescue false)
    # Only anchor once per appearance. Repeatedly assigning X during a DBK
    # animation or dialogue causes jitter and instant teleportation.
    @bss_trainer_placed ||= {}
    key=[actor.object_id,index]
    return if @bss_trainer_placed[key] && !force
    x=bss_camera_trainer_side_x(actor,index)
    return unless x
    actor.x=x if actor.respond_to?(:x=)
    @bss_trainer_placed[key]=true
  end

  def bss_camera_relayer_trainers
    result=super
    return result unless @battle && @sprites && @battle.respond_to?(:opponent) && @battle.opponent
    @battle.opponent.each_index do |i|
      actor=@sprites["trainer_#{i+1}"]
      next unless actor && !(actor.disposed? rescue true)
      foe=@sprites["pokemon_#{2*i+1}"]
      foe_z=(foe && !(foe.disposed? rescue true)) ? foe.z.to_i : 50
      actor.z=[actor.z.to_i,foe_z+2,150+i].max if actor.respond_to?(:z=)
    end
    result
  rescue StandardError => e
    BSS064.log("Trainer depth: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(VermeilTrainerSideLanes)
  Battle::Scene.prepend(VermeilTrainerSideLanes)
end
