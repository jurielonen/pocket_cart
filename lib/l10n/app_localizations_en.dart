// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pocket Cart';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonName => 'Name';

  @override
  String get commonAdd => 'Add';

  @override
  String get authSignInTitle => 'Sign In';

  @override
  String get authSignInButton => 'Sign In';

  @override
  String get authSigningIn => 'Signing in...';

  @override
  String get authCreateAccountLink => 'Create account';

  @override
  String get authForgotPasswordLink => 'Forgot password?';

  @override
  String get authSignInFailed => 'Failed to sign in.';

  @override
  String get authSignUpTitle => 'Sign Up';

  @override
  String get authCreateAccountButton => 'Create account';

  @override
  String get authCreatingAccount => 'Creating...';

  @override
  String get authSignUpFailed => 'Failed to sign up.';

  @override
  String get authResetPasswordTitle => 'Reset Password';

  @override
  String get authSendResetLink => 'Send reset link';

  @override
  String get authSendingResetLink => 'Sending...';

  @override
  String get authResetEmailSent => 'Reset email sent.';

  @override
  String get authResetPasswordFailed => 'Failed to reset password.';

  @override
  String get listsTitle => 'Shopping Lists';

  @override
  String get listsEmptyState =>
      'No lists yet. Create your first shopping list.';

  @override
  String listsFailedToLoad(String error) {
    return 'Failed to load lists: $error';
  }

  @override
  String get listsNewList => 'New list';

  @override
  String get listsCreateListTitle => 'Create List';

  @override
  String listsRenameListTitle(String listName) {
    return 'Rename $listName';
  }

  @override
  String listsDeletedList(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String listsItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get listsItemCountLoading => 'Loading items...';

  @override
  String get listsItemCountError => 'Unable to count items';

  @override
  String get listsNameRequired => 'Name is required';

  @override
  String get listsDetailFallbackTitle => 'List Detail';

  @override
  String get listsNoItemsYet => 'No items yet. Add one below.';

  @override
  String get listsCheckedSection => 'Checked';

  @override
  String listsFailedToLoadItems(String error) {
    return 'Failed to load items: $error';
  }

  @override
  String get listsAddItemHint => 'Add item';

  @override
  String listsDeletedItem(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get settingsPlaceholder => 'Settings placeholder';
}
