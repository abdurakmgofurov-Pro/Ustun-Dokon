# Ishga tushirish qo'llanmasi

## 1. Supabase loyihasini yaratish
1. https://supabase.com saytida bepul hisob oching va yangi loyiha (Project) yarating.
2. Loyiha ochilgach, chap menyudan **SQL Editor** bo'limiga o'ting.
3. `supabase/schema.sql` faylining butun tarkibini nusxalab, SQL Editor'ga
   joylashtiring va **Run** tugmasini bosing. Bu barcha jadvallar, triggerlar
   va xavfsizlik qoidalarini (RLS) yaratadi. `schema.sql` ichida foyda
   hisoboti (`cost` ustuni), chekni bekor qilish va xodim yaratish triggerlari
   allaqachon bor — `profit_report.sql`, `fix_cancel_sale.sql`,
   `fix_handle_new_user.sql` yangi o'rnatishda kerak emas.
   Shundan keyin shu tartibda yana ikkitasini ishga tushiring:
   - `supabase/error_logs.sql` — ilova xato jurnali jadvali;
   - `supabase/fix_seller_rls.sql` — sotuvchi xavfsizligi (mijoz qarzini
     o'zgartirish va savdoni `create_sale`dan chetlab yozishni yopadi).
   - `supabase/payment_method.sql` — kassada naqd/karta ustunlari va triggerlar
     (yangi o'rnatishda `schema.sql` ichida bor, mavjud loyihada ishga tushiring);
   - `supabase/refund_customer.sql` — qarz to'langach tovar qaytarilganda mijozga pulni
     qaytarish funksiyasi (ilovadagi "Pulni qaytarish" tugmasi shuni chaqiradi);
   - `supabase/protect_owner.sql` — asosiy adminni himoyalash. **Birinchi adminni
     yaratib bo'lgach** (3-bo'lim) ishga tushiring; fayldagi `056d631c-...` id'ni
     o'z adminingiz id'siga almashtiring (Authentication -> Users).
   (`fix_error_logs_rls.sql` faqat jurnalga yozishda "row-level security"
   xatosi chiqsa kerak bo'ladi. `reset_data.sql` — barcha do'kon
   ma'lumotlarini o'chiradi, faqat ataylab kerak bo'lganda ishlating.)
4. Chap menyudan **Project Settings -> API** bo'limiga o'ting va quyidagilarni
   nusxalang:
   - **Project URL** (masalan: `https://xxxxxxxx.supabase.co`)
   - **anon public** kaliti (uzun matn)

## 2. Ilovani Supabase'ga ulash
`app/.env` faylini oching va quyidagicha to'ldiring:

```
SUPABASE_URL=https://xxxxxxxx.supabase.co
SUPABASE_ANON_KEY=sizning-anon-kalitingiz
```

## 3. Birinchi admin foydalanuvchini yaratish
Ilovada ochiq ro'yxatdan o'tish yo'q — birinchi admin hisobini Supabase
Dashboard orqali qo'lda yaratasiz:
1. **Authentication -> Users -> Add user -> Create new user** bo'limiga o'ting.
2. Email va parol kiriting, **Auto Confirm User**ni yoqing, **Create user**
   bosing.
3. **Table Editor -> profiles** jadvaliga o'ting, yangi yaratilgan
   foydalanuvchi qatorini toping (avtomatik `sotuvchi` rolida yaratiladi) va
   `role` ustunini `admin` ga o'zgartiring.
4. Shu email/parol bilan ilovaga kiring — endi Kassa, Sozlamalar va boshqa
   xodimlarni boshqarish ochiladi.

## 3a. Edge Function joylashtirish (xodim qo'shish/o'chirish uchun)
Ilovada admin **Sozlamalar -> Xodimlar** bo'limidan yangi xodim qo'sha oladi
yoki hisobni butunlay o'chira oladi. Bu amal xavfsiz tarzda server tomonida
(`service_role` kaliti bilan, brauzerga chiqmagan holda) bajarilishi uchun
bitta Edge Function joylashtirish kerak — CLI shart emas, hammasi
Dashboard orqali:

1. Supabase Dashboard -> **Edge Functions -> Deploy a new function** ga o'ting.
2. Nomini aniq **`manage-employee`** deb kiriting (nom ilova kodidagi bilan
   bir xil bo'lishi shart).
3. `supabase/functions/manage-employee/index.ts` faylining butun tarkibini
   nusxalab, funksiya kod muharririga joylashtiring.
4. **Deploy** tugmasini bosing. (`SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   `SUPABASE_SERVICE_ROLE_KEY` — bular Supabase tomonidan avtomatik
   taqdim etiladi, qo'shimcha sozlash shart emas.)

## 3b. Ochiq ro'yxatdan o'tishni butunlay yopish (tavsiya etiladi)
Ilova UI'sida ro'yxatdan o'tish tugmasi yo'q, lekin xavfsizlik uchun buni
server darajasida ham yoping:
1. **Authentication -> Sign In / Providers -> Email** bo'limiga o'ting.
2. **"Allow new users to sign up"** (yoki shunga o'xshash) sozlamasini
   o'chiring.
Shundan so'ng faqat admin (Dashboard yoki Sozlamalar -> Xodimlar orqali)
yangi hisob yarata oladi.

## 4. Ilovani lokal ishga tushirish

### Talab qilinadigan vositalar (kompyuterda avtomatik o'rnatilgan)
- Flutter SDK: `C:\flutter`
- Android SDK: `C:\Android`
- JDK 17: `C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot`

### Veb versiyasini ishga tushirish
```powershell
cd "c:\Abdurahim\SHAXSIY\ustun dokon\app"
flutter run -d chrome
```

### Android (telefon yoki emulyator)
Telefonni USB orqali ulang, "USB debugging" (Dasturchi rejimi) yoqilgan
bo'lishi kerak, so'ng:
```powershell
cd "c:\Abdurahim\SHAXSIY\ustun dokon\app"
flutter devices          # ulangan qurilmalarni ko'rish
flutter run -d <device_id>
```

## 5. APK (o'rnatiladigan fayl) yig'ish
```powershell
cd "c:\Abdurahim\SHAXSIY\ustun dokon\app"
flutter build apk --release
```
Tayyor fayl: `app\build\app\outputs\flutter-apk\app-release.apk`
Ushbu faylni telefonga ko'chirib, o'rnatishingiz mumkin (noma'lum
manbalardan o'rnatishga ruxsat berish talab qilinishi mumkin).

**Muhim:** APK'ni faqat shu kompyuterda yig'ing — u release kaliti
(`app/android/ustun-dokon-release.keystore` + `key.properties`) bilan
imzolanadi. Codemagic/Mac'da bu kalit yo'q va u debug kaliti bilan
imzolaydi: bunday APK o'rnatilgan ilovaning ustiga o'rnatilmaydi
("konflikt") va avto-yangilanish ishlamaydi. Kalit fayllari `.gitignore`da —
ularni boshqa joyga zaxiralab qo'ying; yo'qolsa, ilovani o'chirib qayta
o'rnatishga to'g'ri keladi.

### Yangi versiya chiqarish (Android avto-yangilanish)
Ilova ochilganda GitHub Releases'dagi so'nggi relizni tekshiradi va yangisi
bo'lsa yangilashni taklif qiladi (Sozlamalar -> Ilova'dan qo'lda ham tekshirish
mumkin).
1. `app/pubspec.yaml`da `version`ni oshiring (masalan `1.1.3+5`).
2. `flutter build apk --release`, so'ng `app-release.apk`ni loyiha ildizidagi
   `ustun-dokon.apk`ga ko'chiring.
3. O'zgarishlarni commit + push qiling.
4. Reliz yarating (teg `v` + versiya, fayl nomi aynan `ustun-dokon.apk`):
   ```powershell
   gh release create v1.1.3 ustun-dokon.apk --repo abdurakmgofurov-Pro/Ustun-Dokon --target main --title "Ustun Do'kon 1.1.3" --notes "Nima o'zgardi"
   ```
Avto-yangilanish faqat Android'da; iOS'da Sideloadly orqali qo'lda o'rnatiladi.

### iOS (ixtiyoriy)
`codemagic.yaml` (ios-workflow) GitHub'dagi repo'dan Codemagic'da `.ipa`
yig'adi; uni bepul Apple ID bilan Sideloadly orqali o'rnatasiz (har 7 kunda
qayta imzolash kerak). Batafsil: PLAN.md.

### Testlar
```powershell
cd "c:\Abdurahim\SHAXSIY\ustun dokon\app"
flutter test
```

## 6. Veb versiyasini internetga joylash (ixtiyoriy)
`flutter build web` buyrug'i `app\build\web` papkasida statik fayllar
yaratadi. Ularni Netlify, Vercel yoki Supabase Storage kabi har qanday
statik hosting xizmatiga yuklab, do'kon xodimlari brauzer orqali kira
oladigan qilib qo'yishingiz mumkin.

## Eslatma: xavfsizlik
- `.env` faylida sizning Supabase manzilingiz va **anon** (ochiq) kalitingiz
  saqlanadi — bu kalit ataylab ochiq bo'lishga mo'ljallangan, lekin baribir
  uni ommaviy joylarga (masalan ochiq GitHub repo) yuklamang.
- Barcha ma'lumotlar xavfsizligi Supabase'dagi RLS (Row Level Security)
  qoidalari orqali ta'minlanadi: sotuvchilar faqat savdo kirita oladi,
  kassa va xodimlar boshqaruvi faqat adminlarga ochiq.
- Supabase bepul tarifda loyiha 7 kun deyarli so'rovsiz tursa **pauza**
  qilinadi (domen ishlamay qoladi). Dashboard'dan **Restore project**
  bosing; ilovadan haftada kamida bir marta foydalanish pauzaning oldini
  oladi. Bepul tarifda avtomatik zaxira nusxa yo'q.
