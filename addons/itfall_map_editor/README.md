# ItFall Map Editor v0.3 — Flat Terrain + Bézier Pen Tool

**Godot 4.7 / SmartShape2D 3.3.2** · Editor độc lập, không cần thao tác SmartShape2D thủ công.

## Thiết kế mới

ItFall không tạo địa hình từ seed trong quy trình chính. Người thiết kế bắt đầu bằng **một mặt đất phẳng** và sử dụng **Pen Tool** giống công cụ vẽ đường cong Bézier trong Photoshop:

1. **New Flat Map** với chiều dài và cao độ ban đầu.
2. **Pen**: click để đặt điểm neo; click–giữ–kéo để tạo hai tay đòn tiếp tuyến đối xứng, nối các đoạn thành đường cong mượt.
3. **Edit**: kéo điểm neo để di chuyển, kéo tay đòn để chỉnh độ dốc; giữ **Alt** khi kéo để điều chỉnh một tay đòn độc lập.
4. **Save** thành `.tres`: giữ toàn bộ điểm neo và tay đòn.
5. **Bake SmartShape** thành `.tscn`: đường Bézier được lấy mẫu, xuất SmartShape2D, texture cỏ và collision.

**Vì gameplay chỉ trên bề mặt**, địa hình được kéo xuống dưới camera và không lộ mặt cắt đất. Đây là hệ thống biên tập *đường mặt đất*, không phải công cụ vẽ hang động.

## Mở cửa sổ Map Editor

1. Pull repository `wadracode/ItFall` và mở bằng Godot 4.7.
2. Bật `ItFall Map Editor` và `SmartShape2D` trong **Project Settings → Plugins** nếu chưa bật.
3. Chọn **Project → Tools → ItFall Map Editor** (vị trí menu phụ thuộc phiên bản Godot).
4. Cửa sổ `ItFall Map Editor v0.3 | Pen Tool Terrain` sẽ hiện ra.

Nếu muốn cửa sổ tách riêng khỏi Godot: tắt **Editor Settings → Interface → Editor → Single Window Mode** (khi desktop hỗ trợ).

## Điều khiển

| Thao tác | Chức năng |
| --- | --- |
| Pen + click chỗ trống | Chèn anchor mới tại tọa độ chuột (theo thứ tự X) |
| Pen + click, giữ rồi kéo | Tạo/điều chỉnh hai tay đòn tiếp tuyến, nối đường cong mượt |
| Pen + click kéo anchor có sẵn | Chỉnh tay đòn của anchor đó |
| Edit + kéo anchor | Di chuyển anchor (giới hạn không vượt qua anchor kề) |
| Edit + kéo hình vuông màu cam | Kéo tay đòn Bézier |
| Alt + kéo tay đòn | Không tự đối xứng tay đòn còn lại |
| Chọn anchor + Delete / nút Delete | Xóa anchor nằm giữa; A và B không xóa |
| Ctrl+Z / Ctrl+Y | Undo / Redo (khi viewport được focus) |
| Chuột phải hoặc chuột giữa + kéo | Pan camera của editor |
| Con lăn | Zoom tại vị trí con trỏ |
| Fit | Xem toàn bộ chiều ngang map |

Hai anchor đầu/cuối luôn ở **X = 0** và **X = Length**, nhưng có thể chỉnh cao độ Y.
Khi thêm anchor, giữ cách nhau ít nhất 24 px theo trục X. Những tay đòn bị giới hạn theo khoảng cách X để đường cong luôn tiến từ trái sang phải, không tự quấn tạo vòng.

**Lưu ý thao tác:** Một cú click ngắn tạo góc nhọn (tay đòn bằng 0). Click rồi kéo tạo đoạn cong mượt. Sau khi vẽ, dùng Edit chỉnh cho vừa ý.

## Dữ liệu và xuất scene

`terrain_data.gd` lưu:

- `anchors`: tọa độ các điểm neo;
- `handles_in`: tay đòn đi vào, tính tương đối với anchor;
- `handles_out`: tay đòn đi ra, tính tương đối với anchor;
- `ground_points`: đường cong được lấy mẫu ở độ phân giải gần 12 px để SmartShape2D và collision sử dụng;
- `width_px`, `base_y`, `fill_depth_px`: kích thước và độ sâu phủ nền.

File `.tres` là **nguồn để chỉnh sửa**. File `.tscn` đã Bake chỉ là đầu ra. Bake lại sẽ tạo một scene mới (ví dụ `Grassland_AB_bake_001.tscn`), không ghi đè scene trước đó.

Baked scene có `SmartShapeGround`, `GroundCollision/SolidGround`, `SkyBackground` và `SpawnPoints/Entrance_A, Entrance_B`.

Texture mặc định:
- `res://assets/terrain/grassland/grassland_fill.svg`
- `res://assets/terrain/grassland/grassland_surface_edge.svg`

Bản v0.3 **không tự sinh cây/đá**, cũng chưa có texture picker, biome, parallax, object editor hay preview SmartShape2D trực tiếp. Những chức năng đó tạm để ngoài scope, tập trung hoàn thiện thao tác địa hình.

## Mở các map đã tạo bằng bản cũ

Khi mở `.tres` v0.2 chỉ có `ground_points`, editor chuyển từng điểm mẫu thành **corner anchor** với tay đòn bằng 0. Điều này giữ được đường địa hình cũ nhưng có thể tạo nhiều anchor. Bạn có thể xóa bớt hoặc lưu như nguồn v0.3.

Các thuộc tính seed/noise cũ vẫn còn trong Resource để **đọc được file legacy**, nhưng **không xuất hiện trên giao diện và không chi phối việc tạo map mới**.

Các file `terrain_generator.gd`, `editor_dock.gd`, `terrain_preview.gd` là code v0.1–0.2 *không còn được plugin hiện tại sử dụng*.

## Kiểm thử

Chạy trong root của project sau lần import đầu:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://addons/itfall_map_editor/tests/smoke_test.gd
```

Bài test kiểm tra tạo map phẳng, thêm/xóa anchor, đối xứng handles, lấy mẫu Bézier, lưu/đọc .tres, Bake scene SmartShape2D và không ghi đè scene cũ.

**Chưa có kiểm thử tương tác trực tiếp bằng Godot trong môi trường tác giả mã.** Nên test thủ công: Pen click+drag, Edit anchor và handle, Alt-drag, Undo/Redo, Save As → Open, Bake → Open Baked. Đặc biệt kiểm tra collider và hướng lặp texture ở các đoạn dốc.

## Nguyên tắc

**Pen Tool dựng đường mặt đất. SmartShape2D dựng hình và collision.** Mọi hệ thống parallax và trang trí cảnh quan sẽ được bổ sung như những thành phần riêng, không làm phức tạp việc vẽ địa hình.
