import '../../domain/entities/blueprint_element_entity.dart';

class BlueprintTranslationMap {
  static const Map<String, String> pageTitles = {
    'Page-1': 'First Floor',
    'CZwG6OWdVMjHw0YqGgOi': 'Ground Floor & Warehouses',
    '2SKE6Rj-lpadhde2bo0e': 'Security Gates',
    'دور الاول': 'First Floor',
    'الدورالارضي ومخازن': 'Ground Floor & Warehouses',
    'البوابات': 'Security Gates',
  };

  /// Explicit cell ID to English translation and category
  static const Map<String, ({String english, BlueprintElementCategory category})> cellOverrides = {
    // Infrastructure & Systems
    '43': (english: 'Main Server', category: BlueprintElementCategory.server),
    '48': (english: 'IP-PBX Telephony System', category: BlueprintElementCategory.telephony),
    'eapRq2363cJ19KXHNwYQ-452': (english: 'Warehouse Switch', category: BlueprintElementCategory.switchDevice),
    'YB2jpgnsKaUNnIzHBjIM-5': (english: 'D-Link Switch', category: BlueprintElementCategory.switchDevice),
    'YB2jpgnsKaUNnIzHBjIM-8': (english: 'Spare Parts Switch', category: BlueprintElementCategory.switchDevice),
    '0SK14sVCR1hRAYqBbC6O-14': (english: 'Server Room Sub-Hub', category: BlueprintElementCategory.server),
    '0SK14sVCR1hRAYqBbC6O-16': (english: 'Fiber Optic + Cat6 Backbone', category: BlueprintElementCategory.generic),
    'M2PY9Z2AMNSf3wnmK2pj-512': (english: 'CCTV Monitoring Station', category: BlueprintElementCategory.security),

    // Departments & Facilities
    'Hb8qYRKMqdVbagsCLfOX-478': (english: 'Accounting Department', category: BlueprintElementCategory.office),
    'Hb8qYRKMqdVbagsCLfOX-488': (english: 'Treasury / Safe Room', category: BlueprintElementCategory.room),
    'Hb8qYRKMqdVbagsCLfOX-552': (english: 'Accounting Manager Office', category: BlueprintElementCategory.office),
    'Hb8qYRKMqdVbagsCLfOX-553': (english: 'Purchasing Department', category: BlueprintElementCategory.office),
    'eapRq2363cJ19KXHNwYQ-455': (english: 'Maintenance Department', category: BlueprintElementCategory.office),
    'eapRq2363cJ19KXHNwYQ-456': (english: 'Plant General Manager Office', category: BlueprintElementCategory.office),
    'Hb8qYRKMqdVbagsCLfOX-592': (english: 'Quality Assurance (QA/QC)', category: BlueprintElementCategory.office),
    'M2PY9Z2AMNSf3wnmK2pj-475': (english: 'Projects Office', category: BlueprintElementCategory.office),
    'M2PY9Z2AMNSf3wnmK2pj-480': (english: 'Projects Office', category: BlueprintElementCategory.office),
    'M2PY9Z2AMNSf3wnmK2pj-501': (english: 'IT Support Office', category: BlueprintElementCategory.office),
    'M2PY9Z2AMNSf3wnmK2pj-502': (english: 'Projects Office', category: BlueprintElementCategory.office),
    'M2PY9Z2AMNSf3wnmK2pj-578': (english: 'Cafeteria', category: BlueprintElementCategory.room),
    'M2PY9Z2AMNSf3wnmK2pj-579': (english: 'Conference / Meeting Room', category: BlueprintElementCategory.room),
    'M2PY9Z2AMNSf3wnmK2pj-582': (english: 'Human Resources (HR)', category: BlueprintElementCategory.office),
    'M2PY9Z2AMNSf3wnmK2pj-468': (english: 'Central Corridor', category: BlueprintElementCategory.room),
    'G93ZiwP67btLzS48jiix-452': (english: 'Cafeteria', category: BlueprintElementCategory.room),
    '0SK14sVCR1hRAYqBbC6O-17': (english: 'Storage Bay 1', category: BlueprintElementCategory.room),
    '0SK14sVCR1hRAYqBbC6O-18': (english: 'Storage Bay 2', category: BlueprintElementCategory.room),
    '0SK14sVCR1hRAYqBbC6O-19': (english: 'Storage Bay 3', category: BlueprintElementCategory.room),
    '0SK14sVCR1hRAYqBbC6O-20': (english: 'Central Warehouses', category: BlueprintElementCategory.room),
    'EL4SRh6Te1i-fMCGcN39-29': (english: 'Raw Material Office', category: BlueprintElementCategory.office),
    'EL4SRh6Te1i-fMCGcN39-30': (english: 'Warehouse Floor', category: BlueprintElementCategory.room),
    'cVh2oM52pXEjVl7mcNOq-2': (english: 'Logistics Office', category: BlueprintElementCategory.office),
    'bUzkar9Z3lB0ubGY5Ex2-7': (english: 'Spare Parts Tech Desk', category: BlueprintElementCategory.office),
    'gpzh1zODavnf_gc-slgo-1': (english: 'Security Office — Gate 2', category: BlueprintElementCategory.security),
    'gpzh1zODavnf_gc-slgo-2': (english: 'Security Office — Gate 1', category: BlueprintElementCategory.security),

    // Employees & Workstations
    'ceP4y6ojxmYwGNpgX_tI-460': (english: 'Mostafa Mohamed', category: BlueprintElementCategory.workstation),
    'ceP4y6ojxmYwGNpgX_tI-496': (english: 'Mostafa Ayman', category: BlueprintElementCategory.workstation),
    'Hb8qYRKMqdVbagsCLfOX-455': (english: 'Hisham Essam', category: BlueprintElementCategory.workstation),
    'Hb8qYRKMqdVbagsCLfOX-476': (english: 'Amr Rafaat (Laptop)', category: BlueprintElementCategory.laptop),
    'Hb8qYRKMqdVbagsCLfOX-483': (english: 'Abdel Moneim Hazaa (Laptop)', category: BlueprintElementCategory.laptop),
    'Hb8qYRKMqdVbagsCLfOX-495': (english: 'Ahmed Helmy', category: BlueprintElementCategory.workstation),
    'Hb8qYRKMqdVbagsCLfOX-500': (english: 'Ahmed Samy', category: BlueprintElementCategory.workstation),
    'Hb8qYRKMqdVbagsCLfOX-504': (english: 'Mohamed Aslan', category: BlueprintElementCategory.workstation),
    'Hb8qYRKMqdVbagsCLfOX-508': (english: 'Mourad Haitham', category: BlueprintElementCategory.workstation),
    'Hb8qYRKMqdVbagsCLfOX-559': (english: 'Ahmed Zaki', category: BlueprintElementCategory.workstation),
    'Hb8qYRKMqdVbagsCLfOX-567': (english: 'Ahmed Abdel-Naby', category: BlueprintElementCategory.workstation),
    'CtNj34wX_UhqDpJhQH_0-462': (english: 'Ahmed Hamdy', category: BlueprintElementCategory.workstation),
    'CtNj34wX_UhqDpJhQH_0-470': (english: 'Hosam Mustafa', category: BlueprintElementCategory.workstation),
    'VYdGAOPkbBN89ayiX8ZU-457': (english: 'Mohamed El-Sbaie', category: BlueprintElementCategory.workstation),
    'VYdGAOPkbBN89ayiX8ZU-465': (english: 'Hesham Abdelnaser', category: BlueprintElementCategory.workstation),
    'VYdGAOPkbBN89ayiX8ZU-470': (english: 'Ahmed Rashad (Laptop)', category: BlueprintElementCategory.laptop),
    'M2PY9Z2AMNSf3wnmK2pj-494': (english: 'Walid', category: BlueprintElementCategory.workstation),
    'M2PY9Z2AMNSf3wnmK2pj-499': (english: 'Salah', category: BlueprintElementCategory.workstation),
    'M2PY9Z2AMNSf3wnmK2pj-508': (english: 'Ahmed', category: BlueprintElementCategory.workstation),
    'M2PY9Z2AMNSf3wnmK2pj-517': (english: 'Mohamed Hussein', category: BlueprintElementCategory.workstation),
    'M2PY9Z2AMNSf3wnmK2pj-521': (english: 'Khaled Ali', category: BlueprintElementCategory.workstation),
    'M2PY9Z2AMNSf3wnmK2pj-525': (english: 'Nour Sayed', category: BlueprintElementCategory.workstation),
    'M2PY9Z2AMNSf3wnmK2pj-529': (english: 'Mohamed Gamal', category: BlueprintElementCategory.workstation),
    'qPz9J1Sibrh_JtBiynap-41': (english: 'Osama Eliwa', category: BlueprintElementCategory.workstation),
    'qPz9J1Sibrh_JtBiynap-45': (english: 'Mohamed Samir', category: BlueprintElementCategory.workstation),
    'ewbW3u-aRs42BIOYivtb-21': (english: 'Mostafa Ahmed', category: BlueprintElementCategory.workstation),
    'YB2jpgnsKaUNnIzHBjIM-16': (english: 'Basem Nabil', category: BlueprintElementCategory.workstation),
    '_eXTDp2E2C0NTwzJeQKI-7': (english: 'Ahmed Ramadan', category: BlueprintElementCategory.workstation),
    'bUzkar9Z3lB0ubGY5Ex2-3': (english: 'Sabry', category: BlueprintElementCategory.workstation),
    'i7ouvbQWoWqsjxlvbGib-3': (english: 'Khamis (Security)', category: BlueprintElementCategory.security),
  };

  /// Phrase translation dictionary for matching text labels
  static const Map<String, String> phraseDictionary = {
    'دور الاول': 'First Floor',
    'الدورالارضي ومخازن': 'Ground Floor & Warehouses',
    'البوابات': 'Security Gates',
    'الحسابات': 'Accounting Department',
    'الخزنة': 'Treasury / Safe Room',
    'مدير الحسابات': 'Accounting Manager',
    'المشتريات': 'Purchasing Department',
    'مدير المصنع': 'Plant General Manager',
    'المدير المالي': 'Chief Financial Officer',
    'الموارد البشرية': 'Human Resources (HR)',
    'HR': 'Human Resources (HR)',
    'تخطيط': 'Production Planning (PPIC)',
    'PPIC': 'Production Planning (PPIC)',
    'مشروعات': 'Projects Office',
    'الجودة': 'Quality Assurance (QA/QC)',
    'الصيانة': 'Maintenance Technical Office',
    'سيرفر روم': 'Server Room Sub-Hub',
    'المخازن': 'Central Warehouses',
    'سوتش السبير': 'Spare Parts Switch',
    'شوتش مخازن': 'Warehouse Switch',
    'Dlink': 'D-Link Switch',
    'فايبر +كات6': 'Fiber Optic + Cat6',
    'الاول': 'Storage Bay 1',
    'الثاني': 'Storage Bay 2',
    'الثالث': 'Storage Bay 3',
    'logistic': 'Logistics Office',
    'SparePart': 'Spare Parts Tech Desk',
    'RM': 'Raw Material Office',
    'مكتب الامن': 'Security Office — Gate 1',
    'مكتب الامن بوابه 2': 'Security Office — Gate 2',
    'الكافتريا': 'Cafeteria',
    'الميتينج روم': 'Conference / Meeting Room',
    'الطرقه': 'Central Corridor',
    'IT': 'IT Support Office',
    'CCTV': 'CCTV Monitoring',
    'Nan Port': 'Spare Data Port',
    'Wifi': 'Wi-Fi',
    'Main Sarver': 'Main Server',
    'IP-PBX': 'IP-PBX System',
    'هشام عصام': 'Hisham Essam',
    'مصطفي محمد': 'Mostafa Mohamed',
    'مصطفي ايمن': 'Mostafa Ayman',
    'عمر رافت': 'Amr Rafaat',
    'عبدالمنعم هزاع': 'Abdel Moneim Hazaa',
    'احمد حلمي': 'Ahmed Helmy',
    'احمد سامي': 'Ahmed Samy',
    'محمد اصلان': 'Mohamed Aslan',
    'مراد هيثم': 'Mourad Haitham',
    'احمد ذكي': 'Ahmed Zaki',
    'احمد عبد النبي': 'Ahmed Abdel-Naby',
    'احمد حمدي': 'Ahmed Hamdy',
    'حسام مصطفي': 'Hosam Mustafa',
    'محمد السباعي': 'Mohamed El-Sbaie',
    'هشام ناصر': 'Hesham Abdelnaser',
    'احمد رشاد': 'Ahmed Rashad',
    'وليد': 'Walid',
    'صلاح': 'Salah',
    'احمد': 'Ahmed',
    'محمد حسين': 'Mohamed Hussein',
    'خالد علي': 'Khaled Ali',
    'نور سيد': 'Nour Sayed',
    'محمد جمال': 'Mohamed Gamal',
    'اسامه عليوة': 'Osama Eliwa',
    'محمد سمير': 'Mohamed Samir',
    'مصطفي احمد': 'Mostafa Ahmed',
    'باسم': 'Basem Nabil',
    'احمد رمضان': 'Ahmed Ramadan',
    'صبري': 'Sabry',
    'خميس': 'Khamis',
  };

  /// Translates a raw label to English, ensuring zero Arabic characters remain.
  static String translate(String raw, {String? cellId}) {
    if (raw.trim().isEmpty) return '';

    // Check cell ID override first
    if (cellId != null && cellOverrides.containsKey(cellId)) {
      return cellOverrides[cellId]!.english;
    }

    final trimmed = raw.trim();
    if (phraseDictionary.containsKey(trimmed)) {
      return phraseDictionary[trimmed]!;
    }

    String result = trimmed;
    phraseDictionary.forEach((arabic, english) {
      result = result.replaceAll(arabic, english);
    });

    // Clean IP formats (e.g. ".22.117" -> "192.168.22.117")
    final ipMatch = RegExp(r'(?:192\.168\.)?(\d+\.\d+)').firstMatch(result);
    if (ipMatch != null) {
      final ipPart = ipMatch.group(1)!;
      if (!result.contains('192.168.')) {
        result = result.replaceFirst(RegExp(r'\.?\d+\.\d+'), '192.168.$ipPart');
      }
    }

    return result;
  }

  /// Categorizes an element based on its translated text and style
  static BlueprintElementCategory resolveCategory(String text, String? cellId, String style) {
    if (cellId != null && cellOverrides.containsKey(cellId)) {
      return cellOverrides[cellId]!.category;
    }

        final lower = text.toLowerCase();
    if (lower.contains('switch')) {
      return BlueprintElementCategory.switchDevice;
    }
    if (lower.contains('server')) {
      return BlueprintElementCategory.server;
    }
    if (lower.contains('laptop') || lower.contains('wi-fi')) {
      return BlueprintElementCategory.laptop;
    }
    if (lower.contains('port') || lower.contains('drop')) {
      return BlueprintElementCategory.wallDrop;
    }
    if (lower.contains('security') || lower.contains('cctv')) {
      return BlueprintElementCategory.security;
    }
    if (lower.contains('department') || lower.contains('office')) {
      return BlueprintElementCategory.office;
    }
    if (lower.contains('room') ||
        lower.contains('warehouse') ||
        lower.contains('bay') ||
        lower.contains('corridor')) {
      return BlueprintElementCategory.room;
    }
    if (RegExp(r'192\.168\.\d+\.\d+').hasMatch(text)) {
      return BlueprintElementCategory.workstation;
    }
    return BlueprintElementCategory.generic;
  }
}
