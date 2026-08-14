uniform mat4 projMat;
uniform vec2 texSizeInv;

uniform vec2 u_camera;       // cam_x, pivot_world_y
uniform vec2 u_optics;       // distance, focal
uniform vec2 u_angle;        // sin(alpha), cos(alpha)
uniform vec2 u_screen;       // center_x, pivot_y
uniform float u_camera_elevation; // altura fisica seguida por la camara
uniform float u_near;

attribute vec2 position;
attribute vec2 texCoord;

varying vec2 v_texCoord;

void main()
{
    // texCoord conserva la posicion absoluta dentro del bitmap del mapa.
    // La profundidad es lineal en Y, por lo que usarla como gl_Position.w
    // hace que la GPU interpole la textura con la perspectiva exacta del plano.
    vec2 world = texCoord;
    float dy = world.y - u_camera.y;
    // Ground esta en Z=0. Con una camara que sigue E, su elevacion relativa
    // es -E. Es la misma ecuacion usada por Mode7.perspective_project().
    float depth = u_optics.x - dy * u_angle.x +
                  u_camera_elevation * u_angle.y;
    float safeDepth = max(depth, u_near);

    float sx = u_screen.x + u_optics.y * (world.x - u_camera.x) / safeDepth;
    float vertical = dy * u_angle.y + u_camera_elevation * u_angle.x;
    float sy = u_screen.y + u_optics.y * vertical / safeDepth;

    // Multiplicar XY por W antes de la matriz ortografica mantiene sx/sy tras
    // la division de perspectiva y habilita interpolacion perspective-correct.
    gl_Position = projMat * vec4(sx * safeDepth, sy * safeDepth, 0.0, safeDepth);
    v_texCoord = texCoord * texSizeInv;
}
