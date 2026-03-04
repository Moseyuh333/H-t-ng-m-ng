# =============================================================================
# NETWORK INFRASTRUCTURE 3D MODEL - SketchUp Ruby Script
# LAB02: Mô hình phân lớp - Thiết lập & Cấu hình mạng LAN
# Tác giả: Tự động sinh từ sơ đồ mạng
# =============================================================================
# HƯỚNG DẪN SỬ DỤNG:
#   1. Mở SketchUp
#   2. Vào Extensions > Ruby Console
#   3. Paste toàn bộ script này và nhấn Enter
#   HOẶC: File > Import > chọn file .rb này
# =============================================================================

module NetworkModel3D

  # -----------------------------------------------------------------------
  # CÀI ĐẶT MÀU SẮC THEO LOẠI THIẾT BỊ
  # -----------------------------------------------------------------------
  COLORS = {
    building_wall:    Sketchup::Color.new(220, 220, 200),
    building_floor:   Sketchup::Color.new(180, 160, 130),
    building_roof:    Sketchup::Color.new(150, 100,  70),
    floor_label:      Sketchup::Color.new(240, 240, 255),

    # Thiết bị mạng
    core_switch:      Sketchup::Color.new( 30, 100, 200),   # Xanh đậm
    dist_switch:      Sketchup::Color.new( 60, 160,  80),   # Xanh lá
    acc_switch:       Sketchup::Color.new(100, 180, 240),   # Xanh nhạt
    router:           Sketchup::Color.new(200,  80,  40),   # Đỏ cam
    firewall:         Sketchup::Color.new(220, 140,  30),   # Vàng cam
    server:           Sketchup::Color.new(160,  60, 160),   # Tím
    pc:               Sketchup::Color.new(200, 200, 200),   # Xám

    # Dây cáp
    cable_trunk:      Sketchup::Color.new(255,  50,  50),   # Đỏ = trunk
    cable_access:     Sketchup::Color.new( 50, 200,  50),   # Xanh = access
    cable_uplink:     Sketchup::Color.new( 50,  50, 255),   # Xanh = uplink
    cable_internet:   Sketchup::Color.new(255, 200,   0),   # Vàng = internet
    cable_dmz:        Sketchup::Color.new(255, 100, 200),   # Hồng = DMZ

    # VLAN màu sắc (Building 1)
    vlan10: Sketchup::Color.new(255, 200, 200),
    vlan11: Sketchup::Color.new(255, 220, 180),
    vlan12: Sketchup::Color.new(255, 240, 160),
    vlan13: Sketchup::Color.new(200, 255, 200),
    vlan14: Sketchup::Color.new(180, 255, 220),
    vlan15: Sketchup::Color.new(160, 220, 255),
    vlan16: Sketchup::Color.new(200, 180, 255),

    # VLAN màu sắc (Building 2)
    vlan20: Sketchup::Color.new(255, 160, 160),
    vlan21: Sketchup::Color.new(255, 180, 130),
    vlan22: Sketchup::Color.new(255, 200, 100),
    vlan23: Sketchup::Color.new(150, 255, 150),
    vlan24: Sketchup::Color.new(130, 255, 200),
    vlan25: Sketchup::Color.new(110, 200, 255),
    vlan26: Sketchup::Color.new(170, 140, 255),
  }

  # -----------------------------------------------------------------------
  # KÍCH THƯỚC (tính bằng inches, SketchUp default)
  # 1 đơn vị = 1 foot = 304.8 mm
  # -----------------------------------------------------------------------
  U = 1.0  # 1 unit = 1 foot

  BUILDING_W  = 40 * U   # Chiều rộng tòa nhà
  BUILDING_D  = 30 * U   # Chiều sâu tòa nhà
  FLOOR_H     =  5 * U   # Chiều cao mỗi tầng
  WALL_T      =  0.5 * U # Độ dày tường
  DEVICE_H    =  0.8 * U # Chiều cao thiết bị
  RACK_W      =  1.5 * U
  RACK_D      =  1.0 * U
  RACK_H      =  3.0 * U

  # -----------------------------------------------------------------------
  # VỊ TRÍ CÁC TÒA NHÀT RONG KHÔNG GIAN 3D
  # -----------------------------------------------------------------------
  # Layout tổng thể:
  #   [Building 1]  [Core/Network Core]  [Building 2]
  #   [DMZ Zone]    [Internal Servers]   [Internet/ISP]
  #
  #   Trục X: Ngang (Đông - Tây)
  #   Trục Y: Sâu (Bắc - Nam)
  #   Trục Z: Cao (Lên - Xuống)

  POSITIONS = {
    building1:   [  0,   0, 0],   # Tòa nhà 1 (trái)
    core_room:   [ 55,   0, 0],   # Phòng Core/Dist
    building2:   [105,   0, 0],   # Tòa nhà 2 (phải)
    dmz_room:    [  0,  45, 0],   # DMZ Zone (trước-trái)
    server_room: [ 55,  45, 0],   # Internal Servers
    internet:    [105,  45, 0],   # Internet/ISP Zone
  }

  # -----------------------------------------------------------------------
  # UTILITY: Tạo hộp (box) có màu và nhãn
  # -----------------------------------------------------------------------
  def self.make_box(model, x, y, z, w, d, h, color, name = nil)
    ents = model.active_entities
    grp  = ents.add_group
    g    = grp.entities

    pts = [
      [x,   y,   z],
      [x+w, y,   z],
      [x+w, y+d, z],
      [x,   y+d, z],
    ]
    face = g.add_face(pts)
    face.pushpull(h)

    mat = model.materials.add(name || "mat_#{rand(9999)}")
    mat.color = color
    grp.material = mat
    grp.name     = name || ""
    grp
  end

  # -----------------------------------------------------------------------
  # UTILITY: Tạo đường cáp (pipe) giữa 2 điểm
  # -----------------------------------------------------------------------
  def self.make_cable(model, p1, p2, color, label = "")
    ents = model.active_entities
    grp  = ents.add_group
    g    = grp.entities

    edge = g.add_line(
      Geom::Point3d.new(*p1),
      Geom::Point3d.new(*p2)
    )

    mat = model.materials.add("cable_#{label}_#{rand(9999)}")
    mat.color = color
    grp.material = mat
    grp.name = "Cable: #{label}"
    grp
  end

  # -----------------------------------------------------------------------
  # UTILITY: Vẽ tầng nhà (sàn + tường + mái)
  # -----------------------------------------------------------------------
  def self.make_floor_shell(model, bx, by, bz, bw, bd, fh, wt, label)
    # Sàn
    make_box(model, bx, by, bz, bw, bd, wt * 0.5, COLORS[:building_floor], "#{label}_floor")

    # Tường 4 mặt
    make_box(model, bx,        by,        bz, bw,  wt, fh, COLORS[:building_wall], "#{label}_wall_S")
    make_box(model, bx,        by+bd-wt,  bz, bw,  wt, fh, COLORS[:building_wall], "#{label}_wall_N")
    make_box(model, bx,        by,        bz, wt,  bd, fh, COLORS[:building_wall], "#{label}_wall_W")
    make_box(model, bx+bw-wt,  by,        bz, wt,  bd, fh, COLORS[:building_wall], "#{label}_wall_E")

    # Mái nhẹ (nửa trong suốt)
    make_box(model, bx, by, bz+fh, bw, bd, wt * 0.3, COLORS[:building_roof], "#{label}_roof")
  end

  # -----------------------------------------------------------------------
  # UTILITY: Tạo thiết bị mạng (rack + device box)
  # -----------------------------------------------------------------------
  def self.make_device(model, x, y, z, color, label, size = 1.0)
    s = size
    make_box(model, x - RACK_W*s*0.5, y - RACK_D*s*0.5, z,
             RACK_W*s, RACK_D*s, DEVICE_H*s, color, "DEV: #{label}")
  end

  # -----------------------------------------------------------------------
  # UTILITY: Tạo nhóm PC (4 PC nhỏ thành cụm)
  # -----------------------------------------------------------------------
  def self.make_pc_cluster(model, cx, cy, z, vlan_color, label)
    offsets = [[-0.8,-0.8], [0.8,-0.8], [-0.8,0.8], [0.8,0.8]]
    offsets.each_with_index do |(ox, oy), i|
      make_box(model, cx+ox - 0.3, cy+oy - 0.3, z,
               0.6, 0.6, 0.5, vlan_color, "PC_#{label}_#{i+1}")
    end
  end

  # -----------------------------------------------------------------------
  # XÂY DỰNG TÒA NHÀ 1 (BUILDING 1) - 3 tầng
  # Zone: 172.16.0.0/16
  # Tầng 1 (Ground): Acc-SW1 + PCs (VLAN 10,11,12)
  # Tầng 2:          Acc-SW2 + PCs (VLAN 12,13,14)
  # Tầng 3:          Acc-SW3 + PCs (VLAN 13,15,16)
  # Tầng kỹ thuật:   Dist-SW1
  # -----------------------------------------------------------------------
  def self.build_building1(model)
    bx, by, bz = POSITIONS[:building1]
    bw, bd = BUILDING_W, BUILDING_D

    3.times do |floor|
      fz     = bz + floor * FLOOR_H
      flabel = "B1_F#{floor+1}"
      make_floor_shell(model, bx, by, fz, bw, bd, FLOOR_H, WALL_T, flabel)
    end

    # ---- Tầng 1: Acc-SW1 + VLAN 10, 11, 12 ----
    fz = bz + 1.0
    make_device(model, bx+8,  by+15, fz, COLORS[:acc_switch], "Acc-SW1")
    # VLAN 10 PCs
    make_pc_cluster(model, bx+6,  by+6,  fz, COLORS[:vlan10], "V10")
    # VLAN 11 PCs
    make_pc_cluster(model, bx+18, by+6,  fz, COLORS[:vlan11], "V11")
    # VLAN 12 PCs
    make_pc_cluster(model, bx+32, by+6,  fz, COLORS[:vlan12], "V12")

    # ---- Tầng 2: Acc-SW2 + VLAN 12, 13, 14 ----
    fz = bz + FLOOR_H + 1.0
    make_device(model, bx+8,  by+15, fz, COLORS[:acc_switch], "Acc-SW2")
    make_pc_cluster(model, bx+6,  by+6,  fz, COLORS[:vlan12], "V12_2")
    make_pc_cluster(model, bx+18, by+6,  fz, COLORS[:vlan13], "V13")
    make_pc_cluster(model, bx+32, by+6,  fz, COLORS[:vlan14], "V14")

    # ---- Tầng 3: Acc-SW3 + VLAN 13, 15, 16 ----
    fz = bz + FLOOR_H*2 + 1.0
    make_device(model, bx+8,  by+15, fz, COLORS[:acc_switch], "Acc-SW3")
    make_pc_cluster(model, bx+6,  by+6,  fz, COLORS[:vlan13], "V13_2")
    make_pc_cluster(model, bx+18, by+6,  fz, COLORS[:vlan15], "V15")
    make_pc_cluster(model, bx+32, by+6,  fz, COLORS[:vlan16], "V16")

    # ---- Tầng kỹ thuật (tầng trên cùng tòa nhà): Dist-SW1 ----
    fz = bz + FLOOR_H*3 + 0.5
    make_floor_shell(model, bx, by, fz, bw, bd, FLOOR_H*0.6, WALL_T, "B1_Tech")
    make_device(model, bx+20, by+15, fz+0.5, COLORS[:dist_switch], "Dist-SW1", 1.2)

    puts "  [OK] Building 1 - 3 tầng + tầng kỹ thuật"
  end

  # -----------------------------------------------------------------------
  # XÂY DỰNG TÒA NHÀ 2 (BUILDING 2) - 3 tầng
  # Zone: 172.20.0.0/16
  # Tầng 1: Acc-SW4 + PCs (VLAN 20,21,22)
  # Tầng 2: Acc-SW5 + PCs (VLAN 23,24,25)
  # Tầng 3: Acc-SW6 + PCs (VLAN 20,23,26)
  # Tầng kỹ thuật: Dist-SW2
  # -----------------------------------------------------------------------
  def self.build_building2(model)
    bx, by, bz = POSITIONS[:building2]
    bw, bd = BUILDING_W, BUILDING_D

    3.times do |floor|
      fz     = bz + floor * FLOOR_H
      flabel = "B2_F#{floor+1}"
      make_floor_shell(model, bx, by, fz, bw, bd, FLOOR_H, WALL_T, flabel)
    end

    # ---- Tầng 1: Acc-SW4 + VLAN 20, 21, 22 ----
    fz = bz + 1.0
    make_device(model, bx+8,  by+15, fz, COLORS[:acc_switch], "Acc-SW4")
    make_pc_cluster(model, bx+6,  by+6,  fz, COLORS[:vlan20], "V20")
    make_pc_cluster(model, bx+18, by+6,  fz, COLORS[:vlan21], "V21")
    make_pc_cluster(model, bx+32, by+6,  fz, COLORS[:vlan22], "V22")

    # ---- Tầng 2: Acc-SW5 + VLAN 23, 24, 25 ----
    fz = bz + FLOOR_H + 1.0
    make_device(model, bx+8,  by+15, fz, COLORS[:acc_switch], "Acc-SW5")
    make_pc_cluster(model, bx+6,  by+6,  fz, COLORS[:vlan23], "V23")
    make_pc_cluster(model, bx+18, by+6,  fz, COLORS[:vlan24], "V24")
    make_pc_cluster(model, bx+32, by+6,  fz, COLORS[:vlan25], "V25")

    # ---- Tầng 3: Acc-SW6 + VLAN 20, 23, 26 ----
    fz = bz + FLOOR_H*2 + 1.0
    make_device(model, bx+8,  by+15, fz, COLORS[:acc_switch], "Acc-SW6")
    make_pc_cluster(model, bx+6,  by+6,  fz, COLORS[:vlan20], "V20_2")
    make_pc_cluster(model, bx+18, by+6,  fz, COLORS[:vlan23], "V23_2")
    make_pc_cluster(model, bx+32, by+6,  fz, COLORS[:vlan26], "V26")

    # ---- Tầng kỹ thuật: Dist-SW2 ----
    fz = bz + FLOOR_H*3 + 0.5
    make_floor_shell(model, bx, by, fz, bw, bd, FLOOR_H*0.6, WALL_T, "B2_Tech")
    make_device(model, bx+20, by+15, fz+0.5, COLORS[:dist_switch], "Dist-SW2", 1.2)

    puts "  [OK] Building 2 - 3 tầng + tầng kỹ thuật"
  end

  # -----------------------------------------------------------------------
  # PHÒNG CORE NETWORK (giữa 2 tòa nhà) - 2 tầng
  # Tầng 1: Core-SW (trung tâm)
  # Tầng 2: Firewall + Gateway Router R1
  # -----------------------------------------------------------------------
  def self.build_core_room(model)
    cx, cy, cz = POSITIONS[:core_room]
    rw, rd = 20 * U, 25 * U

    # Shell tầng 1
    make_floor_shell(model, cx, cy, cz, rw, rd, FLOOR_H, WALL_T, "Core_F1")
    # Shell tầng 2
    make_floor_shell(model, cx, cy, cz+FLOOR_H, rw, rd, FLOOR_H, WALL_T, "Core_F2")

    # Core-SW ở tầng 1 - trung tâm
    make_device(model, cx+10, cy+12, cz+1, COLORS[:core_switch], "Core-SW", 1.5)

    # Firewall ở tầng 2
    make_device(model, cx+5,  cy+12, cz+FLOOR_H+1, COLORS[:firewall], "Firewall", 1.3)

    # Gateway Router R1 ở tầng 2
    make_device(model, cx+15, cy+12, cz+FLOOR_H+1, COLORS[:router], "Gateway-R1", 1.1)

    puts "  [OK] Core Network Room - 2 tầng"
  end

  # -----------------------------------------------------------------------
  # KHU VỰC DMZ (phía trước, bên trái)
  # Web Server (192.168.100.111) + E-Mail Server (192.168.100.222)
  # Network: 192.168.100.0/24
  # -----------------------------------------------------------------------
  def self.build_dmz(model)
    dx, dy, dz = POSITIONS[:dmz_room]
    rw, rd = 25 * U, 20 * U

    make_floor_shell(model, dx, dy, dz, rw, rd, FLOOR_H, WALL_T, "DMZ")

    # Web Server .111
    make_device(model, dx+6,  dy+10, dz+1, COLORS[:server], "WebSrv(.111)", 1.0)
    # E-Mail Server .222
    make_device(model, dx+18, dy+10, dz+1, COLORS[:server], "MailSrv(.222)", 1.0)
    # DMZ Switch (access switch nội bộ DMZ)
    make_device(model, dx+12, dy+5,  dz+1, COLORS[:acc_switch], "DMZ-SW", 0.8)

    puts "  [OK] DMZ Zone"
  end

  # -----------------------------------------------------------------------
  # PHÒNG INTERNAL SERVERS
  # DHCP Server (.254) + DNS Server (.253)
  # Network: 10.50.50.0/24
  # -----------------------------------------------------------------------
  def self.build_server_room(model)
    sx, sy, sz = POSITIONS[:server_room]
    rw, rd = 20 * U, 20 * U

    make_floor_shell(model, sx, sy, sz, rw, rd, FLOOR_H, WALL_T, "SrvRoom")

    # Server-SW1
    make_device(model, sx+10, sy+5,  sz+1, COLORS[:acc_switch], "Server-SW1", 0.9)
    # DHCP Server .254
    make_device(model, sx+5,  sy+12, sz+1, COLORS[:server], "DHCP(.254)", 1.0)
    # DNS Server .253
    make_device(model, sx+15, sy+12, sz+1, COLORS[:server], "DNS(.253)", 1.0)

    puts "  [OK] Internal Server Room"
  end

  # -----------------------------------------------------------------------
  # KHU VỰC INTERNET / ISP
  # ISP Router + Web Server (.200) + VPN Client (.100)
  # -----------------------------------------------------------------------
  def self.build_internet_zone(model)
    ix, iy, iz = POSITIONS[:internet]
    rw, rd = 25 * U, 20 * U

    make_floor_shell(model, ix, iy, iz, rw, rd, FLOOR_H*0.5, WALL_T, "Internet")

    # ISP Router
    make_device(model, ix+6,  iy+10, iz+1, COLORS[:router], "ISP-Router", 1.0)
    # Internet Web Server .200
    make_device(model, ix+16, iy+10, iz+1, COLORS[:server], "WebSrv.200", 0.9)
    # VPN Client .100
    make_device(model, ix+6,  iy+4,  iz+1, COLORS[:pc], "VPN-Client", 0.7)

    puts "  [OK] Internet/ISP Zone"
  end

  # -----------------------------------------------------------------------
  # VẼ CÁC ĐƯỜNG CÁP LIÊN KẾT THEO SƠ ĐỒ MẠNG
  # -----------------------------------------------------------------------
  def self.draw_cables(model)

    # Tọa độ trung tâm các thiết bị (x, y, z)
    b1x, b1y = POSITIONS[:building1][0], POSITIONS[:building1][1]
    b2x, b2y = POSITIONS[:building2][0], POSITIONS[:building2][1]
    cx,  cy  = POSITIONS[:core_room][0], POSITIONS[:core_room][1]
    dx,  dy  = POSITIONS[:dmz_room][0],  POSITIONS[:dmz_room][1]
    sx,  sy  = POSITIONS[:server_room][0], POSITIONS[:server_room][1]
    ix,  iy  = POSITIONS[:internet][0],  POSITIONS[:internet][1]

    # Điểm gốc (giữa) các thiết bị
    core_sw    = [cx+10, cy+12, 1.8]
    dist_sw1   = [b1x+20, b1y+15, FLOOR_H*3+1.0]
    dist_sw2   = [b2x+20, b2y+15, FLOOR_H*3+1.0]
    firewall   = [cx+5,  cy+12, FLOOR_H+1.4]
    gw_r1      = [cx+15, cy+12, FLOOR_H+1.4]
    acc_sw1    = [b1x+8, b1y+15, 1.8]
    acc_sw2    = [b1x+8, b1y+15, FLOOR_H+1.8]
    acc_sw3    = [b1x+8, b1y+15, FLOOR_H*2+1.8]
    acc_sw4    = [b2x+8, b2y+15, 1.8]
    acc_sw5    = [b2x+8, b2y+15, FLOOR_H+1.8]
    acc_sw6    = [b2x+8, b2y+15, FLOOR_H*2+1.8]
    dmz_sw     = [dx+12, dy+5,  1.8]
    srv_sw1    = [sx+10, sy+5,  1.8]
    isp_router = [ix+6,  iy+10, 1.8]

    cables = [
      # Core ↔ Dist-SW1 (L3 EtherChannel Po11) - trunk đỏ
      [core_sw,  dist_sw1,  COLORS[:cable_trunk],   "Po11_Core-DistSW1"],
      # Core ↔ Dist-SW2 (L3 EtherChannel Po12) - trunk đỏ
      [core_sw,  dist_sw2,  COLORS[:cable_trunk],   "Po12_Core-DistSW2"],
      # Core ↔ Server-SW1 (L3 EtherChannel Po13) - uplink xanh
      [core_sw,  srv_sw1,   COLORS[:cable_uplink],  "Po13_Core-SrvSW1"],

      # Dist-SW1 ↔ Acc-SW1 (L2 EtherChannel Po1) - trunk đỏ
      [dist_sw1, acc_sw1,   COLORS[:cable_trunk],   "Po1_DistSW1-AccSW1"],
      # Dist-SW1 ↔ Acc-SW2 (L2 EtherChannel Po2) - trunk đỏ
      [dist_sw1, acc_sw2,   COLORS[:cable_trunk],   "Po2_DistSW1-AccSW2"],
      # Dist-SW1 ↔ Acc-SW3 (L2 EtherChannel Po3) - trunk đỏ
      [dist_sw1, acc_sw3,   COLORS[:cable_trunk],   "Po3_DistSW1-AccSW3"],

      # Dist-SW2 ↔ Acc-SW4 (L2 EtherChannel Po4) - trunk đỏ
      [dist_sw2, acc_sw4,   COLORS[:cable_trunk],   "Po4_DistSW2-AccSW4"],
      # Dist-SW2 ↔ Acc-SW5 (L2 EtherChannel Po5) - trunk đỏ
      [dist_sw2, acc_sw5,   COLORS[:cable_trunk],   "Po5_DistSW2-AccSW5"],
      # Dist-SW2 ↔ Acc-SW6 (L2 EtherChannel Po6) - trunk đỏ
      [dist_sw2, acc_sw6,   COLORS[:cable_trunk],   "Po6_DistSW2-AccSW6"],

      # Firewall ↔ Core-SW (10.10.10.0/24) - uplink
      [firewall, core_sw,   COLORS[:cable_uplink],  "FW-Core_10.10.10.0"],
      # Firewall ↔ DMZ Switch (192.168.100.0/24) - DMZ
      [firewall, dmz_sw,    COLORS[:cable_dmz],     "FW-DMZ_192.168.100.0"],
      # Firewall ↔ Gateway R1 (192.168.200.0/24) - uplink
      [firewall, gw_r1,     COLORS[:cable_uplink],  "FW-GWR1_192.168.200.0"],

      # Gateway R1 ↔ ISP (203.1.1.4/30) - internet
      [gw_r1,    isp_router, COLORS[:cable_internet], "R1-ISP_203.1.1.4/30"],
    ]

    cables.each do |p1, p2, color, label|
      make_cable(model, p1, p2, color, label)
    end

    puts "  [OK] #{cables.length} đường cáp đã vẽ"
  end

  # -----------------------------------------------------------------------
  # HÀM CHÍNH - CHẠY TẤT CẢ
  # -----------------------------------------------------------------------
  def self.run
    model = Sketchup.active_model
    model.start_operation("NetworkModel3D", true)

    begin
      puts "=============================================="
      puts " ĐANG XÂY DỰNG MÔ HÌNH MẠNG 3D..."
      puts "=============================================="

      build_building1(model)
      build_building2(model)
      build_core_room(model)
      build_dmz(model)
      build_server_room(model)
      build_internet_zone(model)
      draw_cables(model)

      # Đặt camera nhìn tổng quan (isometric)
      eye    = Geom::Point3d.new(80, -60, 80)
      target = Geom::Point3d.new(80,  25, 10)
      up     = Geom::Vector3d.new(0,   0,  1)
      model.active_view.camera = Sketchup::Camera.new(eye, target, up)

      model.commit_operation
      puts "=============================================="
      puts " HOÀN THÀNH! Mô hình 3D đã được tạo."
      puts ""
      puts " LEGEND (màu sắc):"
      puts "  - Xanh đậm  = Core Switch"
      puts "  - Xanh lá   = Distribution Switch"
      puts "  - Xanh nhạt = Access Switch"
      puts "  - Đỏ cam    = Router"
      puts "  - Vàng cam  = Firewall"
      puts "  - Tím       = Server"
      puts ""
      puts "  CABLES:"
      puts "  - Đỏ    = Trunk / EtherChannel"
      puts "  - Xanh  = Access Link"
      puts "  - Xanh navy = Uplink L3"
      puts "  - Vàng  = Internet Link"
      puts "  - Hồng  = DMZ Link"
      puts "=============================================="

    rescue => e
      model.abort_operation
      puts "LỖI: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

end

# CHẠY SCRIPT
NetworkModel3D.run
