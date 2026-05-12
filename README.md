# 📱 Notaku - Smart Receipt OCR & Tracking

Aplikasi mobile untuk scan, parse, dan track struk belanja dengan teknologi OCR offline-first dan optional Cloud AI improvement.

---

## ✨ Fitur Utama

### 🎯 **Smart Receipt Scanning**
- Google ML Kit OCR untuk extract text dari struk (offline)
- Optional Cloud AI dengan Google Gemini untuk improve accuracy
- Smart layout reconstruction dengan bounding box analysis
- Graceful fallback ke offline saat tidak ada internet

### 📊 **Intelligent Receipt Parsing**
- Auto-detect nama toko
- Extract items dengan quantity dan price
- Parse metadata (discount, service charge, tax, rounding)
- Smart item-to-price matching
- Support multiple price formats

### ✅ **User Verification & Editing**
- Edit interface sebelum simpan
- Live calculation breakdown
- Add/remove items
- Modify prices dan quantities
- Auto-negative discount handling

### 💾 **Local Database Storage**
- Offline storage dengan Isar database
- Receipt history dengan full metadata
- Akses kapan saja tanpa internet

### ⚙️ **Optional Cloud AI Integration**
- Google Gemini API untuk OCR correction
- 60 request/minute (gratis)
- Seamless fallback ke local OCR jika error
- Privacy-first: data hanya sent saat ada internet

** 📸 Screenshots
<img width="540" height="1170" alt="WhatsApp Image 2026-05-12 at 8 48 10 AM" src="https://github.com/user-attachments/assets/4b923ce5-b674-4393-bf3f-b2ce4128dc96" />
<img width="540" height="1170" alt="WhatsApp Image 2026-05-12 at 8 47 59 AM" src="https://github.com/user-attachments/assets/50da5c0f-fda0-427f-9be2-dfea8909c40a" />
<img width="540" height="1170" alt="WhatsApp Image 2026-05-12 at 8 47 59 AM (1)" src="https://github.com/user-attachments/assets/9bfe3fc9-0a4b-4728-aa44-4127699fe456" />


