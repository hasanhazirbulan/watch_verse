// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'WatchVerse';

  @override
  String get loginSubtitle => 'Sevdiğin film ve dizileri takip et';

  @override
  String get emailHint => 'E-posta';

  @override
  String get emailRequired => 'Lütfen e-posta adresini gir';

  @override
  String get emailInvalid => 'Geçerli bir e-posta adresi gir';

  @override
  String get passwordHint => 'Şifre';

  @override
  String get passwordRequiredLogin => 'Lütfen şifreni gir';

  @override
  String get logIn => 'Giriş Yap';

  @override
  String get continueAsGuest => 'Misafir olarak devam et';

  @override
  String get noAccountPrompt => 'Hesabın yok mu?';

  @override
  String get register => 'Kayıt Ol';

  @override
  String get errorUserNotFound => 'Bu e-posta için kullanıcı bulunamadı.';

  @override
  String get errorWrongPassword => 'E-posta veya şifre hatalı.';

  @override
  String get errorGeneric => 'Bir hata oluştu.';

  @override
  String errorSignIn(String error) {
    return 'Giriş yapılamadı: $error';
  }

  @override
  String get createAccountTitle => 'Hesap oluştur';

  @override
  String get createAccountSubtitle =>
      'Takibe başlamak için WatchVerse\'e katıl';

  @override
  String get usernameHint => 'Kullanıcı adı';

  @override
  String get usernameRequired => 'Lütfen bir kullanıcı adı gir';

  @override
  String get confirmPasswordHint => 'Şifreyi onayla';

  @override
  String get passwordRequiredRegister => 'Lütfen bir şifre gir';

  @override
  String get passwordTooShort => 'En az 6 karakter olmalı';

  @override
  String get passwordsDoNotMatch => 'Şifreler eşleşmiyor';

  @override
  String get createAccountButton => 'Hesap Oluştur';

  @override
  String get alreadyHaveAccountPrompt => 'Zaten hesabın var mı?';

  @override
  String get logInLowercase => 'Giriş yap';

  @override
  String get errorWeakPassword => 'Şifre çok zayıf.';

  @override
  String get errorEmailInUse => 'Bu e-posta zaten kullanımda.';

  @override
  String errorCreateAccount(String error) {
    return 'Hesap oluşturulamadı: $error';
  }

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsAccountSection => 'Hesap';

  @override
  String get settingsAppInfoSection => 'Hakkında';

  @override
  String get settingsPrivacyPolicy => 'Gizlilik Politikası';

  @override
  String get settingsTermsOfService => 'Kullanım Koşulları';

  @override
  String get settingsNotificationsSection => 'Bildirimler';

  @override
  String get settingsNotifyEpisodeTomorrow => 'Yarın çıkan bölümler';

  @override
  String get settingsNotifyEpisodeToday => 'Bugün yayınlanan bölümler';

  @override
  String get settingsNotifyFriendActivity => 'Arkadaş aktivitesi';

  @override
  String get settingsNotifySharedWatch => 'Ortak içerik eşleşmesi';

  @override
  String settingsAppVersion(String version) {
    return 'Sürüm $version';
  }

  @override
  String get settingsDeleteAccount => 'Hesabı Sil';

  @override
  String get settingsDeleteAccountConfirmTitle =>
      'Hesabını silmek istiyor musun?';

  @override
  String get settingsDeleteAccountConfirmBody =>
      'Bu işlem geri alınamaz. Hesabın, giriş bilgilerin, kütüphanen, listelerin, günlüğün ve yorumların kalıcı olarak silinecek. App Store aboneliğin otomatik olarak iptal edilmez — cihazının abonelik ayarlarından ayrıca iptal etmelisin.';

  @override
  String get settingsDeleteAccountAction => 'Sil';

  @override
  String get settingsDeleteAccountRequiresRecentLogin =>
      'Güvenlik nedeniyle bu işlem için yakın zamanda giriş yapmış olman gerekiyor. Lütfen çıkış yapıp tekrar giriş yaparak tekrar dene.';

  @override
  String settingsDeleteAccountError(String error) {
    return 'Hesap silinemedi: $error';
  }

  @override
  String get settingsDeleteAccountIncomplete =>
      'Hesap silme işlemin başladı ama tamamlanamadı. Tamamlamak için tekrar giriş yap.';

  @override
  String get accountDeletionFinishingTitle => 'Hesap silme tamamlanıyor';

  @override
  String get accountDeletionFinishingBody =>
      'Bu hesabı silmek için daha önce yaptığın istek tamamlanmamış. Şimdi tamamlanıyor…';

  @override
  String accountDeletionResumeFailed(String error) {
    return 'Hesabın silinmesi tamamlanamadı: $error';
  }

  @override
  String get accountDeletionRetry => 'Tekrar dene';

  @override
  String get accountDeletionSignOut => 'Çıkış yap';

  @override
  String get selectAvatarTitle => 'Avatar Seç';

  @override
  String get editNameTitle => 'Adı Düzenle';

  @override
  String get enterNewNameHint => 'Yeni adı gir';

  @override
  String get cancel => 'İptal';

  @override
  String get save => 'Kaydet';

  @override
  String nameLabel(String name) {
    return 'Ad: $name';
  }

  @override
  String get noName => 'İsim Yok';

  @override
  String get nameUpdated => 'Ad başarıyla güncellendi!';

  @override
  String failedFetchUser(String error) {
    return 'Kullanıcı verileri alınamadı: $error';
  }

  @override
  String failedUpdateName(String error) {
    return 'Ad güncellenemedi: $error';
  }

  @override
  String get profilePictureUpdated => 'Profil fotoğrafı güncellendi!';

  @override
  String failedUpdateProfilePicture(String error) {
    return 'Profil fotoğrafı güncellenemedi: $error';
  }

  @override
  String get appearance => 'Görünüm';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String tvErrorLoadingShow(String error) {
    return 'Dizi yüklenemedi.\n$error';
  }

  @override
  String get tvOverviewTitle => 'Özet';

  @override
  String get tvSeasonsTitle => 'Sezonlar';

  @override
  String get tvMoreLikeThisTitle => 'Buna Benzer';

  @override
  String get tvAddToListTooltip => 'Listeye ekle';

  @override
  String get tvAddToMyShows => 'Dizilerime Ekle';

  @override
  String get tvStatusCompleted => 'Tamamlandı';

  @override
  String get tvStatusWatching => 'İzleniyor';

  @override
  String get tvInMyShows => 'Dizilerimde';

  @override
  String tvSeasonCountSingular(String count) {
    return '$count Sezon';
  }

  @override
  String tvSeasonCountPlural(String count) {
    return '$count Sezon';
  }

  @override
  String get tvMarkPreviousTitle => 'Önceki bölümler işaretlensin mi?';

  @override
  String tvMarkPreviousQuestion(String episodesPhrase) {
    return 'İleri atladın. $episodesPhrase de izlendi olarak işaretlensin mi?';
  }

  @override
  String tvEpisodeCountSingular(String count) {
    return '$count önceki bölüm';
  }

  @override
  String tvEpisodeCountPlural(String count) {
    return '$count önceki bölüm';
  }

  @override
  String get tvNo => 'Hayır';

  @override
  String get tvYesMarkAll => 'Evet, tümünü işaretle';

  @override
  String tvFinishedShow(String name) {
    return '🎉 $name dizisini bitirdin!';
  }

  @override
  String tvSeasonComplete(String season) {
    return '🎉 $season. Sezon tamamlandı!';
  }

  @override
  String get tvRemoveShowTitle => 'Dizi kaldırılsın mı?';

  @override
  String tvRemoveShowContent(String name) {
    return 'Bu işlem \"$name\" dizisini ve tüm izlenen bölüm ilerlemesini kaldırır.';
  }

  @override
  String get tvRemoveButton => 'Kaldır';

  @override
  String get tvYourProgress => 'İlerlemen';

  @override
  String tvProgressFraction(String watched, String total) {
    return '$watched / $total';
  }

  @override
  String tvPercentWatched(String percent) {
    return '%$percent izlendi';
  }

  @override
  String get tvYourRating => 'Puanın';

  @override
  String get movieYourRating => 'Puanın';

  @override
  String get movieCannotMarkUnreleased => 'Bu film henüz vizyona girmedi.';

  @override
  String get movieNotYetReleased => 'Henüz vizyona girmedi';

  @override
  String movieReleasesOn(String date) {
    return '$date tarihinde vizyona girecek';
  }

  @override
  String get tvUpNextLabel => 'SIRADAKİ';

  @override
  String tvUpNextEpisodeLabel(String season, String episode, String name) {
    return 'S$season B$episode  $name';
  }

  @override
  String tvSeasonNumberLabel(String season) {
    return 'Sezon $season';
  }

  @override
  String tvSeasonFraction(String watched, String total) {
    return '$watched/$total';
  }

  @override
  String get tvUnmarkSeason => 'Sezon işaretini kaldır';

  @override
  String get tvMarkSeasonWatched => 'Sezonu izlendi olarak işaretle';

  @override
  String get tvCannotMarkUnaired => 'Bu bölüm henüz yayınlanmadı.';

  @override
  String get tvMoreEpisodesComing => 'Daha fazla bölüm geliyor';

  @override
  String get tvMarkAllSeasonsButton => 'Tüm sezonları izlendi olarak işaretle';

  @override
  String get tvMarkAllSeasonsTitle =>
      'Tüm sezonlar izlendi olarak işaretlensin mi?';

  @override
  String tvMarkAllSeasonsQuestion(String name) {
    return '$name dizisinin yayınlanmış tüm bölümleri izlendi olarak işaretlenecek.';
  }

  @override
  String tvEpisodeNumberLabel(String number, String name) {
    return '$number. $name';
  }

  @override
  String get tvNotAired => 'Henüz yayınlanmadı';

  @override
  String tvRuntimeMinutes(String minutes) {
    return '${minutes}dk';
  }

  @override
  String profileUpdatePhotoError(String error) {
    return 'Fotoğraf güncellenemedi: $error';
  }

  @override
  String get profileEditNameTitle => 'Adı düzenle';

  @override
  String get profileEditProfileTitle => 'Profili Düzenle';

  @override
  String get profileYourNameHint => 'Adın';

  @override
  String get profileCharacterQuoteHint => 'Bir film/dizi karakteri olsaydım...';

  @override
  String get profileAvatarBackgroundLabel => 'Profil arka planı';

  @override
  String profileSaveNameError(String error) {
    return 'İsim kaydedilemedi: $error';
  }

  @override
  String get profileSignInPrompt => 'Profilini görmek için giriş yap.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileAddYourName => 'Adını ekle';

  @override
  String get profileFriendsActivity => 'Arkadaş Etkinliği';

  @override
  String get profileSettings => 'Ayarlar';

  @override
  String get profileBlockedUsers => 'Engellenen Kullanıcılar';

  @override
  String get profileSignOut => 'Çıkış Yap';

  @override
  String profileSignOutFailed(String error) {
    return 'Çıkış başarısız oldu: $error';
  }

  @override
  String get profileFollowers => 'Takipçiler';

  @override
  String get profileFollowing => 'Takip Edilenler';

  @override
  String get profileFilms => 'Filmler';

  @override
  String get profileMovieTimeSpent => 'Film süresi';

  @override
  String get profileShowTimeSpent => 'Dizi süresi';

  @override
  String profileDurationCompact(String hours, String minutes) {
    return '${hours}sa ${minutes}dk';
  }

  @override
  String profileDurationDaysHours(String days, String hours) {
    return '${days}g ${hours}sa';
  }

  @override
  String profileDurationMonthsDaysHours(
    String months,
    String days,
    String hours,
  ) {
    return '${months}ay ${days}g ${hours}sa';
  }

  @override
  String get watchedMoviesSortTooltip => 'Sırala';

  @override
  String get watchedMoviesSortByDate => 'Eklenme tarihi';

  @override
  String get watchedMoviesSortByRating => 'Puan (yüksekten düşüğe)';

  @override
  String get profileShows => 'Diziler';

  @override
  String get profileEpisodes => 'Bölümler';

  @override
  String profileYourYear(String year) {
    return '$year Yılın';
  }

  @override
  String get profileWatched => 'İzlendi';

  @override
  String get profileFavoritesTitle => 'En Sevdiğin 3 Film';

  @override
  String get profileFavoritesEmptyHint =>
      'Buraya eklemek için bir filmin sayfasındaki ♥ butonuna dokun';

  @override
  String get profileShowcasePickerTitle => 'Vitrine ekle';

  @override
  String get profileShowcaseRemove => 'Vitrinden kaldır';

  @override
  String get profileMoviesTitle => 'Filmler';

  @override
  String get profileSeriesTitle => 'Diziler';

  @override
  String get profileSeeAll => 'Tümünü gör';

  @override
  String get profileMovieLabel => 'Film';

  @override
  String profileSeasonLabel(String season) {
    return 'Sezon $season';
  }

  @override
  String profileEpisodeLabel(String season, String episode) {
    return 'S$season · B$episode';
  }

  @override
  String get followListEmptyMessage => 'Henüz kimse yok.';

  @override
  String get homeLoadFailedTitle => 'İçerikler yüklenemedi';

  @override
  String get homeLoadFailedBody => 'Bağlantını kontrol edip tekrar dene.';

  @override
  String get homeRetryAction => 'Tekrar dene';

  @override
  String get homeFindFriendsBannerTitle => 'WatchVerse\'de arkadaş bul';

  @override
  String get homeFindFriendsBannerBody => 'Takip et, ne izlediklerini gör.';

  @override
  String get homeFindFriendsBannerAction => 'Bul';

  @override
  String asyncErrorMessage(String error) {
    return 'Bir şeyler ters gitti.\n$error';
  }

  @override
  String get movieAddToList => 'Listeye ekle';

  @override
  String get movieTypeLabel => 'Film';

  @override
  String get movieOverview => 'Özet';

  @override
  String get movieMoreLikeThis => 'Buna Benzer';

  @override
  String get movieToWatch => 'İzlenecek';

  @override
  String get movieWatched => 'İzlendi';

  @override
  String get movieYourDiary => 'Günlüğün';

  @override
  String get movieLogAction => 'Kaydet';

  @override
  String get movieLogAgainAction => 'Tekrar kaydet';

  @override
  String get movieDiaryEmpty =>
      'Henüz kayıt yok. Günlüğüne başlamak için bir izleme kaydet — tekrar izlemelerini kendi tarihleriyle kaydedebilirsin.';

  @override
  String movieLogSheetTitle(String action, String title) {
    return '$action \"$title\"';
  }

  @override
  String get movieRewatchAction => 'Tekrar izle';

  @override
  String get movieWatchedOn => 'İzlenme tarihi';

  @override
  String get movieDiaryNote => 'Günlük notu';

  @override
  String get movieDiaryNoteHint => 'Ne düşündün?';

  @override
  String get movieSaveRewatch => 'Tekrar izlemeyi kaydet';

  @override
  String get movieSaveToDiary => 'Günlüğe kaydet';

  @override
  String get pollSectionTitle => 'Nasıldı?';

  @override
  String get pollRatingCommunityMovie => 'Bu filmi herkes nasıl puanladı';

  @override
  String get pollRatingCommunityEpisode => 'Bu bölümü herkes nasıl puanladı';

  @override
  String get pollRatingUnrated => 'Bunu henüz puanlamadın';

  @override
  String get pollRatingBad => 'Kötü';

  @override
  String get pollRatingOk => 'İdare Eder';

  @override
  String get pollRatingGood => 'İyi';

  @override
  String get pollRatingGreat => 'Harika';

  @override
  String get pollRatingWow => 'Vay Canına';

  @override
  String get pollPlatformQuestion => 'Nereden izledin?';

  @override
  String get pollEmotionQuestion => 'Sana ne hissettirdi?';

  @override
  String get pollCharacterQuestion => 'Favori karakterin?';

  @override
  String get pollPlatformCinema => 'Sinema';

  @override
  String get pollPlatformNetflix => 'Netflix';

  @override
  String get pollPlatformDisneyPlus => 'Disney+';

  @override
  String get pollPlatformPrimeVideo => 'Prime Video';

  @override
  String get pollPlatformPirate => 'Korsan';

  @override
  String get pollPlatformOther => 'Diğer';

  @override
  String get pollEmotionHappy => 'Mutlu';

  @override
  String get pollEmotionConfusing => 'Kafam Karıştı';

  @override
  String get pollEmotionSad => 'Üzüldüm';

  @override
  String get pollEmotionScary => 'Korktum';

  @override
  String get pollEmotionFrustrating => 'Sinir Bozucu';

  @override
  String get pollEmotionShocking => 'Şoke Oldum';

  @override
  String get pollEmotionExciting => 'Heyecanlandım';

  @override
  String get pollEmotionBoring => 'Sıkıldım';

  @override
  String get upNextTitle => 'Sırada';

  @override
  String get upNextMyShowsLabel => 'Dizilerim';

  @override
  String get upNextUpcomingLabel => 'Yaklaşan';

  @override
  String get upNextUpcomingEmptyTitle => 'Yaklaşan bir şey yok';

  @override
  String get upNextUpcomingEmptySubtitle =>
      'Takip ettiğin dizilerin yeni bölümleri ve izleme listendeki filmlerin çıkış tarihleri burada görünecek.';

  @override
  String get upNextUpcomingToday => 'Bugün';

  @override
  String get upNextUpcomingTomorrow => 'Yarın';

  @override
  String get upNextUpcomingMovieTag => 'FİLM';

  @override
  String get upNextFilterAll => 'Tümü';

  @override
  String get upNextStatusWatching => 'İzleniyor';

  @override
  String get upNextStatusWatchlist => 'İzleme Listesi';

  @override
  String get upNextStatusCompleted => 'Tamamlandı';

  @override
  String get upNextFilterFavorites => 'Favoriler';

  @override
  String get upNextEmptyTitle => 'Henüz bir şey yok';

  @override
  String get upNextEmptySubtitle =>
      'Bir diziyi takip et ve bölümleri izlendi olarak işaretle — sıradaki izleyeceğin bölüm burada görünecek.';

  @override
  String get upNextNoShowsTitle => 'Burada dizi yok';

  @override
  String upNextNoShowsSubtitle(String filter) {
    return '\"$filter\" ile eşleşen bir şey yok.';
  }

  @override
  String upNextEpisodeProgress(int watched, int total) {
    return '$watched / $total bölüm';
  }

  @override
  String upNextSeasonEpisode(int season, int episode) {
    return 'S$season | B$episode';
  }

  @override
  String upNextEpisodeFallbackName(int number) {
    return 'Bölüm $number';
  }

  @override
  String upNextWatchedCount(int watched, int total) {
    return '$watched / $total izlendi';
  }

  @override
  String upNextAllCaughtUpSnackbar(String name) {
    return '🎉 $name dizisinde güncelsin!';
  }

  @override
  String get upNextMarkWatched => 'İzlendi';

  @override
  String get upNextAllCaughtUp => 'Güncelsin';

  @override
  String get upNextNewEpisodeToday => 'Bugün yeni bölüm';

  @override
  String upNextNextEpisodeOn(String date) {
    return 'Sonraki bölüm $date';
  }

  @override
  String get upNextPremiereTag => 'İLK BÖLÜM';

  @override
  String get upNextNewBadge => 'YENİ';

  @override
  String get upNextAllCaughtUpEmptyTitle => 'Her şey güncel';

  @override
  String get upNextAllCaughtUpEmptySubtitle =>
      'İzlenecek yeni bölüm yok — sıradaki bölümler için Yaklaşan sekmesine bakabilirsin.';

  @override
  String get upNextSwipeStopLabel => 'Bırak';

  @override
  String get upNextStopWatchingTitle =>
      'Bu diziyi izlemeyi bırakmak istiyor musun?';

  @override
  String upNextStopWatchingContent(String name) {
    return '\"$name\" takip listenden ve tüm izleme geçmişinden kaldırılacak.';
  }

  @override
  String get upNextStopWatchingConfirm => 'İzlemeyi bırak';

  @override
  String get upNextStopWatchingCancel => 'Vazgeç';

  @override
  String get detailCastTitle => 'Oyuncular';

  @override
  String get detailWhereToWatch => 'Nereden İzlenir';

  @override
  String get detailReviewsTitle => 'Yorumlar';

  @override
  String get detailReviewsSubtitle => 'topluluktan';

  @override
  String get detailShowLess => 'Daha az göster';

  @override
  String get detailReadMore => 'Devamını oku';

  @override
  String get detailCouldNotOpenTrailer => 'Fragman açılamadı.';

  @override
  String get detailWatchTrailer => 'Fragmanı İzle';

  @override
  String get discoverLoadErrorTitle => 'İçerikler yüklenemedi';

  @override
  String get discoverLoadErrorSubtitle =>
      'Bağlantını kontrol et ve yenilemek için aşağı çek.';

  @override
  String get discoverEmptyTitle => 'Burada bir şey yok';

  @override
  String discoverEmptySubtitle(String genre) {
    return '$genre türünde yapım bulunamadı.';
  }

  @override
  String get socialFollowing => 'Takip Ediliyor';

  @override
  String get socialFollow => 'Takip Et';

  @override
  String get socialDefaultUserName => 'WatchVerse kullanıcısı';

  @override
  String get commentWCommentsLabel => 'Yorumlar';

  @override
  String get commentWSpoilersHint => 'Spoiler içerebilir';

  @override
  String get commentWDelete => 'Sil';

  @override
  String get commentWReport => 'Şikayet et';

  @override
  String get commentWBlockUser => 'Kullanıcıyı engelle';

  @override
  String get commentWLike => 'Beğen';

  @override
  String get commentWReportedSnackbar =>
      'Şikayet edildi. Bildirdiğin için teşekkürler.';

  @override
  String get commentWBlockedSnackbar =>
      'Engellendi. Yorumları gizlendi ve takibi bıraktın.';

  @override
  String get commentWJustNow => 'şimdi';

  @override
  String commentWMinutesAgo(int minutes) {
    return '${minutes}dk';
  }

  @override
  String commentWHoursAgo(int hours) {
    return '${hours}sa';
  }

  @override
  String commentWDaysAgo(int days) {
    return '${days}g';
  }

  @override
  String commentWWeeksAgo(int weeks) {
    return '${weeks}h';
  }

  @override
  String episodeSeasonEpisodeLabel(int season, int episode) {
    return 'S$season · B$episode';
  }

  @override
  String episodeRuntimeMinutes(int minutes) {
    return '$minutes dk';
  }

  @override
  String episodeRatingStars(String rating) {
    return '★ $rating';
  }

  @override
  String get episodeNotAiredYet => 'Henüz yayınlanmadı';

  @override
  String get episodeOverviewTitle => 'Özet';

  @override
  String get episodeWatchedLabel => 'İzlendi';

  @override
  String get episodeMarkAsWatchedLabel => 'İzlendi olarak işaretle';

  @override
  String get episodeYourRatingTitle => 'Puanın';

  @override
  String get episodeYourNotesTitle => 'Notların';

  @override
  String get episodeNotesPrivateHint =>
      'Gizli — bunu yalnızca sen görebilirsin.';

  @override
  String get episodeNoteHint => 'Bu bölüm hakkında bir not yaz…';

  @override
  String get episodeNoteSaved => 'Not kaydedildi';

  @override
  String get episodeSaveNoteButton => 'Notu kaydet';

  @override
  String get commentsAddLinkTitle => 'GIF / görsel bağlantısı ekle';

  @override
  String get commentsLinkHint => 'https://…';

  @override
  String get commentsAddAction => 'Ekle';

  @override
  String get commentsSearchGifs => 'GIF ara';

  @override
  String get commentsAddGifByLink => 'Bağlantıyla GIF / görsel ekle';

  @override
  String commentsCouldNotPost(String error) {
    return 'Gönderilemedi: $error';
  }

  @override
  String get commentsTitle => 'Yorumlar';

  @override
  String get commentsAddCommentHint => 'Yorum ekle…';

  @override
  String get commentsSignInHint => 'Sohbete katılmak için giriş yap.';

  @override
  String get commentsEmptyTitle => 'Henüz yorum yok';

  @override
  String get commentsEmptySubtitle => 'Düşüncelerini ilk paylaşan sen ol.';

  @override
  String get pubProfileFavoriteFilms => 'Favori Filmler';

  @override
  String get pubProfileWatchedMovies => 'İzlenen Filmler';

  @override
  String get pubProfileShows => 'Diziler';

  @override
  String get pubProfileLists => 'Listeler';

  @override
  String get pubProfileDefaultUserName => 'WatchVerse kullanıcısı';

  @override
  String get pubProfileMemberLabel => 'WatchVerse üyesi';

  @override
  String get pubProfileFilms => 'Filmler';

  @override
  String get pubProfileFollowers => 'Takipçiler';

  @override
  String get pubProfileFollowing => 'Takip Edilenler';

  @override
  String get pubProfileAddedToList => 'Listene eklendi';

  @override
  String get searchFilterAll => 'Film ve Dizi';

  @override
  String get searchFilterMovies => 'Filmler';

  @override
  String get searchFilterTv => 'Diziler';

  @override
  String get searchFilterPeople => 'Kişiler';

  @override
  String searchFailed(String error) {
    return 'Arama başarısız: $error';
  }

  @override
  String get searchTitle => 'Ara';

  @override
  String get searchHintPeople => 'İsme göre kişi ara…';

  @override
  String get searchHintTitles => 'Film ve dizi ara…';

  @override
  String get searchFindFriendsTitle => 'Arkadaş bul';

  @override
  String get searchFindFriendsSubtitle =>
      'İsimle kişi ara ve ne izlediklerini görmek için takip et.';

  @override
  String get searchFindNextWatchTitle => 'Sıradaki izleyeceğini bul';

  @override
  String get searchFindNextWatchSubtitle => 'Film ve dizilerde arama yap.';

  @override
  String get searchNoOneFoundTitle => 'Kimse bulunamadı';

  @override
  String searchNoUsersMatched(String query) {
    return '\"$query\" ile eşleşen kullanıcı yok.\nİsimler şimdilik büyük/küçük harfe duyarlıdır.';
  }

  @override
  String get searchNoResultsTitle => 'Sonuç yok';

  @override
  String searchNothingMatched(String query) {
    return '\"$query\" ile eşleşen bir şey yok.';
  }

  @override
  String get homeAppTitle => 'WatchVerse';

  @override
  String get homeGuestLabel => 'Misafir olarak geziniyor';

  @override
  String get homeMyLists => 'Listelerim';

  @override
  String get homeFriendsActivity => 'Arkadaş Etkinliği';

  @override
  String get homeWatchHistory => 'İzleme Geçmişi';

  @override
  String get homeWatchPolls => 'İzleme Oylamaları';

  @override
  String get homeSettingsLabel => 'Ayarlar';

  @override
  String get homeSignOut => 'Çıkış Yap';

  @override
  String get homeTabMovies => 'Filmler';

  @override
  String get homeTabTvShows => 'Diziler';

  @override
  String get homeTrendingThisWeek => 'Bu Hafta Trend';

  @override
  String get homeComingSoon => 'Yakında';

  @override
  String get homePopular => 'Popüler';

  @override
  String get homeTopRated => 'En Çok Beğenilen';

  @override
  String get homeAiringToday => 'Bugün Yayınlanan';

  @override
  String get homeOnTheAir => 'Yayında';

  @override
  String get homePopularShows => 'Popüler Diziler';

  @override
  String get homeFriendsAlsoWatched => 'Arkadaşların da İzledi';

  @override
  String get statsSeeDetails => 'Detayları gör';

  @override
  String get statsScreenTitle => 'İzleme İstatistikleri';

  @override
  String get statsTypeBreakdownTitle => 'Film / Dizi';

  @override
  String get statsGenreBreakdownTitle => 'Türe göre süre';

  @override
  String get statsOtherGenres => 'Diğer';

  @override
  String get statsWeeklyTitle => 'Son 8 hafta';

  @override
  String get statsThisWeek => 'Bu hafta';

  @override
  String get statsWeekdayTitle => 'Haftanın gününe göre';

  @override
  String get statsDayMon => 'Pzt';

  @override
  String get statsDayTue => 'Sal';

  @override
  String get statsDayWed => 'Çar';

  @override
  String get statsDayThu => 'Per';

  @override
  String get statsDayFri => 'Cum';

  @override
  String get statsDaySat => 'Cmt';

  @override
  String get statsDaySun => 'Paz';

  @override
  String get statsEmptyMessage =>
      'İstatistiklerini görmek için birkaç film ya da dizi izle.';

  @override
  String get quickAddWatch => 'İzledim';

  @override
  String get quickAddLike => 'Beğen';

  @override
  String get quickAddWatchlist => 'İzleme Listesi';

  @override
  String get quickAddTrack => 'Takip Et';

  @override
  String get quickAddRate => 'Puanla';

  @override
  String get quickAddReviewOrLog => 'Yorum yap / günlüğe ekle';

  @override
  String get quickAddAddToList => 'Listelere ekle';

  @override
  String quickAddGoTo(String title) {
    return '$title sayfasına git';
  }

  @override
  String homeBecauseYouWatched(String title) {
    return '$title izlediğin için';
  }

  @override
  String get listDetailRenameTitle => 'Listeyi yeniden adlandır';

  @override
  String get listDetailDeleteTitle => 'Liste silinsin mi?';

  @override
  String get listDetailDeleteContent => 'Bu, listeyi kalıcı olarak siler.';

  @override
  String get listDetailDeleteConfirm => 'Sil';

  @override
  String get listDetailRenameMenuItem => 'Yeniden adlandır';

  @override
  String get listDetailDeleteMenuItem => 'Listeyi sil';

  @override
  String get listDetailMakePublicMenuItem => 'Herkese açık yap';

  @override
  String get listDetailMakePrivateMenuItem => 'Gizli yap';

  @override
  String get listDetailMadePublic => 'Liste artık herkese açık';

  @override
  String get listDetailMadePrivate => 'Liste artık gizli';

  @override
  String get listDetailFollow => 'Takip et';

  @override
  String get listDetailFollowing => 'Takip ediliyor';

  @override
  String get listDetailEmptyTitle => 'Boş liste';

  @override
  String get listDetailEmptySubtitle =>
      'Herhangi bir film veya diziyi aç ve \"Listeye ekle\"ye dokun.';

  @override
  String get personKnownForTitle => 'Bilinen Yapımlar';

  @override
  String get personNoCredits => 'Herhangi bir yapım bulunamadı.';

  @override
  String get personBiographyTitle => 'Biyografi';

  @override
  String get personShowLess => 'Daha az göster';

  @override
  String get personReadMore => 'Devamını oku';

  @override
  String get listsNewListTitle => 'Yeni liste';

  @override
  String get listsNewListHint => 'örn. Tüm zamanların en iyi 10\'u';

  @override
  String get listsCreateAction => 'Oluştur';

  @override
  String get listsTitle => 'Listelerim';

  @override
  String get listsSignInTitle => 'Liste oluşturmak için giriş yap';

  @override
  String get listsSignInSubtitle =>
      '\"2026\'da izle\" gibi kendi koleksiyonlarını oluştur.';

  @override
  String get listsEmptyTitle => 'Henüz liste yok';

  @override
  String get listsEmptySubtitle => 'İlk listeni oluşturmak için +\'ya dokun.';

  @override
  String get listsUntitled => 'Adsız';

  @override
  String get listsTabMine => 'Benim';

  @override
  String get listsTabFollowing => 'Takip Ettiklerim';

  @override
  String get listsFollowingEmptyTitle => 'Henüz takip ettiğin liste yok';

  @override
  String get listsFollowingEmptySubtitle =>
      'Başka kullanıcılardan takip ettiğin herkese açık listeler burada görünecek.';

  @override
  String listsFollowingByLabel(String name) {
    return '$name tarafından';
  }

  @override
  String get listsTitleSingular => 'yapım';

  @override
  String get listsTitlePlural => 'yapım';

  @override
  String get listsCardEmptySubtitle =>
      'Boş — herhangi bir film veya diziden yapım ekle.';

  @override
  String get mediaTypeTv => 'Dizi';

  @override
  String get mediaTypeMovie => 'Film';

  @override
  String get addToListTitle => 'Listeye ekle';

  @override
  String get addToListNewListButton => 'Yeni liste';

  @override
  String get addToListSignInMessage => 'Liste oluşturmak için giriş yap.';

  @override
  String get addToListEmptyMessage =>
      'Henüz liste yok — bir tane oluşturmak için \"Yeni liste\"ye dokun.';

  @override
  String get addToListUntitled => 'Adsız';

  @override
  String get addToListTitleSingular => 'yapım';

  @override
  String get addToListTitlePlural => 'yapım';

  @override
  String get addToListCreateTitle => 'Yeni liste';

  @override
  String get addToListCreateHint => 'örn. 2026\'da izle';

  @override
  String get addToListCreateAction => 'Oluştur';

  @override
  String get historyTitle => 'İzleme Geçmişi';

  @override
  String historyWatchedRating(String rating) {
    return 'İzlendi · ★ $rating';
  }

  @override
  String get historyWatchedLabel => 'İzlendi';

  @override
  String historyFinishedSeason(int season, int count) {
    return '$season. Sezon tamamlandı · $count bölüm';
  }

  @override
  String historyEpisodeLine(int season, int episode, String episodeName) {
    return 'S$season B$episode  $episodeName';
  }

  @override
  String get historyEmptyTitle => 'Henüz geçmiş yok';

  @override
  String get historyEmptySubtitle =>
      'İzlendi olarak işaretlediğin filmler ve bölümler burada görünür.';

  @override
  String get historyAgoNow => 'şimdi';

  @override
  String historyAgoMinutes(int minutes) {
    return '${minutes}dk';
  }

  @override
  String historyAgoHours(int hours) {
    return '${hours}sa';
  }

  @override
  String historyAgoDays(int days) {
    return '${days}g';
  }

  @override
  String historyAgoWeeks(int weeks) {
    return '${weeks}h';
  }

  @override
  String get watchlistTitle => 'Filmlerim';

  @override
  String get watchlistCategoryToWatch => 'İzlenecek';

  @override
  String get watchlistCategoryWatched => 'İzlendi';

  @override
  String get watchlistCategoryFavorites => 'Favoriler';

  @override
  String watchlistEmptyMessage(String category) {
    return '\"$category\" içinde henüz film yok.';
  }

  @override
  String get watchlistUntitled => 'Adsız';

  @override
  String watchlistYourRating(String rating) {
    return 'Puanın: $rating';
  }

  @override
  String watchlistReleaseDate(String date) {
    return 'Vizyon: $date';
  }

  @override
  String get gifPickerTitle => 'GIF Seç';

  @override
  String get gifSearchHint => 'GIF ara…';

  @override
  String get gifPoweredBy => 'GIPHY tarafından desteklenmektedir';

  @override
  String get gifLoadErrorTitle => 'GIF\'ler yüklenemedi';

  @override
  String get gifLoadErrorSubtitle => 'Bağlantını kontrol edip tekrar dene.';

  @override
  String get gifEmptyTitle => 'GIF bulunamadı';

  @override
  String get gifEmptySubtitle => 'Farklı bir arama dene.';

  @override
  String get friendsActivityTitle => 'Arkadaş Etkinliği';

  @override
  String get friendsNoFriendsTitle => 'Henüz arkadaş yok';

  @override
  String get friendsNoFriendsSubtitle =>
      'Ne izlediklerini görmek için Arkadaş Bul\'dan kişileri takip et.';

  @override
  String get friendsQuietTitle => 'Şimdilik sessiz';

  @override
  String get friendsQuietSubtitle =>
      'Arkadaşlarının son zamanlarda etkinliği yok.';

  @override
  String get friendsSomeoneFallback => 'Biri';

  @override
  String friendsActionWatchedMovie(String title) {
    return '$title izledi';
  }

  @override
  String friendsActionFinishedSeason(int season, String show) {
    return '$show dizisinin $season. sezonunu tamamladı';
  }

  @override
  String friendsActionWatchedEpisode(int season, int episode, String show) {
    return '$show dizisinin S$season B$episode bölümünü izledi';
  }

  @override
  String get friendsAgoNow => 'şimdi';

  @override
  String friendsAgoMinutes(int minutes) {
    return '${minutes}dk';
  }

  @override
  String friendsAgoHours(int hours) {
    return '${hours}sa';
  }

  @override
  String friendsAgoDays(int days) {
    return '${days}g';
  }

  @override
  String friendsAgoWeeks(int weeks) {
    return '${weeks}h';
  }

  @override
  String get blockedTitle => 'Engellenen Kullanıcılar';

  @override
  String get blockedDefaultUserName => 'WatchVerse kullanıcısı';

  @override
  String get blockedUnblockButton => 'Engeli kaldır';

  @override
  String get blockedEmptyTitle => 'Engellenen kullanıcı yok';

  @override
  String get blockedEmptySubtitle => 'Engellediğin kişiler burada görünür.';

  @override
  String get watchPollsTitle => 'İzleme Oylamaları';

  @override
  String get watchPollDefaultTitle => 'Ne izlesek?';

  @override
  String get watchPollClosedLabel => 'KAPANDI';

  @override
  String watchPollVoteCountSingular(String count) {
    return '$count oy';
  }

  @override
  String watchPollVoteCountPlural(String count) {
    return '$count oy';
  }

  @override
  String get watchPollsEmptyTitle => 'Henüz oylama yok';

  @override
  String get watchPollsEmptySubtitle =>
      'Ne izleneceğine arkadaşlarının oy vermesi için bir oylama başlat.';

  @override
  String get createWatchPollTitle => 'Yeni Oylama';

  @override
  String get watchPollTitleHint => 'Oylama başlığı (isteğe bağlı)';

  @override
  String watchPollOptionsLabel(int count, int max) {
    return 'Seçenekler ($count/$max)';
  }

  @override
  String get watchPollSearchHint => 'Eklemek için film veya dizi ara';

  @override
  String get watchPollInviteLabel => 'Arkadaşları davet et';

  @override
  String get watchPollInviteSubtitle =>
      'İsteğe bağlı — davet edilen herkes oy verebilir. Sadece kendin için de oluşturabilirsin.';

  @override
  String get watchPollNoFriendsYet =>
      'Oylamaya davet etmek için önce birkaç arkadaşı takip et.';

  @override
  String get watchPollCreateAction => 'Oylama Oluştur';

  @override
  String get watchPollCloseTitle => 'Bu oylama kapatılsın mı?';

  @override
  String get watchPollCloseContent =>
      'Bu, mevcut durumu sabitler — bundan sonra kimse oy veremez.';

  @override
  String get watchPollCloseConfirm => 'Oylamayı kapat';

  @override
  String get watchPollCloseMenuItem => 'Oylamayı kapat';

  @override
  String get watchPollDeleteTitle => 'Oylama silinsin mi?';

  @override
  String get watchPollDeleteContent =>
      'Bu, oylamayı davet edilen herkes için kaldırır.';

  @override
  String get watchPollDeleteConfirm => 'Sil';

  @override
  String get watchPollDeleteMenuItem => 'Oylamayı sil';

  @override
  String get watchPollNotFound => 'Bu oylama artık mevcut değil.';

  @override
  String get watchPollClosedBanner => 'Bu oylama kapandı — sonuç böyle.';

  @override
  String watchPollOptionVotesSingular(String count) {
    return '$count oy';
  }

  @override
  String watchPollOptionVotesPlural(String count) {
    return '$count oy';
  }

  @override
  String get homeWatchVersePro => 'WatchVerse Pro';

  @override
  String get proSheetTitle => 'WatchVerse Pro';

  @override
  String get proSheetSubtitle =>
      'WatchVerse\'in tüm özelliklerinin kilidini aç';

  @override
  String get proFeatureStats => 'Gelişmiş izleme istatistikleri ve grafikler';

  @override
  String get proFeatureLists => 'Sınırsız özel liste';

  @override
  String get proFeatureProfile => 'Özel profil temaları';

  @override
  String get proFeatureGame => 'Günlük film tahmin oyunu';

  @override
  String get proTierPro => 'Pro';

  @override
  String get proTierPatron => 'Patron';

  @override
  String get proFeatureEverythingInPro => 'Pro\'daki her şey, artı:';

  @override
  String get proFeatureBadge => 'Profilinde Patron rozeti';

  @override
  String get proFeatureEarlyAccess => 'Yeni özelliklere erken erişim';

  @override
  String get proMonthly => 'Aylık';

  @override
  String get proYearly => 'Yıllık';

  @override
  String proYearlySave(String percent) {
    return '%$percent tasarruf';
  }

  @override
  String get proContinue => 'Devam Et';

  @override
  String get proRestore => 'Satın alımları geri yükle';

  @override
  String get proRestoreSuccess => 'Abonelik geri yüklendi!';

  @override
  String get proRestoreFailure =>
      'Bu Apple ID için önceki bir satın alma bulunamadı';

  @override
  String get proPurchaseFailure =>
      'Satın alma başarısız oldu — lütfen tekrar dene';

  @override
  String get proNotConfigured =>
      'Pro henüz kullanıma açık değil — daha sonra tekrar bak';

  @override
  String get proActiveBadge => 'WatchVerse aboneliğin aktif';

  @override
  String get proSignInToContinue => 'Devam Etmek İçin Giriş Yap';

  @override
  String get proSignInRequired =>
      'Abone olmadan önce giriş yapman veya hesap oluşturman gerekiyor.';

  @override
  String get proListLimitReached =>
      'Ücretsiz hesaplar 3 özel liste ile sınırlıdır — sınırsız liste için WatchVerse Pro\'ya geç.';

  @override
  String get proUnlockStats => 'Pro ile kilidi aç';

  @override
  String get proUnlockProfileTheme => 'Patron teması';

  @override
  String get proExporting => 'Dışa aktarman hazırlanıyor…';

  @override
  String get proExportAction => 'Verilerimi dışa aktar (CSV)';

  @override
  String get importDataAction => 'Letterboxd veya IMDb\'den içe aktar';

  @override
  String get importTitle => 'Verileri içe aktar';

  @override
  String get importIntro =>
      'Geçmişini Letterboxd veya IMDb\'den getir. WatchVerse\'teki hiçbir şeyin üzerine yazılmaz — mevcut puanların ve izlediğin filmler korunur, aynı dosyayı tekrar içe aktarmak kopya oluşturmaz.';

  @override
  String get importLetterboxdHeading => 'Letterboxd';

  @override
  String get importLetterboxdSteps =>
      'letterboxd.com\'da Settings → Import & Export → Export Your Data yolunu izle. İnen .zip dosyasını olduğu gibi seç — ya da yalnızca içindeki watched, ratings, diary ve watchlist CSV dosyalarını.';

  @override
  String get importImdbHeading => 'IMDb';

  @override
  String get importImdbSteps =>
      'imdb.com\'da Your Ratings sayfasını (ve izleme listeni) aç, ⋯ menüsünden Export\'u seç. Hazır olduğunda CSV dosyasını Exports sayfasından indir.';

  @override
  String get importWhatHappens =>
      'İzlenen ve puanlanan filmler orijinal tarihleriyle izlendi olarak işaretlenir, Letterboxd günlük kayıtları korunur, izleme listesindeki filmler izleme listene eklenir. IMDb\'deki diziler, hiçbir bölüm işaretlenmeden Dizilerim\'e eklenir.';

  @override
  String get importPickFiles => 'Dosya seç';

  @override
  String get importPickHint => 'Aynı anda birden fazla dosya seçebilirsin.';

  @override
  String get importReading => 'Dosyalar okunuyor…';

  @override
  String importProgress(String done, String total) {
    return 'Yapımlar eşleştiriliyor… $done / $total';
  }

  @override
  String get importCancelling => 'Durduruluyor…';

  @override
  String get importNothingFound =>
      'Bu dosyalarda Letterboxd veya IMDb verisi bulunamadı.';

  @override
  String importUnrecognizedFiles(String files) {
    return 'Atlandı (Letterboxd veya IMDb dışa aktarımı değil): $files';
  }

  @override
  String get importDoneTitle => 'İçe aktarma tamamlandı';

  @override
  String get importCancelledNote =>
      'İçe aktarma durduruldu. Şu ana kadar eşleşenlerin hepsi kaydedildi — tamamlamak için istediğin zaman tekrar içe aktarabilirsin; hiçbir şey iki kez eklenmez.';

  @override
  String get importSummaryWatched => 'İzlendi olarak işaretlenen filmler';

  @override
  String get importSummaryRatings => 'Puanlar';

  @override
  String get importSummaryWatchlist => 'İzleme listesine eklenenler';

  @override
  String get importSummaryShows => 'Dizilerim\'e eklenen diziler';

  @override
  String get importSummaryDiary => 'Günlük kayıtları';

  @override
  String get importSummaryExisting => 'Zaten kütüphanende olanlar';

  @override
  String get importSummarySkipped =>
      'Atlanan satırlar (bölümler, oyunlar, geçersiz)';

  @override
  String get importSummaryUnmatched => 'Eşleşmeyenler';

  @override
  String get importViewUnmatched => 'Eşleşmeyenleri gör';

  @override
  String get importUnmatchedHint =>
      'Bunlar güvenilir şekilde eşleştirilemedi. Arayarak elle ekleyebilirsin.';

  @override
  String get importLookupFailed =>
      'Arama başarısız — tekrar içe aktarmak sorunu çözebilir';

  @override
  String get importDone => 'Tamam';

  @override
  String get importMore => 'Daha fazla içe aktar';

  @override
  String importError(String error) {
    return 'İçe aktarma başarısız: $error';
  }

  @override
  String get importSignInPrompt =>
      'Letterboxd veya IMDb geçmişini içe aktarmak için giriş yap.';

  @override
  String get proLegalFooter =>
      'Abone olarak Kullanım Koşulları\'nı ve Gizlilik Politikası\'nı kabul etmiş olursun.';

  @override
  String get proSubscriptionTerms =>
      'Ödeme, satın alma onaylandığında Apple ID hesabından tahsil edilir. Abonelikler, mevcut dönem bitmeden en az 24 saat önce otomatik yenileme kapatılmadığı sürece otomatik olarak yenilenir. Cihazında Ayarlar > [adın] > Abonelikler bölümünden istediğin zaman yönetebilir veya iptal edebilirsin.';

  @override
  String get dailyGameTitle => 'Günlük Film Oyunu';

  @override
  String get dailyGameSearchHint => 'Bir film ara…';

  @override
  String dailyGameGuessesLeft(String count) {
    return '$count tahmin hakkı kaldı';
  }

  @override
  String get dailyGameClueDirector => 'Yönetmen';

  @override
  String get dailyGameClueStudio => 'Yapım Stüdyosu';

  @override
  String get dailyGameClueYear => 'Yıl';

  @override
  String get dailyGameClueRevenue => 'Hasılat';

  @override
  String get dailyGameClueRating => 'Puan';

  @override
  String get dailyGameClueCertification => 'Yaş Sınırı';

  @override
  String get dailyGameClueCast => 'Oyuncular';

  @override
  String get dailyGameClueGenres => 'Türler';

  @override
  String get dailyGameHintUnlocked => 'İpucu açıldı!';

  @override
  String get dailyGameShowHint => 'İpucunu göster';

  @override
  String get dailyGameWinTitle => 'Bildin!';

  @override
  String get dailyGameLoseTitle => 'Tahmin hakkın bitti';

  @override
  String get dailyGameShareResult => 'Sonucu paylaş';

  @override
  String get dailyGamePlayAgainTomorrow => 'Yeni film için yarın tekrar gel';

  @override
  String get dailyGameNoPool =>
      'Bugünün bulmacası henüz hazır değil — daha sonra tekrar bak';

  @override
  String get dailyGameRetry => 'Tekrar dene';

  @override
  String get dailyGameSignInPrompt =>
      'Günlük film oyununu oynamak için giriş yap.';

  @override
  String get dailyGameGuessedAlready => 'Zaten tahmin edildi';

  @override
  String get dailyGamePickAnotherDay => 'Başka bir gün seç';

  @override
  String get pollSignInToVote => 'Oy vermek için giriş yap.';

  @override
  String get tvSeasonLoadFailed => 'Bu sezonun bölümleri yüklenemedi.';

  @override
  String get discoverLoadMoreFailed => 'Daha fazlası yüklenemedi.';

  @override
  String get retryAction => 'Tekrar dene';

  @override
  String get patronBadgeLabel => 'Patron';

  @override
  String get dailyGameToday => 'Bugün';

  @override
  String dailyGamePuzzleFor(String date) {
    return '$date bulmacası';
  }

  @override
  String get dailyGameHowToPlay => 'Nasıl oynanır';

  @override
  String dailyGameHowToIntro(String max) {
    return 'Gizemli filmi $max tahminde bul. Herhangi bir filmi arayıp seç — her tahmin, gizemli filmle nasıl karşılaştırıldığını gösterir.';
  }

  @override
  String get dailyGameHowToGreen => 'Yeşil: tam eşleşme';

  @override
  String get dailyGameHowToGold =>
      'Altın: yakın — ortak bir yönetmen, stüdyo, oyuncu ya da tür var veya yıl 5, puan 0,5, hasılat %50 içinde';

  @override
  String get dailyGameHowToGray =>
      'Gri: eşleşme yok. \"?\" olan kutu, filmlerden biri için bilginin bilinmediği anlamına gelir.';

  @override
  String get dailyGameHowToArrows =>
      '↑ ↓: gizemli filmin yılı, hasılatı ya da puanı senin tahmininden yüksek / düşük';

  @override
  String get dailyGameHowToShared =>
      'Oyuncular, türler, stüdyo ve yönetmende altın kutu iki filmin ortak noktasını gösterir.';

  @override
  String dailyGameHowToHints(String first, String second) {
    return 'Takıldın mı? $first. ve $second. tahminden sonra ipucu açılır. Her gün yeni bir film — takvimden geçen haftayı da oynayabilirsin.';
  }

  @override
  String get dailyGameGotIt => 'Anladım';

  @override
  String get dailyGameHints => 'İpuçları';

  @override
  String dailyGameNextHint(String count) {
    return 'Sonraki ipucu $count. tahminden sonra';
  }

  @override
  String dailyGameHintTopBilled(String name) {
    return 'Başrol: $name';
  }

  @override
  String get dailyGameNoResults => 'Eşleşen film yok';

  @override
  String get dailyGameSearchFailed => 'Arama başarısız. Bağlantını kontrol et.';

  @override
  String dailyGameSolvedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tahminde bildin',
      one: 'İlk tahminde bildin!',
    );
    return '$_temp0';
  }

  @override
  String get dailyGameAnswerWas => 'Gizemli film:';

  @override
  String get dailyGameViewMovie => 'Filme git';

  @override
  String get dailyGameGuessFailed => 'Bu film yüklenemedi. Tekrar dene.';

  @override
  String get dailyGameRowFailed => 'Bu tahmin yüklenemedi';

  @override
  String get gamesHubTitle => 'Oyunlar';

  @override
  String get gamesHubDailyMovieSubtitle =>
      'Gizemli filmi ipuçlarından tahmin et. Her gün yeni.';

  @override
  String get gamesHubStatusNotPlayed => 'Bugün oynanmadı';

  @override
  String get gamesHubStatusInProgress => 'Devam ediyor';

  @override
  String get gamesHubStatusSolved => 'Bugün bildin';

  @override
  String get gamesHubStatusMissed => 'Bugün oynandı';

  @override
  String get actorGuessTitle => 'Bu Oyuncu Kim?';

  @override
  String get actorGuessHubSubtitle =>
      'Altı ipucuyla günün gizemli oyuncusunu bul';

  @override
  String get actorGuessSignInPrompt => 'Bu Oyuncu Kim? oynamak için giriş yap.';

  @override
  String get actorGuessLoadError => 'Bugünün oyuncusu yüklenemedi.';

  @override
  String get actorGuessNoPool =>
      'Bugünün bulmacası henüz hazır değil — birazdan tekrar bak';

  @override
  String get actorGuessRetry => 'Tekrar dene';

  @override
  String get actorGuessSearchHint => 'Bir oyuncu ara…';

  @override
  String get actorGuessSearchFailed =>
      'Arama başarısız. Bağlantını kontrol et.';

  @override
  String get actorGuessNoResults => 'Oyuncu bulunamadı';

  @override
  String get actorGuessAlreadyGuessed => 'Zaten tahmin ettin';

  @override
  String actorGuessGuessesLeft(String count) {
    return '$count tahmin hakkın kaldı';
  }

  @override
  String actorGuessClueNumber(String number) {
    return '$number. ipucu';
  }

  @override
  String get actorGuessClueOrigin => 'Kariyer';

  @override
  String actorGuessFirstMovie(String year) {
    return 'İlk film rolü: $year';
  }

  @override
  String actorGuessBornIn(String country) {
    return 'Doğduğu ülke: $country';
  }

  @override
  String get actorGuessClueDeepCuts => 'Şunlarda da oynadı';

  @override
  String get actorGuessClueKnownTitles => 'Bilinen yapımları';

  @override
  String get actorGuessClueCharacter => 'Ünlü rolü';

  @override
  String actorGuessCharacterIn(String character, String title) {
    return '$title yapımında $character';
  }

  @override
  String get actorGuessClueTopTitles => 'En çok bilindiği yapımlar';

  @override
  String get actorGuessCluePhoto => 'Fotoğrafı';

  @override
  String get actorGuessNextClueHint => 'Her yanlış tahmin yeni bir ipucu açar';

  @override
  String get actorGuessYourGuesses => 'Tahminlerin';

  @override
  String get actorGuessWinTitle => 'Bildin!';

  @override
  String actorGuessWinSubtitle(String count, String max) {
    return '$count/$max tahminde bildin';
  }

  @override
  String get actorGuessLoseTitle => 'Tahmin hakkın bitti';

  @override
  String actorGuessAnswerWas(String name) {
    return 'Bugünün oyuncusu: $name';
  }

  @override
  String get actorGuessViewFilmography => 'Filmografiyi gör';

  @override
  String get actorGuessShareResult => 'Sonucu paylaş';

  @override
  String get actorGuessComeBackTomorrow => 'Yeni oyuncu için yarın tekrar gel';

  @override
  String get gamesCommonMovies => 'Filmler';

  @override
  String get gamesCommonTv => 'Diziler';

  @override
  String gamesCommonPuzzleNumber(String number) {
    return 'Bulmaca #$number';
  }

  @override
  String get gamesCommonShare => 'Sonucu paylaş';

  @override
  String get gamesCommonViewDetails => 'Detayları gör';

  @override
  String get gamesCommonComeBackTomorrow => 'Yarın yeni bir bulmaca gelecek.';

  @override
  String get gamesCommonGuestNote =>
      'Misafir olarak oynuyorsun — sonuçlarını kaydetmek için giriş yap.';

  @override
  String get gamesCommonLoadError => 'Bugünün bulmacası yüklenemedi.';

  @override
  String get gamesCommonRetry => 'Tekrar dene';

  @override
  String get gamesCommonSaveFailed =>
      'İlerlemen kaydedilemedi. Bağlantını kontrol et.';

  @override
  String get gamesCommonWin => 'Bildin!';

  @override
  String get gamesCommonLose => 'Bu sefer olmadı';

  @override
  String gamesCommonSolvedIn(String count, String total) {
    return '$count/$total denemede bildin';
  }

  @override
  String gamesCommonAnswerWas(String title) {
    return 'Cevap: $title';
  }

  @override
  String gamesCommonGuessesLeft(String count) {
    return '$count tahmin hakkın kaldı';
  }

  @override
  String get framesGameTitle => 'Kareler';

  @override
  String get framesGameIntroMovie =>
      'Filmi karelerinden bil. Her yanlış tahmin ya da pas yeni bir kare açar.';

  @override
  String get framesGameIntroTv =>
      'Diziyi karelerinden bil. Her yanlış tahmin ya da pas yeni bir kare açar.';

  @override
  String get framesGameSearchHintMovie => 'Film ara…';

  @override
  String get framesGameSearchHintTv => 'Dizi ara…';

  @override
  String get framesGameSkip => 'Pas geç';

  @override
  String framesGameFrameLabel(String number) {
    return 'Kare $number';
  }

  @override
  String get framesGameSkipped => 'Pas geçildi';

  @override
  String get framesGameAlreadyGuessed => 'Bunu zaten denedin';

  @override
  String get framesGameNoResults => 'Sonuç yok';

  @override
  String get titleWordleTitle => 'İsim Wordle';

  @override
  String get titleWordleIntroMovie =>
      'Bugünün film adını 6 denemede bul. Sadece harfleri yaz — kelime araları zaten gösteriliyor.';

  @override
  String get titleWordleIntroTv =>
      'Bugünün dizi adını 6 denemede bul. Sadece harfleri yaz — kelime araları zaten gösteriliyor.';

  @override
  String titleWordleLetterCount(String count) {
    return '$count harf';
  }

  @override
  String get titleWordleNotEnoughLetters => 'Harf sayısı yetmiyor';

  @override
  String get titleWordleSubmit => 'Tahmini gönder';

  @override
  String get titleWordleDelete => 'Harfi sil';

  @override
  String get gamesHubFramesSubtitle =>
      'Filmi ya da diziyi sahnelerinden tahmin et';

  @override
  String get gamesHubTitleWordleSubtitle =>
      'Film ya da dizi adını Wordle usulü tahmin et';

  @override
  String get higherLowerTitle => 'Yüksek mi Düşük mü';

  @override
  String get higherLowerIntro =>
      'Sıradaki yapım daha yüksek mi, daha düşük mü? Doğru bildikçe skorun artsın.';

  @override
  String get higherLowerPickCategory => 'Bir kategori seç';

  @override
  String get higherLowerCategoryMovieRating => 'Film puanı';

  @override
  String get higherLowerCategoryBoxOffice => 'Gişe hasılatı';

  @override
  String get higherLowerCategoryTvRating => 'Dizi puanı';

  @override
  String get higherLowerCategoryRatingDesc => 'TMDB kullanıcı puanı';

  @override
  String get higherLowerCategoryBoxOfficeDesc => 'Dünya geneli hasılat';

  @override
  String higherLowerBest(int score) {
    return 'En iyi: $score';
  }

  @override
  String higherLowerScore(int score) {
    return 'Skor: $score';
  }

  @override
  String higherLowerPrompt(String title) {
    return '$title ile kıyasla daha yüksek mi, düşük mü?';
  }

  @override
  String get higherLowerHigher => 'Daha yüksek';

  @override
  String get higherLowerLower => 'Daha düşük';

  @override
  String get higherLowerCorrect => 'Doğru!';

  @override
  String get higherLowerWrong => 'Yanlış!';

  @override
  String get higherLowerGameOver => 'Oyun bitti';

  @override
  String higherLowerFinalScore(int score) {
    return 'Skorun: $score';
  }

  @override
  String get higherLowerNewBest => 'Yeni kişisel rekor!';

  @override
  String get higherLowerPlayAgain => 'Tekrar oyna';

  @override
  String get higherLowerChangeCategory => 'Kategori değiştir';

  @override
  String get higherLowerTiesNote => 'Eşitlikler doğru sayılır.';

  @override
  String get plotGameTitle => 'Konu';

  @override
  String get plotGameModeMovie => 'Film';

  @override
  String get plotGameModeTv => 'Dizi';

  @override
  String get plotGameIntro =>
      'Bugünün yapımını konusundan tahmin et. İsimler gizli — her yanlış tahmin ya da pas yeni bir ipucu açar.';

  @override
  String get plotGameSearchMovieHint => 'Filmi tahmin et…';

  @override
  String get plotGameSearchTvHint => 'Diziyi tahmin et…';

  @override
  String get plotGameSkip => 'Pas geç';

  @override
  String get plotGameSkipped => 'Pas geçildi';

  @override
  String plotGameAttemptsLeft(int count) {
    return '$count tahmin hakkın kaldı';
  }

  @override
  String get plotGameCluePlot => 'Konu';

  @override
  String get plotGameClueMorePlot => 'Konunun devamı';

  @override
  String get plotGameClueYear => 'Yıl';

  @override
  String get plotGameClueGenres => 'Türler';

  @override
  String get plotGameClueActor => 'Başrol oyuncusu';

  @override
  String get plotGameClueSecondActor => 'Diğer oyuncu';

  @override
  String get plotGameClueTagline => 'Slogan';

  @override
  String get plotGameNextClueLocked => 'Yanlış bir tahminden sonra açılır';

  @override
  String get plotGameAlreadyGuessed => 'Zaten tahmin ettin';

  @override
  String get plotGameNoResults => 'Sonuç yok';

  @override
  String get plotGameWinTitle => 'Bildin!';

  @override
  String get plotGameLoseTitle => 'Tahmin hakkın bitti';

  @override
  String plotGameSolvedIn(int count, int max) {
    return '$count/$max tahminde bildin';
  }

  @override
  String get plotGameViewDetails => 'Detayları gör';

  @override
  String get plotGameShare => 'Sonucu paylaş';

  @override
  String get plotGameComeBack => 'Yeni konu için yarın tekrar gel.';

  @override
  String get plotGameSignInPrompt =>
      'Günlük Konu oyununu oynamak için giriş yap.';

  @override
  String get plotGameNoPuzzle =>
      'Bugünün bulmacası henüz hazır değil — daha sonra tekrar bak.';

  @override
  String get gamesHubPlotSubtitle =>
      'Filmi ya da diziyi gizlenmiş konusundan tahmin et';

  @override
  String get gamesHubHigherLowerSubtitle =>
      'Hangisinin puanı daha yüksek? Sonsuz tur';

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
