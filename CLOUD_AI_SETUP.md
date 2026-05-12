# Cloud AI Integration Guide

## 🚀 Cara Setup Cloud AI untuk OCR Correction

Aplikasi Notaku sekarang support **Cloud AI (Google Gemini)** untuk improve OCR accuracy dengan graceful fallback ke offline jika tidak ada internet atau API error.

---

## 📋 Fitur

✅ **Always offline first**: Google ML Kit OCR always runs local (no internet required)  
✅ **Optional Cloud AI**: Jika device punya internet, Cloud AI automatically improve hasil  
✅ **Graceful fallback**: Jika Cloud AI error / timeout, tetap gunakan local result  
✅ **Free tier**: Google Gemini punya 60 request per menit (gratis, no credit card needed)  

---

## 🔑 Setup Gemini API Key (5 menit)

### Langkah 1: Buat Gemini API Key
1. Buka https://aistudio.google.com/app/apikey
2. Click "Create API key"
3. Copy API key Anda (format: `AIza...`)

### Langkah 2: Input di App
1. Buka app Notaku
2. Tap tab **Pengaturan** (settings icon)
3. Paste API key di field "Google Gemini API Key"
4. Click "Validasi & Simpan"
5. Tunggu validation ✅

Itu saja! Cloud AI sekarang aktif.

---

## ⚙️ Settings Options

### Cloud AI Enhancement Toggle
- **ON** (default): App akan coba improve OCR dengan Cloud AI jika ada internet
- **OFF**: Hanya gunakan local OCR (offline only)

### Enable/Disable Kapan Saja
Jika mau fokus offline atau hemat kuota internet, bisa toggle dari Settings.

---

## 📊 Cara Kerja

```
User scan receipt
    ↓
[1] Google ML Kit - Extract text (OFFLINE) ← Always happens
    ↓
[2] Check Internet + API Key
    ├─ NO internet → Stop, gunakan local result
    ├─ NO API key → Stop, gunakan local result
    └─ YES → Continue to [3]
    ↓
[3] Send to Gemini API untuk correction
    ├─ SUCCESS (200) → Gunakan improved text ✅
    ├─ RATE LIMIT (429) → Show warning, gunakan local result
    ├─ ERROR → Show warning, gunakan local result
    └─ TIMEOUT → Gunakan local result
    ↓
Parse receipt dengan text (local atau improved)
    ↓
Show ReviewReceiptScreen untuk user verify/edit
```

---

## 💡 Quality Improvement

### Contoh:
**Raw OCR (tanpa Cloud AI):**
```
0PEN TOAST MIL0
x 1             21645

DISC 10% COMPLIMENT:
Service Charge :
-24.100
19.280
```

**Dengan Cloud AI Correction:**
```
OPEN TOAST MILO
x 1             21645

DISC 10% COMPLIMENT:
Service Charge :
-24100
19280
```

---

## ⚠️ Important Notes

1. **Gratis dengan batasan**: Google Gemini free tier ada limit 60 request/menit
   - Untuk casual user (< 60 receipt/min), unlimited praktis
   - Jika butuh lebih banyak, bisa upgrade (berbayar)

2. **Privacy**: 
   - OCR text dikirim ke Google saat Cloud AI digunakan
   - Jika mau privacy full, disable Cloud AI atau jangan input API key

3. **Internet Required untuk Cloud AI**:
   - Cloud AI hanya berfungsi saat ada internet
   - App tetap work offline dengan local OCR

4. **API Key Security**:
   - API key disimpan di device (local)
   - Tidak dikirim ke server manapun selain Google Gemini
   - Bisa delete API key kapan saja dari Settings

---

## 🔧 Troubleshooting

### "API key tidak valid" - Solusi Lengkap

**Penyebab 1: Generative Language API belum diaktifkan** (PALING SERING)
```
Solusi:
1. Buka Google Cloud Console: https://console.cloud.google.com
2. Pastikan project sudah select (top left)
3. Search "Generative Language API"
4. Click "Generative Language API" di hasil search
5. Click "ENABLE" button biru
6. Tunggu ~30 detik
7. Coba validate API key lagi di app
```

**Penyebab 2: API key punya restrictions**
```
Solusi:
1. Buka https://aistudio.google.com/app/apikey
2. Click "Edit API Key Settings" (ikon pensil)
3. Scroll ke "API restrictions"
4. Pastikan set ke "Unrestricted" atau pilih "Generative Language API"
5. Save changes
6. Copy API key (baru) ke app
7. Validate lagi
```

**Penyebab 3: API key format salah**
```
- API key harus mulai dengan "AIza..."
- Pastikan tidak ada spasi di awal/akhir
- Copy langsung dari https://aistudio.google.com/app/apikey jangan manual type
```

**Penyebab 4: Google account tergantung region/negara**
```
Solusi:
1. Pastikan Google account punya akses Gemini API
2. Cek di https://ai.google.dev/ - klik "Get API Key"
3. Jika tidak ada option, mungkin region tidak support
   (Coba dengan VPN ke region US jika perlu)
```

### Verifikasi API Key Valid

Sebelum paste di app, test API key di browser:
```
1. Buka URL ini (ganti YOUR_API_KEY dengan API key Anda):
   https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_API_KEY

2. Jika hasil JSON dengan "models", API key valid ✅
3. Jika error 401/403, API key invalid ❌
```

### "Cloud AI tidak meningkatkan akurasi"
- Raw OCR dari Google ML Kit sudah pretty good untuk mayoritas receipt
- Cloud AI most benefit untuk receipt dengan banyak OCR error
- User verification screen always available untuk manual correction

### Ingin offline-only tanpa Cloud AI
- Disable toggle "Cloud AI Enhancement" dari Settings
- Atau don't input API key sama sekali

---

## 📞 Support

Kalau ada masalah:
1. Check internet connection
2. Check API key valid via Settings
3. Try offline (disable Cloud AI)
4. Clear app data dan reinstall jika perlu

Happy scanning! 📸

