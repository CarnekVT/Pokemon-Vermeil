module GameData
  class TrainerType
    attr_accessor :sprite_offset
    attr_accessor :animation_speed

    SCHEMA["SpriteOffset"]    = [:sprite_offset,    "ii"]
    SCHEMA["AnimationSpeed"]  = [:animation_speed,  "u"]

    alias _zbox_tt_init_sprite_offset initialize
    def initialize(hash)
      _zbox_tt_init_sprite_offset(hash)
      @sprite_offset   = hash[:sprite_offset]   || [0, 0]
      @animation_speed = hash[:animation_speed] || 2
    end

    alias _zbox_tt_getpbs_sprite_offset get_property_for_PBS
    def get_property_for_PBS(key)
      ret = _zbox_tt_getpbs_sprite_offset(key)
      case key
      when "SpriteOffset"   then ret = nil if ret == [0, 0]
      when "AnimationSpeed" then ret = nil if ret == 2
      end
      return ret
    end

    def trainer_sprite_offset
      return @sprite_offset || [0, 0]
    end

    def trainer_animation_speed
      return @animation_speed || 2
    end
  end
end

class TrainerSpriteEditor
  def refresh
    if !@trainerID
      @sprites["trainer_1"].visible = false
      @sprites["shadow_1"].visible  = false
      @sprites["trainer_0"].visible = false
      @sprites["mugshot"].visible   = false
      @sprites["icon"].visible      = false
      return
    end
    data = GameData::TrainerType.get(@trainerID)
    offset = data.trainer_sprite_offset
    baseX, baseY = Battle::Scene.pbTrainerPosition(1)
    bitmap = @sprites["trainer_1"].iconBitmap
    if bitmap
      scale = data.trainer_sprite_scale
      hue = data.trainer_sprite_hue
      bitmap.scale = scale
      bitmap.refresh
      bitmap.hue_change(hue)
      speed_val = data.trainer_animation_speed
      speed_map = { 0 => 0, 1 => 0.75, 2 => 1.5, 3 => 3.0, 4 => 6.0 }
      bitmap.anim_speed = speed_map[speed_val] || 1.5 if bitmap.respond_to?(:anim_speed=)
      @sprites["trainer_1"].ox = bitmap.width / 2
      @sprites["trainer_1"].oy = bitmap.height
      @sprites["trainer_1"].x = baseX + offset[0]
      @sprites["trainer_1"].y = baseY + offset[1]
      @sprites["trainer_1"].visible = true
      bitmap = @sprites["shadow_1"].iconBitmap
      shadow = data.shadow_xy
      if shadow && bitmap
        bitmap.scale = scale
        bitmap.refresh
        @sprites["shadow_1"].ox = bitmap.width / 2
        @sprites["shadow_1"].oy = bitmap.height
        @sprites["shadow_1"].x = @sprites["trainer_1"].x + shadow[0]
        @sprites["shadow_1"].y = @sprites["trainer_1"].y + shadow[1]
        @sprites["shadow_1"].visible = data.shows_shadow?
      else
        @sprites["shadow_1"].visible = false
      end
    end
    bitmap = @sprites["trainer_0"].bitmap
    if bitmap
      if bitmap.width > bitmap.height * 2
        @sprites["trainer_0"].src_rect.x = 0
        @sprites["trainer_0"].src_rect.width = bitmap.width / 5
      end
      @sprites["trainer_0"].ox = @sprites["trainer_0"].src_rect.width / 2
      @sprites["trainer_0"].oy = bitmap.height
      @sprites["trainer_0"].visible = true
    end
    bitmap = @sprites["icon"].bitmap
    if bitmap
      charwidth  = @sprites["icon"].bitmap.width
      charheight = @sprites["icon"].bitmap.height
      @sprites["icon"].src_rect = Rect.new(0, 0, charwidth / 4, charheight / 4)
    end
  end

  alias _zbox_tse_orig_pbSetShadowPosition pbSetShadowPosition
  def pbSetShadowPosition
    data = GameData::TrainerType.get(@trainerID)
    if !data.shows_shadow? || data.shadow_xy.nil?
      pbMessage(_INTL("This trainer doesn't have a shadow to edit."))
      return
    end
    _zbox_tse_orig_pbSetShadowPosition
  end

  def pbSetSpritePosition
    data = GameData::TrainerType.get(@trainerID)
    offset = data.trainer_sprite_offset.clone
    oldoffset = offset.clone
    @sprites["info"].visible = true
    loop do
      Graphics.update
      Input.update
      self.update
      @sprites["info"].setTextToFit("Sprite Offset = #{offset[0]},#{offset[1]}")
      if Input.repeat?(Input::RIGHT) || Input.repeat?(Input::LEFT)
        offset[0] += (Input.repeat?(Input::RIGHT)) ? 1 : -1
        data.sprite_offset = offset
        refresh
      elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        offset[1] += (Input.repeat?(Input::DOWN)) ? 1 : -1
        data.sprite_offset = offset
        refresh
      elsif Input.repeat?(Input::USE)
        @trainerChanged = true if offset != oldoffset
        pbPlayDecisionSE
        break
      elsif Input.repeat?(Input::BACK)
        data.sprite_offset = oldoffset
        pbPlayCancelSE
        refresh
        break
      end
    end
    @sprites["info"].visible = false
  end

  def pbSetAnimationSpeed
    data = GameData::TrainerType.get(@trainerID)
    speed = data.trainer_animation_speed
    oldval = speed
    cmdvals = [0, 1, 2, 3, 4]
    commands = [
      _INTL("Very Fast"),
      _INTL("Fast"),
      _INTL("Normal"),
      _INTL("Slow"),
      _INTL("Very Slow")
    ]
    cw = Window_CommandPokemon.new(commands)
    cw.index    = speed
    cw.viewport = @viewport
    @sprites["info"].visible = true
    loop do
      Graphics.update
      Input.update
      cw.update
      self.update
      speed = cmdvals[cw.index]
      @sprites["info"].setTextToFit("Animation Speed = #{commands[cw.index]}")
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        data.animation_speed = speed
        @trainerChanged = true if speed != oldval
        break
      elsif Input.trigger?(Input::BACK)
        data.animation_speed = oldval
        pbPlayCancelSE
        break
      end
    end
    cw.dispose
    @sprites["info"].visible = false
  end

  alias _zbox_tse_orig_pbSetParameter pbSetParameter
  def pbSetParameter(param)
    return _zbox_tse_orig_pbSetParameter(param) if param < 5
    case param
    when 5 then pbSetSpritePosition
    when 6 then pbSetAnimationSpeed
    end
    @sprites["info"].visible = false
    return false
  end

  alias _zbox_tse_orig_pbMenu pbMenu
  def pbMenu
    cw = Window_CommandPokemon.new(
      [_INTL("Replay Animation"),
       _INTL("Set Sprite Scaling"),
       _INTL("Set Shadow Position"),
       _INTL("Set Shadow Visibility"),
       _INTL("Set Sprite Hue"),
       _INTL("Set Sprite Position"),
       _INTL("Set Animation Speed")]
    )
    cw.x        = Graphics.width - cw.width
    cw.y        = Graphics.height - cw.height
    cw.viewport = @viewport
    ret = -1
    loop do
      Graphics.update
      Input.update
      cw.update
      self.update
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = cw.index
        break
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        break
      end
    end
    cw.dispose
    return ret
  end
end

class Battle::Scene::TrainerSprite
  alias _zbox_ts_orig_pbSetPosition pbSetPosition
  def pbSetPosition
    _zbox_ts_orig_pbSetPosition
    return if !@_iconBitmap
    data = GameData::TrainerType.try_get(@tr_type)
    return if !data
    offset = data.trainer_sprite_offset
    self.x += offset[0]
    self.y += offset[1]
  end
end

class Battle::Scene::Animation::TrainerAppear
  def createProcesses
    delay = 0
    if @idxTrainer > 0 && @sprites["trainer_#{@idxTrainer}"].visible
      oldTrainer = addSprite(@sprites["trainer_#{@idxTrainer}"], PictureOrigin::BOTTOM)
      oldTrainer.moveDelta(delay, 8, Graphics.width / 4, 0)
      oldTrainer.setVisible(delay + 8, false)
      delay = oldTrainer.totalDuration
    end
    if @sprites["trainer_#{@idxTrainer + 1}"]
      trainerX, trainerY = Battle::Scene.pbTrainerPosition(1)
      sprite = @sprites["trainer_#{@idxTrainer + 1}"]
      if sprite.is_a?(Battle::Scene::TrainerSprite)
        data = GameData::TrainerType.try_get(sprite.tr_type)
        if data
          offset = data.trainer_sprite_offset
          trainerX += offset[0]
          trainerY += offset[1]
        end
      end
      trainerX += 64 + (Graphics.width / 4)
      newTrainer = addSprite(sprite, PictureOrigin::BOTTOM)
      newTrainer.setVisible(delay, true)
      newTrainer.setXY(delay, trainerX, trainerY)
      newTrainer.moveDelta(delay, 8, -Graphics.width / 4, 0)
    end
  end
end

class TrainerBitmapWrapper
  attr_accessor :anim_speed

  alias _zbox_tbw_orig_initialize initialize
  def initialize(file, scale = 1)
    _zbox_tbw_orig_initialize(file, scale)
    @anim_speed = nil
  end

  alias _zbox_tbw_orig_update update
  def update
    return if disposed? || @total_frames <= 1
    timer = System.uptime
    speed = @anim_speed || Settings::TRAINER_ANIMATION_SPEED
    delay = speed / @total_frames
    return if timer - @last_uptime < delay
    (@reversed) ? @frame_idx -= 1 : @frame_idx += 1
    @frame_idx = 0 if @frame_idx >= @total_frames
    @frame_idx = @total_frames - 1 if @frame_idx < 0
    @last_uptime = timer
  end
end

module GameData
  class TrainerType
    class << self
      alias _zbox_tt_orig_front_sprite_bitmap front_sprite_bitmap
      def front_sprite_bitmap(tr_type, filename = nil)
        ret = _zbox_tt_orig_front_sprite_bitmap(tr_type, filename)
        if ret.is_a?(TrainerBitmapWrapper) && self.exists?(tr_type)
          data = self.get(tr_type)
          speed_val = data.trainer_animation_speed
          speed_map = { 0 => 0, 1 => 0.75, 2 => 1.5, 3 => 3.0, 4 => 6.0 }
          ret.anim_speed = speed_map[speed_val] || 1.5
        end
        return ret
      end
    end
  end
end