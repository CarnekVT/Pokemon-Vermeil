# ==============================================================================
# FIX: Editor de Animaciones — layout completo para 640x480
# ==============================================================================
if defined?(AnimationEditor)
  mw = AnimationEditor::MenuBar::TOTAL_WIDTH   # 258
  mh = AnimationEditor::MenuBar::TOTAL_HEIGHT  # 74
  c  = AnimationEditor::CONTAINER_BORDER        # 3
  sw = ::Settings::SCREEN_WIDTH                 # 640
  sh = ::Settings::SCREEN_HEIGHT                # 480

  nw = sw + (256 * 2) + (c * 6)
  nh = sh + 540 + (c * 4)
  nh = [nh, Graphics.display_height - 100].min
  nh = [nh, sh + 150 + (c * 4)].max

  cx = c + mw + (c * 2)   # 267
  cy = c                   # 3

  pc_y = cy + sh - 72
  be_x = cx + sw + (c * 2)
  pl_y = cy + sh + (c * 2)
  pl_w = be_x + mw - c

  AnimationEditor.send(:remove_const, :WINDOW_WIDTH)  if AnimationEditor.const_defined?(:WINDOW_WIDTH)
  AnimationEditor.const_set(:WINDOW_WIDTH, nw)
  AnimationEditor.send(:remove_const, :WINDOW_HEIGHT) if AnimationEditor.const_defined?(:WINDOW_HEIGHT)
  AnimationEditor.const_set(:WINDOW_HEIGHT, nh)

  AnimationEditor.send(:remove_const, :CANVAS_X)      if AnimationEditor.const_defined?(:CANVAS_X)
  AnimationEditor.const_set(:CANVAS_X, cx)
  AnimationEditor.send(:remove_const, :CANVAS_Y)      if AnimationEditor.const_defined?(:CANVAS_Y)
  AnimationEditor.const_set(:CANVAS_Y, cy)
  AnimationEditor.send(:remove_const, :CANVAS_WIDTH)  if AnimationEditor.const_defined?(:CANVAS_WIDTH)
  AnimationEditor.const_set(:CANVAS_WIDTH, sw)
  AnimationEditor.send(:remove_const, :CANVAS_HEIGHT) if AnimationEditor.const_defined?(:CANVAS_HEIGHT)
  AnimationEditor.const_set(:CANVAS_HEIGHT, sh)

  AnimationEditor.send(:remove_const, :PLAY_CONTROLS_Y) if AnimationEditor.const_defined?(:PLAY_CONTROLS_Y)
  AnimationEditor.const_set(:PLAY_CONTROLS_Y, pc_y)

  AnimationEditor.send(:remove_const, :BATTLERS_LAYOUT_HEIGHT) if AnimationEditor.const_defined?(:BATTLERS_LAYOUT_HEIGHT)
  AnimationEditor.const_set(:BATTLERS_LAYOUT_HEIGHT, pc_y - (c + mh) - (c * 4))

  AnimationEditor.send(:remove_const, :BATCH_EDITS_X) if AnimationEditor.const_defined?(:BATCH_EDITS_X)
  AnimationEditor.const_set(:BATCH_EDITS_X, be_x)
  AnimationEditor.send(:remove_const, :BATCH_EDITS_HEIGHT) if AnimationEditor.const_defined?(:BATCH_EDITS_HEIGHT)
  AnimationEditor.const_set(:BATCH_EDITS_HEIGHT, sh)

  AnimationEditor.send(:remove_const, :PARTICLE_LIST_Y) if AnimationEditor.const_defined?(:PARTICLE_LIST_Y)
  AnimationEditor.const_set(:PARTICLE_LIST_Y, pl_y)
  AnimationEditor.send(:remove_const, :PARTICLE_LIST_WIDTH) if AnimationEditor.const_defined?(:PARTICLE_LIST_WIDTH)
  AnimationEditor.const_set(:PARTICLE_LIST_WIDTH, pl_w)
  AnimationEditor.send(:remove_const, :PARTICLE_LIST_HEIGHT) if AnimationEditor.const_defined?(:PARTICLE_LIST_HEIGHT)
  AnimationEditor.const_set(:PARTICLE_LIST_HEIGHT, nh - pl_y - c)

  AnimationEditor.send(:remove_const, :MESSAGE_BOX_WIDTH) if AnimationEditor.const_defined?(:MESSAGE_BOX_WIDTH)
  AnimationEditor.const_set(:MESSAGE_BOX_WIDTH, nw * 3 / 4)

  AnimationEditor.send(:remove_const, :HELP_X) if AnimationEditor.const_defined?(:HELP_X)
  AnimationEditor.const_set(:HELP_X, (nw - 850) / 2)
  AnimationEditor.send(:remove_const, :HELP_Y) if AnimationEditor.const_defined?(:HELP_Y)
  AnimationEditor.const_set(:HELP_Y, (nh - 500) / 2)

  AnimationEditor.send(:remove_const, :EDITOR_SETTINGS_X) if AnimationEditor.const_defined?(:EDITOR_SETTINGS_X)
  AnimationEditor.const_set(:EDITOR_SETTINGS_X, (nw - 370) / 2)
  AnimationEditor.send(:remove_const, :EDITOR_SETTINGS_Y) if AnimationEditor.const_defined?(:EDITOR_SETTINGS_Y)
  AnimationEditor.const_set(:EDITOR_SETTINGS_Y, (nh - 218) / 2)

  AnimationEditor.send(:remove_const, :ANIM_PROPERTIES_X) if AnimationEditor.const_defined?(:ANIM_PROPERTIES_X)
  AnimationEditor.const_set(:ANIM_PROPERTIES_X, (nw - 370) / 2)
  AnimationEditor.send(:remove_const, :ANIM_PROPERTIES_Y) if AnimationEditor.const_defined?(:ANIM_PROPERTIES_Y)
  AnimationEditor.const_set(:ANIM_PROPERTIES_Y, (nh - 482) / 2)

  AnimationEditor.send(:remove_const, :PARTICLE_PROPERTIES_X) if AnimationEditor.const_defined?(:PARTICLE_PROPERTIES_X)
  AnimationEditor.const_set(:PARTICLE_PROPERTIES_X, (nw - 370) / 2)
  AnimationEditor.send(:remove_const, :PARTICLE_PROPERTIES_Y) if AnimationEditor.const_defined?(:PARTICLE_PROPERTIES_Y)
  AnimationEditor.const_set(:PARTICLE_PROPERTIES_Y, (nh - 674) / 2)

  be_ww = 470
  be_ph = (13 * 20) + (UIControls::List::LIST_FRAME_THICKNESS * 2)
  be_wh = 24 + 24 + be_ph + 4 + 24 + 4 - 1
  AnimationEditor.send(:remove_const, :BATCH_EDITOR_WINDOW_HEIGHT) if AnimationEditor.const_defined?(:BATCH_EDITOR_WINDOW_HEIGHT)
  AnimationEditor.const_set(:BATCH_EDITOR_WINDOW_HEIGHT, be_wh)
  AnimationEditor.send(:remove_const, :BATCH_EDITOR_X) if AnimationEditor.const_defined?(:BATCH_EDITOR_X)
  AnimationEditor.const_set(:BATCH_EDITOR_X, (nw - be_ww) / 2)
  AnimationEditor.send(:remove_const, :BATCH_EDITOR_Y) if AnimationEditor.const_defined?(:BATCH_EDITOR_Y)
  AnimationEditor.const_set(:BATCH_EDITOR_Y, (nh - be_wh) / 2)

  cfw = (150 * 2) + (UIControls::List::LIST_FRAME_THICKNESS * 2)
  cfh = (UIControls::List::ROW_HEIGHT * 15) + (UIControls::List::LIST_FRAME_THICKNESS * 2)
  gcww = c + cfw + 4 + 320 + 4 + c
  gcwh = 30 + cfh + 24 + c
  AnimationEditor.send(:remove_const, :GRAPHIC_CHOOSER_WINDOW_WIDTH) if AnimationEditor.const_defined?(:GRAPHIC_CHOOSER_WINDOW_WIDTH)
  AnimationEditor.const_set(:GRAPHIC_CHOOSER_WINDOW_WIDTH, gcww)
  AnimationEditor.send(:remove_const, :GRAPHIC_CHOOSER_WINDOW_HEIGHT) if AnimationEditor.const_defined?(:GRAPHIC_CHOOSER_WINDOW_HEIGHT)
  AnimationEditor.const_set(:GRAPHIC_CHOOSER_WINDOW_HEIGHT, gcwh)
  AnimationEditor.send(:remove_const, :GRAPHIC_CHOOSER_X) if AnimationEditor.const_defined?(:GRAPHIC_CHOOSER_X)
  AnimationEditor.const_set(:GRAPHIC_CHOOSER_X, (nw - gcww) / 2)
  AnimationEditor.send(:remove_const, :GRAPHIC_CHOOSER_Y) if AnimationEditor.const_defined?(:GRAPHIC_CHOOSER_Y)
  AnimationEditor.const_set(:GRAPHIC_CHOOSER_Y, (nh - gcwh) / 2)

  acww = c + cfw + (8 + 150) * 2 + c
  acwh = 30 + cfh + 24 + c
  AnimationEditor.send(:remove_const, :AUDIO_CHOOSER_WINDOW_WIDTH) if AnimationEditor.const_defined?(:AUDIO_CHOOSER_WINDOW_WIDTH)
  AnimationEditor.const_set(:AUDIO_CHOOSER_WINDOW_WIDTH, acww)
  AnimationEditor.send(:remove_const, :AUDIO_CHOOSER_WINDOW_HEIGHT) if AnimationEditor.const_defined?(:AUDIO_CHOOSER_WINDOW_HEIGHT)
  AnimationEditor.const_set(:AUDIO_CHOOSER_WINDOW_HEIGHT, acwh)
  AnimationEditor.send(:remove_const, :AUDIO_CHOOSER_X) if AnimationEditor.const_defined?(:AUDIO_CHOOSER_X)
  AnimationEditor.const_set(:AUDIO_CHOOSER_X, (nw - acww) / 2)
  AnimationEditor.send(:remove_const, :AUDIO_CHOOSER_Y) if AnimationEditor.const_defined?(:AUDIO_CHOOSER_Y)
  AnimationEditor.const_set(:AUDIO_CHOOSER_Y, (nh - acwh) / 2)
end
