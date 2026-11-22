# frozen_string_literal: true
# Regression contracts for native Notebook/Pokedex UI driven by MakerStudio.
# Runs on a normal Ruby interpreter; no mkxp-z or Game.exe dependency.
require "json"
require "minitest/autorun"

ROOT = File.expand_path("../LA BASE DE SKY", __dir__)
BRIDGE = File.join(ROOT,"Plugins/[VERMEIL] Research Notebook/002_Interface_Layouts.rb")

module Interfaces
  module AnalizadorJSON
    def self.analizar(text,_filename)
      JSON.parse(text)
    end
  end
end

class Color
  attr_accessor :red,:green,:blue,:alpha
  def initialize(r,g,b,a=255)
    @red,@green,@blue,@alpha=r,g,b,a
  end
end

class StubFont
  attr_accessor :size,:bold,:color
  def initialize
    @size=16;@bold=false
  end
end

class StubCanvas
  attr_reader :ops,:font
  attr_accessor :width,:height
  def initialize(width=640,height=480)
    @ops=[];@font=StubFont.new
    @width=width;@height=height
  end
  def fill_rect(x,y,w,h,color)
    @ops << [:panel,x,y,w,h,color.red,color.green,color.blue,color.alpha]
  end
  def draw_text(x,y,w,h,content,align=0)
    @ops << [:text,x,y,w,h,content,align,@font.size]
  end
end

require BRIDGE

class NativeUILayoutContractsTest < Minitest::Test
  PAGES={
    :notebook => ["Libreta/Catalogo","Libreta/Ficha"],
    :pokedex => ["Pokedex/Lista","Pokedex/Ficha",
                 "Pokedex/Area","Pokedex/Formas"]
  }.freeze

  def setup
    @cwd=Dir.pwd
    Dir.chdir(ROOT)
  end

  def teardown
    Dir.chdir(@cwd)
    VermeilInterfaceLayout.release_images
  end

  def test_every_native_page_has_valid_unique_ids_and_actual_layer_geometry
    PAGES.each_value do |names|
      names.each do |name|
        file=File.join("UI",name+".json")
        assert File.file?(file),"Missing native UI screen: #{file}"
        obj=JSON.parse(File.read(file))
        assert_equal 640,obj.fetch("lienzo").fetch("ancho")
        assert_equal 480,obj.fetch("lienzo").fetch("alto")
        items=obj.fetch("elementos")
        ids=items.map { |e| e.fetch("id") }
        assert_equal ids.length,ids.uniq.length,"Duplicate ids: #{name}"
        ids.each do |id|
          assert_match(/\A[a-zA-Z][a-zA-Z0-9_]*\z/,id)
        end
        items.each do |entry|
          assert entry["ancho"].to_f>0 || %w[imagen animado].include?(entry["tipo"]),
            "#{name}.#{entry["id"]} has no width"
          assert entry["alto"].to_f>0 || %w[imagen animado].include?(entry["tipo"]),
            "#{name}.#{entry["id"]} has no height"
        end
      end
    end
  end

  def test_native_layout_loads_canonical_library_and_retains_page_identity
    PAGES.each do |kind,names|
      data=VermeilInterfaceLayout.load(kind)
      names.each do |name|
        json=JSON.parse(File.read("UI/#{name}.json"))
        ids=json.fetch("elementos").map { |e| e.fetch("id") }
        ids.each do |id|
          scoped=data.fetch("__pages").fetch(name)
          assert scoped.key?(id),"#{kind} did not load #{name}/#{id}"
          assert_equal name,scoped.fetch(id).fetch("__page")
        end
      end
    end
  end

  def test_all_shipped_native_objects_are_reserved_to_prevent_static_duplicates
    PAGES.values.flatten.each do |name|
      ids=JSON.parse(File.read("UI/#{name}.json")).fetch("elementos").map{|e|e.fetch("id")}
      native=VermeilInterfaceLayout::NATIVE_IDS.fetch(name)
      assert_empty(ids - native),"#{name} had a shipped component that is also drawn as an EXTRA"
    end
  end

  def test_runtime_orders_panels_by_editor_layer_not_ruby_method_order
    layout={
      "above"=>{"__page"=>"Example","tipo"=>"panel","x"=>0,"y"=>0,
                "ancho"=>4,"alto"=>4,"capa"=>80,"color"=>"#FF0000"},
      "below"=>{"__page"=>"Example","tipo"=>"panel","x"=>0,"y"=>0,
                "ancho"=>4,"alto"=>4,"capa"=>5,"color"=>"#00FF00"}
    }
    bmp=StubCanvas.new
    painted=VermeilInterfaceLayout.render_document(bmp,layout,
        "Example",%w[above below])
    assert_equal %w[below above],painted
    assert_equal [0,255],bmp.ops.map{|o|o[5]}
    assert_equal [255,0],bmp.ops.map{|o|o[6]}
  end

  def test_dynamic_species_name_is_live_but_uses_editor_geometry
    layout={
      "list_name"=>{
        "__page"=>"Pokedex/Lista","tipo"=>"texto",
        "x"=>370,"y"=>45,"ancho"=>220,"alto"=>30,"tamano"=>19,
        "color"=>"#FFFFFF","texto"=>"DEMO","capa"=>10
      }
    }
    bitmap=StubCanvas.new
    painted=VermeilInterfaceLayout.render_document(bitmap,layout,
      "Pokedex/Lista",%w[list_name],
      {"list_name"=>{"texto"=>"Venusaur","x"=>382,"y"=>110}},
      300,20)
    assert_equal ["list_name"],painted
    assert_equal [:text,82,90,220,30,"Venusaur",0,19],bitmap.ops.last
  end

  def test_entrance_state_does_not_override_a_permanently_hidden_layer
    layout={
      "hidden"=>{"__page"=>"Example","tipo"=>"panel","x"=>0,"y"=>0,
                 "ancho"=>10,"alto"=>10,"color"=>"#FFFFFF",
                 "visible"=>false}
    }
    bmp=StubCanvas.new
    assert_empty VermeilInterfaceLayout.render_document(bmp,layout,"Example",%w[hidden])
    assert_empty bmp.ops
  end

  def test_bss_no_longer_builds_black_square_mosaic_or_duplicate_trainer_slide
    path=File.join(ROOT,"Plugins/[CARNEK] Battle Scene Studio Runtime",
                   "99_Hotfix/050_NDS_Intro_Camera_Handoff.rb")
    source=File.read(path)
    refute_includes source,"mosaic_bitmap.fill_rect"
    refute_includes source,"def bss_nds_slide_trainers"
    assert_includes source,"bss_nds_present_trainers"
    assert_includes source,"bss_nds_fade_trainer_actor"
  end
end
