#===============================================================================
# [VERMEIL] Visual 2.5D - 011_InteriorWalls.rb
# Punto de extension para muros interiores / techos recortados.
# Los mapas actuales solo extruyen muros frontales (010_FrontWalls). Este
# modulo queda como hook documentado por si se anaden techos en el futuro:
# la logica iria en update_walls (010) guardando las entradas de Priority > 2
# para recortarlas contra la proyeccion del techo.
#
# Mientras no haya un campo "InteriorWalls" en los mapas, este archivo no
# registra nada y solo documenta la extension. (ponytail: YAGNI => no se
# escribe codigo que no tiene consumidor.)
#===============================================================================
# Nada que hacer por ahora.