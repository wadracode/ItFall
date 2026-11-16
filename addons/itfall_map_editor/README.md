# ItFall Map Editor v0.2 — Standalone Terrain Workspace

**Dành cho Godot 4.7 / SmartShape2D 3.3.2.**

## Mục tiêu

**Người thiết kế map chỉ cần dùng ItFall Map Editor để tạo và chỉnh địa hình.** SmartShape2D là **bộ dựng địa hình khi Bake**, không phải công cụ bắt buộc người dùng phải thao tác.

Quy trình v2:

```text
ItFall Map Editor (cửa sổ riêng trong Godot)
    ├── Seed + tham số -> Generate
    ├── Viewport 2D -> Brush (Raise / Lower / Smooth / Flatten)
    ├── Cây, đá mẫu -> Redistribute
    ├── Save .tres -> nguồn dữ liệu để chỉnh tiếp
    └── Bake -> scene .tscn có SmartShape2D + collision
```

**Bản .tres là nguồn dữ liệu. Scene .tscn là đầu ra để đưa vào game.** Khi cần chỉnh terrain, mở lại .tres trong ItFall Map Editor rồi Bake một scene mới.

## Cách mở

1. Pull project `wadracode/ItFall`.
2. Mở bằng **Godot 4.7**.
3. Trong **Project → Project Settings → Plugins**, bật **SmartShape2D** và **ItFall Map Editor**.
4. Trên thanh menu của Godot, chọn **Project → Tools → ItFall Map Editor** (vị trí menu Tools có thể thay đổi theo bố cục Editor).
5. Cửa sổ `ItFall Map Editor v2 | Terrain Workspace` xuất hiện.

**Nếu cửa sổ bị nhúng trong Godot** thay vì nổi độc lập: vào **Editor → Editor Settings → Interface → Editor → Single Window Mode**, tắt tùy chọn này. Môi trường desktop Windows/macOS/Linux có hỗ trợ nhiều cửa sổ. Không cần chỉnh `project.godot`.

## Giao diện v2

**Bên trái**: tên map, seed, chiều dài, độ cao, độ biến thiên, khoảng cách đồi, độ sâu fill, mật độ cây/đá và brush.

**Ở giữa**: bản đồ toàn chiều dài. Chuột giữa/chuột phải (khuyên dùng chuột phải) để pan, con lăn để zoom, chuột trái dùng brush được chọn.

**Bên phải**: thông tin hiện tại, trạng thái Save và quy trình Bake.

**Trên cùng**: New, Open .tres, Save, Save As, Bake SmartShape, Open Baked, Fit map.

### Terrain Brushes

| Tool | Ý nghĩa |
| --- | --- |
| Pan | Chuột trái/phải kéo để di chuyển màn hình |
| Raise | Nâng mặt đất |
| Lower | Hạ mặt đất |
| Smooth | Làm mượt độ cao |
| Flatten | Đưa vùng địa hình về cùng cao độ tại thời điểm nhấn chuột |

- `Radius`: vùng ảnh hưởng của cọ, tính bằng world pixels.
- `Strength`: cường độ mỗi lượt.
- `Undo/Redo`: quay lại các lượt brush (tối đa 40 bước).
- Các điểm đầu/cuối map được giữ nguyên để thuận lợi kết nối tuyến map.
- Cây và đá tự đổi độ cao theo terrain khi brush hoạt động.

### Chú ý về Generate

- **Generate new terrain** áp dụng tham số, tạo một heightmap mới và thay thế terrain đang mở.
- Để giữ terrain đã chỉnh tay nhưng thay đổi phân bố cây/đá, dùng **Redistribute objects**.
- Nếu thay đổi seed, chiều dài hoặc thông số noise, phải nhấn Generate để các thay đổi có hiệu lực.
- Khi Generate, đường dẫn source trước đó được bỏ liên kết; bản cũ vẫn được lưu, không bị ghi đè ngầm.

## Save và Bake

| Nút | Tác dụng |
| --- | --- |
| Save / Save As | Lưu resource .tres với profile terrain đã sửa |
| Open .tres | Mở bản dữ liệu để chỉnh tiếp |
| Bake SmartShape | Tạo .tscn bằng **SS2D_Shape**, collision, cây/đá và marker A/B |
| Open Baked | Mở scene vừa xuất trong Godot Scene Editor |

File được lưu ở `res://generated_maps/` mặc định.

Nếu đã có nguồn .tres, mỗi lượt Bake tạo scene mới dạng `<tên>_bake.tscn`, `<tên>_bake_001.tscn`... **không ghi đè** scene được tạo trước đó.

Nếu chưa từng Save, nút Bake vẫn lưu nguồn .tres cùng một scene mới. Sau đó có thể dùng Save và tiếp tục chỉnh .tres như bình thường.

Baked scene gồm:
- `SmartShapeGround`: một **SS2D_Shape** đóng, có fill texture cỏ xuống phía dưới camera, có thể tạo mesh từ dữ liệu generator;
- `GroundCollision/SolidGround`: **StaticBody2D + CollisionPolygon2D**;
- `Environment`: cây/đá mẫu dạng Polygon2D;
- `SpawnPoints/Entrance_A` và `Entrance_B`.

Scene gốc `res://Terrain.tscn` **không bị thay đổi**. Không cần edit trực tiếp các control point của SmartShape2D để hoàn thành terrain bằng Map Editor.

## Giới hạn hiện tại

- **Viewport v2 là bản xem trước có thể sculpt**, không phải bản render SmartShape2D 1:1. Texture, lưới mesh và kết quả collision cần xem lại trong scene đã Bake.
- Biome khác đồng cỏ, hồ nước, texture tùy chọn, công trình, kết nối map runtime, chunk streaming, gameplay chặt cây và multiplayer **chưa triển khai**.
- Sửa trực tiếp SmartShape2D trong scene sau khi Bake **không tự đồng bộ ngược về .tres**. Muốn dữ liệu có thể tái tạo, hãy chỉnh trong ItFall Map Editor.
- Kích thước v0.2 giới hạn đến 30.000 px. Đó không phải cam kết hệ thống chunk hiệu năng cao.
- Chưa có test giao diện trực tiếp trong phiên làm việc tạo mã; cần mở Godot để kiểm tra cửa sổ, thao tác brush và bản baked thực tế.

## Kiểm thử

Đề xuất:

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://addons/itfall_map_editor/tests/smoke_test.gd
```

Smoke test kiểm tra seed determinism, không mất brush khi phân bố lại props, lưu/đọc .tres, tạo scene SmartShape + collision và Bake không ghi đè. Test tự xóa các file thử nghiệm nếu thành công.

**Kiểm tra thủ công bắt buộc sau khi bật plugin:**
1. Vào Tools → ItFall Map Editor, thử kéo cửa sổ sang màn hình khác.
2. Generate, zoom, pan, raise, smooth, flatten; thử Undo/Redo.
3. Save As, đóng cửa sổ, mở lại và Open .tres; địa hình đã sculpt phải giữ nguyên.
4. Bake SmartShape, Open Baked; xem fill và collision.
5. Bake lần hai; scene thứ nhất phải còn nguyên.

## Hướng phát triển kế tiếp

- Preview dùng trực tiếp SmartShape2D với bộ material/texture đúng biome.
- Hệ brush chỉnh sửa props, đường, sông, vùng xây dựng và đánh dấu landmarks.
- Chunks ở cấp map, giảm chi phí lưu/render/collision cho map rất dài.
- Quy trình đồng bộ thay đổi source từ Scene Editor nếu cần (hiện chưa hỗ trợ).

**Nguyên tắc:** ItFall Map Editor là nơi author terrain. SmartShape2D chỉ là một renderer có thể thay trong tương lai.
