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
  String get profileYourNameHint => 'Your name';

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
  String get profileFavoritesTitle => 'Favorites';

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
  String get movieYourRating => 'Your rating';

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
  String get upNextTitle => 'Up Next';

  @override
  String get upNextMyShowsLabel => 'My Shows';

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
    return 'S$season  E$episode';
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
  String get commentWSpoilersHint => 'Spoilers may be inside';

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
      'Blocked. You won\'t see their content.';

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
  String get episodeNoteHint => 'Write a comment about this episode…';

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
      'Episodes you mark as watched will show up here.';

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
}
