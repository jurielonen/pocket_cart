// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppLocalizationsFi extends AppLocalizations {
  AppLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get appTitle => 'Pocket Cart';

  @override
  String get commonEmail => 'Sähköposti';

  @override
  String get commonPassword => 'Salasana';

  @override
  String get commonSignOut => 'Kirjaudu ulos';

  @override
  String get commonUndo => 'Kumoa';

  @override
  String get commonCancel => 'Peruuta';

  @override
  String get commonSave => 'Tallenna';

  @override
  String get commonCreate => 'Luo';

  @override
  String get commonDelete => 'Poista';

  @override
  String get commonRename => 'Nimeä uudelleen';

  @override
  String get commonName => 'Nimi';

  @override
  String get commonAdd => 'Lisää';

  @override
  String get authSignInTitle => 'Kirjaudu sisään';

  @override
  String get authSignInButton => 'Kirjaudu sisään';

  @override
  String get authSigningIn => 'Kirjaudutaan...';

  @override
  String get authCreateAccountLink => 'Luo tili';

  @override
  String get authForgotPasswordLink => 'Unohtuiko salasana?';

  @override
  String get authSignInFailed => 'Sisäänkirjautuminen epäonnistui.';

  @override
  String get authSignUpTitle => 'Rekisteröidy';

  @override
  String get authCreateAccountButton => 'Luo tili';

  @override
  String get authCreatingAccount => 'Luodaan...';

  @override
  String get authSignUpFailed => 'Rekisteröityminen epäonnistui.';

  @override
  String get authResetPasswordTitle => 'Nollaa salasana';

  @override
  String get authSendResetLink => 'Lähetä palautuslinkki';

  @override
  String get authSendingResetLink => 'Lähetetään...';

  @override
  String get authResetEmailSent => 'Palautussähköposti lähetetty.';

  @override
  String get authResetPasswordFailed => 'Salasanan nollaus epäonnistui.';

  @override
  String get listsTitle => 'Ostoslistat';

  @override
  String get listsEmptyState =>
      'Ei listoja vielä. Luo ensimmäinen ostoslistasi.';

  @override
  String listsFailedToLoad(String error) {
    return 'Listojen lataus epäonnistui: $error';
  }

  @override
  String get listsNewList => 'Uusi lista';

  @override
  String get listsCreateListTitle => 'Luo lista';

  @override
  String listsRenameListTitle(String listName) {
    return 'Nimeä uudelleen $listName';
  }

  @override
  String listsDeletedList(String name) {
    return 'Poistettu \"$name\"';
  }

  @override
  String listsItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tuotetta',
      one: '1 tuote',
      zero: 'Ei tuotteita',
    );
    return '$_temp0';
  }

  @override
  String get listsItemCountLoading => 'Ladataan tuotteita...';

  @override
  String get listsItemCountError => 'Tuotteiden määrää ei voitu laskea';

  @override
  String get listsNameRequired => 'Nimi on pakollinen';

  @override
  String get listsDetailFallbackTitle => 'Listan tiedot';

  @override
  String get listsNoItemsYet => 'Ei tuotteita vielä. Lisää tuote alle.';

  @override
  String get listsCheckedSection => 'Valittu';

  @override
  String listsFailedToLoadItems(String error) {
    return 'Tuotteiden lataus epäonnistui: $error';
  }

  @override
  String get listsAddItemHint => 'Lisää tuote';

  @override
  String listsDeletedItem(String name) {
    return 'Poistettu \"$name\"';
  }

  @override
  String get settingsPlaceholder => 'Asetusten paikanvaraaja';
}
