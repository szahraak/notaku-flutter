// ══════════════════════════════════════════════════════════════════════
//  GENERAL RECEIPT PARSER  –  store-agnostic, works on any Indonesian receipt
// ══════════════════════════════════════════════════════════════════════

class ReceiptItem {
  final String name;
  final int qty;
  final double price;

  ReceiptItem({required this.name, required this.qty, required this.price});

  double get subtotal => qty * price;
}

class ParsedReceipt {
  final List<ReceiptItem> items;
  final double subtotal;
  final double discount;
  final double serviceCharge;
  final double tax;
  final double pembulatan;
  final double grandTotal;
  final String rawText;
  final String storeName;

  ParsedReceipt({
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.serviceCharge,
    required this.tax,
    required this.pembulatan,
    required this.grandTotal,
    required this.rawText,
    required this.storeName,
  });
}

class ReceiptParser {
  // ─────────────────────────────────────────────────────────────────────
  //  PATTERNS  (tidak ada nama toko / menu spesifik)
  // ─────────────────────────────────────────────────────────────────────

  static final _separatorLine = RegExp(r'^[-=*_.~#|\/\\]{3,}$');

  static final _addressLine = RegExp(
    r'^\s*(?:jl\.|jln\.|jalan\s|gg\.|gang\s|'
    r'telp\w*[:\s]|phone[:\s]|fax[:\s]|'
    r'email[:\s]|website[:\s]|www\.)',
    caseSensitive: false,
  );

  /// Keyword universal receipt — tidak ada nama toko/kota/menu
  static final _nonItemPattern = RegExp(
    r'(?:'
    r'subtotal|sub\s*total|disc(?:ount|on)?|service\s*charge|'
    r'ppn|pb1|sc\s*\(|pembulatan|'
    r'kembali(?:an)?|bayar\b|tunai|kartu|card|debit|kredit|'
    r'qris|transfer|cash\b|change\b|kembalian|'
    r'kasir|cashier|operator|pelayan|karyawan|staff|'
    r'tanggal|tgl|date\b|time\b|jam\b|pukul|'
    r'no\.?\s*(?:meja|struk|nota|invoice|bon|faktur)|'
    r'table\b|meja\b|purpose\b|sales\b|server\b|'
    r'npwp|nib|siup|'
    r'thank\s*(?:you|u)|terima\s*kasih|selamat\s+(?:datang|berkunjung)|'
    r'visit\s+us|kami\s+kembali|'
    r'struk\b|bon\b|lunas|'
    r'brand\s*total|grand\s*total|'
    r'items?\s*$'
    r')',
    caseSensitive: false,
  );

  // ─────────────────────────────────────────────────────────────────────
  //  STORE NAME DETECTION  (heuristik umum: baris pertama yang bermakna)
  // ─────────────────────────────────────────────────────────────────────

  static String _detectStoreName(List<String> lines) {
    final definitelyMeta = RegExp(
      r'^\s*(?:tanggal|date\b|time\b|jam\b|kasir|cashier|'
      r'no\.|nomor|invoice|table\b|meja\b|server\b|sales\b|'
      r'kode|struk|bon|receipt|printed|cetak|powered|version)',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length && i < 12; i++) {
      final line = lines[i].trim();
      if (line.length < 2) continue;
      if (_separatorLine.hasMatch(line)) continue;
      if (_addressLine.hasMatch(line)) continue;
      if (definitelyMeta.hasMatch(line)) continue;
      if (_nonItemPattern.hasMatch(line)) continue;
      // Lewati baris digit/simbol semua
      if (RegExp(r'^[\d\s\W]+$').hasMatch(line)) continue;
      return line;
    }
    return 'Tidak diketahui';
  }

  // ─────────────────────────────────────────────────────────────────────
  //  MAIN PARSE
  // ─────────────────────────────────────────────────────────────────────

  static ParsedReceipt parse(String rawText) {
    var lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    lines = _mergeFragmentedLines(lines);

    final storeName = _detectStoreName(lines);

    final items            = <ReceiptItem>[];
    final pendingItems     = <_PendingItem>[];
    final standalonePrices = <_StandalonePrice>[];
    double? grandTotal;

    final metaKeywords = RegExp(
      r'disc(?:ount|on)?|service\s*charge|ppn|pb1|sc\s*\('
      r'|pembulatan|subtotal|sub\s*total|brand\s*total',
      caseSensitive: false,
    );

    for (int idx = 0; idx < lines.length; idx++) {
      final line  = lines[idx];
      final lower = line.toLowerCase();

      if (_separatorLine.hasMatch(line)) continue;
      if (_addressLine.hasMatch(line)) continue;

      // Non-item kecuali mengandung 'total' (perlu cek total dulu)
      if (_nonItemPattern.hasMatch(line) && !lower.contains('total')) continue;

      // Grand total
      if (lower.contains('total') &&
          !lower.contains('subtotal') &&
          !lower.contains('sub total')) {
        final m = RegExp(
          r'(?:grand\s*)?total\s*[:\-]?\s*([\d.,]+)',
          caseSensitive: false,
        ).firstMatch(line);
        if (m != null) {
          final v = _parsePrice(m.group(1)!);
          if (v > 50) grandTotal = v;
        }
        continue;
      }

      // Metadata keuangan (ditangani _extractMetadata)
      if (metaKeywords.hasMatch(line)) continue;

      // Baris hanya angka → kandidat standalone price
      if (RegExp(r'^-?[\d.,\s]+$').hasMatch(line)) {
        final price    = _parsePrice(line);
        final digitOnly = line.replaceAll(RegExp(r'[^\d]'), '');
        if (price > 50 && digitOnly.length < 10) {
          standalonePrices.add(_StandalonePrice(price, idx));
        }
        continue;
      }

      // Coba parse sebagai item
      final item = _parseItem(line);
      if (item != null && !_nonItemPattern.hasMatch(item.name)) {
        if (item.price > 0) {
          items.add(item);
        } else {
          pendingItems.add(_PendingItem(item.name, item.qty, idx));
        }
      } else if (_looksLikeItemName(line)) {
        // Baris teks polos yang belum cocok format manapun
        final qtyM = RegExp(r'\s+x\s*(\d+)$', caseSensitive: false).firstMatch(line);
        if (qtyM != null) {
          final qty  = int.parse(qtyM.group(1)!);
          final name = line.substring(0, qtyM.start).trim();
          pendingItems.add(_PendingItem(name, qty, idx));
        } else {
          pendingItems.add(_PendingItem(line, 1, idx));
        }
      }
    }

    // Cocokkan pending items dengan standalone prices
    _matchPendingItems(pendingItems, standalonePrices, items);

    // Metadata keuangan
    final itemsSubtotal = items.fold<double>(0, (s, i) => s + i.subtotal);
    final meta = _extractMetadata(lines, itemsSubtotal);

    final computedTotal = (meta['subtotal'] as double)
        + (meta['discount'] as double)
        + (meta['serviceCharge'] as double)
        + (meta['tax'] as double)
        + (meta['pembulatan'] as double);

    return ParsedReceipt(
      items: items,
      subtotal: meta['subtotal'] as double,
      discount: meta['discount'] as double,
      serviceCharge: meta['serviceCharge'] as double,
      tax: meta['tax'] as double,
      pembulatan: meta['pembulatan'] as double,
      grandTotal: grandTotal ?? computedTotal,
      rawText: rawText,
      storeName: storeName,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  PENDING ITEMS MATCHER  (sequential by line proximity)
  // ─────────────────────────────────────────────────────────────────────

  static void _matchPendingItems(
    List<_PendingItem> pending,
    List<_StandalonePrice> prices,
    List<ReceiptItem> output,
  ) {
    if (pending.isEmpty || prices.isEmpty) return;
    final used = <int>{};

    for (final item in pending) {
      int? bestIdx;
      int? bestDist;

      for (int i = 0; i < prices.length; i++) {
        if (used.contains(i)) continue;
        final dist = prices[i].lineIdx - item.lineIdx;
        // Harga setelah item lebih dipercaya; harga sebelum item dikurangi sedikit
        final effective = dist >= 0 ? dist : (dist.abs() + 1000);
        if (bestDist == null || effective < bestDist) {
          bestDist = effective;
          bestIdx  = i;
        }
      }

      if (bestIdx != null) {
        used.add(bestIdx);
        final price     = prices[bestIdx].price;
        double unitPrice = price;
        if (item.qty > 1) {
          final divided = price / item.qty;
          if (divided == divided.roundToDouble() || divided % 500 == 0) {
            unitPrice = divided;
          }
        }
        output.add(ReceiptItem(name: item.name, qty: item.qty, price: unitPrice));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  ITEM NAME HEURISTIC
  // ─────────────────────────────────────────────────────────────────────

  static bool _looksLikeItemName(String line) {
    if (line.length < 4) return false;
    if (_nonItemPattern.hasMatch(line)) return false;
    if (_addressLine.hasMatch(line)) return false;
    if (line.startsWith(':') || line.startsWith('*')) return false;
    if (line.contains(':')) return false;

    final letters = line.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    final digits  = line.replaceAll(RegExp(r'[^\d]'), '');

    if (letters.length < 2) return false;
    if (digits.length > letters.length * 1.5) return false;
    if (line.trim().split(RegExp(r'\s+')).length < 2) return false;

    return true;
  }

  // ─────────────────────────────────────────────────────────────────────
  //  MERGE FRAGMENTED LINES
  // ─────────────────────────────────────────────────────────────────────

  static List<String> _mergeFragmentedLines(List<String> lines) {
    final merged   = <String>[];
    final consumed = <int>{};

    for (int i = 0; i < lines.length; i++) {
      if (consumed.contains(i)) continue;
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // [Set A] / [Paket B] → gabung dengan baris berikutnya
      if (line.startsWith('[') && line.contains(']')) {
        bool ok = false;
        for (int j = i + 1; j < lines.length; j++) {
          if (consumed.contains(j)) continue;
          final next = lines[j].trim();
          if (next.isNotEmpty && !_nonItemPattern.hasMatch(next) && !next.startsWith(':')) {
            merged.add('$line $next');
            consumed.add(j);
            ok = true;
            break;
          }
        }
        if (!ok) merged.add(line);
        continue;
      }

      // "x 3" / "X3" → gabung ke baris sebelumnya
      if (RegExp(r'^[xX]\s*\d+').hasMatch(line) && merged.isNotEmpty) {
        if (!_nonItemPattern.hasMatch(merged.last)) {
          final prev = merged.removeLast();
          merged.add('$prev $line');
          continue;
        }
      }

      // "- note" → continuation item
      if (line.startsWith('-') && merged.isNotEmpty && !_nonItemPattern.hasMatch(merged.last)) {
        final prev = merged.removeLast();
        merged.add('$prev $line');
        continue;
      }

      // Digit kecil berdiri sendiri (1–9) → qty untuk baris sebelumnya
      if (RegExp(r'^\d+$').hasMatch(line)) {
        final n = int.tryParse(line);
        if (n != null && n >= 1 && n <= 9 &&
            merged.isNotEmpty &&
            !_nonItemPattern.hasMatch(merged.last) &&
            !RegExp(r'\d$').hasMatch(merged.last)) {
          final prev = merged.removeLast();
          merged.add('$prev x $line');
          continue;
        }
      }

      merged.add(line);
    }

    print('=== MERGED LINES ===');
    merged.asMap().forEach((i, l) => print('$i: $l'));
    print('=== END MERGED ===');

    return merged;
  }

  // ─────────────────────────────────────────────────────────────────────
  //  PARSE SINGLE ITEM  (4 format)
  // ─────────────────────────────────────────────────────────────────────

  static ReceiptItem? _parseItem(String line) {
    if (line.length < 3) return null;
    if (line.startsWith(':')) return null;

    // Format 1: "Nama Item x 2 75.000"  /  "Nama Item x 2"
    final m1 = RegExp(r'^(.+?)\s+[xX]\s*(\d+)(?:\s+([\d.,]+))?$').firstMatch(line);
    if (m1 != null) {
      final name  = m1.group(1)!.trim();
      final qty   = int.tryParse(m1.group(2)!) ?? 1;
      final price = m1.group(3) != null ? _parsePrice(m1.group(3)!) : 0.0;
      if (name.length > 2 && !_nonItemPattern.hasMatch(name)) {
        return ReceiptItem(name: name, qty: qty, price: price);
      }
    }

    // Format 2: "2 Nama Item 75.000"  /  "2 Nama Item"
    final m2 = RegExp(r'^(\d+)\s+(.+?)(?:\s+([\d.,]+))?$').firstMatch(line);
    if (m2 != null) {
      final qty  = int.tryParse(m2.group(1)!) ?? 1;
      final name = m2.group(2)!.trim();
      final price = m2.group(3) != null ? _parsePrice(m2.group(3)!) : 0.0;

      if (RegExp(r'^(?:items?|pcs|buah|porsi|bungkus)$', caseSensitive: false).hasMatch(name)) {
        return null;
      }
      if (name.length > 2 &&
          !name.contains(RegExp(r'^\d')) &&
          !_nonItemPattern.hasMatch(name) &&
          qty <= 999) {
        return ReceiptItem(name: name, qty: qty, price: price);
      }
    }

    // Format 3: "Nama Item    75.000"  (spasi ≥ 2)
    final m3 = RegExp(r'^(.+?)\s{2,}([\d.,]+)\s*$').firstMatch(line);
    if (m3 != null) {
      final name  = m3.group(1)!.trim();
      final price = _parsePrice(m3.group(2)!);
      final isPhoneOrBig = price > 100000000 ||
          m3.group(2)!.replaceAll(RegExp(r'[\s.,]'), '').length > 12;
      if (!isPhoneOrBig && price >= 50 && name.length > 2 && !_nonItemPattern.hasMatch(name)) {
        return ReceiptItem(name: name, qty: 1, price: price);
      }
    }

    // Format 4: "Nama Item 75.000"  (spasi tunggal)
    final m4 = RegExp(r'^(.+?)\s+([\d.,]+)\s*$').firstMatch(line);
    if (m4 != null) {
      final name  = m4.group(1)!.trim();
      final price = _parsePrice(m4.group(2)!);
      final isPhoneOrBig = price > 100000000 ||
          m4.group(2)!.replaceAll(RegExp(r'[\s.,]'), '').length > 12;
      if (!isPhoneOrBig &&
          price >= 50 &&
          name.length > 2 &&
          !name.contains(RegExp(r'^[\d\-\s]+$')) &&
          !_nonItemPattern.hasMatch(name) &&
          !name.startsWith('-') &&
          !name.contains(RegExp(r'^\d{1,2}\/\d{1,2}'))) {
        return ReceiptItem(name: name, qty: 1, price: price);
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────
  //  METADATA EXTRACTION  (disc, SC, pajak, pembulatan)
  // ─────────────────────────────────────────────────────────────────────

  static Map<String, double> _extractMetadata(List<String> lines, double itemsSubtotal) {
    double subtotal      = itemsSubtotal;
    double discount      = 0;
    double serviceCharge = 0;
    double tax           = 0;
    double pembulatan    = 0;

    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();

      // Cari harga di baris ini atau baris berikutnya
      double? price = _extractPriceFromLine(lines[i]);
      if (price == null && i + 1 < lines.length) {
        price = _extractPriceFromLine(lines[i + 1]);
      }
      if (price == null || price.abs() <= 0) continue;

      if ((lower.contains('subtotal') || lower.contains('sub total')) &&
          subtotal == itemsSubtotal) {
        subtotal = price;
      } else if (lower.contains('disc') && discount == 0) {
        discount = -price.abs();
      } else if ((lower.contains('service') || RegExp(r'\bsc\b').hasMatch(lower)) &&
          serviceCharge == 0) {
        serviceCharge = price;
      } else if ((lower.contains('pb1') || lower.contains('ppn') || lower.contains('pajak')) &&
          tax == 0) {
        tax = price;
      } else if (lower.contains('pembulatan') && pembulatan == 0) {
        pembulatan = price;
      }
    }

    return {
      'subtotal': subtotal,
      'discount': discount,
      'serviceCharge': serviceCharge,
      'tax': tax,
      'pembulatan': pembulatan,
    };
  }

  static double? _extractPriceFromLine(String line) {
    for (final m in RegExp(r'[\d.,]+').allMatches(line).toList().reversed) {
      final v = _parsePrice(m.group(0)!);
      if (v > 0) return v;
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────
  //  PRICE PARSER  (Indonesia + Internasional)
  // ─────────────────────────────────────────────────────────────────────

  static double _parsePrice(String raw) {
    if (raw.isEmpty) return 0;
    String s = raw.trim().replaceAll(RegExp(r'\s+'), '');
    s = s.replaceAll(RegExp(r'^(?:rp\.?\s*|idr\s*)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'[^\d.,]'), '');
    if (s.isEmpty) return 0;

    if (!s.contains('.') && !s.contains(',')) return double.tryParse(s) ?? 0;

    final dots   = '.'.allMatches(s).length;
    final commas = ','.allMatches(s).length;

    if (dots >= 2) return double.tryParse(s.replaceAll('.', '')) ?? 0;

    if (dots == 1 && commas == 1) {
      return s.lastIndexOf('.') < s.lastIndexOf(',')
          ? double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0
          : double.tryParse(s.replaceAll(',', '')) ?? 0;
    }

    if (dots == 1) {
      return s.split('.').last.length == 3
          ? double.tryParse(s.replaceAll('.', '')) ?? 0
          : double.tryParse(s) ?? 0;
    }

    if (commas == 1) {
      return s.split(',').last.length == 3
          ? double.tryParse(s.replaceAll(',', '')) ?? 0
          : double.tryParse(s.replaceAll(',', '.')) ?? 0;
    }

    return double.tryParse(s.replaceAll(RegExp(r'[.,]'), '')) ?? 0;
  }
}

// ── Internal helpers ──────────────────────────────────────────────────

class _PendingItem {
  final String name;
  final int qty;
  final int lineIdx;
  _PendingItem(this.name, this.qty, this.lineIdx);
}

class _StandalonePrice {
  final double price;
  final int lineIdx;
  _StandalonePrice(this.price, this.lineIdx);
}