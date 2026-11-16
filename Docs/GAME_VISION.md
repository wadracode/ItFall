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


## 8. Tầm nhìn sandbox emergent — cập nhật từ người sáng tạo

**Định hướng đã được người sáng tạo nêu rõ:**

ItFall không định giới hạn người chơi trong một vài lớp nhân vật, nghề nghiệp hay chuỗi nhiệm vụ cố định. Mọi người bắt đầu từ **tay trắng (nothing)**, có thể khai thác và biến đổi tài nguyên, rồi tự lựa chọn cuộc sống và vai trò của mình trong một thế giới chung.

Những hoạt động được người sáng tạo trực tiếp nêu:
- Chặt cây, săn bắt, thu thập và chế tác.
- Xây nhà hàng gần nơi người khác săn quái, cung cấp đồ ăn/dịch vụ cho họ.
- Xây bệnh viện; phát triển nông trại; mở xưởng sản xuất đồ dùng.
- Trao đổi hàng hóa và hợp tác hoặc tập hợp để đánh boss.

**Tư tưởng chủ đạo:** Gameplay được hình thành từ tương tác của người chơi, công cụ, tài nguyên, công trình và hệ thống thế giới; không chỉ từ các hoạt động do nhà phát triển viết sẵn. Ví dụ chuỗi hoạt động có thể là: người thu thập → người sản xuất → người kinh doanh → người đi săn → người cung cấp dịch vụ hỗ trợ.

**Lưu ý phạm vi:** Mong muốn 'không giới hạn gameplay' là một **tầm nhìn thiết kế mở**, không phải tuyên bố phần mềm có thể hỗ trợ mọi hành vi bất kỳ. Muốn mở rộng bền vững cần xác định các quy tắc, thành phần tương tác và khả năng kết hợp dùng chung; tính năng mới được thêm từng bước và có tiêu chí kiểm chứng.

### 8.1. Những trụ cột thiết kế được đề xuất để thảo luận (chưa chốt kỹ thuật)
1. **Common world simulation:** hệ vật phẩm, tài nguyên, thuộc tính, thời gian và quy tắc tương tác nhất quán.
2. **Actions & skills:** hành động tổng quát như khai thác, sử dụng, chế tạo, xây, vận chuyển, trao đổi, phục vụ; kỹ năng không buộc vào một nghề cố định.
3. **Compositional crafting & production:** đầu vào → công cụ/quy trình → đầu ra, hỗ trợ chuỗi sản xuất nhiều bước.
4. **Player-owned spaces:** quyền sở hữu, quyền truy cập, xây dựng và tổ chức địa điểm của người chơi; cần chống xung đột/chiếm đất.
5. **Services & economy:** giao dịch hàng hóa và dịch vụ, tiêu dùng, nhu cầu; có thể sinh ra vai trò xã hội tự nhiên.
6. **Persistence & multiplayer authority:** thay đổi thế giới có thể lưu lại, chống gian lận/nhân bản và xử lý khi khu vực ngủ.

### 8.2. Những câu hỏi đặc biệt quan trọng
- Người chơi có thể sửa **địa hình** hay chỉ đặt/xóa công trình trên đất có sẵn?
- Có sở hữu đất lâu dài không? Khi vắng mặt, nhà cửa và cửa hàng tồn tại thế nào?
- Hành động tương tác chạy trên bộ quy tắc/recipe do nhà phát triển chuẩn bị, hay người chơi có thể tự tạo công thức và cơ chế?
- Bệnh viện chữa bệnh do hệ thống gameplay tạo ra, hay chỉ là công trình mang tính nhập vai?
- Nhà hàng cần tự vận hành khi chủ offline không? NPC có thể làm nhân viên không?
- Hàng hóa có độ bền, chất lượng, vận chuyển vật lý và chuỗi cung ứng không?
- Hệ thống PvP và phá hoại công trình có được phép không? Nếu có, cách bảo vệ không gian riêng tư?
- Tốc độ phát triển từ tay trắng đến xây dựng cơ sở sản xuất nên nhanh/chậm thế nào?
- Những hoạt động nào cần mô phỏng trong map đang ngủ và hoạt động nào tính bù thời gian lúc map mở lại?

### 8.3. Cập nhật ưu tiên thiết kế
**Trước khi chốt terrain/server architecture:** định nghĩa *vòng tương tác nền tảng* (thu thập → biến đổi → tạo vật phẩm/công trình → giao dịch → tạo nhu cầu mới), quy tắc về quyền sở hữu và tính liên tục của thế giới. Điều này quyết định dữ liệu và độ tự do của mọi gameplay về sau.


## 9. Nghiên cứu, thử nghiệm và thành quả dài hạn — cập nhật từ người sáng tạo

**Định hướng đã nêu rõ:** ItFall cần giới hạn hợp lý số hành động trực tiếp với vật phẩm, trong khi chiều sâu gameplay đến từ **quá trình khám phá, nghiên cứu, tiêu hao nguyên liệu, thời gian và tỷ lệ thành công**. Người chơi phải đầu tư công sức đáng kể mới đạt được thành quả có giá trị.

### 9.1. Ví dụ quả táo / nghề đầu bếp

Quả táo **không cần có vô số cơ chế riêng**. Ở mức tương tác cơ bản có thể chỉ cần:
- **Tiêu thụ**: sử dụng quả táo trực tiếp.
- **Nghiên cứu / thử nghiệm**: dùng quả táo làm nguyên liệu để tìm ra cách chế biến.

Người đầu bếp không mặc nhiên biết mọi món ăn từ đầu. Thử nghiệm tiêu hao nguyên liệu, thời gian và có xác suất thành công. Khi tìm ra món mới, món ăn có thể cung cấp **hiệu ứng buff** và trở thành sản phẩm có giá trị để sử dụng hoặc giao thương.

**Ý nghĩa:** giới hạn số thao tác nguyên thủy để dễ xây dựng hệ thống; mở rộng sự đa dạng bằng nội dung có thể khám phá, quá trình tiến bộ và những kết quả kết hợp được.

### 9.2. Tư tưởng gameplay đang hình thành

- **Bắt đầu từ tay trắng** và hiểu biết hạn chế.
- **Không cho sẵn mọi công thức / năng lực.**
- **Đầu tư thời gian, nguyên liệu và công sức** để khám phá công thức, quy trình hoặc kỹ năng mới.
- **Thành quả có ý nghĩa**: hiệu ứng, chất lượng, hiệu suất, công dụng hoặc lợi thế trong nền kinh tế người chơi.
- **Từ khám phá cá nhân đến xã hội**: người nghiên cứu có thể sản xuất, dùng, bán sản phẩm hoặc chia sẻ bí quyết — các quyền chia sẻ/bí mật chưa quyết định.

### 9.3. Ví dụ khái quát (đề xuất để thảo luận, chưa chốt)

Vòng lặp: **Thu thập → Thử nghiệm → Thất bại/học hỏi → Khám phá → Chế tạo → Sử dụng/giao thương → Nghiên cứu sâu hơn**.

Có thể áp dụng về sau cho nấu ăn, luyện kim, y dược, nông nghiệp, chế tạo công cụ; không mặc định tất cả đều dùng một minigame hoặc cùng một công thức xác suất.

### 9.4. Các quyết định còn mở

1. Khám phá công thức là **cá nhân**, theo nhóm hay công thức được cộng đồng biết chung?
2. Người chơi có thể **mua/trao đổi bí quyết** hay chỉ mua thành phẩm?
3. Thất bại là mất trắng hay vẫn **tăng kiến thức / thông tin** để giảm RNG thuần túy?
4. Nghiên cứu thành công tạo **công thức cố định** hay một biến thể do tham số/nguyên liệu?
5. Buff và thành quả có giới hạn cân bằng nào để không khóa người mới khỏi nền kinh tế?
6. Tiến trình nghiên cứu cần nhân vật online hay có thể chạy trong lúc offline?
7. Công thức là dữ liệu do nhà phát triển thiết kế hay có thể phát sinh từ tổ hợp quy tắc?

> **Không đồng nhất “mất nhiều thời gian” với “lặp lại nhàm chán”.** Đây là rủi ro thiết kế cần kiểm thử, không phải thay đổi tầm nhìn về thành quả khó đạt.
