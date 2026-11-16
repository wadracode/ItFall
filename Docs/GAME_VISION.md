# ItFall — Game Vision (Working Draft)

> **Trạng thái:** Khởi tạo ý tưởng / chưa chốt GDD.  
> **Mục tiêu:** Ghi nhận tầm nhìn của người sáng tạo trước khi quyết định kiến trúc hoặc viết code.  
> **Nguyên tắc:** Phân biệt rõ **Định hướng đã nêu**, **Giả thuyết cần kiểm chứng**, và **Chưa quyết định**.

## 1. Tầm nhìn ban đầu

**ItFall** được hình dung là một trò chơi góc nhìn ngang trong Godot, với thế giới khám phá cực rộng và nhiều người chơi cùng tồn tại. Không gian cần đủ lớn để người chơi có thể tìm được những nơi vắng vẻ, có cảm giác riêng tư thay vì luôn gặp đám đông.

Đây là **bản mô tả ý tưởng**, không phải cam kết về thể loại, tính năng hoặc quy mô khi phát hành.

## 2. Những định hướng người sáng tạo đã nêu

### 2.1. Góc nhìn và phong cách thế giới
- Game có góc nhìn ngang (side-scrolling), tham khảo cảm giác quan sát và khám phá của Hollow Knight.
- Địa hình chủ yếu trải dài theo chiều ngang; ít phụ thuộc vào cấu trúc nhiều tầng phức tạp.
- Ưa thích cách thể hiện **2D giả chiều sâu / 2.5D**: thảm cỏ, sườn đồi hoặc vách địa hình trải về phía dưới khung hình, **không mặc định** hiển thị mặt cắt các lớp đất.
- Hình ảnh concept là mục tiêu thẩm mỹ/tham khảo, **không phải** asset hay bằng chứng rằng có thể tạo tự động giống hệt.

### 2.2. Tổ chức bản đồ thế giới
- Bản đồ tổng quan gồm các điểm địa lý và những đường nối giữa các điểm, ví dụ A—B, B—C.
- Mỗi đường nối biểu diễn một **map/tuyến khám phá** tương ứng với địa hình của vùng mà đường nối đi qua.
- Người chơi đến một đầu tuyến có thể chuyển sang tuyến liền kề hợp lệ.
- Thế giới dự kiến rất rộng, gồm nhiều tuyến map; số lượng và kích thước cụ thể chưa chốt.

### 2.3. Multiplayer và cảm giác riêng tư
- Mục tiêu là nhiều người cùng tồn tại trong một thế giới rất rộng, được phân bố trên các khu vực khác nhau.
- Người chơi có thể đi đến nơi xa xôi, ít người qua lại.
- Chỉ các map có người chơi hoặc sắp có người vào mới cần được kích hoạt để mô phỏng; map trống có thể ngừng mô phỏng để giảm tải server.
- **Chưa chốt:** một map có nhiều bản sao (instance) hay chỉ một bản duy nhất; kích hoạt theo map hay kết hợp chunk.

### 2.4. Địa hình và môi trường
- Mong muốn sản xuất nhiều khu vực bằng procedural generation hoặc phương pháp lai procedural + thủ công.
- Các môi trường đã được đưa ra để thử hình: đồng bằng có thảm cỏ kéo xuống dưới khung hình; đồi núi, cầu và hồ nước.
- SmartShape2D và TileMapLayer là **ứng viên nghiên cứu**, chưa được chọn làm công nghệ chính.
- Các hiệu ứng (mặt nước, thác, cỏ, cây, parallax, sương mù) cần được phân biệt với logic địa hình và kiểm chứng khả năng tái sử dụng.

## 3. Các nguyên tắc thiết kế đang hướng tới

1. **Thế giới rộng nhưng có ý nghĩa:** Cảm giác xa xôi, vắng vẻ; tránh tạo chiều dài trống rỗng chỉ để tăng quy mô.
2. **Thiết kế có thể tái sử dụng:** Asset và quy tắc địa hình đủ đơn giản để tạo ra nhiều khu vực.
3. **Thẩm mỹ phục vụ sản xuất:** Không phụ thuộc vào bức tranh vẽ tay độc nhất cho từng màn.
4. **Chỉ mô phỏng khi cần:** Ưu tiên tiết kiệm tải server ở những khu vực không có người.
5. **Ý tưởng trước, kỹ thuật sau:** Không chốt kiến trúc chỉ vì một công cụ có vẻ phù hợp.

## 4. Các câu hỏi thiết kế cần trả lời trước khi viết GDD

- Thể loại và **vòng lặp gameplay cốt lõi** của ItFall là gì?
- Bối cảnh, cảm xúc chủ đạo và mục tiêu lâu dài của người chơi?
- Người chơi tương tác với thế giới ở mức nào (khám phá, chiến đấu, thu thập, xây dựng, thay đổi địa hình...)?
- Thế giới là duy nhất hay có nhiều bản sao tuyến map khi đông người?
- Các điểm trên World Map là thành phố, ngã rẽ, vị trí địa lý hay loại nút khác?
- Khi chuyển map, thời gian, trạng thái thế giới và sự hiện diện của người chơi được thể hiện thế nào?
- Procedural generation được chạy trong công cụ làm game rồi lưu cố định hay chạy lúc khám phá?
- Những tiêu chí nào dùng để đánh giá một khu vực là thú vị, không lặp và đủ riêng tư?
- Phong cách hình ảnh nên gần pixel art, hand-painted tối giản hay hướng khác?

## 5. Giả thuyết kỹ thuật — **chưa phải quyết định**

| Chủ đề | Hướng cần kiểm chứng |
| --- | --- |
| Engine | Godot 4.x |
| Terrain | SmartShape2D / TileMapLayer / giải pháp custom |
| Hình ảnh | 2.5D giả chiều sâu, lớp tiền cảnh và hậu cảnh |
| Map streaming | Tải theo tuyến / chunk quanh người chơi |
| Server | Kích hoạt/cho ngủ map theo sự hiện diện của người chơi |
| World state | Lưu trạng thái và xử lý thời gian trôi qua khi map ngủ |
| Multiplayer | Phân vùng xử lý và chỉ đồng bộ thực thể gần người chơi |

> Không đưa các mục trên vào `AGENTS.md` dưới dạng yêu cầu bắt buộc cho Codex cho đến khi được thử nghiệm và chốt.

## 6. Quy trình cập nhật tài liệu

- Mỗi buổi thảo luận: bổ sung ý tưởng, nêu các phương án và lý do.
- Chỉ đánh dấu **Đã chốt** khi người sáng tạo xác nhận rõ.
- Nếu ý tưởng thay đổi, cập nhật lý do thay đổi thay vì âm thầm thay thế.
- Trước khi xây dựng prototype, viết tiêu chí kiểm chứng cụ thể và giới hạn phạm vi.
- Không bắt đầu viết code dựa trên bản nháp này.

## 7. Bước tiếp theo

**Ưu tiên làm rõ Game Vision và gameplay cốt lõi**, sau đó chuyển sang `GAMEPLAY.md` và `WORLD_DESIGN.md`. Kiến trúc kỹ thuật được xây dựng sau khi các yêu cầu gameplay đủ rõ.
