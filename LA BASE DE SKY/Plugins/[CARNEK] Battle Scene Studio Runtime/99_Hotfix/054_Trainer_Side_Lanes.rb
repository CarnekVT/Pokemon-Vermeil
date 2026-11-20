# frozen_string_literal: true
# Vermeil: keep real DBK trainers/speakers BESIDE, not layered behind, foes.
# Uses current visible pixel extents and respects multi-opponent formations.
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

  def bss_camera_trainer_side_x(trainer, trainer_index=0)
    return nil unless trainer && @sprites.is_a?(Hash) && @battle
    foes=[]
    @battle.battlers.each_index do |idx|
      next if idx.even?
      sp=@sprites["pokemon_#{idx}"]
      next if !sp || !(sp.visible rescue false)
      bounds=bss_camera_visible_span(sp)
      foes << bounds if bounds
    end
    return nil if foes.empty?
    actor=bss_camera_visible_span(trainer)
    return nil unless actor
    width=actor[1]-actor[0]
    ox_offset=trainer.x.to_f-actor[0]
    gap=14.0
    min_left=foes.map(&:first).min
    max_right=foes.map(&:last).max
    left_space=min_left-gap-10.0
    right_space=Graphics.width.to_f-max_right-gap-10.0
    # Place outside the WHOLE group, never between Meowth and Persian.
    right=(left_space>=width && right_space>=width) ?
            trainer_index.to_i.odd? : (right_space>=width || right_space>left_space)
    desired=right ? max_right+gap+ox_offset : min_left-gap-width+ox_offset
    minimum=10.0+ox_offset
    maximum=Graphics.width.to_f-10.0-width+ox_offset
    maximum=minimum if maximum<minimum
    [[desired,minimum].max,maximum].min
  rescue StandardError
    nil
  end

  def bss_camera_trainer_overlaps_foe?(trainer)
    current=bss_camera_visible_span(trainer)
    return false unless current && @battle && @sprites
    @battle.battlers.each_index do |idx|
      next if idx.even?
      sp=@sprites["pokemon_#{idx}"]
      next unless sp && (sp.visible rescue false)
      foe=bss_camera_visible_span(sp)
      return true if foe && current[0]<foe[1]+6 && current[1]>foe[0]-6
    end
    false
  rescue StandardError
    false
  end

  def bss_camera_park_trainer(trainer,index)
    return unless trainer && (trainer.visible rescue false)
    return unless bss_camera_trainer_overlaps_foe?(trainer)
    target=bss_camera_trainer_side_x(trainer,index)
    trainer.x=target if target && trainer.respond_to?(:x=)
  end

  def bss_camera_relayer_trainers
    result=super
    return result if @vermeil_cinema_trainer_intro_depth.to_i>0 || @bss_nds_intro_active
    return result if respond_to?(:inPartyAnimation?) && (inPartyAnimation? rescue false)
    if @battle && @battle.respond_to?(:opponent) && @battle.opponent
      @battle.opponent.each_index do |i|
        bss_camera_park_trainer(@sprites["trainer_#{i+1}"],i)
      end
    end
    result
  rescue StandardError => e
    BSS064.log("Trainer side-lane correction: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end

  def pbUpdate(*args,&block)
    result=super
    if @bss_dialogue_cinema_active && @sprites && @battle &&
       !(respond_to?(:inPartyAnimation?) && (inPartyAnimation? rescue false))
      bss_camera_park_trainer(@sprites["midbattle_speaker"],0)
    end
    result
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(VermeilTrainerSideLanes)
  Battle::Scene.prepend(VermeilTrainerSideLanes)
end
