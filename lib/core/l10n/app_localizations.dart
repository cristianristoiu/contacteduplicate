import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ro'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'AppLocalizations missing in widget tree.');
    return localizations!;
  }

  static const Map<String, Map<String, String>> _values = <String, Map<String, String>>{
    'ro': <String, String>{
      'app_title': 'Contacte Duplicate',
      'dashboard_title': 'Curata contactele duplicate',
      'dashboard_subtitle': 'Datele raman pe dispozitiv.',
      'scan_contacts': 'Scaneaza contacte',
      'view_duplicates': 'Vezi duplicate',
      'backup_contacts': 'Backup contacte',
      'settings': 'Setari',
    },
    'en': <String, String>{
      'app_title': 'Contact Duplicate',
      'dashboard_title': 'Clean duplicate contacts',
      'dashboard_subtitle': 'Your data stays on this device.',
      'scan_contacts': 'Scan contacts',
      'view_duplicates': 'View duplicates',
      'backup_contacts': 'Backup contacts',
      'settings': 'Settings',
    },
  };

  String text(String key) {
    final languageCode = _values.containsKey(locale.languageCode) ? locale.languageCode : 'ro';
    return _values[languageCode]?[key] ?? _values['ro']?[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
