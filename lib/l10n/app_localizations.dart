import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('tr'),
  ];

  /// App name shown on the login header
  ///
  /// In en, this message translates to:
  /// **'WatchVerse'**
  String get appTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track the movies & shows you love'**
  String get loginSubtitle;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @passwordRequiredLogin.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordRequiredLogin;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get continueAsGuest;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountPrompt;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @errorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No user found for this email.'**
  String get errorUserNotFound;

  /// No description provided for @errorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get errorWrongPassword;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred.'**
  String get errorGeneric;

  /// No description provided for @errorSignIn.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in: {error}'**
  String errorSignIn(String error);

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountTitle;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join WatchVerse to start tracking'**
  String get createAccountSubtitle;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameHint;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get usernameRequired;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordHint;

  /// No description provided for @passwordRequiredRegister.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get passwordRequiredRegister;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountButton;

  /// No description provided for @alreadyHaveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccountPrompt;

  /// No description provided for @logInLowercase.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logInLowercase;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is too weak.'**
  String get errorWeakPassword;

  /// No description provided for @errorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use.'**
  String get errorEmailInUse;

  /// No description provided for @errorCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not create account: {error}'**
  String errorCreateAccount(String error);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsAppInfoSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAppInfoSection;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsOfService;

  /// No description provided for @settingsNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSection;

  /// No description provided for @settingsNotifyEpisodeTomorrow.
  ///
  /// In en, this message translates to:
  /// **'New episodes airing tomorrow'**
  String get settingsNotifyEpisodeTomorrow;

  /// No description provided for @settingsNotifyEpisodeToday.
  ///
  /// In en, this message translates to:
  /// **'New episodes out today'**
  String get settingsNotifyEpisodeToday;

  /// No description provided for @settingsNotifyFriendActivity.
  ///
  /// In en, this message translates to:
  /// **'Friend activity'**
  String get settingsNotifyFriendActivity;

  /// No description provided for @settingsNotifySharedWatch.
  ///
  /// In en, this message translates to:
  /// **'Shared watch matches'**
  String get settingsNotifySharedWatch;

  /// Caption under the Settings > Notifications toggles while the server-side push senders (functions/) are not deployed. Remove once pushes are actually sent.
  ///
  /// In en, this message translates to:
  /// **'Push notifications aren\'t being sent yet. Your choices here are saved and will apply once they are.'**
  String get settingsNotificationsNotLive;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsAppVersion(String version);

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get settingsDeleteAccountConfirmTitle;

  /// No description provided for @settingsDeleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone. Your account, sign-in, library, lists, diary, and comments will be permanently deleted. An App Store subscription isn\'t cancelled automatically — cancel it separately in your device\'s subscription settings.'**
  String get settingsDeleteAccountConfirmBody;

  /// No description provided for @settingsDeleteAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDeleteAccountAction;

  /// No description provided for @settingsDeleteAccountRequiresRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'For your security, this requires a recent sign-in. Please sign out and sign back in, then try again.'**
  String get settingsDeleteAccountRequiresRecentLogin;

  /// No description provided for @settingsDeleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete account: {error}'**
  String settingsDeleteAccountError(String error);

  /// No description provided for @settingsDeleteAccountIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Your account deletion started but couldn\'t finish. Sign in again to complete it.'**
  String get settingsDeleteAccountIncomplete;

  /// No description provided for @accountDeletionFinishingTitle.
  ///
  /// In en, this message translates to:
  /// **'Finishing account deletion'**
  String get accountDeletionFinishingTitle;

  /// No description provided for @accountDeletionFinishingBody.
  ///
  /// In en, this message translates to:
  /// **'An earlier request to delete this account didn\'t finish. Completing it now…'**
  String get accountDeletionFinishingBody;

  /// No description provided for @accountDeletionResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t finish deleting your account: {error}'**
  String accountDeletionResumeFailed(String error);

  /// No description provided for @accountDeletionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get accountDeletionRetry;

  /// No description provided for @accountDeletionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountDeletionSignOut;

  /// No description provided for @selectAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Select an Avatar'**
  String get selectAvatarTitle;

  /// No description provided for @editNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editNameTitle;

  /// No description provided for @enterNewNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new name'**
  String get enterNewNameHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String nameLabel(String name);

  /// No description provided for @noName.
  ///
  /// In en, this message translates to:
  /// **'No Name'**
  String get noName;

  /// No description provided for @nameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated successfully!'**
  String get nameUpdated;

  /// No description provided for @failedFetchUser.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch user data: {error}'**
  String failedFetchUser(String error);

  /// No description provided for @failedUpdateName.
  ///
  /// In en, this message translates to:
  /// **'Failed to update name: {error}'**
  String failedUpdateName(String error);

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated!'**
  String get profilePictureUpdated;

  /// No description provided for @failedUpdateProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile picture: {error}'**
  String failedUpdateProfilePicture(String error);

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @tvErrorLoadingShow.
  ///
  /// In en, this message translates to:
  /// **'Could not load show.\n{error}'**
  String tvErrorLoadingShow(String error);

  /// No description provided for @tvOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tvOverviewTitle;

  /// No description provided for @tvSeasonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get tvSeasonsTitle;

  /// No description provided for @tvMoreLikeThisTitle.
  ///
  /// In en, this message translates to:
  /// **'More Like This'**
  String get tvMoreLikeThisTitle;

  /// No description provided for @tvAddToListTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get tvAddToListTooltip;

  /// No description provided for @tvAddToMyShows.
  ///
  /// In en, this message translates to:
  /// **'Add to My Shows'**
  String get tvAddToMyShows;

  /// No description provided for @tvStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tvStatusCompleted;

  /// No description provided for @tvStatusWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get tvStatusWatching;

  /// No description provided for @tvInMyShows.
  ///
  /// In en, this message translates to:
  /// **'In My Shows'**
  String get tvInMyShows;

  /// No description provided for @tvSeasonCountSingular.
  ///
  /// In en, this message translates to:
  /// **'{count} Season'**
  String tvSeasonCountSingular(String count);

  /// No description provided for @tvSeasonCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} Seasons'**
  String tvSeasonCountPlural(String count);

  /// No description provided for @tvMarkPreviousTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark previous episodes?'**
  String get tvMarkPreviousTitle;

  /// No description provided for @tvMarkPreviousQuestion.
  ///
  /// In en, this message translates to:
  /// **'You jumped ahead. Also mark the {episodesPhrase} as watched?'**
  String tvMarkPreviousQuestion(String episodesPhrase);

  /// No description provided for @tvEpisodeCountSingular.
  ///
  /// In en, this message translates to:
  /// **'{count} earlier episode'**
  String tvEpisodeCountSingular(String count);

  /// No description provided for @tvEpisodeCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} earlier episodes'**
  String tvEpisodeCountPlural(String count);

  /// No description provided for @tvNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get tvNo;

  /// No description provided for @tvYesMarkAll.
  ///
  /// In en, this message translates to:
  /// **'Yes, mark all'**
  String get tvYesMarkAll;

  /// No description provided for @tvFinishedShow.
  ///
  /// In en, this message translates to:
  /// **'🎉 You finished {name}!'**
  String tvFinishedShow(String name);

  /// No description provided for @tvSeasonComplete.
  ///
  /// In en, this message translates to:
  /// **'🎉 Season {season} complete!'**
  String tvSeasonComplete(String season);

  /// No description provided for @tvRemoveShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove show?'**
  String get tvRemoveShowTitle;

  /// No description provided for @tvRemoveShowContent.
  ///
  /// In en, this message translates to:
  /// **'This removes \"{name}\" and all watched-episode progress.'**
  String tvRemoveShowContent(String name);

  /// No description provided for @tvRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tvRemoveButton;

  /// No description provided for @tvYourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get tvYourProgress;

  /// No description provided for @tvProgressFraction.
  ///
  /// In en, this message translates to:
  /// **'{watched} / {total}'**
  String tvProgressFraction(String watched, String total);

  /// No description provided for @tvPercentWatched.
  ///
  /// In en, this message translates to:
  /// **'{percent}% watched'**
  String tvPercentWatched(String percent);

  /// No description provided for @tvYourRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get tvYourRating;

  /// No description provided for @movieYourRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get movieYourRating;

  /// No description provided for @movieCannotMarkUnreleased.
  ///
  /// In en, this message translates to:
  /// **'This movie hasn\'t been released yet.'**
  String get movieCannotMarkUnreleased;

  /// No description provided for @movieNotYetReleased.
  ///
  /// In en, this message translates to:
  /// **'Not yet released'**
  String get movieNotYetReleased;

  /// No description provided for @movieReleasesOn.
  ///
  /// In en, this message translates to:
  /// **'Releases on {date}'**
  String movieReleasesOn(String date);

  /// No description provided for @tvUpNextLabel.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT'**
  String get tvUpNextLabel;

  /// No description provided for @tvUpNextEpisodeLabel.
  ///
  /// In en, this message translates to:
  /// **'S{season} E{episode}  {name}'**
  String tvUpNextEpisodeLabel(String season, String episode, String name);

  /// No description provided for @tvSeasonNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Season {season}'**
  String tvSeasonNumberLabel(String season);

  /// No description provided for @tvSeasonFraction.
  ///
  /// In en, this message translates to:
  /// **'{watched}/{total}'**
  String tvSeasonFraction(String watched, String total);

  /// No description provided for @tvUnmarkSeason.
  ///
  /// In en, this message translates to:
  /// **'Unmark season'**
  String get tvUnmarkSeason;

  /// No description provided for @tvMarkSeasonWatched.
  ///
  /// In en, this message translates to:
  /// **'Mark season watched'**
  String get tvMarkSeasonWatched;

  /// No description provided for @tvCannotMarkUnaired.
  ///
  /// In en, this message translates to:
  /// **'This episode hasn\'t aired yet.'**
  String get tvCannotMarkUnaired;

  /// No description provided for @tvMoreEpisodesComing.
  ///
  /// In en, this message translates to:
  /// **'More episodes coming'**
  String get tvMoreEpisodesComing;

  /// No description provided for @tvMarkAllSeasonsButton.
  ///
  /// In en, this message translates to:
  /// **'Mark all seasons watched'**
  String get tvMarkAllSeasonsButton;

  /// No description provided for @tvMarkAllSeasonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark all seasons watched?'**
  String get tvMarkAllSeasonsTitle;

  /// No description provided for @tvMarkAllSeasonsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Every aired episode of {name} will be marked as watched.'**
  String tvMarkAllSeasonsQuestion(String name);

  /// No description provided for @tvEpisodeNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'{number}. {name}'**
  String tvEpisodeNumberLabel(String number, String name);

  /// No description provided for @tvNotAired.
  ///
  /// In en, this message translates to:
  /// **'Not aired'**
  String get tvNotAired;

  /// No description provided for @tvRuntimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String tvRuntimeMinutes(String minutes);

  /// No description provided for @profileUpdatePhotoError.
  ///
  /// In en, this message translates to:
  /// **'Could not update photo: {error}'**
  String profileUpdatePhotoError(String error);

  /// No description provided for @profileEditNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get profileEditNameTitle;

  /// No description provided for @profileEditProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfileTitle;

  /// No description provided for @profileYourNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get profileYourNameHint;

  /// No description provided for @profileCharacterQuoteHint.
  ///
  /// In en, this message translates to:
  /// **'If I were a movie/TV character, I\'d be...'**
  String get profileCharacterQuoteHint;

  /// No description provided for @profileAvatarBackgroundLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile background'**
  String get profileAvatarBackgroundLabel;

  /// No description provided for @profileSaveNameError.
  ///
  /// In en, this message translates to:
  /// **'Could not save name: {error}'**
  String profileSaveNameError(String error);

  /// No description provided for @profileSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your profile.'**
  String get profileSignInPrompt;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileAddYourName.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get profileAddYourName;

  /// No description provided for @profileFriendsActivity.
  ///
  /// In en, this message translates to:
  /// **'Friends\' Activity'**
  String get profileFriendsActivity;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get profileBlockedUsers;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign out failed: {error}'**
  String profileSignOutFailed(String error);

  /// No description provided for @profileFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileFollowers;

  /// No description provided for @profileFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowing;

  /// No description provided for @profileFilms.
  ///
  /// In en, this message translates to:
  /// **'Films'**
  String get profileFilms;

  /// No description provided for @profileMovieTimeSpent.
  ///
  /// In en, this message translates to:
  /// **'Movie time'**
  String get profileMovieTimeSpent;

  /// No description provided for @profileShowTimeSpent.
  ///
  /// In en, this message translates to:
  /// **'Show time'**
  String get profileShowTimeSpent;

  /// No description provided for @profileDurationCompact.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String profileDurationCompact(String hours, String minutes);

  /// No description provided for @profileDurationDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String profileDurationDaysHours(String days, String hours);

  /// No description provided for @profileDurationMonthsDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{months}mo {days}d {hours}h'**
  String profileDurationMonthsDaysHours(
    String months,
    String days,
    String hours,
  );

  /// No description provided for @watchedMoviesSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get watchedMoviesSortTooltip;

  /// No description provided for @watchedMoviesSortByDate.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get watchedMoviesSortByDate;

  /// No description provided for @watchedMoviesSortByRating.
  ///
  /// In en, this message translates to:
  /// **'Rating (high to low)'**
  String get watchedMoviesSortByRating;

  /// No description provided for @profileShows.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get profileShows;

  /// No description provided for @profileEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get profileEpisodes;

  /// No description provided for @profileYourYear.
  ///
  /// In en, this message translates to:
  /// **'Your {year}'**
  String profileYourYear(String year);

  /// No description provided for @profileWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get profileWatched;

  /// No description provided for @profileFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Top 3 Favorite Films'**
  String get profileFavoritesTitle;

  /// No description provided for @profileFavoritesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the ♥ on a movie\'s page to add it here'**
  String get profileFavoritesEmptyHint;

  /// No description provided for @profileShowcasePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to showcase'**
  String get profileShowcasePickerTitle;

  /// No description provided for @profileShowcaseRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from showcase'**
  String get profileShowcaseRemove;

  /// No description provided for @profileMoviesTitle.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get profileMoviesTitle;

  /// No description provided for @profileSeriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get profileSeriesTitle;

  /// No description provided for @profileSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get profileSeeAll;

  /// No description provided for @profileMovieLabel.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get profileMovieLabel;

  /// No description provided for @profileSeasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Season {season}'**
  String profileSeasonLabel(String season);

  /// No description provided for @profileEpisodeLabel.
  ///
  /// In en, this message translates to:
  /// **'S{season} · E{episode}'**
  String profileEpisodeLabel(String season, String episode);

  /// No description provided for @followListEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Nobody here yet.'**
  String get followListEmptyMessage;

  /// No description provided for @homeLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load titles'**
  String get homeLoadFailedTitle;

  /// No description provided for @homeLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get homeLoadFailedBody;

  /// No description provided for @homeRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get homeRetryAction;

  /// No description provided for @homeFindFriendsBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Find friends on WatchVerse'**
  String get homeFindFriendsBannerTitle;

  /// No description provided for @homeFindFriendsBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Follow people to see what they\'re watching.'**
  String get homeFindFriendsBannerBody;

  /// No description provided for @homeFindFriendsBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get homeFindFriendsBannerAction;

  /// No description provided for @asyncErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.\n{error}'**
  String asyncErrorMessage(String error);

  /// No description provided for @movieAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get movieAddToList;

  /// No description provided for @movieTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get movieTypeLabel;

  /// No description provided for @movieOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get movieOverview;

  /// No description provided for @movieMoreLikeThis.
  ///
  /// In en, this message translates to:
  /// **'More Like This'**
  String get movieMoreLikeThis;

  /// No description provided for @movieToWatch.
  ///
  /// In en, this message translates to:
  /// **'To Watch'**
  String get movieToWatch;

  /// No description provided for @movieWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get movieWatched;

  /// No description provided for @movieYourDiary.
  ///
  /// In en, this message translates to:
  /// **'Your Diary'**
  String get movieYourDiary;

  /// No description provided for @movieLogAction.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get movieLogAction;

  /// No description provided for @movieLogAgainAction.
  ///
  /// In en, this message translates to:
  /// **'Log again'**
  String get movieLogAgainAction;

  /// No description provided for @movieDiaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No entries yet. Log a watch to start your diary — you can record rewatches with their own dates.'**
  String get movieDiaryEmpty;

  /// No description provided for @movieLogSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'{action} \"{title}\"'**
  String movieLogSheetTitle(String action, String title);

  /// No description provided for @movieRewatchAction.
  ///
  /// In en, this message translates to:
  /// **'Rewatch'**
  String get movieRewatchAction;

  /// No description provided for @movieWatchedOn.
  ///
  /// In en, this message translates to:
  /// **'Watched on'**
  String get movieWatchedOn;

  /// No description provided for @movieDiaryNote.
  ///
  /// In en, this message translates to:
  /// **'Diary note'**
  String get movieDiaryNote;

  /// No description provided for @movieDiaryNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What did you think?'**
  String get movieDiaryNoteHint;

  /// No description provided for @movieSaveRewatch.
  ///
  /// In en, this message translates to:
  /// **'Save rewatch'**
  String get movieSaveRewatch;

  /// No description provided for @movieSaveToDiary.
  ///
  /// In en, this message translates to:
  /// **'Save to diary'**
  String get movieSaveToDiary;

  /// No description provided for @pollSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'How was it?'**
  String get pollSectionTitle;

  /// No description provided for @pollRatingCommunityMovie.
  ///
  /// In en, this message translates to:
  /// **'How everyone rated this movie'**
  String get pollRatingCommunityMovie;

  /// No description provided for @pollRatingCommunityEpisode.
  ///
  /// In en, this message translates to:
  /// **'How everyone rated this episode'**
  String get pollRatingCommunityEpisode;

  /// No description provided for @pollRatingUnrated.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t rated this yet'**
  String get pollRatingUnrated;

  /// No description provided for @pollRatingBad.
  ///
  /// In en, this message translates to:
  /// **'Bad'**
  String get pollRatingBad;

  /// No description provided for @pollRatingOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get pollRatingOk;

  /// No description provided for @pollRatingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get pollRatingGood;

  /// No description provided for @pollRatingGreat.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get pollRatingGreat;

  /// No description provided for @pollRatingWow.
  ///
  /// In en, this message translates to:
  /// **'Wow'**
  String get pollRatingWow;

  /// No description provided for @pollPlatformQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where did you watch it?'**
  String get pollPlatformQuestion;

  /// No description provided for @pollEmotionQuestion.
  ///
  /// In en, this message translates to:
  /// **'How did it make you feel?'**
  String get pollEmotionQuestion;

  /// No description provided for @pollCharacterQuestion.
  ///
  /// In en, this message translates to:
  /// **'Favorite character?'**
  String get pollCharacterQuestion;

  /// No description provided for @pollPlatformCinema.
  ///
  /// In en, this message translates to:
  /// **'Cinema'**
  String get pollPlatformCinema;

  /// No description provided for @pollPlatformNetflix.
  ///
  /// In en, this message translates to:
  /// **'Netflix'**
  String get pollPlatformNetflix;

  /// No description provided for @pollPlatformDisneyPlus.
  ///
  /// In en, this message translates to:
  /// **'Disney+'**
  String get pollPlatformDisneyPlus;

  /// No description provided for @pollPlatformPrimeVideo.
  ///
  /// In en, this message translates to:
  /// **'Prime Video'**
  String get pollPlatformPrimeVideo;

  /// No description provided for @pollPlatformPirate.
  ///
  /// In en, this message translates to:
  /// **'Pirated'**
  String get pollPlatformPirate;

  /// No description provided for @pollPlatformOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get pollPlatformOther;

  /// No description provided for @pollEmotionHappy.
  ///
  /// In en, this message translates to:
  /// **'Happy'**
  String get pollEmotionHappy;

  /// No description provided for @pollEmotionConfusing.
  ///
  /// In en, this message translates to:
  /// **'Confusing'**
  String get pollEmotionConfusing;

  /// No description provided for @pollEmotionSad.
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get pollEmotionSad;

  /// No description provided for @pollEmotionScary.
  ///
  /// In en, this message translates to:
  /// **'Scary'**
  String get pollEmotionScary;

  /// No description provided for @pollEmotionFrustrating.
  ///
  /// In en, this message translates to:
  /// **'Frustrating'**
  String get pollEmotionFrustrating;

  /// No description provided for @pollEmotionShocking.
  ///
  /// In en, this message translates to:
  /// **'Shocking'**
  String get pollEmotionShocking;

  /// No description provided for @pollEmotionExciting.
  ///
  /// In en, this message translates to:
  /// **'Exciting'**
  String get pollEmotionExciting;

  /// No description provided for @pollEmotionBoring.
  ///
  /// In en, this message translates to:
  /// **'Boring'**
  String get pollEmotionBoring;

  /// No description provided for @upNextTitle.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get upNextTitle;

  /// No description provided for @upNextMyShowsLabel.
  ///
  /// In en, this message translates to:
  /// **'My Shows'**
  String get upNextMyShowsLabel;

  /// No description provided for @upNextUpcomingLabel.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upNextUpcomingLabel;

  /// No description provided for @upNextUpcomingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing coming up'**
  String get upNextUpcomingEmptyTitle;

  /// No description provided for @upNextUpcomingEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'New episodes of tracked shows and release dates for watchlisted movies will show up here.'**
  String get upNextUpcomingEmptySubtitle;

  /// No description provided for @upNextUpcomingToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get upNextUpcomingToday;

  /// No description provided for @upNextUpcomingTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get upNextUpcomingTomorrow;

  /// No description provided for @upNextUpcomingMovieTag.
  ///
  /// In en, this message translates to:
  /// **'MOVIE'**
  String get upNextUpcomingMovieTag;

  /// No description provided for @upNextFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get upNextFilterAll;

  /// No description provided for @upNextStatusWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get upNextStatusWatching;

  /// No description provided for @upNextStatusWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get upNextStatusWatchlist;

  /// No description provided for @upNextStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get upNextStatusCompleted;

  /// No description provided for @upNextFilterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get upNextFilterFavorites;

  /// No description provided for @upNextEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get upNextEmptyTitle;

  /// No description provided for @upNextEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track a show and mark episodes watched — your next episode to watch will show up here.'**
  String get upNextEmptySubtitle;

  /// No description provided for @upNextNoShowsTitle.
  ///
  /// In en, this message translates to:
  /// **'No shows here'**
  String get upNextNoShowsTitle;

  /// No description provided for @upNextNoShowsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{filter}\".'**
  String upNextNoShowsSubtitle(String filter);

  /// No description provided for @upNextEpisodeProgress.
  ///
  /// In en, this message translates to:
  /// **'{watched} / {total} episodes'**
  String upNextEpisodeProgress(int watched, int total);

  /// No description provided for @upNextSeasonEpisode.
  ///
  /// In en, this message translates to:
  /// **'S{season} | E{episode}'**
  String upNextSeasonEpisode(int season, int episode);

  /// No description provided for @upNextEpisodeFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String upNextEpisodeFallbackName(int number);

  /// No description provided for @upNextWatchedCount.
  ///
  /// In en, this message translates to:
  /// **'{watched} / {total} watched'**
  String upNextWatchedCount(int watched, int total);

  /// No description provided for @upNextAllCaughtUpSnackbar.
  ///
  /// In en, this message translates to:
  /// **'🎉 All caught up on {name}!'**
  String upNextAllCaughtUpSnackbar(String name);

  /// No description provided for @upNextMarkWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get upNextMarkWatched;

  /// No description provided for @upNextAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get upNextAllCaughtUp;

  /// No description provided for @upNextNewEpisodeToday.
  ///
  /// In en, this message translates to:
  /// **'New episode today'**
  String get upNextNewEpisodeToday;

  /// No description provided for @upNextNextEpisodeOn.
  ///
  /// In en, this message translates to:
  /// **'Next episode {date}'**
  String upNextNextEpisodeOn(String date);

  /// No description provided for @upNextPremiereTag.
  ///
  /// In en, this message translates to:
  /// **'PREMIERE'**
  String get upNextPremiereTag;

  /// No description provided for @upNextNewBadge.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get upNextNewBadge;

  /// No description provided for @upNextAllCaughtUpEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get upNextAllCaughtUpEmptyTitle;

  /// No description provided for @upNextAllCaughtUpEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No new episodes to watch right now — check the Upcoming tab for what\'s coming next.'**
  String get upNextAllCaughtUpEmptySubtitle;

  /// No description provided for @upNextSwipeStopLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get upNextSwipeStopLabel;

  /// No description provided for @upNextStopWatchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop watching this show?'**
  String get upNextStopWatchingTitle;

  /// No description provided for @upNextStopWatchingContent.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from your list along with its watch history.'**
  String upNextStopWatchingContent(String name);

  /// No description provided for @upNextStopWatchingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop watching'**
  String get upNextStopWatchingConfirm;

  /// No description provided for @upNextStopWatchingCancel.
  ///
  /// In en, this message translates to:
  /// **'Never mind'**
  String get upNextStopWatchingCancel;

  /// No description provided for @detailCastTitle.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get detailCastTitle;

  /// No description provided for @detailWhereToWatch.
  ///
  /// In en, this message translates to:
  /// **'Where to Watch'**
  String get detailWhereToWatch;

  /// No description provided for @detailReviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get detailReviewsTitle;

  /// No description provided for @detailReviewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'from the community'**
  String get detailReviewsSubtitle;

  /// No description provided for @detailShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get detailShowLess;

  /// No description provided for @detailReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get detailReadMore;

  /// No description provided for @detailCouldNotOpenTrailer.
  ///
  /// In en, this message translates to:
  /// **'Could not open the trailer.'**
  String get detailCouldNotOpenTrailer;

  /// No description provided for @detailWatchTrailer.
  ///
  /// In en, this message translates to:
  /// **'Watch Trailer'**
  String get detailWatchTrailer;

  /// No description provided for @discoverLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load titles'**
  String get discoverLoadErrorTitle;

  /// No description provided for @discoverLoadErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and pull to refresh.'**
  String get discoverLoadErrorSubtitle;

  /// No description provided for @discoverEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get discoverEmptyTitle;

  /// No description provided for @discoverEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No {genre} titles found.'**
  String discoverEmptySubtitle(String genre);

  /// No description provided for @socialFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get socialFollowing;

  /// No description provided for @socialFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get socialFollow;

  /// No description provided for @socialDefaultUserName.
  ///
  /// In en, this message translates to:
  /// **'WatchVerse user'**
  String get socialDefaultUserName;

  /// No description provided for @commentWCommentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentWCommentsLabel;

  /// No description provided for @commentWSpoilersHint.
  ///
  /// In en, this message translates to:
  /// **'May contain spoilers'**
  String get commentWSpoilersHint;

  /// No description provided for @commentWDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commentWDelete;

  /// No description provided for @commentWReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get commentWReport;

  /// No description provided for @commentWBlockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get commentWBlockUser;

  /// No description provided for @commentWLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get commentWLike;

  /// No description provided for @commentWReportedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Reported. Thanks for flagging.'**
  String get commentWReportedSnackbar;

  /// No description provided for @commentWBlockedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Blocked. Their comments are hidden and you\'ve unfollowed them.'**
  String get commentWBlockedSnackbar;

  /// No description provided for @commentWJustNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get commentWJustNow;

  /// No description provided for @commentWMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String commentWMinutesAgo(int minutes);

  /// No description provided for @commentWHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String commentWHoursAgo(int hours);

  /// No description provided for @commentWDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String commentWDaysAgo(int days);

  /// No description provided for @commentWWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{weeks}w'**
  String commentWWeeksAgo(int weeks);

  /// No description provided for @episodeSeasonEpisodeLabel.
  ///
  /// In en, this message translates to:
  /// **'S{season} · E{episode}'**
  String episodeSeasonEpisodeLabel(int season, int episode);

  /// No description provided for @episodeRuntimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String episodeRuntimeMinutes(int minutes);

  /// No description provided for @episodeRatingStars.
  ///
  /// In en, this message translates to:
  /// **'★ {rating}'**
  String episodeRatingStars(String rating);

  /// No description provided for @episodeNotAiredYet.
  ///
  /// In en, this message translates to:
  /// **'Not aired yet'**
  String get episodeNotAiredYet;

  /// No description provided for @episodeOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get episodeOverviewTitle;

  /// No description provided for @episodeWatchedLabel.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get episodeWatchedLabel;

  /// No description provided for @episodeMarkAsWatchedLabel.
  ///
  /// In en, this message translates to:
  /// **'Mark as watched'**
  String get episodeMarkAsWatchedLabel;

  /// No description provided for @episodeYourRatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get episodeYourRatingTitle;

  /// No description provided for @episodeYourNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your notes'**
  String get episodeYourNotesTitle;

  /// No description provided for @episodeNotesPrivateHint.
  ///
  /// In en, this message translates to:
  /// **'Private — only you can see this.'**
  String get episodeNotesPrivateHint;

  /// No description provided for @episodeNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Write a note about this episode…'**
  String get episodeNoteHint;

  /// No description provided for @episodeNoteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get episodeNoteSaved;

  /// No description provided for @episodeSaveNoteButton.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get episodeSaveNoteButton;

  /// No description provided for @commentsAddLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add GIF / image link'**
  String get commentsAddLinkTitle;

  /// No description provided for @commentsLinkHint.
  ///
  /// In en, this message translates to:
  /// **'https://…'**
  String get commentsLinkHint;

  /// No description provided for @commentsAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commentsAddAction;

  /// No description provided for @commentsUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload photo'**
  String get commentsUploadPhoto;

  /// No description provided for @commentsSearchGifs.
  ///
  /// In en, this message translates to:
  /// **'Search GIFs'**
  String get commentsSearchGifs;

  /// No description provided for @commentsAddGifByLink.
  ///
  /// In en, this message translates to:
  /// **'Add GIF / image by link'**
  String get commentsAddGifByLink;

  /// No description provided for @commentsCouldNotPost.
  ///
  /// In en, this message translates to:
  /// **'Could not post: {error}'**
  String commentsCouldNotPost(String error);

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @commentsAddCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get commentsAddCommentHint;

  /// No description provided for @commentsSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to join the conversation.'**
  String get commentsSignInHint;

  /// No description provided for @commentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get commentsEmptyTitle;

  /// No description provided for @commentsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be the first to share what you thought.'**
  String get commentsEmptySubtitle;

  /// No description provided for @pubProfileFavoriteFilms.
  ///
  /// In en, this message translates to:
  /// **'Favorite Films'**
  String get pubProfileFavoriteFilms;

  /// No description provided for @pubProfileWatchedMovies.
  ///
  /// In en, this message translates to:
  /// **'Watched Movies'**
  String get pubProfileWatchedMovies;

  /// No description provided for @pubProfileShows.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get pubProfileShows;

  /// No description provided for @pubProfileLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get pubProfileLists;

  /// No description provided for @pubProfileDefaultUserName.
  ///
  /// In en, this message translates to:
  /// **'WatchVerse user'**
  String get pubProfileDefaultUserName;

  /// No description provided for @pubProfileMemberLabel.
  ///
  /// In en, this message translates to:
  /// **'WatchVerse member'**
  String get pubProfileMemberLabel;

  /// No description provided for @pubProfileFilms.
  ///
  /// In en, this message translates to:
  /// **'Films'**
  String get pubProfileFilms;

  /// No description provided for @pubProfileFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get pubProfileFollowers;

  /// No description provided for @pubProfileFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get pubProfileFollowing;

  /// No description provided for @pubProfileAddedToList.
  ///
  /// In en, this message translates to:
  /// **'Added to your list'**
  String get pubProfileAddedToList;

  /// No description provided for @searchFilterAll.
  ///
  /// In en, this message translates to:
  /// **'Movies & TV'**
  String get searchFilterAll;

  /// No description provided for @searchFilterMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get searchFilterMovies;

  /// No description provided for @searchFilterTv.
  ///
  /// In en, this message translates to:
  /// **'TV Shows'**
  String get searchFilterTv;

  /// No description provided for @searchFilterPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchFilterPeople;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(String error);

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHintPeople.
  ///
  /// In en, this message translates to:
  /// **'Search people by name…'**
  String get searchHintPeople;

  /// No description provided for @searchHintTitles.
  ///
  /// In en, this message translates to:
  /// **'Search movies & TV shows…'**
  String get searchHintTitles;

  /// No description provided for @searchFindFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Find friends'**
  String get searchFindFriendsTitle;

  /// No description provided for @searchFindFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search people by name and follow them to see what they watch.'**
  String get searchFindFriendsSubtitle;

  /// No description provided for @searchFindNextWatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your next watch'**
  String get searchFindNextWatchTitle;

  /// No description provided for @searchFindNextWatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search across movies and TV shows.'**
  String get searchFindNextWatchSubtitle;

  /// No description provided for @searchNoOneFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No one found'**
  String get searchNoOneFoundTitle;

  /// No description provided for @searchNoUsersMatched.
  ///
  /// In en, this message translates to:
  /// **'No users matched \"{query}\".\nNames are case-sensitive for now.'**
  String searchNoUsersMatched(String query);

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNothingMatched.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched \"{query}\".'**
  String searchNothingMatched(String query);

  /// No description provided for @homeAppTitle.
  ///
  /// In en, this message translates to:
  /// **'WatchVerse'**
  String get homeAppTitle;

  /// No description provided for @homeGuestLabel.
  ///
  /// In en, this message translates to:
  /// **'Browsing as guest'**
  String get homeGuestLabel;

  /// No description provided for @homeMyLists.
  ///
  /// In en, this message translates to:
  /// **'My Lists'**
  String get homeMyLists;

  /// No description provided for @homeFriendsActivity.
  ///
  /// In en, this message translates to:
  /// **'Friends\' Activity'**
  String get homeFriendsActivity;

  /// No description provided for @homeWatchHistory.
  ///
  /// In en, this message translates to:
  /// **'Watch History'**
  String get homeWatchHistory;

  /// No description provided for @homeWatchPolls.
  ///
  /// In en, this message translates to:
  /// **'Watch Polls'**
  String get homeWatchPolls;

  /// No description provided for @homeSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettingsLabel;

  /// No description provided for @homeSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get homeSignOut;

  /// No description provided for @homeTabMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get homeTabMovies;

  /// No description provided for @homeTabTvShows.
  ///
  /// In en, this message translates to:
  /// **'TV Shows'**
  String get homeTabTvShows;

  /// No description provided for @homeTrendingThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Trending This Week'**
  String get homeTrendingThisWeek;

  /// No description provided for @homeComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get homeComingSoon;

  /// No description provided for @homePopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get homePopular;

  /// No description provided for @homeTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get homeTopRated;

  /// No description provided for @homeAiringToday.
  ///
  /// In en, this message translates to:
  /// **'Airing Today'**
  String get homeAiringToday;

  /// No description provided for @homeOnTheAir.
  ///
  /// In en, this message translates to:
  /// **'On The Air'**
  String get homeOnTheAir;

  /// No description provided for @homePopularShows.
  ///
  /// In en, this message translates to:
  /// **'Popular Shows'**
  String get homePopularShows;

  /// No description provided for @homeFriendsAlsoWatched.
  ///
  /// In en, this message translates to:
  /// **'Your Friends Also Watched'**
  String get homeFriendsAlsoWatched;

  /// No description provided for @statsSeeDetails.
  ///
  /// In en, this message translates to:
  /// **'See details'**
  String get statsSeeDetails;

  /// No description provided for @statsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch Statistics'**
  String get statsScreenTitle;

  /// No description provided for @statsTypeBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Movies vs Shows'**
  String get statsTypeBreakdownTitle;

  /// No description provided for @statsGenreBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Time by genre'**
  String get statsGenreBreakdownTitle;

  /// No description provided for @statsOtherGenres.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get statsOtherGenres;

  /// No description provided for @statsWeeklyTitle.
  ///
  /// In en, this message translates to:
  /// **'Last 8 weeks'**
  String get statsWeeklyTitle;

  /// No description provided for @statsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get statsThisWeek;

  /// No description provided for @statsWeekdayTitle.
  ///
  /// In en, this message translates to:
  /// **'By day of week'**
  String get statsWeekdayTitle;

  /// No description provided for @statsDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get statsDayMon;

  /// No description provided for @statsDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get statsDayTue;

  /// No description provided for @statsDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get statsDayWed;

  /// No description provided for @statsDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get statsDayThu;

  /// No description provided for @statsDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get statsDayFri;

  /// No description provided for @statsDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get statsDaySat;

  /// No description provided for @statsDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get statsDaySun;

  /// No description provided for @statsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Watch a few movies or shows to see your stats here.'**
  String get statsEmptyMessage;

  /// No description provided for @quickAddWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get quickAddWatch;

  /// No description provided for @quickAddLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get quickAddLike;

  /// No description provided for @quickAddWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get quickAddWatchlist;

  /// No description provided for @quickAddTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get quickAddTrack;

  /// No description provided for @quickAddRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get quickAddRate;

  /// No description provided for @quickAddReviewOrLog.
  ///
  /// In en, this message translates to:
  /// **'Review or log'**
  String get quickAddReviewOrLog;

  /// No description provided for @quickAddAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to lists'**
  String get quickAddAddToList;

  /// No description provided for @quickAddGoTo.
  ///
  /// In en, this message translates to:
  /// **'Go to {title}'**
  String quickAddGoTo(String title);

  /// No description provided for @homeBecauseYouWatched.
  ///
  /// In en, this message translates to:
  /// **'Because you watched {title}'**
  String homeBecauseYouWatched(String title);

  /// No description provided for @listDetailRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get listDetailRenameTitle;

  /// No description provided for @listDetailDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete list?'**
  String get listDetailDeleteTitle;

  /// No description provided for @listDetailDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the list.'**
  String get listDetailDeleteContent;

  /// No description provided for @listDetailDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get listDetailDeleteConfirm;

  /// No description provided for @listDetailRenameMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get listDetailRenameMenuItem;

  /// No description provided for @listDetailDeleteMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get listDetailDeleteMenuItem;

  /// No description provided for @listDetailMakePublicMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Make public'**
  String get listDetailMakePublicMenuItem;

  /// No description provided for @listDetailMakePrivateMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Make private'**
  String get listDetailMakePrivateMenuItem;

  /// No description provided for @listDetailMadePublic.
  ///
  /// In en, this message translates to:
  /// **'List is now public'**
  String get listDetailMadePublic;

  /// No description provided for @listDetailMadePrivate.
  ///
  /// In en, this message translates to:
  /// **'List is now private'**
  String get listDetailMadePrivate;

  /// No description provided for @listDetailFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get listDetailFollow;

  /// No description provided for @listDetailFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get listDetailFollowing;

  /// No description provided for @listDetailEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty list'**
  String get listDetailEmptyTitle;

  /// No description provided for @listDetailEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open any movie or show and tap \"Add to list\".'**
  String get listDetailEmptySubtitle;

  /// No description provided for @personKnownForTitle.
  ///
  /// In en, this message translates to:
  /// **'Known For'**
  String get personKnownForTitle;

  /// No description provided for @personNoCredits.
  ///
  /// In en, this message translates to:
  /// **'No credits found.'**
  String get personNoCredits;

  /// No description provided for @personBiographyTitle.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get personBiographyTitle;

  /// No description provided for @personShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get personShowLess;

  /// No description provided for @personReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get personReadMore;

  /// No description provided for @listsNewListTitle.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get listsNewListTitle;

  /// No description provided for @listsNewListHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Top 10 of all time'**
  String get listsNewListHint;

  /// No description provided for @listsCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get listsCreateAction;

  /// No description provided for @listsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Lists'**
  String get listsTitle;

  /// No description provided for @listsSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create lists'**
  String get listsSignInTitle;

  /// No description provided for @listsSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Curate your own collections like \"Watch in 2026\".'**
  String get listsSignInSubtitle;

  /// No description provided for @listsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No lists yet'**
  String get listsEmptyTitle;

  /// No description provided for @listsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first list.'**
  String get listsEmptySubtitle;

  /// No description provided for @listsUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get listsUntitled;

  /// No description provided for @listsTabMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get listsTabMine;

  /// No description provided for @listsTabFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get listsTabFollowing;

  /// No description provided for @listsFollowingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Not following any lists yet'**
  String get listsFollowingEmptyTitle;

  /// No description provided for @listsFollowingEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Public lists you follow from other users will show up here.'**
  String get listsFollowingEmptySubtitle;

  /// No description provided for @listsFollowingByLabel.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String listsFollowingByLabel(String name);

  /// No description provided for @listsTitleSingular.
  ///
  /// In en, this message translates to:
  /// **'title'**
  String get listsTitleSingular;

  /// No description provided for @listsTitlePlural.
  ///
  /// In en, this message translates to:
  /// **'titles'**
  String get listsTitlePlural;

  /// No description provided for @listsCardEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Empty — add titles from any movie or show.'**
  String get listsCardEmptySubtitle;

  /// No description provided for @mediaTypeTv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get mediaTypeTv;

  /// No description provided for @mediaTypeMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get mediaTypeMovie;

  /// No description provided for @addToListTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get addToListTitle;

  /// No description provided for @addToListNewListButton.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get addToListNewListButton;

  /// No description provided for @addToListSignInMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create lists.'**
  String get addToListSignInMessage;

  /// No description provided for @addToListEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No lists yet — tap \"New list\" to make one.'**
  String get addToListEmptyMessage;

  /// No description provided for @addToListUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get addToListUntitled;

  /// No description provided for @addToListTitleSingular.
  ///
  /// In en, this message translates to:
  /// **'title'**
  String get addToListTitleSingular;

  /// No description provided for @addToListTitlePlural.
  ///
  /// In en, this message translates to:
  /// **'titles'**
  String get addToListTitlePlural;

  /// No description provided for @addToListCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get addToListCreateTitle;

  /// No description provided for @addToListCreateHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Watch in 2026'**
  String get addToListCreateHint;

  /// No description provided for @addToListCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get addToListCreateAction;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch History'**
  String get historyTitle;

  /// No description provided for @historyWatchedRating.
  ///
  /// In en, this message translates to:
  /// **'Watched · ★ {rating}'**
  String historyWatchedRating(String rating);

  /// No description provided for @historyWatchedLabel.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get historyWatchedLabel;

  /// No description provided for @historyFinishedSeason.
  ///
  /// In en, this message translates to:
  /// **'Finished Season {season} · {count} episodes'**
  String historyFinishedSeason(int season, int count);

  /// No description provided for @historyEpisodeLine.
  ///
  /// In en, this message translates to:
  /// **'S{season} E{episode}  {episodeName}'**
  String historyEpisodeLine(int season, int episode, String episodeName);

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Movies and episodes you mark as watched will show up here.'**
  String get historyEmptySubtitle;

  /// No description provided for @historyAgoNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get historyAgoNow;

  /// No description provided for @historyAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String historyAgoMinutes(int minutes);

  /// No description provided for @historyAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String historyAgoHours(int hours);

  /// No description provided for @historyAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String historyAgoDays(int days);

  /// No description provided for @historyAgoWeeks.
  ///
  /// In en, this message translates to:
  /// **'{weeks}w'**
  String historyAgoWeeks(int weeks);

  /// No description provided for @watchlistTitle.
  ///
  /// In en, this message translates to:
  /// **'My Movies'**
  String get watchlistTitle;

  /// No description provided for @watchlistCategoryToWatch.
  ///
  /// In en, this message translates to:
  /// **'To Watch'**
  String get watchlistCategoryToWatch;

  /// No description provided for @watchlistCategoryWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get watchlistCategoryWatched;

  /// No description provided for @watchlistCategoryFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get watchlistCategoryFavorites;

  /// No description provided for @watchlistEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No movies in \"{category}\" yet.'**
  String watchlistEmptyMessage(String category);

  /// No description provided for @watchlistUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get watchlistUntitled;

  /// No description provided for @watchlistYourRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating: {rating}'**
  String watchlistYourRating(String rating);

  /// No description provided for @watchlistReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release: {date}'**
  String watchlistReleaseDate(String date);

  /// No description provided for @gifPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a GIF'**
  String get gifPickerTitle;

  /// No description provided for @gifSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search GIFs…'**
  String get gifSearchHint;

  /// No description provided for @gifPoweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by GIPHY'**
  String get gifPoweredBy;

  /// No description provided for @gifLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load GIFs'**
  String get gifLoadErrorTitle;

  /// No description provided for @gifLoadErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get gifLoadErrorSubtitle;

  /// No description provided for @gifEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No GIFs found'**
  String get gifEmptyTitle;

  /// No description provided for @gifEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different search.'**
  String get gifEmptySubtitle;

  /// No description provided for @friendsActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends\' Activity'**
  String get friendsActivityTitle;

  /// No description provided for @friendsNoFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get friendsNoFriendsTitle;

  /// No description provided for @friendsNoFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow people from Find Friends to see what they watch.'**
  String get friendsNoFriendsSubtitle;

  /// No description provided for @friendsQuietTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet for now'**
  String get friendsQuietTitle;

  /// No description provided for @friendsQuietSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your friends have no recent activity.'**
  String get friendsQuietSubtitle;

  /// No description provided for @friendsSomeoneFallback.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get friendsSomeoneFallback;

  /// No description provided for @friendsActionWatchedMovie.
  ///
  /// In en, this message translates to:
  /// **'watched {title}'**
  String friendsActionWatchedMovie(String title);

  /// No description provided for @friendsActionFinishedSeason.
  ///
  /// In en, this message translates to:
  /// **'finished Season {season} of {show}'**
  String friendsActionFinishedSeason(int season, String show);

  /// No description provided for @friendsActionWatchedEpisode.
  ///
  /// In en, this message translates to:
  /// **'watched S{season} E{episode} of {show}'**
  String friendsActionWatchedEpisode(int season, int episode, String show);

  /// No description provided for @friendsAgoNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get friendsAgoNow;

  /// No description provided for @friendsAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String friendsAgoMinutes(int minutes);

  /// No description provided for @friendsAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String friendsAgoHours(int hours);

  /// No description provided for @friendsAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String friendsAgoDays(int days);

  /// No description provided for @friendsAgoWeeks.
  ///
  /// In en, this message translates to:
  /// **'{weeks}w'**
  String friendsAgoWeeks(int weeks);

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedTitle;

  /// No description provided for @blockedDefaultUserName.
  ///
  /// In en, this message translates to:
  /// **'WatchVerse user'**
  String get blockedDefaultUserName;

  /// No description provided for @blockedUnblockButton.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get blockedUnblockButton;

  /// No description provided for @blockedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get blockedEmptyTitle;

  /// No description provided for @blockedEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'People you block will appear here.'**
  String get blockedEmptySubtitle;

  /// No description provided for @watchPollsTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch Polls'**
  String get watchPollsTitle;

  /// No description provided for @watchPollDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we watch?'**
  String get watchPollDefaultTitle;

  /// No description provided for @watchPollClosedLabel.
  ///
  /// In en, this message translates to:
  /// **'CLOSED'**
  String get watchPollClosedLabel;

  /// No description provided for @watchPollVoteCountSingular.
  ///
  /// In en, this message translates to:
  /// **'{count} vote'**
  String watchPollVoteCountSingular(String count);

  /// No description provided for @watchPollVoteCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} votes'**
  String watchPollVoteCountPlural(String count);

  /// No description provided for @watchPollsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No polls yet'**
  String get watchPollsEmptyTitle;

  /// No description provided for @watchPollsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a poll to let friends vote on what to watch next.'**
  String get watchPollsEmptySubtitle;

  /// No description provided for @createWatchPollTitle.
  ///
  /// In en, this message translates to:
  /// **'New Watch Poll'**
  String get createWatchPollTitle;

  /// No description provided for @watchPollTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Poll title (optional)'**
  String get watchPollTitleHint;

  /// No description provided for @watchPollOptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Options ({count}/{max})'**
  String watchPollOptionsLabel(int count, int max);

  /// No description provided for @watchPollSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search movies or shows to add'**
  String get watchPollSearchHint;

  /// No description provided for @watchPollInviteLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get watchPollInviteLabel;

  /// No description provided for @watchPollInviteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional — anyone invited can vote. You can also just create it for yourself.'**
  String get watchPollInviteSubtitle;

  /// No description provided for @watchPollNoFriendsYet.
  ///
  /// In en, this message translates to:
  /// **'Follow some friends to invite them to a poll.'**
  String get watchPollNoFriendsYet;

  /// No description provided for @watchPollCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create Poll'**
  String get watchPollCreateAction;

  /// No description provided for @watchPollCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close this poll?'**
  String get watchPollCloseTitle;

  /// No description provided for @watchPollCloseContent.
  ///
  /// In en, this message translates to:
  /// **'This locks in the current standings — no one will be able to vote after this.'**
  String get watchPollCloseContent;

  /// No description provided for @watchPollCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close poll'**
  String get watchPollCloseConfirm;

  /// No description provided for @watchPollCloseMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Close poll'**
  String get watchPollCloseMenuItem;

  /// No description provided for @watchPollDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete poll?'**
  String get watchPollDeleteTitle;

  /// No description provided for @watchPollDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'This removes the poll for everyone invited.'**
  String get watchPollDeleteContent;

  /// No description provided for @watchPollDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get watchPollDeleteConfirm;

  /// No description provided for @watchPollDeleteMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete poll'**
  String get watchPollDeleteMenuItem;

  /// No description provided for @watchPollNotFound.
  ///
  /// In en, this message translates to:
  /// **'This poll no longer exists.'**
  String get watchPollNotFound;

  /// No description provided for @watchPollClosedBanner.
  ///
  /// In en, this message translates to:
  /// **'This poll is closed — here\'s how it landed.'**
  String get watchPollClosedBanner;

  /// No description provided for @watchPollOptionVotesSingular.
  ///
  /// In en, this message translates to:
  /// **'{count} vote'**
  String watchPollOptionVotesSingular(String count);

  /// No description provided for @watchPollOptionVotesPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} votes'**
  String watchPollOptionVotesPlural(String count);

  /// No description provided for @homeWatchVersePro.
  ///
  /// In en, this message translates to:
  /// **'WatchVerse Pro'**
  String get homeWatchVersePro;

  /// No description provided for @proSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'WatchVerse Pro'**
  String get proSheetTitle;

  /// No description provided for @proSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock the full WatchVerse experience'**
  String get proSheetSubtitle;

  /// No description provided for @proFeatureStats.
  ///
  /// In en, this message translates to:
  /// **'Advanced watch stats & charts'**
  String get proFeatureStats;

  /// No description provided for @proFeatureLists.
  ///
  /// In en, this message translates to:
  /// **'Unlimited custom lists'**
  String get proFeatureLists;

  /// No description provided for @proFeatureProfile.
  ///
  /// In en, this message translates to:
  /// **'Exclusive profile themes'**
  String get proFeatureProfile;

  /// No description provided for @proFeatureGame.
  ///
  /// In en, this message translates to:
  /// **'Daily movie guessing game'**
  String get proFeatureGame;

  /// No description provided for @proTierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get proTierPro;

  /// No description provided for @proTierPatron.
  ///
  /// In en, this message translates to:
  /// **'Patron'**
  String get proTierPatron;

  /// No description provided for @proFeatureEverythingInPro.
  ///
  /// In en, this message translates to:
  /// **'Everything in Pro, plus:'**
  String get proFeatureEverythingInPro;

  /// No description provided for @proFeatureBadge.
  ///
  /// In en, this message translates to:
  /// **'Patron badge on your profile'**
  String get proFeatureBadge;

  /// No description provided for @proFeatureEarlyAccess.
  ///
  /// In en, this message translates to:
  /// **'Early access to new features'**
  String get proFeatureEarlyAccess;

  /// No description provided for @proMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get proMonthly;

  /// No description provided for @proYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get proYearly;

  /// No description provided for @proYearlySave.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String proYearlySave(String percent);

  /// No description provided for @proContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get proContinue;

  /// No description provided for @proRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get proRestore;

  /// No description provided for @proRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Subscription restored!'**
  String get proRestoreSuccess;

  /// No description provided for @proRestoreFailure.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase found for this Apple ID'**
  String get proRestoreFailure;

  /// No description provided for @proPurchaseFailure.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed — please try again'**
  String get proPurchaseFailure;

  /// No description provided for @proNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Pro isn\'t available yet — check back soon'**
  String get proNotConfigured;

  /// No description provided for @proActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Your WatchVerse subscription is active'**
  String get proActiveBadge;

  /// No description provided for @proSignInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign In to Continue'**
  String get proSignInToContinue;

  /// No description provided for @proSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account first to subscribe.'**
  String get proSignInRequired;

  /// No description provided for @proListLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Free accounts get 3 custom lists — upgrade to WatchVerse Pro for unlimited lists.'**
  String get proListLimitReached;

  /// No description provided for @proUnlockStats.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Pro'**
  String get proUnlockStats;

  /// No description provided for @proUnlockProfileTheme.
  ///
  /// In en, this message translates to:
  /// **'Patron theme'**
  String get proUnlockProfileTheme;

  /// No description provided for @proExporting.
  ///
  /// In en, this message translates to:
  /// **'Preparing your export…'**
  String get proExporting;

  /// No description provided for @proExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export my data (CSV)'**
  String get proExportAction;

  /// No description provided for @importDataAction.
  ///
  /// In en, this message translates to:
  /// **'Import from Letterboxd or IMDb'**
  String get importDataAction;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get importTitle;

  /// No description provided for @importIntro.
  ///
  /// In en, this message translates to:
  /// **'Bring your history over from Letterboxd or IMDb. Nothing already in WatchVerse is overwritten — your existing ratings and watched films are kept, and importing the same file again won\'t create duplicates.'**
  String get importIntro;

  /// No description provided for @importLetterboxdHeading.
  ///
  /// In en, this message translates to:
  /// **'Letterboxd'**
  String get importLetterboxdHeading;

  /// No description provided for @importLetterboxdSteps.
  ///
  /// In en, this message translates to:
  /// **'On letterboxd.com, go to Settings → Import & Export → Export Your Data. Pick the .zip you get as is — or just its watched, ratings, diary and watchlist CSV files.'**
  String get importLetterboxdSteps;

  /// No description provided for @importImdbHeading.
  ///
  /// In en, this message translates to:
  /// **'IMDb'**
  String get importImdbHeading;

  /// No description provided for @importImdbSteps.
  ///
  /// In en, this message translates to:
  /// **'On imdb.com, open Your Ratings (and your Watchlist) and choose Export from the ⋯ menu. When it\'s ready, download the CSV from the Exports page.'**
  String get importImdbSteps;

  /// No description provided for @importWhatHappens.
  ///
  /// In en, this message translates to:
  /// **'Watched and rated films are marked watched with their original dates, Letterboxd diary entries are kept, and watchlist films go to your watchlist. TV series from IMDb are added to My Shows without marking any episodes.'**
  String get importWhatHappens;

  /// No description provided for @importPickFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get importPickFiles;

  /// No description provided for @importPickHint.
  ///
  /// In en, this message translates to:
  /// **'You can pick several files at once.'**
  String get importPickHint;

  /// No description provided for @importReading.
  ///
  /// In en, this message translates to:
  /// **'Reading files…'**
  String get importReading;

  /// No description provided for @importProgress.
  ///
  /// In en, this message translates to:
  /// **'Matching titles… {done} / {total}'**
  String importProgress(String done, String total);

  /// No description provided for @importCancelling.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get importCancelling;

  /// No description provided for @importNothingFound.
  ///
  /// In en, this message translates to:
  /// **'No Letterboxd or IMDb data found in those files.'**
  String get importNothingFound;

  /// No description provided for @importUnrecognizedFiles.
  ///
  /// In en, this message translates to:
  /// **'Skipped (not a Letterboxd or IMDb export): {files}'**
  String importUnrecognizedFiles(String files);

  /// No description provided for @importDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get importDoneTitle;

  /// No description provided for @importCancelledNote.
  ///
  /// In en, this message translates to:
  /// **'Import stopped. Everything matched so far is saved — import again anytime to finish; nothing will be duplicated.'**
  String get importCancelledNote;

  /// No description provided for @importSummaryWatched.
  ///
  /// In en, this message translates to:
  /// **'Films marked watched'**
  String get importSummaryWatched;

  /// No description provided for @importSummaryRatings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get importSummaryRatings;

  /// No description provided for @importSummaryWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Added to watchlist'**
  String get importSummaryWatchlist;

  /// No description provided for @importSummaryShows.
  ///
  /// In en, this message translates to:
  /// **'Shows added to My Shows'**
  String get importSummaryShows;

  /// No description provided for @importSummaryDiary.
  ///
  /// In en, this message translates to:
  /// **'Diary entries'**
  String get importSummaryDiary;

  /// No description provided for @importSummaryExisting.
  ///
  /// In en, this message translates to:
  /// **'Already in your library'**
  String get importSummaryExisting;

  /// No description provided for @importSummarySkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped rows (episodes, games, invalid)'**
  String get importSummarySkipped;

  /// No description provided for @importSummaryUnmatched.
  ///
  /// In en, this message translates to:
  /// **'Not matched'**
  String get importSummaryUnmatched;

  /// No description provided for @importViewUnmatched.
  ///
  /// In en, this message translates to:
  /// **'View unmatched titles'**
  String get importViewUnmatched;

  /// No description provided for @importUnmatchedHint.
  ///
  /// In en, this message translates to:
  /// **'These couldn\'t be matched confidently. Search for them to add them by hand.'**
  String get importUnmatchedHint;

  /// No description provided for @importLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Lookup failed — importing again may fix this'**
  String get importLookupFailed;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get importDone;

  /// No description provided for @importMore.
  ///
  /// In en, this message translates to:
  /// **'Import more'**
  String get importMore;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importError(String error);

  /// No description provided for @importSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to import your Letterboxd or IMDb history.'**
  String get importSignInPrompt;

  /// No description provided for @proLegalFooter.
  ///
  /// In en, this message translates to:
  /// **'By subscribing you agree to our Terms of Service and Privacy Policy.'**
  String get proLegalFooter;

  /// No description provided for @proSubscriptionTerms.
  ///
  /// In en, this message translates to:
  /// **'Payment is charged to your Apple ID account at confirmation of purchase. Subscriptions renew automatically unless auto-renew is turned off at least 24 hours before the end of the current period. Manage or cancel anytime in Settings > [your name] > Subscriptions on your device.'**
  String get proSubscriptionTerms;

  /// No description provided for @dailyGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Movie Game'**
  String get dailyGameTitle;

  /// No description provided for @dailyGameSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a movie…'**
  String get dailyGameSearchHint;

  /// No description provided for @dailyGameGuessesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} guesses left'**
  String dailyGameGuessesLeft(String count);

  /// No description provided for @dailyGameClueDirector.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get dailyGameClueDirector;

  /// No description provided for @dailyGameClueStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get dailyGameClueStudio;

  /// No description provided for @dailyGameClueYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get dailyGameClueYear;

  /// No description provided for @dailyGameClueRevenue.
  ///
  /// In en, this message translates to:
  /// **'Box Office'**
  String get dailyGameClueRevenue;

  /// No description provided for @dailyGameClueRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get dailyGameClueRating;

  /// No description provided for @dailyGameClueCertification.
  ///
  /// In en, this message translates to:
  /// **'Rated'**
  String get dailyGameClueCertification;

  /// No description provided for @dailyGameClueCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get dailyGameClueCast;

  /// No description provided for @dailyGameClueGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get dailyGameClueGenres;

  /// No description provided for @dailyGameHintUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Hint unlocked!'**
  String get dailyGameHintUnlocked;

  /// No description provided for @dailyGameShowHint.
  ///
  /// In en, this message translates to:
  /// **'Show hint'**
  String get dailyGameShowHint;

  /// No description provided for @dailyGameWinTitle.
  ///
  /// In en, this message translates to:
  /// **'You got it!'**
  String get dailyGameWinTitle;

  /// No description provided for @dailyGameLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of guesses'**
  String get dailyGameLoseTitle;

  /// No description provided for @dailyGameShareResult.
  ///
  /// In en, this message translates to:
  /// **'Share result'**
  String get dailyGameShareResult;

  /// No description provided for @dailyGamePlayAgainTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for a new movie'**
  String get dailyGamePlayAgainTomorrow;

  /// No description provided for @dailyGameNoPool.
  ///
  /// In en, this message translates to:
  /// **'Today\'s puzzle isn\'t ready yet — check back soon'**
  String get dailyGameNoPool;

  /// No description provided for @dailyGameRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get dailyGameRetry;

  /// No description provided for @dailyGameSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to play the daily movie game.'**
  String get dailyGameSignInPrompt;

  /// No description provided for @dailyGameGuessedAlready.
  ///
  /// In en, this message translates to:
  /// **'Already guessed'**
  String get dailyGameGuessedAlready;

  /// No description provided for @dailyGamePickAnotherDay.
  ///
  /// In en, this message translates to:
  /// **'Pick a day'**
  String get dailyGamePickAnotherDay;

  /// No description provided for @pollSignInToVote.
  ///
  /// In en, this message translates to:
  /// **'Sign in to vote.'**
  String get pollSignInToVote;

  /// No description provided for @tvSeasonLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this season\'s episodes.'**
  String get tvSeasonLoadFailed;

  /// No description provided for @discoverLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more.'**
  String get discoverLoadMoreFailed;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @patronBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Patron'**
  String get patronBadgeLabel;

  /// No description provided for @dailyGameToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dailyGameToday;

  /// No description provided for @dailyGamePuzzleFor.
  ///
  /// In en, this message translates to:
  /// **'Puzzle for {date}'**
  String dailyGamePuzzleFor(String date);

  /// No description provided for @dailyGameHowToPlay.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get dailyGameHowToPlay;

  /// No description provided for @dailyGameHowToIntro.
  ///
  /// In en, this message translates to:
  /// **'Find the mystery movie in {max} guesses. Search for any movie and pick it — each guess shows how it compares to the mystery movie.'**
  String dailyGameHowToIntro(String max);

  /// No description provided for @dailyGameHowToGreen.
  ///
  /// In en, this message translates to:
  /// **'Green: exact match'**
  String get dailyGameHowToGreen;

  /// No description provided for @dailyGameHowToGold.
  ///
  /// In en, this message translates to:
  /// **'Gold: close — shares a director, studio, cast member or genre, or the year is within 5, the rating within 0.5, or the box office within 50%'**
  String get dailyGameHowToGold;

  /// No description provided for @dailyGameHowToGray.
  ///
  /// In en, this message translates to:
  /// **'Gray: no match. A \"?\" tile means the info is unknown for one of the movies.'**
  String get dailyGameHowToGray;

  /// No description provided for @dailyGameHowToArrows.
  ///
  /// In en, this message translates to:
  /// **'↑ ↓: the mystery movie\'s year, box office or rating is higher / lower than your guess'**
  String get dailyGameHowToArrows;

  /// No description provided for @dailyGameHowToShared.
  ///
  /// In en, this message translates to:
  /// **'For cast, genres, studio and director, a gold tile shows what the two movies share.'**
  String get dailyGameHowToShared;

  /// No description provided for @dailyGameHowToHints.
  ///
  /// In en, this message translates to:
  /// **'Stuck? Hints unlock after guess {first} and {second}. A new movie every day — the calendar lets you play the past week too.'**
  String dailyGameHowToHints(String first, String second);

  /// No description provided for @dailyGameGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get dailyGameGotIt;

  /// No description provided for @dailyGameHints.
  ///
  /// In en, this message translates to:
  /// **'Hints'**
  String get dailyGameHints;

  /// No description provided for @dailyGameNextHint.
  ///
  /// In en, this message translates to:
  /// **'Next hint after guess {count}'**
  String dailyGameNextHint(String count);

  /// No description provided for @dailyGameHintTopBilled.
  ///
  /// In en, this message translates to:
  /// **'Top-billed: {name}'**
  String dailyGameHintTopBilled(String name);

  /// No description provided for @dailyGameNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching movies'**
  String get dailyGameNoResults;

  /// No description provided for @dailyGameSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Check your connection.'**
  String get dailyGameSearchFailed;

  /// No description provided for @dailyGameSolvedIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Solved on the first guess!} other{Solved in {count} guesses}}'**
  String dailyGameSolvedIn(int count);

  /// No description provided for @dailyGameAnswerWas.
  ///
  /// In en, this message translates to:
  /// **'The movie was'**
  String get dailyGameAnswerWas;

  /// No description provided for @dailyGameViewMovie.
  ///
  /// In en, this message translates to:
  /// **'View movie'**
  String get dailyGameViewMovie;

  /// No description provided for @dailyGameGuessFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load that movie. Try again.'**
  String get dailyGameGuessFailed;

  /// No description provided for @dailyGameRowFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this guess'**
  String get dailyGameRowFailed;

  /// No description provided for @gamesHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get gamesHubTitle;

  /// No description provided for @gamesHubDailyMovieSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Guess the mystery movie from clues. New every day.'**
  String get gamesHubDailyMovieSubtitle;

  /// No description provided for @gamesHubStatusNotPlayed.
  ///
  /// In en, this message translates to:
  /// **'Not played today'**
  String get gamesHubStatusNotPlayed;

  /// No description provided for @gamesHubStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get gamesHubStatusInProgress;

  /// No description provided for @gamesHubStatusSolved.
  ///
  /// In en, this message translates to:
  /// **'Solved today'**
  String get gamesHubStatusSolved;

  /// No description provided for @gamesHubStatusMissed.
  ///
  /// In en, this message translates to:
  /// **'Played today'**
  String get gamesHubStatusMissed;

  /// No description provided for @actorGuessTitle.
  ///
  /// In en, this message translates to:
  /// **'Who\'s the Actor?'**
  String get actorGuessTitle;

  /// No description provided for @actorGuessHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name today\'s mystery actor from six clues'**
  String get actorGuessHubSubtitle;

  /// No description provided for @actorGuessSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to play Who\'s the Actor?'**
  String get actorGuessSignInPrompt;

  /// No description provided for @actorGuessLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load today\'s actor.'**
  String get actorGuessLoadError;

  /// No description provided for @actorGuessNoPool.
  ///
  /// In en, this message translates to:
  /// **'Today\'s puzzle isn\'t ready yet — check back soon'**
  String get actorGuessNoPool;

  /// No description provided for @actorGuessRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actorGuessRetry;

  /// No description provided for @actorGuessSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for an actor or actress…'**
  String get actorGuessSearchHint;

  /// No description provided for @actorGuessSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Check your connection.'**
  String get actorGuessSearchFailed;

  /// No description provided for @actorGuessNoResults.
  ///
  /// In en, this message translates to:
  /// **'No actors found'**
  String get actorGuessNoResults;

  /// No description provided for @actorGuessAlreadyGuessed.
  ///
  /// In en, this message translates to:
  /// **'Already guessed'**
  String get actorGuessAlreadyGuessed;

  /// No description provided for @actorGuessGuessesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} guesses left'**
  String actorGuessGuessesLeft(String count);

  /// No description provided for @actorGuessClueNumber.
  ///
  /// In en, this message translates to:
  /// **'Clue {number}'**
  String actorGuessClueNumber(String number);

  /// No description provided for @actorGuessClueOrigin.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get actorGuessClueOrigin;

  /// No description provided for @actorGuessFirstMovie.
  ///
  /// In en, this message translates to:
  /// **'First movie role: {year}'**
  String actorGuessFirstMovie(String year);

  /// No description provided for @actorGuessBornIn.
  ///
  /// In en, this message translates to:
  /// **'Born in: {country}'**
  String actorGuessBornIn(String country);

  /// No description provided for @actorGuessClueDeepCuts.
  ///
  /// In en, this message translates to:
  /// **'Also appeared in'**
  String get actorGuessClueDeepCuts;

  /// No description provided for @actorGuessClueKnownTitles.
  ///
  /// In en, this message translates to:
  /// **'Well-known titles'**
  String get actorGuessClueKnownTitles;

  /// No description provided for @actorGuessClueCharacter.
  ///
  /// In en, this message translates to:
  /// **'Famous role'**
  String get actorGuessClueCharacter;

  /// No description provided for @actorGuessCharacterIn.
  ///
  /// In en, this message translates to:
  /// **'{character} in {title}'**
  String actorGuessCharacterIn(String character, String title);

  /// No description provided for @actorGuessClueTopTitles.
  ///
  /// In en, this message translates to:
  /// **'Best known for'**
  String get actorGuessClueTopTitles;

  /// No description provided for @actorGuessCluePhoto.
  ///
  /// In en, this message translates to:
  /// **'Their photo'**
  String get actorGuessCluePhoto;

  /// No description provided for @actorGuessNextClueHint.
  ///
  /// In en, this message translates to:
  /// **'Each wrong guess reveals another clue'**
  String get actorGuessNextClueHint;

  /// No description provided for @actorGuessYourGuesses.
  ///
  /// In en, this message translates to:
  /// **'Your guesses'**
  String get actorGuessYourGuesses;

  /// No description provided for @actorGuessWinTitle.
  ///
  /// In en, this message translates to:
  /// **'You got it!'**
  String get actorGuessWinTitle;

  /// No description provided for @actorGuessWinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Solved in {count}/{max} guesses'**
  String actorGuessWinSubtitle(String count, String max);

  /// No description provided for @actorGuessLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of guesses'**
  String get actorGuessLoseTitle;

  /// No description provided for @actorGuessAnswerWas.
  ///
  /// In en, this message translates to:
  /// **'Today\'s actor was {name}'**
  String actorGuessAnswerWas(String name);

  /// No description provided for @actorGuessViewFilmography.
  ///
  /// In en, this message translates to:
  /// **'View filmography'**
  String get actorGuessViewFilmography;

  /// No description provided for @actorGuessShareResult.
  ///
  /// In en, this message translates to:
  /// **'Share result'**
  String get actorGuessShareResult;

  /// No description provided for @actorGuessComeBackTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for a new actor'**
  String get actorGuessComeBackTomorrow;

  /// No description provided for @gamesCommonMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get gamesCommonMovies;

  /// No description provided for @gamesCommonTv.
  ///
  /// In en, this message translates to:
  /// **'TV Shows'**
  String get gamesCommonTv;

  /// No description provided for @gamesCommonPuzzleNumber.
  ///
  /// In en, this message translates to:
  /// **'Puzzle #{number}'**
  String gamesCommonPuzzleNumber(String number);

  /// No description provided for @gamesCommonShare.
  ///
  /// In en, this message translates to:
  /// **'Share result'**
  String get gamesCommonShare;

  /// No description provided for @gamesCommonViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get gamesCommonViewDetails;

  /// No description provided for @gamesCommonComeBackTomorrow.
  ///
  /// In en, this message translates to:
  /// **'A new puzzle arrives tomorrow.'**
  String get gamesCommonComeBackTomorrow;

  /// No description provided for @gamesCommonGuestNote.
  ///
  /// In en, this message translates to:
  /// **'Playing as a guest — sign in to save your results.'**
  String get gamesCommonGuestNote;

  /// No description provided for @gamesCommonLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load today\'s puzzle.'**
  String get gamesCommonLoadError;

  /// No description provided for @gamesCommonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get gamesCommonRetry;

  /// No description provided for @gamesCommonSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your progress. Check your connection.'**
  String get gamesCommonSaveFailed;

  /// No description provided for @gamesCommonWin.
  ///
  /// In en, this message translates to:
  /// **'You got it!'**
  String get gamesCommonWin;

  /// No description provided for @gamesCommonLose.
  ///
  /// In en, this message translates to:
  /// **'Not this time'**
  String get gamesCommonLose;

  /// No description provided for @gamesCommonSolvedIn.
  ///
  /// In en, this message translates to:
  /// **'Solved in {count}/{total}'**
  String gamesCommonSolvedIn(String count, String total);

  /// No description provided for @gamesCommonAnswerWas.
  ///
  /// In en, this message translates to:
  /// **'The answer was {title}'**
  String gamesCommonAnswerWas(String title);

  /// No description provided for @gamesCommonGuessesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} guesses left'**
  String gamesCommonGuessesLeft(String count);

  /// No description provided for @framesGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get framesGameTitle;

  /// No description provided for @framesGameIntroMovie.
  ///
  /// In en, this message translates to:
  /// **'Name the movie from its stills. Each wrong guess or skip reveals another frame.'**
  String get framesGameIntroMovie;

  /// No description provided for @framesGameIntroTv.
  ///
  /// In en, this message translates to:
  /// **'Name the TV show from its stills. Each wrong guess or skip reveals another frame.'**
  String get framesGameIntroTv;

  /// No description provided for @framesGameSearchHintMovie.
  ///
  /// In en, this message translates to:
  /// **'Search for a movie…'**
  String get framesGameSearchHintMovie;

  /// No description provided for @framesGameSearchHintTv.
  ///
  /// In en, this message translates to:
  /// **'Search for a TV show…'**
  String get framesGameSearchHintTv;

  /// No description provided for @framesGameSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get framesGameSkip;

  /// No description provided for @framesGameFrameLabel.
  ///
  /// In en, this message translates to:
  /// **'Frame {number}'**
  String framesGameFrameLabel(String number);

  /// No description provided for @framesGameSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get framesGameSkipped;

  /// No description provided for @framesGameAlreadyGuessed.
  ///
  /// In en, this message translates to:
  /// **'Already guessed'**
  String get framesGameAlreadyGuessed;

  /// No description provided for @framesGameNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get framesGameNoResults;

  /// No description provided for @titleWordleTitle.
  ///
  /// In en, this message translates to:
  /// **'Title Wordle'**
  String get titleWordleTitle;

  /// No description provided for @titleWordleIntroMovie.
  ///
  /// In en, this message translates to:
  /// **'Guess today\'s movie title in 6 tries. Type letters only — word breaks are already shown.'**
  String get titleWordleIntroMovie;

  /// No description provided for @titleWordleIntroTv.
  ///
  /// In en, this message translates to:
  /// **'Guess today\'s TV show title in 6 tries. Type letters only — word breaks are already shown.'**
  String get titleWordleIntroTv;

  /// No description provided for @titleWordleLetterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} letters'**
  String titleWordleLetterCount(String count);

  /// No description provided for @titleWordleNotEnoughLetters.
  ///
  /// In en, this message translates to:
  /// **'Not enough letters'**
  String get titleWordleNotEnoughLetters;

  /// No description provided for @titleWordleSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit guess'**
  String get titleWordleSubmit;

  /// No description provided for @titleWordleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete letter'**
  String get titleWordleDelete;

  /// No description provided for @gamesHubFramesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Guess the movie or show from its stills'**
  String get gamesHubFramesSubtitle;

  /// No description provided for @gamesHubTitleWordleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Guess the movie or show title, Wordle style'**
  String get gamesHubTitleWordleSubtitle;

  /// No description provided for @higherLowerTitle.
  ///
  /// In en, this message translates to:
  /// **'Higher or Lower'**
  String get higherLowerTitle;

  /// No description provided for @higherLowerIntro.
  ///
  /// In en, this message translates to:
  /// **'Is the next title higher or lower? Keep guessing right to build your score.'**
  String get higherLowerIntro;

  /// No description provided for @higherLowerPickCategory.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get higherLowerPickCategory;

  /// No description provided for @higherLowerCategoryMovieRating.
  ///
  /// In en, this message translates to:
  /// **'Movie rating'**
  String get higherLowerCategoryMovieRating;

  /// No description provided for @higherLowerCategoryBoxOffice.
  ///
  /// In en, this message translates to:
  /// **'Box office'**
  String get higherLowerCategoryBoxOffice;

  /// No description provided for @higherLowerCategoryTvRating.
  ///
  /// In en, this message translates to:
  /// **'TV show rating'**
  String get higherLowerCategoryTvRating;

  /// No description provided for @higherLowerCategoryRatingDesc.
  ///
  /// In en, this message translates to:
  /// **'TMDB user score'**
  String get higherLowerCategoryRatingDesc;

  /// No description provided for @higherLowerCategoryBoxOfficeDesc.
  ///
  /// In en, this message translates to:
  /// **'Worldwide gross'**
  String get higherLowerCategoryBoxOfficeDesc;

  /// No description provided for @higherLowerBest.
  ///
  /// In en, this message translates to:
  /// **'Best: {score}'**
  String higherLowerBest(int score);

  /// No description provided for @higherLowerScore.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String higherLowerScore(int score);

  /// No description provided for @higherLowerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Higher or lower than {title}?'**
  String higherLowerPrompt(String title);

  /// No description provided for @higherLowerHigher.
  ///
  /// In en, this message translates to:
  /// **'Higher'**
  String get higherLowerHigher;

  /// No description provided for @higherLowerLower.
  ///
  /// In en, this message translates to:
  /// **'Lower'**
  String get higherLowerLower;

  /// No description provided for @higherLowerCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get higherLowerCorrect;

  /// No description provided for @higherLowerWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong!'**
  String get higherLowerWrong;

  /// No description provided for @higherLowerGameOver.
  ///
  /// In en, this message translates to:
  /// **'Game over'**
  String get higherLowerGameOver;

  /// No description provided for @higherLowerFinalScore.
  ///
  /// In en, this message translates to:
  /// **'You scored {score}'**
  String higherLowerFinalScore(int score);

  /// No description provided for @higherLowerNewBest.
  ///
  /// In en, this message translates to:
  /// **'New personal best!'**
  String get higherLowerNewBest;

  /// No description provided for @higherLowerPlayAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get higherLowerPlayAgain;

  /// No description provided for @higherLowerChangeCategory.
  ///
  /// In en, this message translates to:
  /// **'Change category'**
  String get higherLowerChangeCategory;

  /// No description provided for @higherLowerTiesNote.
  ///
  /// In en, this message translates to:
  /// **'Ties count as correct.'**
  String get higherLowerTiesNote;

  /// No description provided for @plotGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Plot'**
  String get plotGameTitle;

  /// No description provided for @plotGameModeMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get plotGameModeMovie;

  /// No description provided for @plotGameModeTv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get plotGameModeTv;

  /// No description provided for @plotGameIntro.
  ///
  /// In en, this message translates to:
  /// **'Guess today\'s title from its plot. Names are hidden — every miss or skip reveals another clue.'**
  String get plotGameIntro;

  /// No description provided for @plotGameSearchMovieHint.
  ///
  /// In en, this message translates to:
  /// **'Guess the movie…'**
  String get plotGameSearchMovieHint;

  /// No description provided for @plotGameSearchTvHint.
  ///
  /// In en, this message translates to:
  /// **'Guess the show…'**
  String get plotGameSearchTvHint;

  /// No description provided for @plotGameSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get plotGameSkip;

  /// No description provided for @plotGameSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get plotGameSkipped;

  /// No description provided for @plotGameAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} guesses left'**
  String plotGameAttemptsLeft(int count);

  /// No description provided for @plotGameCluePlot.
  ///
  /// In en, this message translates to:
  /// **'Plot'**
  String get plotGameCluePlot;

  /// No description provided for @plotGameClueMorePlot.
  ///
  /// In en, this message translates to:
  /// **'More plot'**
  String get plotGameClueMorePlot;

  /// No description provided for @plotGameClueYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get plotGameClueYear;

  /// No description provided for @plotGameClueGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get plotGameClueGenres;

  /// No description provided for @plotGameClueActor.
  ///
  /// In en, this message translates to:
  /// **'Top-billed actor'**
  String get plotGameClueActor;

  /// No description provided for @plotGameClueSecondActor.
  ///
  /// In en, this message translates to:
  /// **'Also starring'**
  String get plotGameClueSecondActor;

  /// No description provided for @plotGameClueTagline.
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get plotGameClueTagline;

  /// No description provided for @plotGameNextClueLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocks after a miss'**
  String get plotGameNextClueLocked;

  /// No description provided for @plotGameAlreadyGuessed.
  ///
  /// In en, this message translates to:
  /// **'Already guessed'**
  String get plotGameAlreadyGuessed;

  /// No description provided for @plotGameNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get plotGameNoResults;

  /// No description provided for @plotGameWinTitle.
  ///
  /// In en, this message translates to:
  /// **'You got it!'**
  String get plotGameWinTitle;

  /// No description provided for @plotGameLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of guesses'**
  String get plotGameLoseTitle;

  /// No description provided for @plotGameSolvedIn.
  ///
  /// In en, this message translates to:
  /// **'Solved in {count}/{max}'**
  String plotGameSolvedIn(int count, int max);

  /// No description provided for @plotGameViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get plotGameViewDetails;

  /// No description provided for @plotGameShare.
  ///
  /// In en, this message translates to:
  /// **'Share result'**
  String get plotGameShare;

  /// No description provided for @plotGameComeBack.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for a new plot.'**
  String get plotGameComeBack;

  /// No description provided for @plotGameSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to play the daily Plot game.'**
  String get plotGameSignInPrompt;

  /// No description provided for @plotGameNoPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s puzzle isn\'t available yet — check back soon.'**
  String get plotGameNoPuzzle;

  /// No description provided for @gamesHubPlotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Guess the movie or show from its redacted plot'**
  String get gamesHubPlotSubtitle;

  /// No description provided for @gamesHubHigherLowerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which one is rated higher? Endless rounds'**
  String get gamesHubHigherLowerSubtitle;

  /// No description provided for @streamingSettingsTile.
  ///
  /// In en, this message translates to:
  /// **'My streaming services'**
  String get streamingSettingsTile;

  /// No description provided for @streamingSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'My streaming services'**
  String get streamingSetupTitle;

  /// No description provided for @streamingSetupIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick the services you subscribe to and we\'ll show what on your watchlist you can stream right now.'**
  String get streamingSetupIntro;

  /// No description provided for @streamingRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get streamingRegionLabel;

  /// No description provided for @streamingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search services'**
  String get streamingSearchHint;

  /// No description provided for @streamingSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No services selected} =1{1 service selected} other{{count} services selected}}'**
  String streamingSelectedCount(int count);

  /// No description provided for @streamingNoProviders.
  ///
  /// In en, this message translates to:
  /// **'No streaming services are listed for this region.'**
  String get streamingNoProviders;

  /// No description provided for @streamingSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your services. Try again.'**
  String get streamingSaveError;

  /// No description provided for @streamingJustWatchCredit.
  ///
  /// In en, this message translates to:
  /// **'Streaming data by JustWatch'**
  String get streamingJustWatchCredit;

  /// No description provided for @streamingFilterChip.
  ///
  /// In en, this message translates to:
  /// **'On my services'**
  String get streamingFilterChip;

  /// No description provided for @streamingChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking {checked}/{total}…'**
  String streamingChecking(int checked, int total);

  /// No description provided for @streamingCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Couldn\'t check 1 title} other{Couldn\'t check {count} titles}}'**
  String streamingCheckFailed(int count);

  /// No description provided for @streamingFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is streaming on your services right now.'**
  String get streamingFilterEmpty;

  /// No description provided for @streamingNotSetUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your streaming services'**
  String get streamingNotSetUpTitle;

  /// No description provided for @streamingNotSetUpBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us which services you subscribe to and we\'ll filter this list to what you can watch right now.'**
  String get streamingNotSetUpBody;

  /// No description provided for @streamingSetUpAction.
  ///
  /// In en, this message translates to:
  /// **'Choose services'**
  String get streamingSetUpAction;

  /// No description provided for @streamingOnYour.
  ///
  /// In en, this message translates to:
  /// **'On your {services}'**
  String streamingOnYour(String services);
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
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
