# Schema dữ liệu Rolly — quan sát từ payload thật

Ghi từ dữ liệu **thật** kéo về ngày 2026-08-21, không đoán. Nguồn: Supabase PostgREST của Rolly (`ilcayaumqidkbjpecfhq.supabase.co`), tài khoản `<USER_UUID>`. Đây là hợp đồng mà importer ở Phase 9 phải khớp.

## Tổng quan

- Backend: **Supabase / PostgREST**. Bảng nằm schema `public`.
- Rolly gọi giao dịch là **`input`**, không phải "transaction". Đây là lý do dò tên "transactions" lúc đầu trả 404.
- Truy vấn phải **lọc `user_id=eq.<uuid>`** — không lọc thì server trả 500 (RLS + bảng dùng chung mọi user).
- Đã kéo về `raw_rolly/`: `input` (362), `category_view` (21), `wallet_view` (1), `monthly_category_sums_with_total` (50), `chat_history_with_input_view` (741), `input_savings_view` (8), `savings`/`savings_with_total`, `categorisation_rule` (41), `subcategory` (30). `budget`/`debt`/`recurring` đều rỗng (Tony chưa dùng).

---

## Bảng `input` — giao dịch *(bảng quan trọng nhất)*

362 bản ghi. Một dòng đầy đủ:

```json
{
  "id": 12189685,
  "created_at": "2026-06-21T13:49:08.12253+00:00",
  "item": "gửi xe",
  "amount": 36000.0,
  "date": "2026-06-21",
  "type": "Expense",
  "message_in": "gửi xe 36k",
  "message_out": "Chi phí gửi xe 36k của bạn rất hợp lý…",
  "user_id": "<USER_UUID>",
  "category_id": 7237238,
  "subcategory_id": 30048,
  "wallet_id": 651423,
  "source_wallet_id": null,
  "destination_wallet_id": null,
  "linking_transfer_id": null,
  "savings_id": null, "linking_savings_id": null,
  "debt_id": null, "linking_debt_id": null,
  "loan_id": null, "linking_loan_id": null,
  "challenge_id": null,
  "is_audio": false, "is_onboarding": null, "is_recurring": false,
  "image_url": null, "note": null,
  "client_uuid": "042ecfb1-3b11-4fc9-a127-8f8832c6494e",
  "version": 0
}
```

### Ba câu hỏi sống-còn — trả lời bằng dữ liệu, đã đối chiếu chéo

| Câu hỏi | Trả lời | Bằng chứng |
|---|---|---|
| **Số tiền: minor hay major unit?** | **MAJOR** (đồng nguyên). `amount` là `float`, giá trị = số tiền thật. | `"gửi xe 36k"` → `amount: 36000.0`. Dải 1.000 – 19.383.000. Mọi giá trị đều `.0` (không có xu, đúng với VND) |
| **Quy ước dấu thu/chi?** | **KHÔNG dùng dấu.** `amount` **luôn dương**. Thu/chi phân biệt bằng field **`type`** (chuỗi). | 345 `Expense`, 9 `Income`, 8 `Savings` — cả ba nhóm `amount` đều ≥ 0 |
| **Múi giờ?** | `created_at` là **UTC** (`+00:00`). `date` là **ngày theo giờ Việt Nam (+07)**, chỉ ngày không giờ. | Với bản ghi tạo lúc `13:49 UTC`, `date` = ngày UTC+7. Trong 200 bản có 2 ca `date` khớp ngày-VN nhưng lệch ngày-UTC → `date` đã theo giờ local |

> ⚠️ **Importer PHẢI dùng field `date` làm ngày giao dịch, KHÔNG dùng `created_at`.** `created_at` là lúc bản ghi được ghi lên server (UTC); dùng nó sẽ đẩy sai ngày cho các giao dịch nhập vào buổi tối (sau 17:00 giờ VN = đã sang ngày hôm sau theo UTC). Đây chính là "bug múi giờ âm thầm" mà TODOS cảnh báo.

### Giá trị của `type`

| `type` | Số lượng | Nghĩa | Map sang TonyFino |
|---|---|---|---|
| `Expense` | 345 | Chi | giao dịch chi, `amount` giữ nguyên |
| `Income` | 9 | Thu | giao dịch thu |
| `Savings` | 8 | Chuyển tiền vào mục tiết kiệm | **chuyển khoản** (xem cảnh báo dưới) |

### 🔴 Cạm bẫy transfer — sẽ phá số dư gấp đôi nếu bỏ qua

Mỗi lần chuyển tiền vào tiết kiệm được Rolly ghi thành **HAI dòng** trong `input`, ghép bằng **`linking_transfer_id`**:

```
id=12450889 item='Lương' amount=7000000 wallet=651423 link=12450888   ← chiều ra khỏi ví thu chi
id=12450890 (dòng ghép)  amount=7000000                link=12450888   ← chiều vào mục tiết kiệm
```

Bằng chứng: tổng `Savings` tự cộng từ `input` = **86.400.000**, nhưng `wallet_view.total_transfer_out` của chính Rolly = **43.200.000** — đúng một nửa. 8 dòng `Savings` = 4 lần chuyển × 2 dòng.

> **Importer phải khử trùng lặp transfer theo `linking_transfer_id`** (giữ một dòng mỗi cặp), hoặc mô hình hoá thành một giao dịch chuyển khoản duy nhất. Nếu import cả hai dòng như hai giao dịch độc lập, số dư và tổng tiết kiệm sẽ sai gấp đôi.

### Field còn lại

| Field | Kiểu | Ghi chú cho importer |
|---|---|---|
| `id` | int | khoá chính Rolly. **Dùng làm `sourceId` để idempotent** (Phase 9) |
| `item` | str | tên giao dịch ngắn, vd `"gửi xe"`, `"lương"` |
| `message_in` | str/null | **câu người dùng gõ thật**, vd `"gửi xe 36k"` — vàng ròng cho corpus parser Phase 7 |
| `message_out` | str/null | câu AI trả lời (lời khuyên/cằn nhằn). Không cần import |
| `category_id` | int/null | FK sang `category_view.id` |
| `subcategory_id` | int/null | danh mục con |
| `wallet_id` | int/null | FK sang `wallet_view.id` |
| `source_wallet_id`, `destination_wallet_id` | int/null | chỉ điền ở transfer |
| `linking_transfer_id` | int/null | **ghép cặp transfer** — xem cạm bẫy trên |
| `savings_id`, `debt_id`, `loan_id`, `challenge_id` | int/null | liên kết tính năng phụ, Tony hầu như không dùng |
| `is_audio` | bool/null | nhập bằng giọng nói hay không |
| `is_recurring` | bool | giao dịch định kỳ |
| `client_uuid` | str | uuid sinh phía client, cũng có thể làm khoá idempotent phụ |
| `note`, `image_url` | null | Tony chưa dùng |
| `version` | int | version optimistic-lock của Rolly, bỏ qua |

**Không thấy field soft-delete** (`deleted_at`/`is_deleted`) trong payload. 362 bản đều là bản sống.

---

## Bảng `category_view` — danh mục

21 bản. Field: `id`, `title`, `type` (`Expense`/`Income`), `icon_image_url`, `wallet_id`, `input_count`, `user_id`, `created_at`. `icon_data`/`icon_id` null.

- Danh mục gắn với **`type`** (danh mục chi vs danh mục thu tách riêng).
- `title` là tiếng Việt: `"Chưa được phân loại"`, `"Thực phẩm"`, `"Giặt đồ"`, `"Làm đẹp"`, `"Điện tử"`, …
- `icon_image_url` trỏ tới ảnh PNG trên Supabase Storage của Rolly — TonyFino sẽ thay bằng icon riêng (D10: lưu `categoryColorId` + iconCode, không lưu URL).

## Bảng `subcategory` — danh mục con

30 bản, phủ đủ 27 subcategory mà giao dịch tham chiếu. Field: `id`, `category_id` (FK sang `category_view`), `title`, `wallet_id`, `user_id`, `created_at`. Giao dịch trỏ tới đây qua `input.subcategory_id`. Đã kéo về `raw_rolly/subcategory.json`.

## Bảng `wallet_view` — ví

1 bản (`"Ví thu chi"`). Field quan trọng: `initial_balance` (3.000.000), `currency_code` (`VND`), `type` (`cash`), `total_expense`, `total_income`, `total_transfer_out` — **các tổng này là oracle sẵn của Rolly**.

## `chat_history_with_input_view` — 741 tin nhắn chat

Không cần import, **nhưng cực giá trị cho Phase 7**: chứa câu gõ thật của người dùng và cách Rolly parse ra. Giữ lại làm nguồn seed cho corpus parser tiếng Việt.

---

## Oracle nghiệm thu *(Phase 9 phải khớp con số này)*

Tự tính từ `input`, gom theo field `date` (giờ VN), **đã đối chiếu khớp chính xác với `wallet_view` của Rolly** cho Expense và Income:

| Tháng | #GD | Expense (₫) | Income (₫) | Savings (₫, gộp 2 chiều) |
|---|---|---|---|---|
| 2026-05 | 99 | 18.803.000 | 21.428.000 | 0 |
| 2026-06 | 110 | 15.396.000 | 20.637.000 | 20.000.000 |
| 2026-07 | 85 | 8.891.000 | 25.682.000 | 14.000.000 |
| 2026-08 | 68 | 8.359.000 | 29.533.000 | 52.400.000 |
| **TỔNG** | **362** | **51.449.000** | **97.280.000** | 86.400.000 *(= 43.200.000 × 2)* |

Đối chiếu với `wallet_view` (nguồn độc lập, do chính Rolly tính):
- `total_expense` = **51.449.000** ✅ khớp
- `total_income` = **97.280.000** ✅ khớp
- `total_transfer_out` = **43.200.000** = một nửa Savings gộp (xác nhận cạm bẫy transfer 2 dòng)

Số dư ví suy ra: `3.000.000 + 97.280.000 − 51.449.000 − 43.200.000` = **5.631.000 ₫**.

> Số này đọc-tính từ dữ liệu kéo về. Còn thiếu **con số đọc thẳng từ UI Rolly** (màn báo cáo / số dư ví hiển thị trên app) — Tony sẽ bổ sung + ảnh chụp để có nguồn xác nhận thứ ba hoàn toàn độc lập. Nhưng việc `input` khớp `wallet_view` đã là hai nguồn độc lập trùng khớp, đủ tin cho importer.

---

## Cách kéo lại (nếu token hết hạn, cần lấy mới)

Token trong `raw_rolly/rolly-curl.txt` hết hạn sau 1 giờ. Lấy curl mới theo `rolly-extraction.md`, rồi:

```
python3 tool/pull_rolly.py   # (script kéo, nếu tạo)  — hoặc dùng lại đoạn inline trong lịch sử git Phase 2
```

Bảng cần: `input`, `category_view`, `wallet_view`, `monthly_category_sums_with_total`. Luôn thêm `&user_id=eq.<uuid>&limit=100000`.
