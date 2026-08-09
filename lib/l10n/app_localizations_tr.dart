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
  String get emailRequired => 'Lütfen e-posta adresinizi girin';

  @override
  String get emailInvalid => 'Geçerli bir e-posta adresi girin';

  @override
  String get passwordHint => 'Şifre';

  @override
  String get passwordRequiredLogin => 'Lütfen şifrenizi girin';

  @override
  String get logIn => 'Giriş Yap';

  @override
  String get continueAsGuest => 'Misafir olarak devam et';

  @override
  String get noAccountPrompt => 'Hesabınız yok mu?';

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
  String get usernameRequired => 'Lütfen bir kullanıcı adı girin';

  @override
  String get confirmPasswordHint => 'Şifreyi onayla';

  @override
  String get passwordRequiredRegister => 'Lütfen bir şifre girin';

  @override
  String get passwordTooShort => 'En az 6 karakter olmalı';

  @override
  String get passwordsDoNotMatch => 'Şifreler eşleşmiyor';

  @override
  String get createAccountButton => 'Hesap Oluştur';

  @override
  String get alreadyHaveAccountPrompt => 'Zaten hesabınız var mı?';

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
      'Bu işlem geri alınamaz. Hesabın ve giriş bilgilerin kalıcı olarak silinecek.';

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
  String get selectAvatarTitle => 'Avatar Seç';

  @override
  String get editNameTitle => 'Adı Düzenle';

  @override
  String get enterNewNameHint => 'Yeni adı girin';

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
  String get tvOverviewTitle => 'Genel Bakış';

  @override
  String get tvSeasonsTitle => 'Sezonlar';

  @override
  String get tvMoreLikeThisTitle => 'Bunlara Benzer';

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
    return 'İleri atladınız. $episodesPhrase de izlendi olarak işaretlensin mi?';
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
    return '🎉 $name dizisini bitirdiniz!';
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
  String get tvYourProgress => 'İlerlemeniz';

  @override
  String tvProgressFraction(String watched, String total) {
    return '$watched / $total';
  }

  @override
  String tvPercentWatched(String percent) {
    return '%$percent izlendi';
  }

  @override
  String get tvYourRating => 'Puanınız';

  @override
  String get movieYourRating => 'Puanınız';

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
  String get profileYourNameHint => 'Adınız';

  @override
  String get profileCharacterQuoteHint => 'Bir film/dizi karakteri olsaydım...';

  @override
  String get profileAvatarBackgroundLabel => 'Profil arka planı';

  @override
  String profileSaveNameError(String error) {
    return 'İsim kaydedilemedi: $error';
  }

  @override
  String get profileSignInPrompt => 'Profilinizi görmek için giriş yapın.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileAddYourName => 'Adınızı ekleyin';

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
    return '${hours}s ${minutes}d';
  }

  @override
  String profileDurationDaysHours(String days, String hours) {
    return '${days}g ${hours}s';
  }

  @override
  String profileDurationMonthsDaysHours(
    String months,
    String days,
    String hours,
  ) {
    return '${months}a ${days}g ${hours}s';
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
    return '$year Yılınız';
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
  String get movieYourDiary => 'Günlüğünüz';

  @override
  String get movieLogAction => 'Kaydet';

  @override
  String get movieLogAgainAction => 'Tekrar kaydet';

  @override
  String get movieDiaryEmpty =>
      'Henüz kayıt yok. Günlüğünüze başlamak için bir izleme kaydedin — tekrar izlemelerinizi kendi tarihleriyle kaydedebilirsiniz.';

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
  String get movieDiaryNoteHint => 'Ne düşündünüz?';

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
      'Bir diziyi takip edin ve bölümleri izlendi olarak işaretleyin — bir sonraki izleyeceğiniz bölüm burada görünecek.';

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
    return '🎉 $name dizisinde güncelsiniz!';
  }

  @override
  String get upNextMarkWatched => 'İzlendi';

  @override
  String get upNextAllCaughtUp => 'Güncelsiniz';

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
      'İzlenecek yeni bölüm yok — sıradaki bölümler için Yaklaşan sekmesine bakabilirsiniz.';

  @override
  String get upNextSwipeStopLabel => 'Bırak';

  @override
  String get upNextStopWatchingTitle => 'Bu diziyi izlemeyi bırak?';

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
  String get discoverLoadErrorTitle => 'Başlıklar yüklenemedi';

  @override
  String get discoverLoadErrorSubtitle =>
      'Bağlantınızı kontrol edin ve yenilemek için aşağı çekin.';

  @override
  String get discoverEmptyTitle => 'Burada bir şey yok';

  @override
  String discoverEmptySubtitle(String genre) {
    return '$genre türünde başlık bulunamadı.';
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
  String get commentWSpoilersHint => 'İçerik spoiler barındırabilir';

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
      'Bildirildi. Bildirdiğiniz için teşekkürler.';

  @override
  String get commentWBlockedSnackbar =>
      'Engellendi. İçeriklerini artık görmeyeceksiniz.';

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
  String get episodeYourRatingTitle => 'Puanınız';

  @override
  String get episodeYourNotesTitle => 'Notlarınız';

  @override
  String get episodeNotesPrivateHint =>
      'Gizli — bunu yalnızca siz görebilirsiniz.';

  @override
  String get episodeNoteHint => 'Bu bölüm hakkında bir not yazın…';

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
  String get commentsUploadPhoto => 'Fotoğraf yükle';

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
  String get commentsSignInHint => 'Sohbete katılmak için giriş yapın.';

  @override
  String get commentsEmptyTitle => 'Henüz yorum yok';

  @override
  String get commentsEmptySubtitle => 'Düşüncelerinizi paylaşan ilk kişi olun.';

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
  String get pubProfileFollowing => 'Takip edilenler';

  @override
  String get pubProfileAddedToList => 'Listenize eklendi';

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
      'İsimle kişi arayın ve ne izlediklerini görmek için takip edin.';

  @override
  String get searchFindNextWatchTitle => 'Bir sonraki izleyeceğinizi bulun';

  @override
  String get searchFindNextWatchSubtitle => 'Film ve dizilerde arama yapın.';

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
    return '$title izlediğiniz için';
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
      'Herhangi bir film veya diziyi açın ve \"Listeye ekle\"ye dokunun.';

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
  String get listsSignInTitle => 'Liste oluşturmak için giriş yapın';

  @override
  String get listsSignInSubtitle =>
      '\"2026\'da izle\" gibi kendi koleksiyonlarınızı oluşturun.';

  @override
  String get listsEmptyTitle => 'Henüz liste yok';

  @override
  String get listsEmptySubtitle =>
      'İlk listenizi oluşturmak için +\'ya dokunun.';

  @override
  String get listsUntitled => 'Adsız';

  @override
  String get listsTabMine => 'Benim';

  @override
  String get listsTabFollowing => 'Takip Ettiklerim';

  @override
  String get listsFollowingEmptyTitle => 'Henüz takip ettiğiniz liste yok';

  @override
  String get listsFollowingEmptySubtitle =>
      'Başka kullanıcılardan takip ettiğiniz herkese açık listeler burada görünecek.';

  @override
  String listsFollowingByLabel(String name) {
    return '$name tarafından';
  }

  @override
  String get listsTitleSingular => 'başlık';

  @override
  String get listsTitlePlural => 'başlık';

  @override
  String get listsCardEmptySubtitle =>
      'Boş — herhangi bir film veya diziden başlık ekleyin.';

  @override
  String get mediaTypeTv => 'Dizi';

  @override
  String get mediaTypeMovie => 'Film';

  @override
  String get addToListTitle => 'Listeye ekle';

  @override
  String get addToListNewListButton => 'Yeni liste';

  @override
  String get addToListSignInMessage => 'Liste oluşturmak için giriş yapın.';

  @override
  String get addToListEmptyMessage =>
      'Henüz liste yok — bir tane oluşturmak için \"Yeni liste\"ye dokunun.';

  @override
  String get addToListUntitled => 'Adsız';

  @override
  String get addToListTitleSingular => 'başlık';

  @override
  String get addToListTitlePlural => 'başlık';

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
      'İzlendi olarak işaretlediğiniz bölümler burada görünür.';

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
    return 'Puanınız: $rating';
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
  String get gifLoadErrorSubtitle =>
      'Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get gifEmptyTitle => 'GIF bulunamadı';

  @override
  String get gifEmptySubtitle => 'Farklı bir arama deneyin.';

  @override
  String get friendsActivityTitle => 'Arkadaş Etkinliği';

  @override
  String get friendsNoFriendsTitle => 'Henüz arkadaş yok';

  @override
  String get friendsNoFriendsSubtitle =>
      'Ne izlediklerini görmek için Arkadaş Bul\'dan kişileri takip edin.';

  @override
  String get friendsQuietTitle => 'Şimdilik sessiz';

  @override
  String get friendsQuietSubtitle =>
      'Arkadaşlarınızın son zamanlarda etkinliği yok.';

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
  String get blockedEmptySubtitle => 'Engellediğiniz kişiler burada görünür.';

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
      'Arkadaşlarınızın sıradaki bölüm/film için oy vermesi için bir oylama başlatın.';

  @override
  String get createWatchPollTitle => 'Yeni Oylama';

  @override
  String get watchPollTitleHint => 'Oylama başlığı (isteğe bağlı)';

  @override
  String watchPollOptionsLabel(int count, int max) {
    return 'Seçenekler ($count/$max)';
  }

  @override
  String get watchPollSearchHint => 'Eklemek için film veya dizi arayın';

  @override
  String get watchPollInviteLabel => 'Arkadaşları davet et';

  @override
  String get watchPollInviteSubtitle =>
      'İsteğe bağlı — davet edilen herkes oy verebilir. Sadece kendiniz için de oluşturabilirsiniz.';

  @override
  String get watchPollNoFriendsYet =>
      'Oylamaya davet etmek için önce birkaç arkadaş takip edin.';

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
  String get proFeatureExport => 'Verilerini CSV olarak dışa aktar';

  @override
  String get proFeatureGame => 'Günlük film tahmin oyunu';

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
  String get proRestoreSuccess => 'Pro geri yüklendi!';

  @override
  String get proRestoreFailure =>
      'Bu hesap için önceki bir satın alma bulunamadı';

  @override
  String get proPurchaseFailure =>
      'Satın alma başarısız oldu — lütfen tekrar deneyin';

  @override
  String get proNotConfigured => 'Pro henüz kullanıma açık değil — yakında';

  @override
  String get proActiveBadge => 'Pro üyesin';

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
  String get proUnlockProfileTheme => 'Pro tema';

  @override
  String get proExporting => 'Dışa aktarman hazırlanıyor…';

  @override
  String get proExportAction => 'Verilerimi dışa aktar (CSV)';

  @override
  String get dailyGameTitle => 'Günlük Film Oyunu';

  @override
  String get dailyGameDrawerLabel => 'Günlük Film Oyunu';

  @override
  String get dailyGameSearchHint => 'Bir film ara…';

  @override
  String dailyGameGuessesLeft(String count) {
    return '$count tahmin hakkı kaldı';
  }

  @override
  String dailyGameStreak(String count) {
    return 'Seri $count';
  }

  @override
  String dailyGameBestStreak(String count) {
    return 'En iyi $count';
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
  String dailyGameLoseSubtitle(String title) {
    return 'Bugünün filmi $title idi';
  }

  @override
  String get dailyGameShareResult => 'Sonucu paylaş';

  @override
  String get dailyGameRewatch => 'Geçmiş günler';

  @override
  String get dailyGamePlayAgainTomorrow => 'Yeni film için yarın tekrar gel';

  @override
  String get dailyGameLoading => 'Bugünün filmi yükleniyor…';

  @override
  String get dailyGameNoPool => 'Bugünün bulmacası henüz hazır değil — yakında';

  @override
  String get dailyGameGuessedAlready => 'Zaten tahmin edildi';

  @override
  String get dailyGamePickAnotherDay => 'Başka bir gün seç';
}
