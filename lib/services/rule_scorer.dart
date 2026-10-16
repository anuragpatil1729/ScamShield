import 'dart:math' as math;

/// Layer 1: Rule-Based Scam Scorer
///
/// Ported from Python Layer 1 engine.
/// score in [-1, 1]: -1 = clearly legit, +1 = clearly scam.
/// label is binary: "scam" or "not_scam", deliberately biased toward "scam".
///   "scam"     -> forwarded to Layer 2 ML model (cheap to be wrong: ML can clear it).
///   "not_scam" -> delivered straight to the user (costly to be wrong: nobody re-checks it).
///
/// A message is "not_scam" only when Layer 1 is confident it is legit:
/// the combined score is low enough AND raw scam evidence is small.
/// Anything ambiguous or empty defaults to "scam".
/// feature_vector / FEATURE_NAMES: fixed-order numeric features for Layer 2.

const String kHomeCc = '+91';

// Decision thresholds (binary, biased toward "scam").
const double kLegitScoreMax = -0.30; // combined score must be at or below this
const double kLegitScamPMax = 0.25; // raw scam evidence must stay below this

const Map<String, List<String>> kBrands = {
  'sbi': ['sbi.co.in', 'onlinesbi.sbi', 'sbicard.com'],
  'hdfc': ['hdfcbank.com'],
  'icici': ['icicibank.com'],
  'axis': ['axisbank.com'],
  'paytm': ['paytm.com'],
  'phonepe': ['phonepe.com'],
  'amazon': ['amazon.in', 'amazon.com'],
  'flipkart': ['flipkart.com'],
  'paypal': ['paypal.com'],
  'netflix': ['netflix.com'],
  'microsoft': ['microsoft.com'],
  'apple': ['apple.com'],
  'google': ['google.com'],
  'fedex': ['fedex.com'],
  'dhl': ['dhl.com'],
  'irs': ['irs.gov'],
};

const Set<String> kShorteners = {
  'bit.ly',
  'tinyurl.com',
  't.co',
  'goo.gl',
  'cutt.ly',
  'rb.gy',
  'is.gd',
};

const Set<String> kFreeMail = {
  'gmail.com',
  'yahoo.com',
  'outlook.com',
  'hotmail.com',
  'proton.me',
  'protonmail.com',
  'rediffmail.com',
};

class RuleEntry {
  final RegExp regex;
  final double weight;
  RuleEntry(String pattern, this.weight)
      : regex = RegExp(pattern, caseSensitive: false, multiLine: true);
}

class HitEntry {
  final String category;
  final double weight;
  final String match;

  const HitEntry({
    required this.category,
    required this.weight,
    required this.match,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'weight': weight,
    'match': match,
  };
}

class SenderInfo {
  final String type;
  final bool verified;

  const SenderInfo({
    required this.type,
    required this.verified,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'verified': verified,
  };
}

const List<String> kScamCats = [
  'urgency',
  'threat',
  'credentials',
  'money_lure',
  'payment_request',
  'impersonation',
  'relationship_romance',
  'link_lure',
  'secrecy',
  'structure',
  'hinglish',
  'domain',
  'sender',
];

const List<String> kHamCats = [
  'otp_safety',
  'txn_alert',
  'service_notice',
  'casual',
  'trusted_domain',
  'sender',
];

const List<String> kSenderTypes = [
  'none',
  'header',
  'shortcode',
  'phone',
  'email',
  'other',
];

final List<String> kFeatureNames = [
  'score',
  'scam_score',
  'ham_score',
  'scam_hit_count',
  'ham_hit_count',
  'strong_cat_count',
  'leet_changed',
  'hinglish_hit_count',
  ...kScamCats.map((c) => 'scam_$c'),
  ...kHamCats.map((c) => 'ham_$c'),
  'len_log',
  'digit_ratio',
  'upper_ratio',
  'punct_ratio',
  'exclaim_count',
  'currency_count',
  'max_amount_log',
  'url_count',
  'phone_count',
  'upi_count',
  'sender_verified',
  'sender_known',
  ...kSenderTypes.map((s) => 'sender_$s'),
];

class RuleScorerResult {
  final double score;
  final String label; // "scam" or "not_scam"
  final String route; // "deliver" or "layer2_ml"
  final double scamScore;
  final double hamScore;
  final SenderInfo sender;
  final Map<String, double> scamCategories;
  final Map<String, double> hamCategories;
  final List<HitEntry> scamHits;
  final List<HitEntry> hamHits;
  final Map<String, double> features;
  final List<double> featureVector;

  const RuleScorerResult({
    required this.score,
    required this.label,
    required this.route,
    required this.scamScore,
    required this.hamScore,
    required this.sender,
    required this.scamCategories,
    required this.hamCategories,
    required this.scamHits,
    required this.hamHits,
    required this.features,
    required this.featureVector,
  });

  Map<String, dynamic> toJson() => {
    'score': score,
    'label': label,
    'route': route,
    'scam_score': scamScore,
    'ham_score': hamScore,
    'sender': sender.toJson(),
    'scam_categories': scamCategories,
    'ham_categories': hamCategories,
    'scam_hits': scamHits.map((h) => h.toJson()).toList(),
    'ham_hits': hamHits.map((h) => h.toJson()).toList(),
    'features': features,
    'feature_vector': featureVector,
  };
}

class Layer1RuleScorer {
  late final Map<String, List<RuleEntry>> _scamRules;
  late final Map<String, List<RuleEntry>> _hamRules;

  static final List<RegExp> _urlPats = [
    RegExp(r'https?://([^/\s:?#]+)', caseSensitive: false),
    RegExp(r'\bwww\.([a-z0-9.-]+\.[a-z]{2,})', caseSensitive: false),
    RegExp(
      r'\b((?:[a-z0-9-]+\.)+(?:com|in|net|org|xyz|top|click|club|info|icu|buzz|rest|cfd|co|io|me|ly|app|link|site|online|live|bank|gov))/',
      caseSensitive: false,
    ),
  ];

  static final RegExp _phoneRx = RegExp(r'(?<![\d+])\+?\d[\d\s\-]{8,13}\d');
  static final RegExp _upiRx = RegExp(
    r'\b[a-z0-9._\-]{2,}@(?:ybl|ibl|axl|oksbi|okaxis|okhdfcbank|okicici|paytm|apl|upi)\b',
    caseSensitive: false,
  );
  static final RegExp _amtRx = RegExp(
    r'(?:₹|rs\.?|inr|\$|usd|€|£)\s?(\d[\d,]*(?:\.\d+)?)',
    caseSensitive: false,
  );

  static const Map<String, String> _leetMap = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '@': 'a',
    '\$': 's',
  };

  static const Map<String, String> _lookMap = {
    '0': 'o',
    '1': 'l',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '@': 'a',
    '\$': 's',
  };

  Layer1RuleScorer() {
    _initRules();
  }

  void _initRules() {
    final rawRules = {
      'urgency': [
        (r'\b(act|reply|respond|call|click) (now|immediately|asap|today)\b', 0.35),
        (r'\b(within|in) (24|48|12|2|1) ?(hours?|hrs?)\b', 0.30),
        (r'\blast (chance|warning|notice)\b', 0.40),
        (r'\b(expires?|expiring) (today|soon|tonight)\b', 0.30),
        (r'\b(urgent|immediate action|final notice)\b', 0.30),
      ],
      'threat': [
        (r'\b(account|card|sim|number|service)\b.{0,30}\b(blocked|suspended|deactivated|disconnected|closed|frozen)\b', 0.55),
        (r'\blegal action\b|\barrest warrant\b|\bdigital arrest\b', 0.60),
        (r'\b(unauthori[sz]ed|suspicious) (login|activity|transaction|access)\b', 0.45),
      ],
      'credentials': [
        (r"(?<!not )(?<!never )(?<!n't )(?<!dont )(?<!not to )\b(share|send|enter|provide|confirm) (your |the )?(otp|pin|cvv|password|passcode)\b", 0.80),
        (r'\b(verify|update|confirm) (your )?(kyc|account|identity|details|bank|card)\b', 0.55),
        (r'\b(otp|cvv|pin)\b', 0.20),
        (r'\b(aadhaar|pan card|ssn|social security)\b.{0,30}\b(update|verify|link|expired?)\b', 0.55),
      ],
      'money_lure': [
        (r"\b(you('| ha)ve|you are|you)\s*(won|been selected|been chosen)\b", 0.60),
        (r'\b(lottery|jackpot|prize|lucky draw|sweepstakes?)\b', 0.50),
        (r'\b(claim|collect) (your )?(prize|reward|refund|cash|gift)\b', 0.55),
        (r'\b(refund|cashback|reward points?)\b.{0,30}\b(pending|expire|claim)\b', 0.45),
        (r'\b(free|bonus) (gift|iphone|money|cash|recharge)\b', 0.40),
        (r'\b(guaranteed|assured) (returns?|profit|income)\b', 0.60),
        (r'\b(double|triple) your (money|investment)\b', 0.70),
        (r'\b(work from home|earn) (\$|rs\.?|inr|₹)?\s?\d+[\d,]* ?(per|a|/) ?(day|hour|week)\b', 0.55),
      ],
      'payment_request': [
        (r'\b(gift ?cards?|itunes|google play card|steam card)\b', 0.55),
        (r'\b(crypto|bitcoin|usdt|btc)\b.{0,40}\b(send|transfer|pay|deposit)\b', 0.55),
        (r'\b(wire|transfer|send) (the )?(money|funds|payment|fee)\b', 0.45),
        (r'\b(processing|registration|clearance|customs|release) fee\b', 0.60),
        (r'\b(upi|paytm|gpay|phonepe)\b.{0,30}\b(request|collect|pay|send)\b', 0.30),
      ],
      'impersonation': [
        (r'\b(dear (customer|user|member|winner|sir/?madam|valued))\b', 0.30),
        (r'\b(bank|irs|hmrc|customs|police|cbi|rbi|amazon|paypal|netflix|fedex|dhl|microsoft|apple) (support|team|officer|department|security)\b', 0.35),
        (r'\b(electricity|power) (bill|connection)\b.{0,40}\b(disconnect|cut|tonight|unpaid)\b', 0.55),
        (r'\b(package|parcel|delivery)\b.{0,40}\b(held|failed|pending|undeliverable|customs)\b', 0.40),
      ],
      'relationship_romance': [
        (r"\b(i am|i'm) (a )?(widow|soldier|deployed|stranded|oil rig)\b", 0.55),
        (r'\b(inheritance|next of kin|unclaimed funds?)\b', 0.65),
        (r'\b(trust me|god fearing|kindly assist)\b', 0.40),
        (r'\b(i need (your )?help|emergency).{0,40}\b(money|send|transfer)\b', 0.45),
      ],
      'link_lure': [
        (r'https?://\S+', 0.10),
        (r'\b(bit\.ly|tinyurl\.com|t\.co|goo\.gl|cutt\.ly|rb\.gy|is\.gd)/\S+', 0.40),
        (r'\bhttps?://\S*\.(xyz|top|click|club|info|icu|buzz|rest|cfd)\b', 0.40),
        (r'\b(click|tap|open|visit) (the |this )?(link|below|here)\b', 0.30),
      ],
      'secrecy': [
        (r"\b(do not|don't|dont) (tell|share|inform) (anyone|anybody|family|others)\b", 0.55),
        (r'\b(confidential|keep (this )?(secret|private))\b', 0.35),
      ],
      'structure': [
        (r'\b(call|whatsapp|contact|dial|message|text)\b.{0,25}?(?<![\d+])(?!1800)\+?\d[\d\s\-]{8,13}\d', 0.35),
        (r'\b(join|add|contact|message|text)\b.{0,25}\b(whatsapp|telegram|signal)\b', 0.40),
        (r'\b[a-z0-9._\-]{2,}@(?:ybl|ibl|axl|oksbi|okaxis|okhdfcbank|okicici|paytm|apl|upi)\b', 0.30),
        (r'\b(won|prize|claim|reward|pay|send|transfer|deposit|fee|refund|earn|gift)\b.{0,40}(?:₹|rs\.?|inr|\$|usd|€|£)\s?\d[\d,]{3,}', 0.25),
      ],
      'hinglish': [
        (r'\b(aapka|aapki|aapke|apka|apki) (?:\w+ )?(account|khata|card|sim|number|kyc)\b.{0,30}\b(band|block|blocked|suspend|suspended|bandh|expire|expired)\b', 0.55),
        (r'\b(turant|jaldi|abhi|foran)\b.{0,15}\b(call|click|reply|verify|update|contact|link)\b', 0.35),
        (r'\bkyc\b.{0,20}\b(update|verify|expire|pending)\b.{0,20}\b(karein|karo|kare|karna|nahi|nahin)\b', 0.55),
        (r'\b(otp|pin|cvv|password)\b(?!.{0,25}\b(na|nahi|nahin|mat|never)\b).{0,15}\b(share|bhej|bhejo|bhejiye|batao|batayen|batayein|bataiye|dijiye)\b', 0.80),
        (r'\b(aapne|aap ne|aapko|aapki)\b.{0,30}\b(jeet|jeeta|jita|lottery|inaam|inam|prize)\b', 0.60),
        (r'\bghar baithe\b.{0,25}\b(kama|kamaye|kamao|paise|income|earning)\b', 0.55),
        (r'\b(paise|paisa|rupye|money)\b.{0,12}\b(double|dugna|dugne|dugni)\b', 0.65),
        (r'\baapke naam (par|pe|se)\b.{0,30}\b(parcel|courier|drugs|fir|case|warrant)\b', 0.60),
        (r'\b(yeh|ye|is) (baat|bat|case|call)\b.{0,25}\b(kisi ko|kisi se|kisise)\b.{0,12}\b(mat|na|nahi|nahin)\b', 0.55),
        (r'\b(link|neeche|niche)\b.{0,15}\bclick\b|\bclick kar(ein|o|e)\b', 0.30),
        (r'(खाता|अकाउंट|कार्ड|सिम).{0,20}(बंद|बन्द|ब्लॉक|सस्पेंड)', 0.55),
        (r'(ओटीपी|पिन|सीवीवी|पासवर्ड)(?!.{0,25}(न |नहीं|मत)).{0,15}(शेयर|बताएं|बताइए|भेजें|भेजिए)', 0.80),
        (r'(केवाईसी|kyc).{0,20}(अपडेट|वेरिफाई|वेरीफाई|एक्सपायर)', 0.55),
        (r'लॉटरी|इनाम', 0.50),
        (r'तुरंत', 0.30),
      ],
    };

    final rawHamRules = {
      'otp_safety': [
        (r"\b(do not|don't|dont|never|not) (to )?(share|disclose|reveal|give)\b.{0,30}\b(otp|code|pin|cvv|password)\b", 0.55),
        (r'\b(otp|one[- ]time password|verification code|login code|security code)\b.{0,30}\b(is|:)\s*\d{4,8}\b|\b\d{4,8} (is|is your|is the) (your |the )?(otp|one[- ]time password|verification code|login code|security code)\b', 0.45),
        (r'\b(we|bank|team|staff|employees?) (will )?never (ask|call|request)\b.{0,30}\b(otp|pin|cvv|password)\b', 0.55),
        (r'\b(otp|pin|cvv|password)\b.{0,30}\b(kisi (ko|se)|kisise|kisi aur)\b.{0,15}\b(na|nahi|nahin|mat)\b', 0.55),
        (r'(ओटीपी|पिन|पासवर्ड).{0,30}किसी.{0,15}(न |नहीं|मत)', 0.55),
      ],
      'txn_alert': [
        (r'\b(debited|credited|withdrawn|spent)\b.{0,60}\b(a/c|acct|account|card|upi)\b|\b(a/c|acct|account|card)\b.{0,40}\b(debited|credited)\b', 0.40),
        (r'\bavl\.? ?bal(ance)?\b|\bavailable balance\b', 0.30),
      ],
      'service_notice': [
        (r'\b(appointment|booking|reservation)\b.{0,40}\b(confirmed|scheduled|reminder)\b', 0.30),
        (r'\b(order|shipment)\b.{0,15}#?\w*\d+.{0,40}\b(shipped|dispatched|delivered|out for delivery)\b', 0.30),
        (r'\bnumber (on|at) the back of your card\b|\bvisit (your |the )?(nearest|home) branch\b|\bofficial (app|website)\b', 0.35),
      ],
      'casual': [
        (r'\b(are we|see you|see ya|talk later|call you later|on my way|running late|reached home)\b', 0.30),
        (r'\b(dinner|lunch|breakfast|movie|coffee|party|birthday|meeting)\b', 0.20),
        (r'\b(thanks|thank you|lol|haha|bro|bhai|dude|mom|dad)\b', 0.20),
        (r'\b(kya haal|kaise ho|kya chal raha|ghar pahunch|khana kha|kal milte|theek hai|thik hai)\b', 0.25),
      ],
    };

    _scamRules = rawRules.map((k, v) => MapEntry(k, v.map((p) => RuleEntry(p.$1, p.$2)).toList()));
    _hamRules = rawHamRules.map((k, v) => MapEntry(k, v.map((p) => RuleEntry(p.$1, p.$2)).toList()));
  }

  static String normalize(String text) {
    // Remove zero-width characters: \u200B, \u200C, \u200D, \u2060, \uFEFF
    var t = text.replaceAll(RegExp(r'[\u200b\u200c\u200d\u2060\ufeff]'), '').toLowerCase();
    t = t.replaceAll('\u2019', "'").replaceAll('\u2018', "'");
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static String leetNormalize(String t) {
    final List<String> out = [];
    final tokens = t.split(' ');
    for (final tok in tokens) {
      final core = tok.replaceAll(RegExp(r"""^[\.,;:!\?\(\)\[\]'"]+|[\.,;:!\?\(\)\[\]'"]+$"""), '');
      final alphaCount = core.codeUnits.where((c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122)).length;
      final maxLen = math.max(core.length, 1);
      final isWordLike = alphaCount >= 2 && (alphaCount / maxLen >= 0.5);
      final hasUrlOrEmail = core.contains('://') ||
          core.contains('www.') ||
          core.contains('/') ||
          RegExp(r'[a-z0-9]\.[a-z]{2,}', caseSensitive: false).hasMatch(core) ||
          RegExp(r'@\w+\.', caseSensitive: false).hasMatch(core);

      if (!isWordLike || hasUrlOrEmail) {
        out.add(tok);
      } else {
        var translated = tok;
        _leetMap.forEach((k, v) {
          translated = translated.replaceAll(k, v);
        });
        out.add(translated);
      }
    }
    return out.join(' ');
  }

  void _scan(String t, Map<String, List<RuleEntry>> compiled, List<HitEntry> hits) {
    for (final entry in compiled.entries) {
      for (final rule in entry.value) {
        final m = rule.regex.firstMatch(t);
        if (m != null) {
          final matchedText = m.group(0)!;
          hits.add(HitEntry(
            category: entry.key,
            weight: rule.weight,
            match: matchedText.length > 60 ? matchedText.substring(0, 60) : matchedText,
          ));
        }
      }
    }
  }

  Set<String> _hosts(String t) {
    final Set<String> hosts = {};
    for (final p in _urlPats) {
      for (final m in p.allMatches(t)) {
        if (m.groupCount >= 1 && m.group(1) != null) {
          var h = m.group(1)!.trim().replaceAll(RegExp(r"""[\.,\);'"\s]+$"""), '');
          if (h.isNotEmpty) {
            hosts.add(h);
          }
        }
      }
    }
    return hosts;
  }

  bool _isOfficial(String host, [String? brand]) {
    final List<String> doms = brand != null
        ? (kBrands[brand] ?? [])
        : kBrands.values.expand((element) => element).toList();
    return doms.any((d) => host == d || host.endsWith('.$d'));
  }

  void _domainSignals(String t, List<HitEntry> scam, List<HitEntry> ham) {
    for (final h in _hosts(t)) {
      if (kShorteners.contains(h)) continue;

      if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(h)) {
        scam.add(HitEntry(category: 'domain', weight: 0.55, match: h));
        continue;
      }

      if (h.contains('xn--')) {
        scam.add(HitEntry(category: 'domain', weight: 0.50, match: h));
      }

      if (_isOfficial(h)) {
        ham.add(HitEntry(category: 'trusted_domain', weight: 0.35, match: h));
        continue;
      }

      var lookH = h;
      _lookMap.forEach((k, v) {
        lookH = lookH.replaceAll(k, v);
      });
      final lookH2 = h.replaceAll('1', 'i');
      var lookH2Mapped = lookH2;
      _lookMap.forEach((k, v) {
        lookH2Mapped = lookH2Mapped.replaceAll(k, v);
      });

      final variants = {h, lookH, lookH2Mapped};
      final toks = variants.expand((v) => v.split(RegExp(r'[.\-]'))).toSet();

      final brandMatched = kBrands.keys.any((b) =>
          toks.contains(b) || (b.length >= 4 && toks.any((tk) => tk.contains(b))));

      if (brandMatched) {
        scam.add(HitEntry(category: 'domain', weight: 0.60, match: h));
      }

      if (h.split('-').length - 1 >= 2) {
        scam.add(HitEntry(category: 'domain', weight: 0.30, match: h));
      }

      if (h.split('.').length - 1 >= 4) {
        scam.add(HitEntry(category: 'domain', weight: 0.25, match: h));
      }

      if (RegExp(r'(verify|secure|login|update|kyc|refund|claim|reward|bonus)', caseSensitive: false)
          .hasMatch(h)) {
        scam.add(HitEntry(category: 'domain', weight: 0.35, match: h));
      }
    }
  }

  String _senderType(String? s) {
    if (s == null || s.trim().isEmpty) return 'none';
    final trimmed = s.trim();
    if (trimmed.contains('@')) return 'email';
    if (RegExp(r'^\+?[\d\s\-()]{10,16}$').hasMatch(trimmed)) return 'phone';
    if (RegExp(r'^\+?\d{3,6}$').hasMatch(trimmed)) return 'shortcode';
    if (RegExp(r'^(?:[a-zA-Z]{2}-[a-zA-Z0-9]{3,8}(?:-[a-zA-Z])?|[a-zA-Z][a-zA-Z0-9]{3,10})$')
        .hasMatch(trimmed)) {
      return 'header';
    }
    return 'other';
  }

  String _core(String h) {
    var s = h.trim().toUpperCase();
    s = s.replaceAll(RegExp(r'^[A-Z]{2}-'), ''); // operator prefix
    return s.replaceAll(RegExp(r'-[A-Z]$'), ''); // category suffix
  }

  Map<String, String?>? _normRegistry(Map<String, String?>? reg) {
    if (reg == null) return null;
    return reg.map((k, v) => MapEntry(_core(k), v?.toLowerCase()));
  }

  (String, bool, bool) _senderSignals(
    String? sender,
    String t,
    Set<String> known,
    Map<String, String?>? registry,
    List<HitEntry> scam,
    List<HitEntry> ham,
  ) {
    final s = (sender ?? '').trim();
    final stype = _senderType(s);
    if (stype == 'none') return (stype, false, false);

    if (known.contains(s) || known.any((k) => k.toLowerCase() == s.toLowerCase())) {
      ham.add(const HitEntry(category: 'sender', weight: 0.80, match: 'known contact'));
      return (stype, true, true);
    }

    final brandInText = kBrands.keys.any((b) => RegExp('\\b$b', caseSensitive: false).hasMatch(t)) ||
        t.contains('bank');
    final hasUrl = _hosts(t).isNotEmpty;
    final reg = _normRegistry(registry);

    if (stype == 'header') {
      final core = _core(s);
      if (reg != null && reg.containsKey(core)) {
        ham.add(HitEntry(category: 'sender', weight: 0.60, match: 'verified header $core'));
        final vb = reg[core];
        if (vb != null && vb.isNotEmpty) {
          final bad = _hosts(t).where((h) => !kShorteners.contains(h) && !_isOfficial(h, vb)).toList();
          if (bad.isNotEmpty) {
            scam.add(HitEntry(category: 'sender', weight: 0.45, match: '$core links to ${bad[0]}'));
          }
        }
        return (stype, true, false);
      }
      if (reg != null) {
        if (kBrands.keys.any((b) => core.toLowerCase().contains(b))) {
          scam.add(HitEntry(category: 'sender', weight: 0.35, match: 'unverified header claims brand: $core'));
        } else if (brandInText) {
          scam.add(const HitEntry(category: 'sender', weight: 0.15, match: 'unverified header, brand in text'));
        }
      }
      return (stype, false, false);
    }

    if (stype == 'email') {
      final dom = s.toLowerCase().split('@').last;
      if (kFreeMail.contains(dom) && brandInText) {
        scam.add(const HitEntry(category: 'sender', weight: 0.50, match: 'free-mail sender claiming a brand'));
      } else if (brandInText && !_isOfficial(dom)) {
        scam.add(const HitEntry(category: 'sender', weight: 0.35, match: 'brand message from unrelated email domain'));
      }
    } else if (stype == 'phone') {
      if (brandInText) {
        scam.add(const HitEntry(category: 'sender', weight: 0.45, match: 'brand message from personal number'));
      }
      if (s.startsWith('+') && !s.startsWith(kHomeCc)) {
        scam.add(const HitEntry(category: 'sender', weight: 0.20, match: 'foreign number'));
      }
      if (hasUrl) {
        scam.add(const HitEntry(category: 'sender', weight: 0.20, match: 'link from personal number'));
      }
    } else if (brandInText) {
      scam.add(const HitEntry(category: 'sender', weight: 0.15, match: 'unrecognized sender claiming a brand'));
    }

    return (stype, false, false);
  }

  (double, Map<String, double>) _combine(List<HitEntry> hits) {
    final Map<String, double> cats = {};
    for (final h in hits) {
      final prev = cats[h.category] ?? 0.0;
      cats[h.category] = 1.0 - (1.0 - prev) * (1.0 - h.weight);
    }
    double prod = 1.0;
    for (final s in cats.values) {
      prod *= (1.0 - s);
    }
    final combined = cats.isEmpty ? 0.0 : (1.0 - prod);
    return (combined, cats);
  }

  Map<String, double> _features({
    required String text,
    required String t,
    required List<HitEntry> scam,
    required List<HitEntry> ham,
    required double scamP,
    required double hamP,
    required double score,
    required Map<String, double> scamCats,
    required Map<String, double> hamCats,
    required int nStrong,
    required bool leetChanged,
    required String stype,
    required bool verified,
    required bool known,
  }) {
    final n = math.max(text.length, 1);
    final amts = _amtRx.allMatches(t).map((m) {
      final s = m.group(1)!.replaceAll(',', '');
      return double.tryParse(s) ?? 0.0;
    }).toList();

    int digitCount = 0;
    int upperCount = 0;
    int punctCount = 0;

    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 48 && code <= 57) digitCount++;
      if (code >= 65 && code <= 90) upperCount++;
      final ch = text[i];
      if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\\/;~`+=]').hasMatch(ch)) {
        punctCount++;
      }
    }

    final currencyCount = RegExp(r'₹|\$|€|£|\brs\.?|\binr\b|\busd\b', caseSensitive: false)
        .allMatches(t)
        .length;
    final maxAmount = amts.isNotEmpty ? amts.reduce(math.max) : 0.0;

    final Map<String, double> f = {
      'score': score,
      'scam_score': scamP,
      'ham_score': hamP,
      'scam_hit_count': scam.length.toDouble(),
      'ham_hit_count': ham.length.toDouble(),
      'strong_cat_count': nStrong.toDouble(),
      'leet_changed': leetChanged ? 1.0 : 0.0,
      'hinglish_hit_count': scam.where((h) => h.category == 'hinglish').length.toDouble(),
      'len_log': math.log(1.0 + text.length) / math.ln10,
      'digit_ratio': digitCount / n,
      'upper_ratio': upperCount / n,
      'punct_ratio': punctCount / n,
      'exclaim_count': (text.split('!').length - 1).toDouble(),
      'currency_count': currencyCount.toDouble(),
      'max_amount_log': maxAmount > 0 ? math.log(1.0 + maxAmount) / math.ln10 : 0.0,
      'url_count': _hosts(t).length.toDouble(),
      'phone_count': _phoneRx.allMatches(t).length.toDouble(),
      'upi_count': _upiRx.allMatches(t).length.toDouble(),
      'sender_verified': verified ? 1.0 : 0.0,
      'sender_known': known ? 1.0 : 0.0,
    };

    for (final c in kScamCats) {
      f['scam_$c'] = scamCats[c] ?? 0.0;
    }
    for (final c in kHamCats) {
      f['ham_$c'] = hamCats[c] ?? 0.0;
    }
    for (final s in kSenderTypes) {
      f['sender_$s'] = (stype == s) ? 1.0 : 0.0;
    }

    return f.map((k, v) => MapEntry(k, (v * 10000).round() / 10000));
  }

  /// Score a message using the complete Layer 1 rule-based engine.
  RuleScorerResult scoreMessage(
    String text, {
    String? sender,
    Iterable<String> knownContacts = const [],
    Map<String, String?>? verifiedSenders,
  }) {
    final t = normalize(text);
    final List<HitEntry> scam = [];
    final List<HitEntry> ham = [];

    _scan(t, _scamRules, scam);

    final t2 = leetNormalize(t);
    final leetChanged = t2 != t;
    if (leetChanged) {
      final List<HitEntry> extra = [];
      _scan(t2, _scamRules, extra);
      final seen = scam.map((h) => '${h.category}:${h.match}').toSet();
      for (final h in extra) {
        if (!seen.contains('${h.category}:${h.match}')) {
          scam.add(h);
        }
      }
    }

    final letters = text.codeUnits.where((c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122)).toList();
    if (letters.length >= 15) {
      final upperCount = letters.where((c) => c >= 65 && c <= 90).length;
      if (upperCount / letters.length > 0.5) {
        scam.add(const HitEntry(category: 'structure', weight: 0.25, match: 'mostly caps'));
      }
    }

    if ((text.split('!').length - 1 >= 3) || text.contains('!!')) {
      scam.add(const HitEntry(category: 'structure', weight: 0.20, match: 'excess !'));
    }

    _domainSignals(t, scam, ham);

    final (stype, verified, known) = _senderSignals(
      sender,
      t,
      knownContacts.toSet(),
      verifiedSenders,
      scam,
      ham,
    );

    _scan(t, _hamRules, ham);

    var (scamP, scamCats) = _combine(scam);
    final strong = scamCats.entries.where((e) => e.value >= 0.3).map((e) => e.key).toList();

    if (strong.length >= 3) {
      scamP = math.min(1.0, scamP + 0.10);
    }
    if (scamCats.containsKey('link_lure') && strong.length >= 2) {
      scamP = math.min(1.0, scamP + 0.05);
    }

    var (hamP, hamCats) = _combine(ham);
    if (!verified) {
      hamP = math.min(hamP, 0.60); // text-only legit cues capped
    }

    final score = scamP - hamP * (1.0 - scamP);

    // Decision rule (binary and scam-biased)
    final isLegit = score <= kLegitScoreMax && scamP < kLegitScamPMax;
    final label = isLegit ? 'not_scam' : 'scam';
    final route = isLegit ? 'deliver' : 'layer2_ml';

    final feats = _features(
      text: text,
      t: t,
      scam: scam,
      ham: ham,
      scamP: scamP,
      hamP: hamP,
      score: score,
      scamCats: scamCats,
      hamCats: hamCats,
      nStrong: strong.length,
      leetChanged: leetChanged,
      stype: stype,
      verified: verified,
      known: known,
    );

    final featureVector = kFeatureNames.map((k) => feats[k] ?? 0.0).toList();

    return RuleScorerResult(
      score: (score * 1000).round() / 1000,
      label: label,
      route: route,
      scamScore: (scamP * 1000).round() / 1000,
      hamScore: (hamP * 1000).round() / 1000,
      sender: SenderInfo(type: stype, verified: verified),
      scamCategories: scamCats.map((k, v) => MapEntry(k, (v * 1000).round() / 1000)),
      hamCategories: hamCats.map((k, v) => MapEntry(k, (v * 1000).round() / 1000)),
      scamHits: scam,
      hamHits: ham,
      features: feats,
      featureVector: featureVector,
    );
  }
}
