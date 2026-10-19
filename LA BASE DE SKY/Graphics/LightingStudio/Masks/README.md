# Lighting Studio — Máscaras de luz PNG

Coloca aquí imágenes PNG que definan directamente la forma de una fuente luminosa.

**Formato:** PNG RGBA en escala de grises. Se admite un máximo de 512×512 píxeles por archivo. No se aceptan rutas arbitrarias: solo nombres simples como `cueva_salida.png`.

- **Blanco opaco:** emisión máxima.
- **Gris:** emisión intermedia.
- **Negro o transparencia:** zona sin emisión.
- **Borde difuminado:** crea gradientes suaves en la propia imagen.

Para la salida de una cueva, dibuja el contorno de luz que debería proyectarse hacia el exterior: coloca blanco/crema en el área principal, degrada los extremos a gris y deja transparente todo lo que quede detrás de las paredes. No copies el dibujo del muro entero: el PNG debe describir únicamente el área iluminada.

En Maker Studio → Lighting Studio:
1. Crea o selecciona una fuente de luz y elige `Máscara PNG`.
2. Especifica, por ejemplo, `cueva_salida.png`.
3. Configura anchura/altura (tamaño de la proyección en píxeles del mundo), rotación, color e intensidad.
4. Usa «Comprobar PNG» y activa «Ver luces en mapa».

La imagen se carga tanto en la vista previa como en el runtime. El runtime recolorea los valores RGB con el color de la luz y conserva luminancia y transparencia. Es una **máscara real** y no un cono geométrico aproximado. La superposición usa un sprite dinámico para respetar el contorno, incluso si cambia la pulsación.
