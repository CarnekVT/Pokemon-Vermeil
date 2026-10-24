# encoding: UTF-8
# Contrato de catálogo y registro de formas sin dependencias de mkxp.
class Color
  attr_reader :red, :green, :blue
  def initialize(r=0,g=0,b=0,*);@red=r;@green=g;@blue=b;end
end
module Graphics
  def self.width;640;end
  def self.height;480;end
end
module GameData
  class Species
    Data = Struct.new(:species,:form,:name,:category,:height,:weight,:types,
                      :pokedex_entry,:form_name,:id_number) do
      def has_flag?(_);false;end
    end
    def self.try_get(id)
      return nil if id.nil?
      id = id.to_s.split("_").first.to_sym
      Data.new(id,0,id.to_s.capitalize,"Ratón",4,35,[:NORMAL],"Ficha",nil,1)
    end
    def self.get_species_form(id, form)
      d=try_get(id);return nil unless d
      d.form=form
      d.form_name = (form.to_i>0 ? "Variante #{form}" : nil)
      d.types = (form.to_i>0 ? [:DARK] : [:NORMAL])
      d
    end
    def self.each_species
      [:BULBASAUR,:RATTATA,:RATICATE].each{|id|yield try_get(id)}
    end
    def self.each_form_for_species(id)
      if id == :RATTATA
        yield get_species_form(id, 1)
        yield get_species_form(id, 2)
      end
    end
  end
end
require_relative "../LA BASE DE SKY/Plugins/[ZBOX] Nueva Pokedex/000_Config"
require_relative "../LA BASE DE SKY/Plugins/[ZBOX] Nueva Pokedex/main"

def check(value,message)
  raise "FAIL #{message}" unless value
  puts "OK #{message}"
end

Dir.chdir(File.expand_path("../LA BASE DE SKY",__dir__)) do
  regions=NuevaPokedex.enabled_dexes
  check(regions==[9],"La región 9 está habilitada y no se inventan regiones")
  slots=NuevaPokedex.regional_species(9)
  check(slots.length==66,"El catálogo conserva los 66 slots de Payu")
  check(slots.include?(:RATTATA_1),"La forma regional conserva su slot propio")
  check(NuevaPokedex.regional_species(-2).empty?,"No se permiten índices de región negativos")
  check(NuevaPokedex.regional_species(-1).empty?,"Nacional no se abre estando deshabilitada")
  model=NuevaPokedexData.new(9)
  check(model.slot_number_for(:RATTATA,1)==12,"Número regional de forma independiente")
  original=model.species_at(0)
  model.sort=:NAME
  check(model.data_for(0)[:number].is_a?(Integer),"La lista ordenada conserva números oficiales")
  model.sort=:NUM
  check(model.species_at(0)==original,"Orden numérico restaura el JSON original")
  idx=(0...model.species_count).find{|i| model.species_at(i)==:RATTATA_1}
  check(model.data_for(idx)[:form]==1,"Ficha de forma obtiene ID correcto")
  check(model.data_for(idx)[:types]==[:DARK],"La ficha utiliza los tipos de la forma")
  class DemoDex
    attr_accessor :seen_forms
    def initialize;@seen_forms=false;end
    def seen?(base);base==:RATTATA;end
    def owned?(base);base==:RATTATA;end
    def seen_form?(base,gender,form);base==:RATTATA && gender==0 && form==2 || (base==:RATTATA && gender==0 && form==1 && @seen_forms);end
  end
  class DemoPlayer
    attr_reader :pokedex
    def initialize;@pokedex=DemoDex.new;end
  end
  $player=DemoPlayer.new
  check(!NuevaPokedex.slot_seen?(:RATTATA_1),"La forma no se filtra como vista por ver solo la base")
  $player.pokedex.seen_forms=true
  check(NuevaPokedex.slot_seen?(:RATTATA_1),"Se registra forma vista con Essentials")
  scene=PokemonPokedexNueva_Scene.new(9)
  scene.instance_variable_set(:@current_index,idx)
  check(scene.collect_form_list==[1],"Un slot propio de forma no abre selector de formas")
  base_index=(0...model.species_count).find{|i|model.species_at(i)==:RATTATA}
  check(!base_index.nil?,"El catálogo tiene la especie base")
  scene.instance_variable_set(:@current_index,base_index)
  check(scene.collect_form_list==[0,2],"El selector excluye formas que poseen slot propio")
  base_entry=scene.instance_variable_get(:@model).data_for(base_index)
  $PokemonGlobal = Struct.new(:encounter_version).new(0)
  scene.store_display_form(base_entry,2)
  check(scene.selected_display_form(base_entry)==2,"Forma elegida persiste en la lista")
  second_scene = PokemonPokedexNueva_Scene.new(9)
  check(second_scene.selected_display_form(base_entry)==2,
        "Forma elegida permanece después de cerrar y reabrir la Pokédex")
  changed=scene.effective_entry(base_entry)
  check(changed[:types]==[:DARK] && changed[:number]==base_entry[:number],
        "Forma elegida actualiza ficha sin alterar el número regional")

  module GameData
    class Encounter
      def self.each_with_species(species, version)
        yield Struct.new(:map).new(14) if species == :RATTATA
      end
    end
    class MapMetadata
      def self.try_get(id)
        return nil unless id == 14
        obj = Struct.new(:name) do
          def has_flag?(_flag);false;end
        end
        obj.new("Ruta de prueba")
      end
    end
  end
  check(scene.locations_for_species(:RATTATA)==["Ruta de prueba"],
        "Ubicaciones desde los encuentros reales")
  check(scene.locations_for_species(:BULBASAUR)==[],
        "Especies sin ubicación devuelven lista vacía para mostrar Desconocida")
end
puts "Pokédex logic: OK"
