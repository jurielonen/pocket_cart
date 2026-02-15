import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fi'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Pocket Cart'**
  String get appTitle;

  /// Label for email fields
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// Label for password fields
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get commonPassword;

  /// Tooltip or action label for signing out
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonSignOut;

  /// Undo action label
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// Delete action label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Rename action label
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// Title for sign-in screen
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignInTitle;

  /// Primary sign-in button label
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignInButton;

  /// Loading label while signing in
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get authSigningIn;

  /// Link to sign-up screen
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountLink;

  /// Link to password reset screen
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPasswordLink;

  /// Log/snackbar message for sign-in failure
  ///
  /// In en, this message translates to:
  /// **'Failed to sign in.'**
  String get authSignInFailed;

  /// Title for sign-up screen
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUpTitle;

  /// Primary sign-up button label
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountButton;

  /// Loading label while creating account
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get authCreatingAccount;

  /// Log/snackbar message for sign-up failure
  ///
  /// In en, this message translates to:
  /// **'Failed to sign up.'**
  String get authSignUpFailed;

  /// Title for reset password screen
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authResetPasswordTitle;

  /// Primary reset password button label
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authSendResetLink;

  /// Loading label while sending reset link
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get authSendingResetLink;

  /// Snackbar shown after reset email is sent
  ///
  /// In en, this message translates to:
  /// **'Reset email sent.'**
  String get authResetEmailSent;

  /// Log/snackbar message for reset password failure
  ///
  /// In en, this message translates to:
  /// **'Failed to reset password.'**
  String get authResetPasswordFailed;

  /// Title for shopping lists screen
  ///
  /// In en, this message translates to:
  /// **'Shopping Lists'**
  String get listsTitle;

  /// Empty state text when no shopping lists exist
  ///
  /// In en, this message translates to:
  /// **'No lists yet. Create your first shopping list.'**
  String get listsEmptyState;

  /// Error text when loading lists fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load lists: {error}'**
  String listsFailedToLoad(String error);

  /// Label for create list floating action button
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get listsNewList;

  /// Dialog title for creating a shopping list
  ///
  /// In en, this message translates to:
  /// **'Create List'**
  String get listsCreateListTitle;

  /// Dialog title for renaming a shopping list
  ///
  /// In en, this message translates to:
  /// **'Rename {listName}'**
  String listsRenameListTitle(String listName);

  /// Snackbar message shown when a list is deleted
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String listsDeletedList(String name);

  /// Item count label for a list
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String listsItemCount(int count);

  /// Placeholder text while loading list item count
  ///
  /// In en, this message translates to:
  /// **'Loading items...'**
  String get listsItemCountLoading;

  /// Error text when item count cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Unable to count items'**
  String get listsItemCountError;

  /// Validation message for required list or item name
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get listsNameRequired;

  /// Fallback app bar title for list detail screen
  ///
  /// In en, this message translates to:
  /// **'List Detail'**
  String get listsDetailFallbackTitle;

  /// Empty state text when list has no items
  ///
  /// In en, this message translates to:
  /// **'No items yet. Add one below.'**
  String get listsNoItemsYet;

  /// Header label for checked items section
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get listsCheckedSection;

  /// Error text when loading list items fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load items: {error}'**
  String listsFailedToLoadItems(String error);

  /// Hint text for quick add item field
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get listsAddItemHint;

  /// Snackbar message shown when an item is deleted
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String listsDeletedItem(String name);

  /// Placeholder text for settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings placeholder'**
  String get settingsPlaceholder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fi':
      return AppLocalizationsFi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
