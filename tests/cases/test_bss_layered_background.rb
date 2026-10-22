require "minitest/autorun"

# Lightweight RGSS stand-ins for the new source-preserving bitmap slices.
Rect=Struct.new(:x,:y,:width,:height) do
  def set(a,b,c,d)
    self.x=a;self.y=b;self.width=c;self.height=d
  end
end
class Bitmap
  attr_reader :width,:height
  attr_accessor :raw_data
  def initialize(w,h);@width=w;@height=h;@raw_data=nil;end
  def disposed?;false;end
end
class Tone
  attr_reader :red,:green,:blue,:gray
  def initialize(r,g,b,a=0);@red=r;@green=g;@blue=b;@gray=a;end
end
class Color
  attr_reader :red,:green,:blue,:alpha
  def initialize(r,g,b,a=255);@red=r;@green=g;@blue=b;@alpha=a;end
end
class Sprite
  attr_accessor :bitmap,:x,:y,:ox,:oy,:z,:zoom_x,:zoom_y,:angle,:opacity,:visible,:tone,:color
  attr_reader :src_rect
  def initialize(_viewport=nil)
    @src_rect=Rect.new(0,0,0,0)
    @x=200;@y=100;@ox=80;@oy=70;@z=0
    @zoom_x=1.2;@zoom_y=1.2;@angle=0;@opacity=255;@visible=true
    @disposed=false
  end
  def disposed?;@disposed;end
  def dispose;@disposed=true;end
end
class BSS070EBDXRoom;end
class BSS070CustomRoom < BSS070EBDXRoom;end
class Battle; class Scene;end;end
module BSSLightingClockBridge
  def self.slot(_=nil);:dawn;end
  def self.hour;19.0;end
end
require_relative "../../LA BASE DE SKY/Plugins/[CARNEK] Battle Scene Studio Runtime/90_CustomRooms/039_Lighting_Layered_Backdrops"

class BattleBackdropLayersTest < Minitest::Test
  def room(data={"sky"=>true})
    s=BSS070EBDXRoom.allocate
    original=Bitmap.new(384,308)
    bg=Sprite.new;bg.bitmap=original
    s.instance_variable_set(:@data,data)
    s.instance_variable_set(:@sprites,{"bg"=>bg})
    s.instance_variable_set(:@viewport,Object.new)
    [s,bg,original]
  end

  def test_preserves_bitmap_and_separates_three_screen_aligned_slices
    s,bg,bitmap=room
    s.bss_layered_split!
    slices=s.instance_variable_get(:@bss_layered_extra)
    assert_equal 2,slices.length
    assert_equal [0,92], [bg.src_rect.y,bg.src_rect.height]
    assert_equal [92,40], [slices[0].src_rect.y,slices[0].src_rect.height]
    assert_equal [132,176], [slices[1].src_rect.y,slices[1].src_rect.height]
    assert_same bitmap,slices[0].bitmap
    assert_same bitmap,slices[1].bitmap
    assert_equal bg.y,slices[1].y
    assert_equal bg.oy-132,slices[1].oy
  end

  def test_tree_colors_are_not_solid_black_and_dusk_horizon_is_warm
    s,bg,_=room
    tree=Sprite.new
    s.instance_variable_get(:@sprites)["tree0"]=tree
    s.bss_layered_split!
    s.bss_layered_apply_tone!(true)
    assert_operator tree.color.alpha,:>,0
    assert_operator tree.color.green,:>,0
    assert_operator bg.tone.red,:>,s.instance_variable_get(:@bss_layered_extra)[1].tone.red
    assert_operator s.instance_variable_get(:@bss_layered_extra)[0].color.alpha,:>,0
  end

  def test_real_alpha_segmentation_preserves_every_source_pixel
    s,bg,_old=room
    image=Bitmap.new(80,80)
    source=Array.new(80*80*4,0)
    80.times do |y|
      80.times do |x|
        rgb=y<32 ? [61,129,182] : (y<42 ? [242,182,82] : [55,137,66])
        i=(y*80+x)*4
        source[i,4]=rgb+[255]
      end
    end
    image.raw_data=source.pack('C*')
    bg.bitmap=image
    s.bss_layered_split!
    output=s.instance_variable_get(:@bss_layered_generated)
    assert_equal 3,output.length
    assert_same image,s.instance_variable_get(:@bss_layered_source)
    80.times do |y|
      80.times do |x|
        i=(y*80+x)*4
        count=output.count{|bmp| bmp.raw_data.getbyte(i+3)>0}
        assert_equal 1,count,"Source pixel must belong to exactly one layer"
      end
    end
    assert_equal 255,output[0].raw_data.getbyte((5*80+10)*4+3)
    assert_equal 255,output[2].raw_data.getbyte((74*80+10)*4+3)
  end

  def test_scanline_sky_detection_keeps_black_foreground_separate
    s,_,_=room
    w=16;h=12
    raw=+"".b
    h.times do |y|
      w.times do |x|
        # Bright blue gradient; an opaque tree occupies the far left.
        rgb=x<3 ? [5,22,14] : [85+y,150+y,205+y]
        raw << rgb.pack("C3") << [255].pack("C")
      end
    end
    palette=s.bss_layered_sky_palette(raw,w,h)
    assert_operator palette[5][2],:>,190
    sky_at=(5*w+6)*4
    tree_at=(5*w+1)*4
    sky_distance=(0..2).sum{|i|(raw.getbyte(sky_at+i)-palette[5][i]).abs}
    tree_distance=(0..2).sum{|i|(raw.getbyte(tree_at+i)-palette[5][i]).abs}
    assert_operator sky_distance,:<,112
    assert_operator tree_distance,:>,112
  end

  def test_disabled_indoor_and_custom_split_and_disposal
    s,_,_=room({"outdoor"=>false,"sky"=>true})
    s.bss_layered_split!
    assert_nil s.instance_variable_get(:@bss_layered_extra)
    s,bg,_=room({"sky"=>true,"skySplitY"=>75,"horizonSplitY"=>105})
    s.bss_layered_split!
    assert_equal 75,bg.src_rect.height
    slices=s.instance_variable_get(:@bss_layered_extra)
    assert_equal 105,slices[1].src_rect.y
    s.bss_layered_release!
    assert slices.all?(&:disposed?)
  end
end
