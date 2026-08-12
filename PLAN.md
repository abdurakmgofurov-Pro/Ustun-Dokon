# Oziq-ovqat do'koni boshqaruv dasturi — Reja

## Maqsad
Oziq-ovqat do'koni uchun savdo, tovar (mahsulot) qoldiqlari, prihod-rashod
(kirim-chiqim) va qarzdorlar ro'yxatini boshqaradigan, ham veb, ham Android
APK ko'rinishida ishlaydigan to'liq dastur.

## Texnologiyalar
- **Frontend**: Flutter (bitta kod — Web + Android APK)
- **Backend / DB**: Supabase (PostgreSQL + Auth + Realtime + Row Level Security)
- **State management**: Riverpod
- **Grafiklar**: fl_chart
- **Foydalanuvchilar**: ko'p xodimli, rolga asoslangan huquqlar
  - `admin` — hammasini ko'radi va boshqaradi (tovarlar, savdo, prihod-rashod,
    qarzdorlar, hisobotlar, xodimlar)
  - `sotuvchi` — faqat savdo kiritadi va tovar qoldig'ini ko'radi

## Modullar

### 1. Autentifikatsiya
- Supabase Auth (email + parol)
- Har bir foydalanuvchi `profiles` jadvalida rolga ega (admin/sotuvchi)
- Rolga qarab UI va ruxsatlar (RLS) cheklanadi

### 2. Mahsulotlar (Tovarlar)
- Nomi, kategoriyasi, o'lchov birligi (dona/kg/litr), kirim narxi, sotish narxi
- Joriy qoldiq (miqdor), minimal qoldiq chegarasi (ogohlantirish uchun)
- Shtrix-kod (ixtiyoriy, keyingi bosqichda skanerlash uchun)
- CRUD: qo'shish, tahrirlash, o'chirish, qidirish/filtrlash

### 3. Savdo (POS)
- Tovarlarni tanlab savdo cheki yaratish (miqdor, narx, jami summa)
- To'lov turi: naqd, karta, qarzga (qarz bo'lsa — mijoz tanlanadi/yaratiladi)
- Savdo tarixi, kunlik/oylik ro'yxat, chekni bekor qilish (admin huquqi)
- Har bir savdo avtomatik tovar qoldig'ini kamaytiradi

### 4. Prihod-Rashod (Kirim-Chiqim)
- Qo'lda kiritiladigan kirim (kapital, boshqa daromad) va chiqim
  (ijaraq, ish haqi, kommunal, tovar xaridi) yozuvlari
- Sana, summa, kategoriya, izoh
- Savdodan tushgan naqd pul avtomatik kirim sifatida hisoblanadi
- Kunlik/oylik kassa balansi hisoboti

### 5. Qarzdorlar
- Mijozlar ro'yxati (ism, telefon, joriy qarz summasi)
- Qarz tarixi (qachon, qancha, nima uchun — savdo cheki bilan bog'liq)
- Qarzni qisman/to'liq to'lash, to'lov tarixi
- Muddati o'tgan qarzlar bo'yicha ogohlantirish

### 6. Bosh sahifa / Dashboard
- Bugungi savdo, foyda, kassa qoldig'i
- Eng ko'p sotilgan tovarlar, kam qolgan tovarlar ogohlantirishi
- Umumiy qarzdorlik summasi
- Grafiklar: kunlik/haftalik/oylik savdo dinamikasi

### 7. Sozlamalar
- Xodimlar boshqaruvi (admin qo'shadi/o'chiradi, rol beradi) — faqat admin
- Do'kon ma'lumotlari (nomi, manzili — chek uchun)

## Ma'lumotlar bazasi jadvallari (Supabase/Postgres)
- `profiles` (id, full_name, role, created_at)
- `categories` (id, name)
- `products` (id, name, category_id, unit, buy_price, sell_price, stock, min_stock)
- `customers` (id, full_name, phone, total_debt)
- `sales` (id, cashier_id, customer_id, total, payment_type, created_at)
- `sale_items` (id, sale_id, product_id, qty, price)
- `debt_payments` (id, customer_id, amount, note, created_at)
- `cash_transactions` (id, type[income/expense], amount, category, note, created_at, created_by)

RLS: admin — to'liq huquq; sotuvchi — faqat o'qish (products), yozish (sales,
sale_items), o'zining yozuvlarini ko'rish.

## Bosqichlar (ijro tartibi)
1. [BAJARILDI] Muhitni tayyorlash: Git, JDK, Android SDK, Flutter SDK o'rnatish
2. [BAJARILDI] Supabase loyihasi va SQL sxemasini tayyorlash (`supabase/schema.sql`)
3. [BAJARILDI] Flutter loyihasini yaratish (papka strukturasi, paketlar) (`app/`)
4. [BAJARILDI] Autentifikatsiya va rollar
5. [BAJARILDI] Mahsulotlar moduli
6. [BAJARILDI] Savdo (POS) moduli
7. [BAJARILDI] Prihod-Rashod moduli
8. [BAJARILDI] Qarzdorlar moduli
9. [BAJARILDI] Dashboard va hisobotlar
10. [BAJARILDI] Veb va Android'da test qilish
11. [BAJARILDI] APK yig'ish va yakuniy tekshiruv (`ustun-dokon.apk`, release keystore sozlangan)

## Rejadan tashqari qo'shilgan funksiyalar

Loyiha davomida dastlabki rejada yo'q bo'lgan quyidagi imkoniyatlar ham
qo'shildi:

- **Shtrix-kod skanerlash** — `mobile_scanner` orqali kamera bilan skanerlash
  (`widgets/barcode_scanner_sheet.dart`, `services/barcode_lookup_service.dart`);
  `products` jadvalida `barcode` ustuni
- **Faktura/chek skanerlash (OCR)** — Google ML Kit text recognition orqali
  fakturadan mahsulotlarni avtomatik o'qib olish
  (`screens/products/invoice_scan_screen.dart`, `services/invoice_ocr_service.dart`)
- **Bluetooth chek printer** — ESC/POS orqali fizik chek chiqarish
  (`services/receipt_printer_service.dart`, `services/receipt_formatter.dart`,
  `widgets/receipt_view.dart`, `models/receipt.dart`)
- **Xodimlarni boshqarish (server tomonda)** — Supabase Edge Function
  (`supabase/functions/manage-employee`) admin uchun xodim qo'shish/o'chirishni
  xavfsiz (auth.users darajasida) bajaradi
- **Dark/Light tema almashtirish** — `providers/theme_provider.dart`,
  `core/theme.dart`
- **Mijoz tez tanlash/yaratish** — POS ichida `screens/sales/customer_picker.dart`
- **Savdoni bekor qilishda qoldiqni to'g'ri tiklash** — alohida tuzatish
  (`supabase/fix_cancel_sale.sql`)
- **Umumiy bo'sh-holat komponenti (empty state)** — `widgets/empty_state.dart`
- **iOS qo'llab-quvvatlash (Codemagic + Sideloadly orqali bepul)** — `app/ios`,
  `codemagic.yaml` (ios-workflow/android-workflow), `Info.plist`ga kamera/
  galereya/Bluetooth ruxsat matnlari, iOS deployment target 15.5
  (`google_mlkit_text_recognition` talabi), `mobile_scanner`ni 7.x'ga
  yangilash (iOS'da Google MLKit o'rniga Apple Vision — versiyalar
  ziddiyatini yechish uchun)
- **Masofaviy xato jurnali (error logging)** — ilovadagi xatoliklarni
  Supabase'dagi `app_error_logs` jadvaliga yozib boradi (global handlerlar +
  kirish/savdo/printer/OCR kontekstli loglar), faqat admin o'qiy oladi
  (`supabase/error_logs.sql`, `services/error_log_service.dart`)
- **Oylik hisobot (savdo, tannarx, foyda, xarajatlar)** — Kassa ekranidan
  alohida, oyma-oy (oldinga/orqaga) ko'rish mumkin bo'lgan to'liq hisobot:
  jami sotuv, tovarlar tannarxi, yalpi/sof foyda va rashodlarning
  kategoriya bo'yicha taqsimoti (`screens/cash/expense_report_screen.dart`,
  `providers/cash_provider.dart`). Foydani hisoblash uchun `sale_items`
  jadvaliga sotilgan paytdagi tannarxni saqlaydigan `cost` ustuni qo'shildi
  (`supabase/profit_report.sql`) — mavjud Supabase loyihasida bu faylni
  SQL Editor orqali ishga tushirish kerak.
- **Kategoriya qo'shishda tushunarli xato xabari** — takroriy nom
  kiritilsa ("allaqachon mavjud") aniq ko'rsatiladi, ilgari sukut saqlab
  hech narsa ko'rsatmasdi

## Eslatmalar
- Ish kompyuterida hech qanday dev vosita o'rnatilmagan edi — Git, OpenJDK 17,
  Android SDK command-line tools va Flutter SDK skript orqali o'rnatilmoqda.
- Supabase — bepul (free tier) hisob orqali ishga tushiriladi; loyiha URL va
  anon key foydalanuvchidan so'raladi yoki birga sozlanadi.
