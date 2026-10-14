// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WatchVerse';

  @override
  String get loginSubtitle => 'Track the movies & shows you love';

  @override
  String get emailHint => 'Email';

  @override
  String get emailRequired => 'Please enter your email';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get passwordHint => 'Password';

  @override
  String get passwordRequiredLogin => 'Please enter your password';

  @override
  String get logIn => 'Log In';

  @override
  String get continueAsGuest => 'Continue as guest';

  @override
  String get noAccountPrompt => 'Don\'t have an account?';

  @override
  String get register => 'Register';

  @override
  String get errorUserNotFound => 'No user found for this email.';

  @override
  String get errorWrongPassword => 'Incorrect email or password.';

  @override
  String get errorGeneric => 'An error occurred.';

  @override
  String errorSignIn(String error) {
    return 'Could not sign in: $error';
  }

  @override
  String get createAccountTitle => 'Create account';

  @override
  String get createAccountSubtitle => 'Join WatchVerse to start tracking';

  @override
  String get usernameHint => 'Username';

  @override
  String get usernameRequired => 'Please enter a username';

  @override
  String get confirmPasswordHint => 'Confirm password';

  @override
  String get passwordRequiredRegister => 'Please enter a password';

  @override
  String get passwordTooShort => 'At least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get createAccountButton => 'Create Account';

  @override
  String get alreadyHaveAccountPrompt => 'Already have an account?';

  @override
  String get logInLowercase => 'Log in';

  @override
  String get errorWeakPassword => 'The password is too weak.';

  @override
  String get errorEmailInUse => 'This email is already in use.';

  @override
  String errorCreateAccount(String error) {
    return 'Could not create account: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsAppInfoSection => 'About';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTermsOfService => 'Terms of Service';

  @override
  String get settingsNotificationsSection => 'Notifications';

  @override
  String get settingsNotifyEpisodeTomorrow => 'New episodes airing tomorrow';

  @override
  String get settingsNotifyEpisodeToday => 'New episodes out today';

  @override
  String get settingsNotifyFriendActivity => 'Friend activity';

  @override
  String get settingsNotifySharedWatch => 'Shared watch matches';

  @override
  String settingsAppVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsDeleteAccount => 'Delete Account';

  @override
  String get settingsDeleteAccountConfirmTitle => 'Delete your account?';

  @override
  String get settingsDeleteAccountConfirmBody =>
      'This can\'t be undone. Your account, sign-in, library, lists, diary, and comments will be permanently deleted. An App Store subscription isn\'t cancelled automatically — cancel it separately in your device\'s subscription settings.';

  @override
  String get settingsDeleteAccountAction => 'Delete';

  @override
  String get settingsDeleteAccountRequiresRecentLogin =>
      'For your security, this requires a recent sign-in. Please sign out and sign back in, then try again.';

  @override
  String settingsDeleteAccountError(String error) {
    return 'Could not delete account: $error';
  }

  @override
  String get settingsDeleteAccountIncomplete =>
      'Your account deletion started but couldn\'t finish. Sign in again to complete it.';

  @override
  String get accountDeletionFinishingTitle => 'Finishing account deletion';

  @override
  String get accountDeletionFinishingBody =>
      'An earlier request to delete this account didn\'t finish. Completing it now…';

  @override
  String accountDeletionResumeFailed(String error) {
    return 'Couldn\'t finish deleting your account: $error';
  }

  @override
  String get accountDeletionRetry => 'Try again';

  @override
  String get accountDeletionSignOut => 'Sign out';

  @override
  String get selectAvatarTitle => 'Select an Avatar';

  @override
  String get editNameTitle => 'Edit Name';

  @override
  String get enterNewNameHint => 'Enter new name';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String nameLabel(String name) {
    return 'Name: $name';
  }

  @override
  String get noName => 'No Name';

  @override
  String get nameUpdated => 'Name updated successfully!';

  @override
  String failedFetchUser(String error) {
    return 'Failed to fetch user data: $error';
  }

  @override
  String failedUpdateName(String error) {
    return 'Failed to update name: $error';
  }

  @override
  String get profilePictureUpdated => 'Profile picture updated!';

  @override
  String failedUpdateProfilePicture(String error) {
    return 'Failed to update profile picture: $error';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String tvErrorLoadingShow(String error) {
    return 'Could not load show.\n$error';
  }

  @override
  String get tvOverviewTitle => 'Overview';

  @override
  String get tvSeasonsTitle => 'Seasons';

  @override
  String get tvMoreLikeThisTitle => 'More Like This';

  @override
  String get tvAddToListTooltip => 'Add to list';

  @override
  String get tvAddToMyShows => 'Add to My Shows';

  @override
  String get tvStatusCompleted => 'Completed';

  @override
  String get tvStatusWatching => 'Watching';

  @override
  String get tvInMyShows => 'In My Shows';

  @override
  String tvSeasonCountSingular(String count) {
    return '$count Season';
  }

  @override
  String tvSeasonCountPlural(String count) {
    return '$count Seasons';
  }

  @override
  String get tvMarkPreviousTitle => 'Mark previous episodes?';

  @override
  String tvMarkPreviousQuestion(String episodesPhrase) {
    return 'You jumped ahead. Also mark the $episodesPhrase as watched?';
  }

  @override
  String tvEpisodeCountSingular(String count) {
    return '$count earlier episode';
  }

  @override
  String tvEpisodeCountPlural(String count) {
    return '$count earlier episodes';
  }

  @override
  String get tvNo => 'No';

  @override
  String get tvYesMarkAll => 'Yes, mark all';

  @override
  String tvFinishedShow(String name) {
    return '🎉 You finished $name!';
  }

  @override
  String tvSeasonComplete(String season) {
    return '🎉 Season $season complete!';
  }

  @override
  String get tvRemoveShowTitle => 'Remove show?';

  @override
  String tvRemoveShowContent(String name) {
    return 'This removes \"$name\" and all watched-episode progress.';
  }

  @override
  String get tvRemoveButton => 'Remove';

  @override
  String get tvYourProgress => 'Your progress';

  @override
  String tvProgressFraction(String watched, String total) {
    return '$watched / $total';
  }

  @override
  String tvPercentWatched(String percent) {
    return '$percent% watched';
  }

  @override
  String get tvYourRating => 'Your rating';

  @override
  String get movieYourRating => 'Your rating';

  @override
  String get movieCannotMarkUnreleased =>
      'This movie hasn\'t been released yet.';

  @override
  String get movieNotYetReleased => 'Not yet released';

  @override
  String movieReleasesOn(String date) {
    return 'Releases on $date';
  }

  @override
  String get tvUpNextLabel => 'UP NEXT';

  @override
  String tvUpNextEpisodeLabel(String season, String episode, String name) {
    return 'S$season E$episode  $name';
  }

  @override
  String tvSeasonNumberLabel(String season) {
    return 'Season $season';
  }

  @override
  String tvSeasonFraction(String watched, String total) {
    return '$watched/$total';
  }

  @override
  String get tvUnmarkSeason => 'Unmark season';

  @override
  String get tvMarkSeasonWatched => 'Mark season watched';

  @override
  String get tvCannotMarkUnaired => 'This episode hasn\'t aired yet.';

  @override
  String get tvMoreEpisodesComing => 'More episodes coming';

  @override
  String get tvMarkAllSeasonsButton => 'Mark all seasons watched';

  @override
  String get tvMarkAllSeasonsTitle => 'Mark all seasons watched?';

  @override
  String tvMarkAllSeasonsQuestion(String name) {
    return 'Every aired episode of $name will be marked as watched.';
  }

  @override
  String tvEpisodeNumberLabel(String number, String name) {
    return '$number. $name';
  }

  @override
  String get tvNotAired => 'Not aired';

  @override
  String tvRuntimeMinutes(String minutes) {
    return '${minutes}m';
  }

  @override
  String profileUpdatePhotoError(String error) {
    return 'Could not update photo: $error';
  }

  @override
  String get profileEditNameTitle => 'Edit name';

  @override
  String get profileEditProfileTitle => 'Edit Profile';

  @override
  String get profileYourNameHint => 'Your name';

  @override
  String get profileCharacterQuoteHint =>
      'If I were a movie/TV character, I\'d be...';

  @override
  String get profileAvatarBackgroundLabel => 'Profile background';

  @override
  String profileSaveNameError(String error) {
    return 'Could not save name: $error';
  }

  @override
  String get profileSignInPrompt => 'Sign in to view your profile.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAddYourName => 'Add your name';

  @override
  String get profileFriendsActivity => 'Friends\' Activity';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileBlockedUsers => 'Blocked Users';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String profileSignOutFailed(String error) {
    return 'Sign out failed: $error';
  }

  @override
  String get profileFollowers => 'Followers';

  @override
  String get profileFollowing => 'Following';

  @override
  String get profileFilms => 'Films';

  @override
  String get profileMovieTimeSpent => 'Movie time';

  @override
  String get profileShowTimeSpent => 'Show time';

  @override
  String profileDurationCompact(String hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String profileDurationDaysHours(String days, String hours) {
    return '${days}d ${hours}h';
  }

  @override
  String profileDurationMonthsDaysHours(
    String months,
    String days,
    String hours,
  ) {
    return '${months}mo ${days}d ${hours}h';
  }

  @override
  String get watchedMoviesSortTooltip => 'Sort';

  @override
  String get watchedMoviesSortByDate => 'Date added';

  @override
  String get watchedMoviesSortByRating => 'Rating (high to low)';

  @override
  String get profileShows => 'Shows';

  @override
  String get profileEpisodes => 'Episodes';

  @override
  String profileYourYear(String year) {
    return 'Your $year';
  }

  @override
  String get profileWatched => 'Watched';

  @override
  String get profileFavoritesTitle => 'Top 3 Favorite Films';

  @override
  String get profileFavoritesEmptyHint =>
      'Tap the ♥ on a movie\'s page to add it here';

  @override
  String get profileShowcasePickerTitle => 'Add to showcase';

  @override
  String get profileShowcaseRemove => 'Remove from showcase';

  @override
  String get profileMoviesTitle => 'Movies';

  @override
  String get profileSeriesTitle => 'Series';

  @override
  String get profileSeeAll => 'See all';

  @override
  String get profileMovieLabel => 'Movie';

  @override
  String profileSeasonLabel(String season) {
    return 'Season $season';
  }

  @override
  String profileEpisodeLabel(String season, String episode) {
    return 'S$season · E$episode';
  }

  @override
  String get followListEmptyMessage => 'Nobody here yet.';

  @override
  String get homeLoadFailedTitle => 'Couldn\'t load titles';

  @override
  String get homeLoadFailedBody => 'Check your connection and try again.';

  @override
  String get homeRetryAction => 'Try again';

  @override
  String get homeFindFriendsBannerTitle => 'Find friends on WatchVerse';

  @override
  String get homeFindFriendsBannerBody =>
      'Follow people to see what they\'re watching.';

  @override
  String get homeFindFriendsBannerAction => 'Find';

  @override
  String asyncErrorMessage(String error) {
    return 'Something went wrong.\n$error';
  }

  @override
  String get movieAddToList => 'Add to list';

  @override
  String get movieTypeLabel => 'Movie';

  @override
  String get movieOverview => 'Overview';

  @override
  String get movieMoreLikeThis => 'More Like This';

  @override
  String get movieToWatch => 'To Watch';

  @override
  String get movieWatched => 'Watched';

  @override
  String get movieYourDiary => 'Your Diary';

  @override
  String get movieLogAction => 'Log';

  @override
  String get movieLogAgainAction => 'Log again';

  @override
  String get movieDiaryEmpty =>
      'No entries yet. Log a watch to start your diary — you can record rewatches with their own dates.';

  @override
  String movieLogSheetTitle(String action, String title) {
    return '$action \"$title\"';
  }

  @override
  String get movieRewatchAction => 'Rewatch';

  @override
  String get movieWatchedOn => 'Watched on';

  @override
  String get movieDiaryNote => 'Diary note';

  @override
  String get movieDiaryNoteHint => 'What did you think?';

  @override
  String get movieSaveRewatch => 'Save rewatch';

  @override
  String get movieSaveToDiary => 'Save to diary';

  @override
  String get pollSectionTitle => 'How was it?';

  @override
  String get pollRatingCommunityMovie => 'How everyone rated this movie';

  @override
  String get pollRatingCommunityEpisode => 'How everyone rated this episode';

  @override
  String get pollRatingUnrated => 'You haven\'t rated this yet';

  @override
  String get pollRatingBad => 'Bad';

  @override
  String get pollRatingOk => 'OK';

  @override
  String get pollRatingGood => 'Good';

  @override
  String get pollRatingGreat => 'Great';

  @override
  String get pollRatingWow => 'Wow';

  @override
  String get pollPlatformQuestion => 'Where did you watch it?';

  @override
  String get pollEmotionQuestion => 'How did it make you feel?';

  @override
  String get pollCharacterQuestion => 'Favorite character?';

  @override
  String get pollPlatformCinema => 'Cinema';

  @override
  String get pollPlatformNetflix => 'Netflix';

  @override
  String get pollPlatformDisneyPlus => 'Disney+';

  @override
  String get pollPlatformPrimeVideo => 'Prime Video';

  @override
  String get pollPlatformPirate => 'Pirated';

  @override
  String get pollPlatformOther => 'Other';

  @override
  String get pollEmotionHappy => 'Happy';

  @override
  String get pollEmotionConfusing => 'Confusing';

  @override
  String get pollEmotionSad => 'Sad';

  @override
  String get pollEmotionScary => 'Scary';

  @override
  String get pollEmotionFrustrating => 'Frustrating';

  @override
  String get pollEmotionShocking => 'Shocking';

  @override
  String get pollEmotionExciting => 'Exciting';

  @override
  String get pollEmotionBoring => 'Boring';

  @override
  String get upNextTitle => 'Up Next';

  @override
  String get upNextMyShowsLabel => 'My Shows';

  @override
  String get upNextUpcomingLabel => 'Upcoming';

  @override
  String get upNextUpcomingEmptyTitle => 'Nothing coming up';

  @override
  String get upNextUpcomingEmptySubtitle =>
      'New episodes of tracked shows and release dates for watchlisted movies will show up here.';

  @override
  String get upNextUpcomingToday => 'Today';

  @override
  String get upNextUpcomingTomorrow => 'Tomorrow';

  @override
  String get upNextUpcomingMovieTag => 'MOVIE';

  @override
  String get upNextFilterAll => 'All';

  @override
  String get upNextStatusWatching => 'Watching';

  @override
  String get upNextStatusWatchlist => 'Watchlist';

  @override
  String get upNextStatusCompleted => 'Completed';

  @override
  String get upNextFilterFavorites => 'Favorites';

  @override
  String get upNextEmptyTitle => 'Nothing here yet';

  @override
  String get upNextEmptySubtitle =>
      'Track a show and mark episodes watched — your next episode to watch will show up here.';

  @override
  String get upNextNoShowsTitle => 'No shows here';

  @override
  String upNextNoShowsSubtitle(String filter) {
    return 'Nothing matches \"$filter\".';
  }

  @override
  String upNextEpisodeProgress(int watched, int total) {
    return '$watched / $total episodes';
  }

  @override
  String upNextSeasonEpisode(int season, int episode) {
    return 'S$season | E$episode';
  }

  @override
  String upNextEpisodeFallbackName(int number) {
    return 'Episode $number';
  }

  @override
  String upNextWatchedCount(int watched, int total) {
    return '$watched / $total watched';
  }

  @override
  String upNextAllCaughtUpSnackbar(String name) {
    return '🎉 All caught up on $name!';
  }

  @override
  String get upNextMarkWatched => 'Watched';

  @override
  String get upNextAllCaughtUp => 'All caught up';

  @override
  String get upNextNewEpisodeToday => 'New episode today';

  @override
  String upNextNextEpisodeOn(String date) {
    return 'Next episode $date';
  }

  @override
  String get upNextPremiereTag => 'PREMIERE';

  @override
  String get upNextNewBadge => 'NEW';

  @override
  String get upNextAllCaughtUpEmptyTitle => 'All caught up';

  @override
  String get upNextAllCaughtUpEmptySubtitle =>
      'No new episodes to watch right now — check the Upcoming tab for what\'s coming next.';

  @override
  String get upNextSwipeStopLabel => 'Stop';

  @override
  String get upNextStopWatchingTitle => 'Stop watching this show?';

  @override
  String upNextStopWatchingContent(String name) {
    return '\"$name\" will be removed from your list along with its watch history.';
  }

  @override
  String get upNextStopWatchingConfirm => 'Stop watching';

  @override
  String get upNextStopWatchingCancel => 'Never mind';

  @override
  String get detailCastTitle => 'Cast';

  @override
  String get detailWhereToWatch => 'Where to Watch';

  @override
  String get detailReviewsTitle => 'Reviews';

  @override
  String get detailReviewsSubtitle => 'from the community';

  @override
  String get detailShowLess => 'Show less';

  @override
  String get detailReadMore => 'Read more';

  @override
  String get detailCouldNotOpenTrailer => 'Could not open the trailer.';

  @override
  String get detailWatchTrailer => 'Watch Trailer';

  @override
  String get discoverLoadErrorTitle => 'Couldn\'t load titles';

  @override
  String get discoverLoadErrorSubtitle =>
      'Check your connection and pull to refresh.';

  @override
  String get discoverEmptyTitle => 'Nothing here';

  @override
  String discoverEmptySubtitle(String genre) {
    return 'No $genre titles found.';
  }

  @override
  String get socialFollowing => 'Following';

  @override
  String get socialFollow => 'Follow';

  @override
  String get socialDefaultUserName => 'WatchVerse user';

  @override
  String get commentWCommentsLabel => 'Comments';

  @override
  String get commentWSpoilersHint => 'May contain spoilers';

  @override
  String get commentWDelete => 'Delete';

  @override
  String get commentWReport => 'Report';

  @override
  String get commentWBlockUser => 'Block user';

  @override
  String get commentWLike => 'Like';

  @override
  String get commentWReportedSnackbar => 'Reported. Thanks for flagging.';

  @override
  String get commentWBlockedSnackbar =>
      'Blocked. Their comments are hidden and you\'ve unfollowed them.';

  @override
  String get commentWJustNow => 'now';

  @override
  String commentWMinutesAgo(int minutes) {
    return '${minutes}m';
  }

  @override
  String commentWHoursAgo(int hours) {
    return '${hours}h';
  }

  @override
  String commentWDaysAgo(int days) {
    return '${days}d';
  }

  @override
  String commentWWeeksAgo(int weeks) {
    return '${weeks}w';
  }

  @override
  String episodeSeasonEpisodeLabel(int season, int episode) {
    return 'S$season · E$episode';
  }

  @override
  String episodeRuntimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String episodeRatingStars(String rating) {
    return '★ $rating';
  }

  @override
  String get episodeNotAiredYet => 'Not aired yet';

  @override
  String get episodeOverviewTitle => 'Overview';

  @override
  String get episodeWatchedLabel => 'Watched';

  @override
  String get episodeMarkAsWatchedLabel => 'Mark as watched';

  @override
  String get episodeYourRatingTitle => 'Your rating';

  @override
  String get episodeYourNotesTitle => 'Your notes';

  @override
  String get episodeNotesPrivateHint => 'Private — only you can see this.';

  @override
  String get episodeNoteHint => 'Write a note about this episode…';

  @override
  String get episodeNoteSaved => 'Note saved';

  @override
  String get episodeSaveNoteButton => 'Save note';

  @override
  String get commentsAddLinkTitle => 'Add GIF / image link';

  @override
  String get commentsLinkHint => 'https://…';

  @override
  String get commentsAddAction => 'Add';

  @override
  String get commentsUploadPhoto => 'Upload photo';

  @override
  String get commentsSearchGifs => 'Search GIFs';

  @override
  String get commentsAddGifByLink => 'Add GIF / image by link';

  @override
  String commentsCouldNotPost(String error) {
    return 'Could not post: $error';
  }

  @override
  String get commentsTitle => 'Comments';

  @override
  String get commentsAddCommentHint => 'Add a comment…';

  @override
  String get commentsSignInHint => 'Sign in to join the conversation.';

  @override
  String get commentsEmptyTitle => 'No comments yet';

  @override
  String get commentsEmptySubtitle => 'Be the first to share what you thought.';

  @override
  String get pubProfileFavoriteFilms => 'Favorite Films';

  @override
  String get pubProfileWatchedMovies => 'Watched Movies';

  @override
  String get pubProfileShows => 'Shows';

  @override
  String get pubProfileLists => 'Lists';

  @override
  String get pubProfileDefaultUserName => 'WatchVerse user';

  @override
  String get pubProfileMemberLabel => 'WatchVerse member';

  @override
  String get pubProfileFilms => 'Films';

  @override
  String get pubProfileFollowers => 'Followers';

  @override
  String get pubProfileFollowing => 'Following';

  @override
  String get pubProfileAddedToList => 'Added to your list';

  @override
  String get searchFilterAll => 'Movies & TV';

  @override
  String get searchFilterMovies => 'Movies';

  @override
  String get searchFilterTv => 'TV Shows';

  @override
  String get searchFilterPeople => 'People';

  @override
  String searchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHintPeople => 'Search people by name…';

  @override
  String get searchHintTitles => 'Search movies & TV shows…';

  @override
  String get searchFindFriendsTitle => 'Find friends';

  @override
  String get searchFindFriendsSubtitle =>
      'Search people by name and follow them to see what they watch.';

  @override
  String get searchFindNextWatchTitle => 'Find your next watch';

  @override
  String get searchFindNextWatchSubtitle =>
      'Search across movies and TV shows.';

  @override
  String get searchNoOneFoundTitle => 'No one found';

  @override
  String searchNoUsersMatched(String query) {
    return 'No users matched \"$query\".\nNames are case-sensitive for now.';
  }

  @override
  String get searchNoResultsTitle => 'No results';

  @override
  String searchNothingMatched(String query) {
    return 'Nothing matched \"$query\".';
  }

  @override
  String get homeAppTitle => 'WatchVerse';

  @override
  String get homeGuestLabel => 'Browsing as guest';

  @override
  String get homeMyLists => 'My Lists';

  @override
  String get homeFriendsActivity => 'Friends\' Activity';

  @override
  String get homeWatchHistory => 'Watch History';

  @override
  String get homeWatchPolls => 'Watch Polls';

  @override
  String get homeSettingsLabel => 'Settings';

  @override
  String get homeSignOut => 'Sign Out';

  @override
  String get homeTabMovies => 'Movies';

  @override
  String get homeTabTvShows => 'TV Shows';

  @override
  String get homeTrendingThisWeek => 'Trending This Week';

  @override
  String get homeComingSoon => 'Coming Soon';

  @override
  String get homePopular => 'Popular';

  @override
  String get homeTopRated => 'Top Rated';

  @override
  String get homeAiringToday => 'Airing Today';

  @override
  String get homeOnTheAir => 'On The Air';

  @override
  String get homePopularShows => 'Popular Shows';

  @override
  String get homeFriendsAlsoWatched => 'Your Friends Also Watched';

  @override
  String get statsSeeDetails => 'See details';

  @override
  String get statsScreenTitle => 'Watch Statistics';

  @override
  String get statsTypeBreakdownTitle => 'Movies vs Shows';

  @override
  String get statsGenreBreakdownTitle => 'Time by genre';

  @override
  String get statsOtherGenres => 'Other';

  @override
  String get statsWeeklyTitle => 'Last 8 weeks';

  @override
  String get statsThisWeek => 'This week';

  @override
  String get statsWeekdayTitle => 'By day of week';

  @override
  String get statsDayMon => 'Mon';

  @override
  String get statsDayTue => 'Tue';

  @override
  String get statsDayWed => 'Wed';

  @override
  String get statsDayThu => 'Thu';

  @override
  String get statsDayFri => 'Fri';

  @override
  String get statsDaySat => 'Sat';

  @override
  String get statsDaySun => 'Sun';

  @override
  String get statsEmptyMessage =>
      'Watch a few movies or shows to see your stats here.';

  @override
  String get quickAddWatch => 'Watch';

  @override
  String get quickAddLike => 'Like';

  @override
  String get quickAddWatchlist => 'Watchlist';

  @override
  String get quickAddTrack => 'Track';

  @override
  String get quickAddRate => 'Rate';

  @override
  String get quickAddReviewOrLog => 'Review or log';

  @override
  String get quickAddAddToList => 'Add to lists';

  @override
  String quickAddGoTo(String title) {
    return 'Go to $title';
  }

  @override
  String homeBecauseYouWatched(String title) {
    return 'Because you watched $title';
  }

  @override
  String get listDetailRenameTitle => 'Rename list';

  @override
  String get listDetailDeleteTitle => 'Delete list?';

  @override
  String get listDetailDeleteContent => 'This permanently deletes the list.';

  @override
  String get listDetailDeleteConfirm => 'Delete';

  @override
  String get listDetailRenameMenuItem => 'Rename';

  @override
  String get listDetailDeleteMenuItem => 'Delete list';

  @override
  String get listDetailMakePublicMenuItem => 'Make public';

  @override
  String get listDetailMakePrivateMenuItem => 'Make private';

  @override
  String get listDetailMadePublic => 'List is now public';

  @override
  String get listDetailMadePrivate => 'List is now private';

  @override
  String get listDetailFollow => 'Follow';

  @override
  String get listDetailFollowing => 'Following';

  @override
  String get listDetailEmptyTitle => 'Empty list';

  @override
  String get listDetailEmptySubtitle =>
      'Open any movie or show and tap \"Add to list\".';

  @override
  String get personKnownForTitle => 'Known For';

  @override
  String get personNoCredits => 'No credits found.';

  @override
  String get personBiographyTitle => 'Biography';

  @override
  String get personShowLess => 'Show less';

  @override
  String get personReadMore => 'Read more';

  @override
  String get listsNewListTitle => 'New list';

  @override
  String get listsNewListHint => 'e.g. Top 10 of all time';

  @override
  String get listsCreateAction => 'Create';

  @override
  String get listsTitle => 'My Lists';

  @override
  String get listsSignInTitle => 'Sign in to create lists';

  @override
  String get listsSignInSubtitle =>
      'Curate your own collections like \"Watch in 2026\".';

  @override
  String get listsEmptyTitle => 'No lists yet';

  @override
  String get listsEmptySubtitle => 'Tap + to create your first list.';

  @override
  String get listsUntitled => 'Untitled';

  @override
  String get listsTabMine => 'Mine';

  @override
  String get listsTabFollowing => 'Following';

  @override
  String get listsFollowingEmptyTitle => 'Not following any lists yet';

  @override
  String get listsFollowingEmptySubtitle =>
      'Public lists you follow from other users will show up here.';

  @override
  String listsFollowingByLabel(String name) {
    return 'by $name';
  }

  @override
  String get listsTitleSingular => 'title';

  @override
  String get listsTitlePlural => 'titles';

  @override
  String get listsCardEmptySubtitle =>
      'Empty — add titles from any movie or show.';

  @override
  String get mediaTypeTv => 'TV';

  @override
  String get mediaTypeMovie => 'Movie';

  @override
  String get addToListTitle => 'Add to list';

  @override
  String get addToListNewListButton => 'New list';

  @override
  String get addToListSignInMessage => 'Sign in to create lists.';

  @override
  String get addToListEmptyMessage =>
      'No lists yet — tap \"New list\" to make one.';

  @override
  String get addToListUntitled => 'Untitled';

  @override
  String get addToListTitleSingular => 'title';

  @override
  String get addToListTitlePlural => 'titles';

  @override
  String get addToListCreateTitle => 'New list';

  @override
  String get addToListCreateHint => 'e.g. Watch in 2026';

  @override
  String get addToListCreateAction => 'Create';

  @override
  String get historyTitle => 'Watch History';

  @override
  String historyWatchedRating(String rating) {
    return 'Watched · ★ $rating';
  }

  @override
  String get historyWatchedLabel => 'Watched';

  @override
  String historyFinishedSeason(int season, int count) {
    return 'Finished Season $season · $count episodes';
  }

  @override
  String historyEpisodeLine(int season, int episode, String episodeName) {
    return 'S$season E$episode  $episodeName';
  }

  @override
  String get historyEmptyTitle => 'No history yet';

  @override
  String get historyEmptySubtitle =>
      'Movies and episodes you mark as watched will show up here.';

  @override
  String get historyAgoNow => 'now';

  @override
  String historyAgoMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String historyAgoHours(int hours) {
    return '${hours}h';
  }

  @override
  String historyAgoDays(int days) {
    return '${days}d';
  }

  @override
  String historyAgoWeeks(int weeks) {
    return '${weeks}w';
  }

  @override
  String get watchlistTitle => 'My Movies';

  @override
  String get watchlistCategoryToWatch => 'To Watch';

  @override
  String get watchlistCategoryWatched => 'Watched';

  @override
  String get watchlistCategoryFavorites => 'Favorites';

  @override
  String watchlistEmptyMessage(String category) {
    return 'No movies in \"$category\" yet.';
  }

  @override
  String get watchlistUntitled => 'Untitled';

  @override
  String watchlistYourRating(String rating) {
    return 'Your rating: $rating';
  }

  @override
  String watchlistReleaseDate(String date) {
    return 'Release: $date';
  }

  @override
  String get gifPickerTitle => 'Pick a GIF';

  @override
  String get gifSearchHint => 'Search GIFs…';

  @override
  String get gifPoweredBy => 'Powered by GIPHY';

  @override
  String get gifLoadErrorTitle => 'Couldn\'t load GIFs';

  @override
  String get gifLoadErrorSubtitle => 'Check your connection and try again.';

  @override
  String get gifEmptyTitle => 'No GIFs found';

  @override
  String get gifEmptySubtitle => 'Try a different search.';

  @override
  String get friendsActivityTitle => 'Friends\' Activity';

  @override
  String get friendsNoFriendsTitle => 'No friends yet';

  @override
  String get friendsNoFriendsSubtitle =>
      'Follow people from Find Friends to see what they watch.';

  @override
  String get friendsQuietTitle => 'Quiet for now';

  @override
  String get friendsQuietSubtitle => 'Your friends have no recent activity.';

  @override
  String get friendsSomeoneFallback => 'Someone';

  @override
  String friendsActionWatchedMovie(String title) {
    return 'watched $title';
  }

  @override
  String friendsActionFinishedSeason(int season, String show) {
    return 'finished Season $season of $show';
  }

  @override
  String friendsActionWatchedEpisode(int season, int episode, String show) {
    return 'watched S$season E$episode of $show';
  }

  @override
  String get friendsAgoNow => 'now';

  @override
  String friendsAgoMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String friendsAgoHours(int hours) {
    return '${hours}h';
  }

  @override
  String friendsAgoDays(int days) {
    return '${days}d';
  }

  @override
  String friendsAgoWeeks(int weeks) {
    return '${weeks}w';
  }

  @override
  String get blockedTitle => 'Blocked Users';

  @override
  String get blockedDefaultUserName => 'WatchVerse user';

  @override
  String get blockedUnblockButton => 'Unblock';

  @override
  String get blockedEmptyTitle => 'No blocked users';

  @override
  String get blockedEmptySubtitle => 'People you block will appear here.';

  @override
  String get watchPollsTitle => 'Watch Polls';

  @override
  String get watchPollDefaultTitle => 'What should we watch?';

  @override
  String get watchPollClosedLabel => 'CLOSED';

  @override
  String watchPollVoteCountSingular(String count) {
    return '$count vote';
  }

  @override
  String watchPollVoteCountPlural(String count) {
    return '$count votes';
  }

  @override
  String get watchPollsEmptyTitle => 'No polls yet';

  @override
  String get watchPollsEmptySubtitle =>
      'Start a poll to let friends vote on what to watch next.';

  @override
  String get createWatchPollTitle => 'New Watch Poll';

  @override
  String get watchPollTitleHint => 'Poll title (optional)';

  @override
  String watchPollOptionsLabel(int count, int max) {
    return 'Options ($count/$max)';
  }

  @override
  String get watchPollSearchHint => 'Search movies or shows to add';

  @override
  String get watchPollInviteLabel => 'Invite friends';

  @override
  String get watchPollInviteSubtitle =>
      'Optional — anyone invited can vote. You can also just create it for yourself.';

  @override
  String get watchPollNoFriendsYet =>
      'Follow some friends to invite them to a poll.';

  @override
  String get watchPollCreateAction => 'Create Poll';

  @override
  String get watchPollCloseTitle => 'Close this poll?';

  @override
  String get watchPollCloseContent =>
      'This locks in the current standings — no one will be able to vote after this.';

  @override
  String get watchPollCloseConfirm => 'Close poll';

  @override
  String get watchPollCloseMenuItem => 'Close poll';

  @override
  String get watchPollDeleteTitle => 'Delete poll?';

  @override
  String get watchPollDeleteContent =>
      'This removes the poll for everyone invited.';

  @override
  String get watchPollDeleteConfirm => 'Delete';

  @override
  String get watchPollDeleteMenuItem => 'Delete poll';

  @override
  String get watchPollNotFound => 'This poll no longer exists.';

  @override
  String get watchPollClosedBanner =>
      'This poll is closed — here\'s how it landed.';

  @override
  String watchPollOptionVotesSingular(String count) {
    return '$count vote';
  }

  @override
  String watchPollOptionVotesPlural(String count) {
    return '$count votes';
  }

  @override
  String get homeWatchVersePro => 'WatchVerse Pro';

  @override
  String get proSheetTitle => 'WatchVerse Pro';

  @override
  String get proSheetSubtitle => 'Unlock the full WatchVerse experience';

  @override
  String get proFeatureStats => 'Advanced watch stats & charts';

  @override
  String get proFeatureLists => 'Unlimited custom lists';

  @override
  String get proFeatureProfile => 'Exclusive profile themes';

  @override
  String get proFeatureGame => 'Daily movie guessing game';

  @override
  String get proTierPro => 'Pro';

  @override
  String get proTierPatron => 'Patron';

  @override
  String get proFeatureEverythingInPro => 'Everything in Pro, plus:';

  @override
  String get proFeatureBadge => 'Patron badge on your profile';

  @override
  String get proFeatureEarlyAccess => 'Early access to new features';

  @override
  String get proMonthly => 'Monthly';

  @override
  String get proYearly => 'Yearly';

  @override
  String proYearlySave(String percent) {
    return 'Save $percent%';
  }

  @override
  String get proContinue => 'Continue';

  @override
  String get proRestore => 'Restore purchases';

  @override
  String get proRestoreSuccess => 'Subscription restored!';

  @override
  String get proRestoreFailure =>
      'No previous purchase found for this Apple ID';

  @override
  String get proPurchaseFailure => 'Purchase failed — please try again';

  @override
  String get proNotConfigured => 'Pro isn\'t available yet — check back soon';

  @override
  String get proActiveBadge => 'Your WatchVerse subscription is active';

  @override
  String get proSignInToContinue => 'Sign In to Continue';

  @override
  String get proSignInRequired =>
      'Sign in or create an account first to subscribe.';

  @override
  String get proListLimitReached =>
      'Free accounts get 3 custom lists — upgrade to WatchVerse Pro for unlimited lists.';

  @override
  String get proUnlockStats => 'Unlock with Pro';

  @override
  String get proUnlockProfileTheme => 'Patron theme';

  @override
  String get proExporting => 'Preparing your export…';

  @override
  String get proExportAction => 'Export my data (CSV)';

  @override
  String get importDataAction => 'Import from Letterboxd or IMDb';

  @override
  String get importTitle => 'Import data';

  @override
  String get importIntro =>
      'Bring your history over from Letterboxd or IMDb. Nothing already in WatchVerse is overwritten — your existing ratings and watched films are kept, and importing the same file again won\'t create duplicates.';

  @override
  String get importLetterboxdHeading => 'Letterboxd';

  @override
  String get importLetterboxdSteps =>
      'On letterboxd.com, go to Settings → Import & Export → Export Your Data. Pick the .zip you get as is — or just its watched, ratings, diary and watchlist CSV files.';

  @override
  String get importImdbHeading => 'IMDb';

  @override
  String get importImdbSteps =>
      'On imdb.com, open Your Ratings (and your Watchlist) and choose Export from the ⋯ menu. When it\'s ready, download the CSV from the Exports page.';

  @override
  String get importWhatHappens =>
      'Watched and rated films are marked watched with their original dates, Letterboxd diary entries are kept, and watchlist films go to your watchlist. TV series from IMDb are added to My Shows without marking any episodes.';

  @override
  String get importPickFiles => 'Choose files';

  @override
  String get importPickHint => 'You can pick several files at once.';

  @override
  String get importReading => 'Reading files…';

  @override
  String importProgress(String done, String total) {
    return 'Matching titles… $done / $total';
  }

  @override
  String get importCancelling => 'Stopping…';

  @override
  String get importNothingFound =>
      'No Letterboxd or IMDb data found in those files.';

  @override
  String importUnrecognizedFiles(String files) {
    return 'Skipped (not a Letterboxd or IMDb export): $files';
  }

  @override
  String get importDoneTitle => 'Import complete';

  @override
  String get importCancelledNote =>
      'Import stopped. Everything matched so far is saved — import again anytime to finish; nothing will be duplicated.';

  @override
  String get importSummaryWatched => 'Films marked watched';

  @override
  String get importSummaryRatings => 'Ratings';

  @override
  String get importSummaryWatchlist => 'Added to watchlist';

  @override
  String get importSummaryShows => 'Shows added to My Shows';

  @override
  String get importSummaryDiary => 'Diary entries';

  @override
  String get importSummaryExisting => 'Already in your library';

  @override
  String get importSummarySkipped => 'Skipped rows (episodes, games, invalid)';

  @override
  String get importSummaryUnmatched => 'Not matched';

  @override
  String get importViewUnmatched => 'View unmatched titles';

  @override
  String get importUnmatchedHint =>
      'These couldn\'t be matched confidently. Search for them to add them by hand.';

  @override
  String get importLookupFailed =>
      'Lookup failed — importing again may fix this';

  @override
  String get importDone => 'Done';

  @override
  String get importMore => 'Import more';

  @override
  String importError(String error) {
    return 'Import failed: $error';
  }

  @override
  String get importSignInPrompt =>
      'Sign in to import your Letterboxd or IMDb history.';

  @override
  String get proLegalFooter =>
      'By subscribing you agree to our Terms of Service and Privacy Policy.';

  @override
  String get proSubscriptionTerms =>
      'Payment is charged to your Apple ID account at confirmation of purchase. Subscriptions renew automatically unless auto-renew is turned off at least 24 hours before the end of the current period. Manage or cancel anytime in Settings > [your name] > Subscriptions on your device.';

  @override
  String get dailyGameTitle => 'Daily Movie Game';

  @override
  String get dailyGameSearchHint => 'Search for a movie…';

  @override
  String dailyGameGuessesLeft(String count) {
    return '$count guesses left';
  }

  @override
  String get dailyGameClueDirector => 'Director';

  @override
  String get dailyGameClueStudio => 'Studio';

  @override
  String get dailyGameClueYear => 'Year';

  @override
  String get dailyGameClueRevenue => 'Box Office';

  @override
  String get dailyGameClueRating => 'Rating';

  @override
  String get dailyGameClueCertification => 'Rated';

  @override
  String get dailyGameClueCast => 'Cast';

  @override
  String get dailyGameClueGenres => 'Genres';

  @override
  String get dailyGameHintUnlocked => 'Hint unlocked!';

  @override
  String get dailyGameShowHint => 'Show hint';

  @override
  String get dailyGameWinTitle => 'You got it!';

  @override
  String get dailyGameLoseTitle => 'Out of guesses';

  @override
  String get dailyGameShareResult => 'Share result';

  @override
  String get dailyGamePlayAgainTomorrow => 'Come back tomorrow for a new movie';

  @override
  String get dailyGameNoPool =>
      'Today\'s puzzle isn\'t ready yet — check back soon';

  @override
  String get dailyGameRetry => 'Try again';

  @override
  String get dailyGameSignInPrompt => 'Sign in to play the daily movie game.';

  @override
  String get dailyGameGuessedAlready => 'Already guessed';

  @override
  String get dailyGamePickAnotherDay => 'Pick a day';

  @override
  String get pollSignInToVote => 'Sign in to vote.';

  @override
  String get tvSeasonLoadFailed => 'Couldn\'t load this season\'s episodes.';

  @override
  String get discoverLoadMoreFailed => 'Couldn\'t load more.';

  @override
  String get retryAction => 'Retry';

  @override
  String get patronBadgeLabel => 'Patron';

  @override
  String get dailyGameToday => 'Today';

  @override
  String dailyGamePuzzleFor(String date) {
    return 'Puzzle for $date';
  }

  @override
  String get dailyGameHowToPlay => 'How to play';

  @override
  String dailyGameHowToIntro(String max) {
    return 'Find the mystery movie in $max guesses. Search for any movie and pick it — each guess shows how it compares to the mystery movie.';
  }

  @override
  String get dailyGameHowToGreen => 'Green: exact match';

  @override
  String get dailyGameHowToGold =>
      'Gold: close — shares a director, studio, cast member or genre, or the year is within 5, the rating within 0.5, or the box office within 50%';

  @override
  String get dailyGameHowToGray =>
      'Gray: no match. A \"?\" tile means the info is unknown for one of the movies.';

  @override
  String get dailyGameHowToArrows =>
      '↑ ↓: the mystery movie\'s year, box office or rating is higher / lower than your guess';

  @override
  String get dailyGameHowToShared =>
      'For cast, genres, studio and director, a gold tile shows what the two movies share.';

  @override
  String dailyGameHowToHints(String first, String second) {
    return 'Stuck? Hints unlock after guess $first and $second. A new movie every day — the calendar lets you play the past week too.';
  }

  @override
  String get dailyGameGotIt => 'Got it';

  @override
  String get dailyGameHints => 'Hints';

  @override
  String dailyGameNextHint(String count) {
    return 'Next hint after guess $count';
  }

  @override
  String dailyGameHintTopBilled(String name) {
    return 'Top-billed: $name';
  }

  @override
  String get dailyGameNoResults => 'No matching movies';

  @override
  String get dailyGameSearchFailed => 'Search failed. Check your connection.';

  @override
  String dailyGameSolvedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Solved in $count guesses',
      one: 'Solved on the first guess!',
    );
    return '$_temp0';
  }

  @override
  String get dailyGameAnswerWas => 'The movie was';

  @override
  String get dailyGameViewMovie => 'View movie';

  @override
  String get dailyGameGuessFailed => 'Couldn\'t load that movie. Try again.';

  @override
  String get dailyGameRowFailed => 'Couldn\'t load this guess';

  @override
  String get gamesHubTitle => 'Games';

  @override
  String get gamesHubDailyMovieSubtitle =>
      'Guess the mystery movie from clues. New every day.';

  @override
  String get gamesHubStatusNotPlayed => 'Not played today';

  @override
  String get gamesHubStatusInProgress => 'In progress';

  @override
  String get gamesHubStatusSolved => 'Solved today';

  @override
  String get gamesHubStatusMissed => 'Played today';

  @override
  String get actorGuessTitle => 'Who\'s the Actor?';

  @override
  String get actorGuessHubSubtitle =>
      'Name today\'s mystery actor from six clues';

  @override
  String get actorGuessSignInPrompt => 'Sign in to play Who\'s the Actor?';

  @override
  String get actorGuessLoadError => 'Couldn\'t load today\'s actor.';

  @override
  String get actorGuessNoPool =>
      'Today\'s puzzle isn\'t ready yet — check back soon';

  @override
  String get actorGuessRetry => 'Try again';

  @override
  String get actorGuessSearchHint => 'Search for an actor or actress…';

  @override
  String get actorGuessSearchFailed => 'Search failed. Check your connection.';

  @override
  String get actorGuessNoResults => 'No actors found';

  @override
  String get actorGuessAlreadyGuessed => 'Already guessed';

  @override
  String actorGuessGuessesLeft(String count) {
    return '$count guesses left';
  }

  @override
  String actorGuessClueNumber(String number) {
    return 'Clue $number';
  }

  @override
  String get actorGuessClueOrigin => 'Career';

  @override
  String actorGuessFirstMovie(String year) {
    return 'First movie role: $year';
  }

  @override
  String actorGuessBornIn(String country) {
    return 'Born in: $country';
  }

  @override
  String get actorGuessClueDeepCuts => 'Also appeared in';

  @override
  String get actorGuessClueKnownTitles => 'Well-known titles';

  @override
  String get actorGuessClueCharacter => 'Famous role';

  @override
  String actorGuessCharacterIn(String character, String title) {
    return '$character in $title';
  }

  @override
  String get actorGuessClueTopTitles => 'Best known for';

  @override
  String get actorGuessCluePhoto => 'Their photo';

  @override
  String get actorGuessNextClueHint => 'Each wrong guess reveals another clue';

  @override
  String get actorGuessYourGuesses => 'Your guesses';

  @override
  String get actorGuessWinTitle => 'You got it!';

  @override
  String actorGuessWinSubtitle(String count, String max) {
    return 'Solved in $count/$max guesses';
  }

  @override
  String get actorGuessLoseTitle => 'Out of guesses';

  @override
  String actorGuessAnswerWas(String name) {
    return 'Today\'s actor was $name';
  }

  @override
  String get actorGuessViewFilmography => 'View filmography';

  @override
  String get actorGuessShareResult => 'Share result';

  @override
  String get actorGuessComeBackTomorrow => 'Come back tomorrow for a new actor';

  @override
  String get gamesCommonMovies => 'Movies';

  @override
  String get gamesCommonTv => 'TV Shows';

  @override
  String gamesCommonPuzzleNumber(String number) {
    return 'Puzzle #$number';
  }

  @override
  String get gamesCommonShare => 'Share result';

  @override
  String get gamesCommonViewDetails => 'View details';

  @override
  String get gamesCommonComeBackTomorrow => 'A new puzzle arrives tomorrow.';

  @override
  String get gamesCommonGuestNote =>
      'Playing as a guest — sign in to save your results.';

  @override
  String get gamesCommonLoadError => 'Couldn\'t load today\'s puzzle.';

  @override
  String get gamesCommonRetry => 'Try again';

  @override
  String get gamesCommonSaveFailed =>
      'Couldn\'t save your progress. Check your connection.';

  @override
  String get gamesCommonWin => 'You got it!';

  @override
  String get gamesCommonLose => 'Not this time';

  @override
  String gamesCommonSolvedIn(String count, String total) {
    return 'Solved in $count/$total';
  }

  @override
  String gamesCommonAnswerWas(String title) {
    return 'The answer was $title';
  }

  @override
  String gamesCommonGuessesLeft(String count) {
    return '$count guesses left';
  }

  @override
  String get framesGameTitle => 'Frames';

  @override
  String get framesGameIntroMovie =>
      'Name the movie from its stills. Each wrong guess or skip reveals another frame.';

  @override
  String get framesGameIntroTv =>
      'Name the TV show from its stills. Each wrong guess or skip reveals another frame.';

  @override
  String get framesGameSearchHintMovie => 'Search for a movie…';

  @override
  String get framesGameSearchHintTv => 'Search for a TV show…';

  @override
  String get framesGameSkip => 'Skip';

  @override
  String framesGameFrameLabel(String number) {
    return 'Frame $number';
  }

  @override
  String get framesGameSkipped => 'Skipped';

  @override
  String get framesGameAlreadyGuessed => 'Already guessed';

  @override
  String get framesGameNoResults => 'No matches';

  @override
  String get titleWordleTitle => 'Title Wordle';

  @override
  String get titleWordleIntroMovie =>
      'Guess today\'s movie title in 6 tries. Type letters only — word breaks are already shown.';

  @override
  String get titleWordleIntroTv =>
      'Guess today\'s TV show title in 6 tries. Type letters only — word breaks are already shown.';

  @override
  String titleWordleLetterCount(String count) {
    return '$count letters';
  }

  @override
  String get titleWordleNotEnoughLetters => 'Not enough letters';

  @override
  String get titleWordleSubmit => 'Submit guess';

  @override
  String get titleWordleDelete => 'Delete letter';

  @override
  String get gamesHubFramesSubtitle =>
      'Guess the movie or show from its stills';

  @override
  String get gamesHubTitleWordleSubtitle =>
      'Guess the movie or show title, Wordle style';

  @override
  String get higherLowerTitle => 'Higher or Lower';

  @override
  String get higherLowerIntro =>
      'Is the next title higher or lower? Keep guessing right to build your score.';

  @override
  String get higherLowerPickCategory => 'Pick a category';

  @override
  String get higherLowerCategoryMovieRating => 'Movie rating';

  @override
  String get higherLowerCategoryBoxOffice => 'Box office';

  @override
  String get higherLowerCategoryTvRating => 'TV show rating';

  @override
  String get higherLowerCategoryRatingDesc => 'TMDB user score';

  @override
  String get higherLowerCategoryBoxOfficeDesc => 'Worldwide gross';

  @override
  String higherLowerBest(int score) {
    return 'Best: $score';
  }

  @override
  String higherLowerScore(int score) {
    return 'Score: $score';
  }

  @override
  String higherLowerPrompt(String title) {
    return 'Higher or lower than $title?';
  }

  @override
  String get higherLowerHigher => 'Higher';

  @override
  String get higherLowerLower => 'Lower';

  @override
  String get higherLowerCorrect => 'Correct!';

  @override
  String get higherLowerWrong => 'Wrong!';

  @override
  String get higherLowerGameOver => 'Game over';

  @override
  String higherLowerFinalScore(int score) {
    return 'You scored $score';
  }

  @override
  String get higherLowerNewBest => 'New personal best!';

  @override
  String get higherLowerPlayAgain => 'Play again';

  @override
  String get higherLowerChangeCategory => 'Change category';

  @override
  String get higherLowerTiesNote => 'Ties count as correct.';

  @override
  String get plotGameTitle => 'Plot';

  @override
  String get plotGameModeMovie => 'Movie';

  @override
  String get plotGameModeTv => 'TV';

  @override
  String get plotGameIntro =>
      'Guess today\'s title from its plot. Names are hidden — every miss or skip reveals another clue.';

  @override
  String get plotGameSearchMovieHint => 'Guess the movie…';

  @override
  String get plotGameSearchTvHint => 'Guess the show…';

  @override
  String get plotGameSkip => 'Skip';

  @override
  String get plotGameSkipped => 'Skipped';

  @override
  String plotGameAttemptsLeft(int count) {
    return '$count guesses left';
  }

  @override
  String get plotGameCluePlot => 'Plot';

  @override
  String get plotGameClueMorePlot => 'More plot';

  @override
  String get plotGameClueYear => 'Year';

  @override
  String get plotGameClueGenres => 'Genres';

  @override
  String get plotGameClueActor => 'Top-billed actor';

  @override
  String get plotGameClueSecondActor => 'Also starring';

  @override
  String get plotGameClueTagline => 'Tagline';

  @override
  String get plotGameNextClueLocked => 'Unlocks after a miss';

  @override
  String get plotGameAlreadyGuessed => 'Already guessed';

  @override
  String get plotGameNoResults => 'No matches';

  @override
  String get plotGameWinTitle => 'You got it!';

  @override
  String get plotGameLoseTitle => 'Out of guesses';

  @override
  String plotGameSolvedIn(int count, int max) {
    return 'Solved in $count/$max';
  }

  @override
  String get plotGameViewDetails => 'View details';

  @override
  String get plotGameShare => 'Share result';

  @override
  String get plotGameComeBack => 'Come back tomorrow for a new plot.';

  @override
  String get plotGameSignInPrompt => 'Sign in to play the daily Plot game.';

  @override
  String get plotGameNoPuzzle =>
      'Today\'s puzzle isn\'t available yet — check back soon.';

  @override
  String get gamesHubPlotSubtitle =>
      'Guess the movie or show from its redacted plot';

  @override
  String get gamesHubHigherLowerSubtitle =>
      'Which one is rated higher? Endless rounds';

  @override
  String get yirTitle => 'Year in Review';

  @override
  String yirEntryTitle(String year) {
    return 'Your $year in review';
  }

  @override
  String get yirEntrySubtitle => 'Films, shows and hours, recapped';

  @override
  String yirHeroSoFar(String year) {
    return 'Your $year so far';
  }

  @override
  String yirHeroFull(String year) {
    return 'Your $year in film & TV';
  }

  @override
  String yirEmptyTitle(String year) {
    return 'Nothing logged in $year';
  }

  @override
  String yirEmptyBody(String year) {
    return 'Films you log and episodes you mark as watched during $year will show up here.';
  }

  @override
  String get yirFilmWatches => 'film watches';

  @override
  String yirDistinctFilms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count different films',
      one: '1 different film',
    );
    return '$_temp0';
  }

  @override
  String get yirEpisodes => 'episodes';

  @override
  String yirShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'across $count shows',
      one: 'across 1 show',
    );
    return '$_temp0';
  }

  @override
  String get yirHoursWatched => 'hours watched';

  @override
  String yirDaysEquivalent(String days) {
    return 'That\'s about $days days of screen time';
  }

  @override
  String yirRuntimeUnknownNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count watches have no known runtime and aren\'t in the hours.',
      one: '1 watch has no known runtime and isn\'t in the hours.',
    );
    return '$_temp0';
  }

  @override
  String yirRuntimeEstimatedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episode lengths are estimated from their show\'s average.',
      one: '1 episode length is estimated from its show\'s average.',
    );
    return '$_temp0';
  }

  @override
  String get yirTopGenres => 'Top genres';

  @override
  String get yirTopGenresCaption => 'By time watched';

  @override
  String get yirBusiestMonth => 'Busiest month';

  @override
  String yirBusiestMonthValue(String month) {
    return '$month was your busiest month';
  }

  @override
  String get yirChartMinutesCaption => 'Hours watched per month';

  @override
  String get yirChartCountCaption => 'Watches per month';

  @override
  String get yirMonthInitials => 'JFMAMJJASOND';

  @override
  String yirFavouriteDay(String day) {
    return 'Favourite day to watch: $day';
  }

  @override
  String get yirDayMonday => 'Monday';

  @override
  String get yirDayTuesday => 'Tuesday';

  @override
  String get yirDayWednesday => 'Wednesday';

  @override
  String get yirDayThursday => 'Thursday';

  @override
  String get yirDayFriday => 'Friday';

  @override
  String get yirDaySaturday => 'Saturday';

  @override
  String get yirDaySunday => 'Sunday';

  @override
  String get yirTopRated => 'Highest rated';

  @override
  String yirTopRatedCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your $count top-rated films this year',
      one: 'Your top-rated film this year',
    );
    return '$_temp0';
  }

  @override
  String get yirTopShow => 'Most watched show';

  @override
  String yirEpisodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String get yirBookends => 'First & latest';

  @override
  String get yirFirstWatch => 'First watch';

  @override
  String get yirLatestWatch => 'Latest watch';

  @override
  String yirEpisodeCode(int season, int episode) {
    return 'S$season · E$episode';
  }

  @override
  String get yirFunFacts => 'Fun facts';

  @override
  String yirFactLongest(String title, String duration) {
    return 'Longest film: $title ($duration)';
  }

  @override
  String yirFactRewatched(String title, int count) {
    return 'Most rewatched: $title, $count times';
  }

  @override
  String yirFactRepeatWatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repeat watches of films you\'d already seen this year',
      one: '1 repeat watch of a film you\'d already seen this year',
    );
    return '$_temp0';
  }

  @override
  String yirFactBusiestDay(String date, int count) {
    return 'Biggest day: $date, with $count watches';
  }

  @override
  String yirFactAverageRating(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rated films',
      one: '1 rated film',
    );
    return 'Average rating: $rating across $_temp0';
  }

  @override
  String get yirShare => 'Share';

  @override
  String yirShareText(String year) {
    return 'My $year on WatchVerse';
  }

  @override
  String get yirShareFailed => 'Couldn\'t create the image to share.';

  @override
  String get yirYearPickerTooltip => 'Choose year';

  @override
  String get streamingSettingsTile => 'My streaming services';

  @override
  String get streamingSetupTitle => 'My streaming services';

  @override
  String get streamingSetupIntro =>
      'Pick the services you subscribe to and we\'ll show what on your watchlist you can stream right now.';

  @override
  String get streamingRegionLabel => 'Region';

  @override
  String get streamingSearchHint => 'Search services';

  @override
  String streamingSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count services selected',
      one: '1 service selected',
      zero: 'No services selected',
    );
    return '$_temp0';
  }

  @override
  String get streamingNoProviders =>
      'No streaming services are listed for this region.';

  @override
  String get streamingSaveError => 'Couldn\'t save your services. Try again.';

  @override
  String get streamingJustWatchCredit => 'Streaming data by JustWatch';

  @override
  String get streamingFilterChip => 'On my services';

  @override
  String streamingChecking(int checked, int total) {
    return 'Checking $checked/$total…';
  }

  @override
  String streamingCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn\'t check $count titles',
      one: 'Couldn\'t check 1 title',
    );
    return '$_temp0';
  }

  @override
  String get streamingFilterEmpty =>
      'Nothing here is streaming on your services right now.';

  @override
  String get streamingNotSetUpTitle => 'Choose your streaming services';

  @override
  String get streamingNotSetUpBody =>
      'Tell us which services you subscribe to and we\'ll filter this list to what you can watch right now.';

  @override
  String get streamingSetUpAction => 'Choose services';

  @override
  String streamingOnYour(String services) {
    return 'On your $services';
  }

  @override
  String get settingsNotifyMovieRelease => 'Watchlist movies released today';
}
