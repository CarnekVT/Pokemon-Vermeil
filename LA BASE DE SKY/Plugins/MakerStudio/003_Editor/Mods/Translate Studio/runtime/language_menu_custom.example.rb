# encoding: UTF-8
# Translate Studio v1.1.0 - selector personalizado: CÓDIGO RUBY + IMÁGENES
# Actívalo en Translate Studio > UI de idioma > Código Ruby + imágenes.
#
# Las imágenes configuradas se mantienen disponibles en este modo:
#   Graphics/UI/TranslateStudio/language_bg.png
#   Graphics/UI/TranslateStudio/language_header.png
#   Graphics/UI/TranslateStudio/language_es.png
#   Graphics/UI/TranslateStudio/language_en.png
#   Graphics/UI/TranslateStudio/language_cursor.png
#   Graphics/UI/TranslateStudio/language_footer.png
#
# Devuelve "es" o "en". Devuelve nil únicamente para cancelar si allow_cancel es true.
module TranslateStudioLanguageUI
  def self.choose(initial_code = "es", allow_cancel = false)
    # Esta escena ya mezcla tu código con las imágenes configuradas arriba.
    # Puedes reemplazar este cuerpo por tu propia escena Sprite/Bitmap/Viewport
    # y leer las rutas desde CarnekTranslateStudio.config.
    CarnekTranslateStudio::LanguageScene.new(initial_code, allow_cancel).run
  end
end
