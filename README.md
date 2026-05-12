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


