#===============================================================================
# Battle Scene Studio v0.8.14
# Background layer deformation / curvature authority.
#
# JSON schema (inside img###):
#   :warp => {
#     :enabled => true,
#     :mode    => "quad" | "mesh",
#     :cols    => 2..5,
#     :rows    => 2..5,
#     :quality => 1..4,
#     :points  => [[local_x,local_y], ... row-major; before layer scale/angle]
#   }
#
# Essentials/RGSS sprites do not expose a native arbitrary texture mesh on every
# supported renderer. BSS therefore renders a portable adaptive micro-mesh made
# from independent bitmap tiles. Each tile follows the local tangent of the
# authored control grid. Higher quality increases subdivision and makes curved
# layers visually smooth while keeping the original EBDX camera authoritative.
#===============================================================================
module BSS093WarpMeshAuthority
  VERSION = "0.8.15"

  def bss093_num(v, fallback=0.0)
    # Never use Float(v) as validation here. mkxp/Essentials debug tracing logs
    # every rescued Float(nil) as an exception, and this method runs once per
    # mesh point/tile every frame. Validate without raising instead.
    return fallback.to_f if v.nil?
    return v.to_f if v.is_a?(Numeric)
    str=v.to_s.strip
    return fallback.to_f if str.empty?
    return str.to_f if str =~ /\A[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?\z/
    fallback.to_f
  end

  def bss093_warp_config(data)
    return nil if !data.is_a?(Hash)
    w=data[:warp]
    return nil if !w.is_a?(Hash) || w[:enabled] != true
    cols=[[bss093_num(w[:cols],2).to_i,2].max,5].min
    rows=[[bss093_num(w[:rows],2).to_i,2].max,5].min
    raw=w[:points]
    return nil if !raw.is_a?(Array) || raw.length < cols*rows
    pts=[]
    (cols*rows).times do |i|
      p=raw[i]
      return nil if !p.is_a?(Array) || p.length < 2
      pts << [bss093_num(p[0],0.0),bss093_num(p[1],0.0)]
    end
    quality=[[bss093_num(w[:quality],4).to_i,1].max,6].min
    {:cols=>cols,:rows=>rows,:quality=>quality,:points=>pts,:mode=>w[:mode].to_s}
  rescue
    nil
  end

  def bss093_sample_warp(cfg,u,v)
    u=[[u.to_f,0.0].max,1.0].min
    v=[[v.to_f,0.0].max,1.0].min
    gx=u*(cfg[:cols]-1); gy=v*(cfg[:rows]-1)
    x0=[gx.floor,cfg[:cols]-2].min; y0=[gy.floor,cfg[:rows]-2].min
    tx=gx-x0; ty=gy-y0
    idx=lambda { |x,y| cfg[:points][y*cfg[:cols]+x] }
    p00=idx.call(x0,y0); p10=idx.call(x0+1,y0)
    p01=idx.call(x0,y0+1); p11=idx.call(x0+1,y0+1)
    ax=p00[0]+(p10[0]-p00[0])*tx; ay=p00[1]+(p10[1]-p00[1])*tx
    bx=p01[0]+(p11[0]-p01[0])*tx; by=p01[1]+(p11[1]-p01[1])*tx
    [ax+(bx-ax)*ty, ay+(by-ay)*ty]
  end

  def bss093_dispose_tile_entry(entry)
    return if !entry
    sp=entry[:sprite] rescue nil
    begin
      bmp=sp.bitmap if sp && !(sp.disposed? rescue true)
      sp.bitmap=nil if sp && sp.respond_to?(:bitmap=)
      bmp.dispose if bmp && !(bmp.disposed? rescue false)
    rescue
    end
    begin
      sp.dispose if sp && !(sp.disposed? rescue false)
    rescue
    end
  end

  def bss093_dispose_warp_layer!(key)
    return if !@bss093_warp_layers.is_a?(Hash)
    row=@bss093_warp_layers.delete(key.to_s)
    return if !row
    (row[:tiles] || []).each { |entry| bss093_dispose_tile_entry(entry) }
  rescue
  end

  def bss093_dispose_warp_tiles!
    if @bss093_warp_layers.is_a?(Hash)
      @bss093_warp_layers.keys.clone.each { |k| bss093_dispose_warp_layer!(k) }
    end
    @bss093_warp_layers={}
  rescue
    @bss093_warp_layers={}
  end

  def bss076_dispose_owned_sprites!
    bss093_dispose_warp_tiles!
    super
  end

  def drawImg(key)
    ret=super
    begin
      bss093_build_warp_layer!(key)
    rescue => e
      echoln("[BSS093] Warp layer #{key} skipped: #{e.class}: #{e.message}") if defined?(echoln)
    end
    ret
  end

  def bss093_build_warp_layer!(raw_key)
    key=raw_key.to_s
    data=@data[raw_key] || @data[key]
    cfg=bss093_warp_config(data)
    return if !cfg
    root=@sprites[key] || @sprites[raw_key]
    return if !root || (root.disposed? rescue true) || !root.bitmap || (root.bitmap.disposed? rescue true)

    @bss093_warp_layers||={}
    bss093_dispose_warp_layer!(key)

    # Portable subdivision. Hard-cap total sprites to avoid pathological JSON.
    quality=cfg[:quality]
    subdiv=[quality*2,2].max
    seg_x=(cfg[:cols]-1)*subdiv
    seg_y=(cfg[:rows]-1)*subdiv
    while seg_x*seg_y > 768 && subdiv>2
      subdiv-=1
      seg_x=(cfg[:cols]-1)*subdiv; seg_y=(cfg[:rows]-1)*subdiv
    end
    seg_x=[seg_x,1].max; seg_y=[seg_y,1].max
    src=root.bitmap
    tiles=[]
    seg_y.times do |iy|
      sy0=(iy*src.height.to_f/seg_y).floor
      sy1=((iy+1)*src.height.to_f/seg_y).ceil
      sh=[sy1-sy0,1].max
      seg_x.times do |ix|
        sx0=(ix*src.width.to_f/seg_x).floor
        sx1=((ix+1)*src.width.to_f/seg_x).ceil
        sw=[sx1-sx0,1].max
        bmp=Bitmap.new(sw,sh)
        bmp.blt(0,0,src,Rect.new(sx0,sy0,sw,sh))
        sp=BSS070EBDXSprite.new(@viewport)
        sp.bitmap=bmp
        sp.ox=sw/2.0; sp.oy=sh/2.0
        sp.z=root.z
        sp.opacity=root.opacity
        sp.visible=false
        tiles << {
          :sprite=>sp,:sw=>sw.to_f,:sh=>sh.to_f,
          :u0=>ix.to_f/seg_x,:u1=>(ix+1).to_f/seg_x,
          :v0=>iy.to_f/seg_y,:v1=>(iy+1).to_f/seg_y
        }
      end
    end
    root.visible=false
    @bss093_warp_layers[key]={:root=>root,:data=>data,:config=>cfg,:tiles=>tiles}
  end

  def bss093_project_point(root,data,cfg,u,v)
    bg=@sprites && @sprites["bg"]
    return [0.0,0.0] if !bg
    rel=bss093_sample_warp(cfg,u,v)
    general=data.has_key?(:zoom) ? bss093_num(data[:zoom],1.0) : 1.0
    zx=data.has_key?(:zoom_x) ? bss093_num(data[:zoom_x],general) : general
    zy=data.has_key?(:zoom_y) ? bss093_num(data[:zoom_y],general) : general
    rad=bss093_num(data[:angle],0.0)*Math::PI/180.0
    cs=Math.cos(rad); sn=Math.sin(rad)
    lx=rel[0]*zx; ly=rel[1]*zy
    tx=lx*cs-ly*sn; ty=lx*sn+ly*cs
    ax=(root.respond_to?(:ex) && !root.ex.nil?) ? root.ex.to_f : bss093_num(data[:x],0)
    ay=(root.respond_to?(:ey) && !root.ey.nil?) ? root.ey.to_f : bss093_num(data[:y],0)
    cx=bg.x.to_f-(bg.ox.to_f-ax)*bg.zoom_x.to_f
    cy=bg.y.to_f-(bg.oy.to_f-ay)*bg.zoom_y.to_f
    # EBDX uses bg.zoom_y only for flat layers. Depth layers use horizontal
    # perspective for both axes, matching the final independent-scale authority.
    ry=(data[:flat] == true) ? bg.zoom_y.to_f : bg.zoom_x.to_f
    [cx+tx*bg.zoom_x.to_f, cy+ty*ry]
  end

  def bss093_copy_sprite_visuals(root,sp)
    sp.z=root.z if sp.respond_to?(:z=)
    sp.opacity=root.opacity if sp.respond_to?(:opacity=)
    sp.blend_type=root.blend_type if sp.respond_to?(:blend_type=) && root.respond_to?(:blend_type)
    begin; sp.tone=root.tone if sp.respond_to?(:tone=) && root.respond_to?(:tone); rescue; end
    begin; sp.color=root.color if sp.respond_to?(:color=) && root.respond_to?(:color); rescue; end
  rescue
  end

  def bss093_update_warp_tiles!
    return if !@bss093_warp_layers.is_a?(Hash) || @bss093_warp_layers.empty?
    visible_state=@bss093_visible_state.nil? ? true : @bss093_visible_state
    @bss093_warp_layers.each do |key,row|
      root=row[:root]; data=row[:data]; cfg=row[:config]
      next if !root || (root.disposed? rescue true) || !data || !cfg
      root.visible=false if root.respond_to?(:visible=)
      row[:tiles].each do |entry|
        sp=entry[:sprite]; next if !sp || (sp.disposed? rescue true)
        u0=entry[:u0];u1=entry[:u1];v0=entry[:v0];v1=entry[:v1]
        uc=(u0+u1)*0.5; vc=(v0+v1)*0.5
        pc=bss093_project_point(root,data,cfg,uc,vc)
        pl=bss093_project_point(root,data,cfg,u0,vc); pr=bss093_project_point(root,data,cfg,u1,vc)
        pt=bss093_project_point(root,data,cfg,uc,v0); pb=bss093_project_point(root,data,cfg,uc,v1)
        hx=pr[0]-pl[0]; hy=pr[1]-pl[1]
        vx=pb[0]-pt[0]; vy=pb[1]-pt[1]
        hlen=Math.sqrt(hx*hx+hy*hy)
        angle=Math.atan2(hy,hx)
        nx=-Math.sin(angle); ny=Math.cos(angle)
        vproj=(vx*nx+vy*ny).abs
        vlen=Math.sqrt(vx*vx+vy*vy)
        vproj=vlen if vproj < 0.01
        # Slight overlap hides sampling seams produced by bilinear filtering.
        sp.x=pc[0]; sp.y=pc[1]
        sp.angle=angle*180.0/Math::PI
        sp.zoom_x=[hlen/[entry[:sw],0.001].max*1.018,0.001].max
        sp.zoom_y=[vproj/[entry[:sh],0.001].max*1.018,0.001].max
        bss093_copy_sprite_visuals(root,sp)
        sp.visible=visible_state
      end
    end
  rescue => e
    echoln("[BSS093] Warp update skipped: #{e.class}: #{e.message}") if defined?(echoln)
  end

  def position
    ret=super
    bss093_update_warp_tiles!
    ret
  end

  def visible=(val)
    ret=super
    @bss093_visible_state=!!val
    if @bss093_warp_layers.is_a?(Hash)
      @bss093_warp_layers.each_value do |row|
        begin; row[:root].visible=false if row[:root] && row[:root].respond_to?(:visible=); rescue; end
        (row[:tiles] || []).each do |entry|
          sp=entry[:sprite] rescue nil
          sp.visible=!!val if sp && !(sp.disposed? rescue true)
        end
      end
    end
    ret
  end

  def focus
    ret=super
    bss093_update_warp_tiles!
    ret
  end

  def defocus
    ret=super
    bss093_update_warp_tiles!
    ret
  end
end

begin
  if defined?(BSS070EBDXRoom) && !(BSS070EBDXRoom.ancestors.include?(BSS093WarpMeshAuthority) rescue false)
    BSS070EBDXRoom.prepend(BSS093WarpMeshAuthority)
  end
rescue => e
  echoln("[BSS093] Warp mesh authority install skipped: #{e.class}: #{e.message}") if defined?(echoln)
end
