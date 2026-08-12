# Ishga tushirish qo'llanmasi

## 1. Supabase loyihasini yaratish
1. https://supabase.com saytida bepul hisob oching va yangi loyiha (Project) yarating.
2. Loyiha ochilgach, chap menyudan **SQL Editor** bo'limiga o'ting.
3. `supabase/schema.sql` faylining butun tarkibini nusxalab, SQL Editor'ga
   joylashtiring va **Run** tugmasini bosing. Bu barcha jadvallar, triggerlar
   va xavfsizlik qoidalarini (RLS) yaratadi.
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
cd "c:\Abdurahim\ustun dokon\app"
flutter run -d chrome
```

### Android (telefon yoki emulyator)
Telefonni USB orqali ulang, "USB debugging" (Dasturchi rejimi) yoqilgan
bo'lishi kerak, so'ng:
```powershell
cd "c:\Abdurahim\ustun dokon\app"
flutter devices          # ulangan qurilmalarni ko'rish
flutter run -d <device_id>
```

## 5. APK (o'rnatiladigan fayl) yig'ish
```powershell
cd "c:\Abdurahim\ustun dokon\app"
flutter build apk --release
```
Tayyor fayl: `app\build\app\outputs\flutter-apk\app-release.apk`
Ushbu faylni telefonga ko'chirib, o'rnatishingiz mumkin (noma'lum
manbalardan o'rnatishga ruxsat berish talab qilinishi mumkin).

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
