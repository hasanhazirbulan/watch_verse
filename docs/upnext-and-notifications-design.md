# Up Next Liste Düzeni + Bildirim Sistemi — Tasarım Dokümanı

Bu doküman iki bölümü kapsar: (1) `up_next_screen.dart`'ın "Sırada" sekmesinin
yeniden düzenlenmesi, (2) yeni bir bildirim sistemi (yeni bölüm hatırlatmaları
+ arkadaş aktivitesi + özet/gruplama). Her bölüm önce UX/wireframe, sonra
teknik implementasyon (veri modeli + tetikleyici mantığı) olarak anlatılıyor.
Referans verilen dosya/satırlar mevcut koddan alınmıştır, tahmini değildir.

> **Durum (2026-10-15):** Bölüm 2 canlıda. İstemci tarafı (FCM token kaydı,
> Ayarlar'daki bildirim anahtarları, bildirime dokununca yönlendirme)
> uygulamada. Bildirimleri **gönderen** taraf Cloud Functions değil:
> `functions/src/index.ts` hâlâ **deploy edilmedi** (proje ücretsiz Spark
> planında), onun yerine aynı mantık `scripts/notify/run.js` içinde GitHub
> Actions zamanlanmış görevi olarak çalışıyor
> (`.github/workflows/notifications.yml`, `FIREBASE_SERVICE_ACCOUNT` repo
> secret'ı ile). Takvim (UTC): 06:00 yarın yayınlanacak bölümler, 06:10 bugün
> vizyona giren izleme listesi filmleri, 16:00 arkadaş aktivitesi özeti
> (digest), 17:00 bugün yayınlanan bölümler, her saat :20'de aktivite taraması
> (ortak izleme eşleşmeleri + özet kuyruğu). Bu dokümandaki Cloud Functions /
> tetikleyici anlatımı tasarım olarak geçerli, ama gerçek gönderim yolu bu
> cron görevidir — ikisini birden deploy etmeyin, yoksa her bildirim iki kez
> gider. Ayrıntı: `README.md` → "Push Notifications", `plan.md` → "1.0 status
> + maintenance".

---

## Bölüm 1 — "Sırada" Sekmesi Yeniden Düzenlemesi

### 1.1 Mevcut durum (kök neden)

`lib/screens/up_next_screen.dart` içindeki `_NextUpCard.build()` şu üç dalı
render ediyor:

```dart
if (next != null) return _nextUp(context, show, next, watchedAired, aired.length);
final upcoming = show.nextEpisodeToAir;
if (upcoming != null) return _caughtUp(context, show, upcoming);
return const SizedBox.shrink();
```

- `_nextUp` → gerçekten izlenebilir bölümü olan kart: poster + S/B rozeti +
  bölüm adı + izlendi butonu (checkbox).
- `_caughtUp` → "Her şeyi izledin, sıradaki bölüm 12 Mar'da" kartı — **farklı
  bir görsel format** (bölüm adı yok, sadece durum metni), ve **aksiyon
  gerektirmiyor** (checkbox yok).

İkisi aynı `ListView`'de art arda render edildiği için kullanıcı her kartı
okuyup "bu izlenebilir mi, yoksa bekleniyor mu?" diye ayırt etmek zorunda
kalıyor — tam olarak bildirdiğiniz sorun.

`_caughtUp` kartındaki gösterilen dizi zaten "Yaklaşan" sekmesinde de var:
`_upcomingItems` (aynı dosya) her takip edilen dizinin
`show.nextEpisodeToAir`'ını, izleme listesindeki filmlerin vizyon tarihiyle
birlikte tarihe göre sıralı tek bir listede zaten gösteriyor. Yani
`_caughtUp` kartını Sırada'dan kaldırmak **veri kaybı değil**, zaten var olan
bir mükerrerliği temizlemek.

### 1.2 Yeni davranış — wireframe

```
┌─ SIRADA ───────────────────────────────────────────┐
│                                                      │
│  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓   │  ← bugün çıkan bölüm:
│  ┃ [poster]  YENİ ✨                            ┃   │    vurgulu kenarlık +
│  ┃           From                               ┃   │    "YENİ" rozeti
│  ┃           S3B1 · "The Way Out"          ( ✓ ) ┃   │
│  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │  ← daha önce çıkmış,
│  │ [poster]                                      │   │    izlenmemiş bölüm
│  │           Severance                           │   │    (normal kenarlık)
│  │           S2B4 · "Woe's Hollow"        ( ○ )  │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ [poster]                                      │   │
│  │           The Bear                             │   │
│  │           S3B2 · "Doors"                ( ○ )  │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│           (yalnızca izlenebilir dizi kalmadıysa)     │
│              "Her şey güncel 🎉" boş durumu          │
└──────────────────────────────────────────────────────┘
```

Kurallar:

1. **Filtre**: Sırada'da yalnızca `_nextUp` dalına giren diziler kalır —
   yani `aired.where(!watched)` boş olmayan diziler. `_caughtUp` durumu
   tamamen listeden çıkar (Yaklaşan sekmesinde zaten var, bkz. 1.1).
2. **Sıralama**: tek anahtar — sıradaki izlenmemiş bölümün `airDate`'i,
   **azalan** (en yeni tarih en üstte). Bu, "bugün çıkanlar en üstte, sonra
   tarihe göre" isteğini tek kuralla karşılıyor: bugün yayınlanan bir bölüm
   olası en yeni tarih olduğu için otomatik en üste çıkar; geride kalan
   izlenmemiş bölümler de yine tarihe göre sırayla altına dizilir.
3. **Kart formatı tutarlılığı**: Sırada'da tek kart tipi kalıyor (`_nextUp`),
   dolayısıyla "bazı kartlarda sadece durum metni" tutarsızlığı kendiliğinden
   ortadan kalkıyor — ayrı bir "iki farklı formatı birleştir" işi gerekmiyor.
4. **Vurgu**: sıradaki bölümün `airDate`'i bugünse karta `context.colors.primary`
   renginde ince bir kenarlık + küçük bir "YENİ" rozeti eklenir (bkz. 1.3);
   diğer kartlar mevcut nötr görünümde kalır.
5. **Boş durum**: filtre sonrası liste boşsa (kullanıcı her şeyi izlemiş,
   hiçbir dizide bekleyen bölüm yok), `AsyncStateView`/mevcut boş-durum
   deseniyle "Her şey güncel 🎉" mesajı gösterilir — bu, önceden dolaylı
   olarak zaten oluyordu (tüm kartlar `_caughtUp`/shrink olduğunda liste
   seyrekleşiyordu), şimdi kasıtlı ve nettir.

### 1.3 Teknik implementasyon

**`_upNextView` sıralaması** (şu an "son izlenen önce, sonra takip sırası" —
bkz. `_ShowBundle` ve onu üreten sıralama bloğu): sıralama anahtarı
`lastWatchedAt`'tan, her `_ShowBundle`'ın **sıradaki izlenmemiş aired
bölümünün `airDate`'ine** değişir. `_ShowBundle`'a yeni bir alan eklenir:

```dart
class _ShowBundle {
  final TvShow show;
  final List<Episode> flat;
  final int watchedAiredCount;
  final DateTime? lastWatchedAt;
  final Episode? nextUnwatched;      // YENİ — filtre + sıralama anahtarı
  _ShowBundle(this.show, this.flat, this.watchedAiredCount,
      this.lastWatchedAt, this.nextUnwatched);
}
```

Bundle üretilirken (`_upNextView`'daki mevcut fold/map bloğunda):

```dart
Episode? nextUnwatched;
for (final e in aired) {
  if (!watched.contains(e.key)) { nextUnwatched = e; break; }
}
// filtre: nextUnwatched == null olan bundle'lar listeye hiç eklenmiyor
if (nextUnwatched == null) continue;
```

Sıralama:

```dart
bundles.sort((a, b) {
  final da = DateTime.tryParse(a.nextUnwatched!.airDate);
  final db = DateTime.tryParse(b.nextUnwatched!.airDate);
  if (da == null || db == null) return 0;
  return db.compareTo(da); // azalan: en yeni tarih en üstte
});
```

**`_NextUpCard` sadeleşmesi**: `build()` artık dallanmıyor, doğrudan
`_nextUp(...)` çağırıyor (çünkü `_caughtUp` dalına giren bundle'lar zaten
`_upNextView` seviyesinde filtrelendi). `_caughtUp` metodu tamamen silinir —
"Yaklaşan" sekmesindeki `_upcomingItems` zaten aynı bilgiyi (dizi +
sıradaki tarih) veriyor, tekrar yazmaya gerek yok.

**Vurgu (bugünkü bölüm)**: `_nextUp`'ın `Container` dekorasyonuna koşullu
`border` eklenir:

```dart
final isToday = _isToday(ep.airDate); // dosyada zaten var olan yardımcı
decoration: BoxDecoration(
  color: context.colors.surface,
  borderRadius: BorderRadius.circular(16),
  border: isToday
      ? Border.all(color: context.colors.primary, width: 1.4)
      : null,
),
```

`isPremiere` rozetinin yanına, `isToday` doğruysa küçük bir "YENİ" `Container`
rozeti eklenir (mevcut `isPremiere` rozetiyle aynı görsel dilde — dosyada
zaten `PREMIERE` etiketi için bir chip deseni var, aynısı kopyalanır).

**Yaklaşan sekmesi değişmiyor** — `_upcomingItems` zaten `nextEpisodeToAir`'ı
listeliyor; Sırada'dan çıkan diziler otomatik olarak sadece orada görünür
hale geliyor, ek kod gerekmiyor.

**Yeni l10n anahtarları**: `upNextNewBadge` ("YENİ"/"NEW"),
`upNextAllCaughtUpEmpty` (boş durum mesajı, mevcut `upNextAllCaughtUp`'tan
farklı — o tek kart içindi, bu tüm liste boş durumudur).

---

## Bölüm 2 — Bildirim Sistemi

### 2.1 Mevcut altyapı (neyin üzerine inşa edileceği)

- `lib/services/notification_service.dart`: FCM izin isteme, token kaydetme
  (`users/{uid}.fcmToken`), foreground'da local notification gösterme.
  **Bildirime dokununca ilgili sayfaya gitme yok** — bu, yeni bildirim
  türleri için eklenmesi gereken bir eksik (aşağıda 2.5'te ele alınıyor).
- `functions/src/index.ts`: **deploy edilmemiş bir iskelet** (dosyanın kendi
  yorumunda belirtiliyor — Blaze plana geçiş + Firebase CLI gerekiyor).
  Şu an `onNewFollower` ve `onNewActivity` var; `onNewActivity` her
  `activity` dokümanı oluştuğunda **anında ve filtresiz** tüm takipçilere
  push gönderiyor — ne tür bazlı açma/kapama var, ne "aynı içeriği izledin"
  ayrımı, ne gruplama.
- Tek FCM token, bildirim tercihi alanı yok (`users/{uid}` üzerinde).

### 2.2 (a) Yeni bölüm bildirimleri — wireframe + mantık

**Ayarlar ekranı** (`settings_screen.dart`'a yeni bir bölüm):

```
Bildirimler
┌────────────────────────────────────────────┐
│ Yarın çıkan bölümler              [ ●━━ ]  │
│ Bugün yayınlanan bölümler         [ ●━━ ]  │
│ ──────────────────────────────────────────  │
│ Arkadaş aktivitesi                [ ●━━ ]  │
│ Ortak içerik eşleşmesi            [ ●━━ ]  │
└────────────────────────────────────────────┘
```

Dört ayrı `SwitchListTile`, `users/{uid}` üzerindeki dört bool alanı
okuyup/yazıyor (varsayılan hepsi `true`).

**Veri modeli — `users/{uid}/shows/{showId}` dokümanına yeni alan:**

`TvTrackingService._metadata()` (tv_tracking_service.dart) her yazımda
zaten güncel bir `TvShow` nesnesi alıyor; tek eklenecek satır:

```dart
Map<String, dynamic> _metadata(TvShow show) => {
  ...
  'nextEpisodeAirDate': show.nextEpisodeToAir?.airDate ?? '',
};
```

Bu, TMDB'ye ekstra istek atmadan, kullanıcı zaten dizi ekrandayken/bir
bölüm işaretlerken doğal olarak tazeleniyor. Programlanmış (scheduled)
fonksiyonun sorgu atabilmesi için bu alanın **her kullanıcının her dizisinde**
var olması lazım — yani `collectionGroup('shows')` sorgusu.

**Cloud Functions — iki yeni scheduled fonksiyon:**

```ts
// functions/src/index.ts

export const notifyEpisodesAiringTomorrow = onSchedule(
  { schedule: "every day 09:00", timeZone: "Europe/Istanbul" },
  async () => {
    const tomorrow = isoDateOffset(1); // "2026-08-06" gibi
    const snap = await db
      .collectionGroup("shows")
      .where("nextEpisodeAirDate", "==", tomorrow)
      .get();
    for (const doc of snap.docs) {
      const uid = doc.ref.parent.parent!.id;
      const userSnap = await db.collection("users").doc(uid).get();
      if (userSnap.data()?.notifyEpisodeTomorrow === false) continue;
      await sendToUser(uid, "Yarın yeni bölüm",
        `${doc.data().name} yarın yeni bir bölümle dönüyor.`,
        { type: "episode-tomorrow", showId: String(doc.data().id) });
    }
  }
);

export const notifyEpisodesAiringToday = onSchedule(
  { schedule: "every day 20:00", timeZone: "Europe/Istanbul" },
  async () => {
    const today = isoDateOffset(0);
    const snap = await db
      .collectionGroup("shows")
      .where("nextEpisodeAirDate", "==", today)
      .get();
    for (const doc of snap.docs) {
      const uid = doc.ref.parent.parent!.id;
      const userSnap = await db.collection("users").doc(uid).get();
      if (userSnap.data()?.notifyEpisodeToday === false) continue;
      await sendToUser(uid, "Bugün yayında",
        `${doc.data().name} bugünkü yeni bölümüyle yayında! 🎬`,
        { type: "episode-today", showId: String(doc.data().id) });
    }
  }
);
```

Notlar:
- "Bugün yayında" saati **20:00** olarak seçildi çünkü TMDB bölüm bazında
  yayın **saatini** vermiyor, sadece tarih; akşam saatinde göndermek
  bölümün muhtemelen çoktan yayınlanmış olmasını garantiliyor. Bu değer
  kolayca ayarlanabilir bir sabit olmalı.
- `collectionGroup('shows')` sorgusu için Firestore konsolunda
  `nextEpisodeAirDate` alanına **collection-group scope** tek-alan indeksi
  açılması gerekiyor (ilk deploy'da Firestore hata mesajıyla otomatik link
  verir, `firestore.indexes.json`'a da eklenmeli).
- Bu iki fonksiyon **Cloud Scheduler** kullanır → projeyi Blaze plana
  taşımanın yanında Scheduler'ın da etkin olması gerekiyor (küçük ölçekte
  ücretsiz kotanın çok altında kalır, ama operasyonel bir ön koşul olarak
  not düşülmeli).

### 2.3 (b) Takipçi/arkadaş bildirimleri — öncelik ayrımı

**Mantık akışı** (`onNewActivity` fonksiyonu genişletiliyor):

```
activity dokümanı oluştu (movie/episode/season)
        │
        ▼
actor'ın her takipçisi için:
        │
        ├─ takipçi de aynı içeriği (movieId/showId) kendi
        │  kütüphanesinde takip ediyor/izliyor mu?
        │       (users/{followerUid}/movies/{movieId} VEYA
        │        users/{followerUid}/shows/{showId} var mı?)
        │
        ├─ EVET → "Ortak içerik eşleşmesi" — ANINDA, öncelikli push
        │          "Ahmet de Ted Lasso S4B1'i izledi 🎬"
        │          (notifySharedWatch açıksa)
        │
        └─ HAYIR → normal aktivite — ANINDA GÖNDERME, bunun yerine
                    users/{followerUid}.pendingActivityDigest içine
                    biriktir (bkz. 2.4)
                    (notifyFriendActivity açıksa)
```

```ts
export const onNewActivity = onDocumentCreated(
  "users/{uid}/activity/{activityId}",
  async (event) => {
    const actorUid = event.params.uid;
    const activity = event.data?.data();
    if (!activity) return;

    const actorSnap = await db.collection("users").doc(actorUid).get();
    const actorName = (actorSnap.data()?.name as string) || "Someone";
    const followers = (actorSnap.data()?.followers as string[] | undefined) ?? [];
    if (followers.length === 0) return;

    const contentId = activity.kind === "movie" ? activity.movieId : activity.showId;
    const contentCol = activity.kind === "movie" ? "movies" : "shows";
    const contentTitle = activity.kind === "movie" ? activity.title : activity.showName;

    for (const followerUid of followers.slice(0, 500)) {
      const followerSnap = await db.collection("users").doc(followerUid).get();
      const prefs = followerSnap.data() ?? {};

      const sharedDoc = await db
        .collection("users").doc(followerUid)
        .collection(contentCol).doc(String(contentId)).get();

      if (sharedDoc.exists && prefs.notifySharedWatch !== false) {
        await sendToUser(followerUid, "Ortak içerik!",
          `${actorName} de ${contentTitle} izledi.`,
          { type: "shared-watch", actorUid, contentId: String(contentId) });
        continue; // öncelikli bildirim gönderildi, digest'e eklenmiyor
      }

      if (prefs.notifyFriendActivity !== false) {
        await enqueueDigest(followerUid, actorName);
      }
    }
  }
);
```

### 2.4 (c) Bildirim gruplama / özet

**Veri modeli** — `users/{uid}` üzerinde tek bir map alanı:

```
pendingActivityDigest: {
  count: number,          // bugün biriken aktivite sayısı
  actorNames: string[],   // ilk 3 aktör adı (UI'da "Ahmet, Zeynep ve 1 kişi daha" için)
  firstAt: Timestamp,     // ilk biriken aktivitenin zamanı
}
```

```ts
async function enqueueDigest(uid: string, actorName: string) {
  const ref = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.data()?.pendingActivityDigest ?? { count: 0, actorNames: [] };
    tx.set(ref, {
      pendingActivityDigest: {
        count: current.count + 1,
        actorNames: [...new Set([...current.actorNames, actorName])].slice(0, 3),
        firstAt: current.count === 0 ? FieldValue.serverTimestamp() : current.firstAt,
      },
    }, { merge: true });
  });
}
```

**Flush (özet gönderimi) — scheduled fonksiyon:**

```ts
export const flushActivityDigests = onSchedule(
  { schedule: "every day 19:00", timeZone: "Europe/Istanbul" },
  async () => {
    const snap = await db.collection("users")
      .where("pendingActivityDigest.count", ">", 0)
      .get();

    for (const doc of snap.docs) {
      const digest = doc.data().pendingActivityDigest;
      const body = digest.count === 1
        ? `${digest.actorNames[0]} yeni bir şey izledi.`
        : `${digest.actorNames.slice(0, 2).join(", ")} ve ${digest.count - digest.actorNames.slice(0,2).length} kişi daha yeni aktivite paylaştı.`;

      await sendToUser(doc.id, "Arkadaş aktivitesi", body,
        { type: "activity-digest" });

      await doc.ref.set({
        pendingActivityDigest: { count: 0, actorNames: [], firstAt: null },
      }, { merge: true });
    }
  }
);
```

Notlar:
- **"Ortak içerik eşleşmesi" bildirimleri bu gruplamaya girmiyor** — kasıtlı
  olarak anında ve ayrık gönderiliyor, çünkü siz bunu "önceliğini normal
  takipçi aktivitesinden yüksek göster" diye belirttiniz; bir özete
  gömülürse önem kaybeder.
- Flush saati (19:00) `notifyEpisodeToday`'in 20:00'ından önce seçildi ki
  aynı akşam iki bildirim üst üste gelmesin; ince ayar gerekirse tek
  parametre.
- `count === 1` durumunda tek aktör adıyla özelleştirilmiş metin
  kullanılıyor (spam hissi vermesin diye "1 arkadaşının..." yerine
  doğal cümle).

### 2.5 Bildirime dokununca yönlendirme (eksik, eklenmesi gereken plumbing)

Şu an `notification_service.dart`'ta **tap handling yok** — sadece
foreground gösterim var. Yeni bildirim türlerinin hepsi (`episode-tomorrow`,
`episode-today`, `shared-watch`, `activity-digest`) `data` payload'ında
`showId`/`movieId`/`type` taşıyor; bunları ilgili sayfaya yönlendirmek için:

1. `main.dart`'a global bir `navigatorKey` (`GlobalKey<NavigatorState>`)
   eklenir (route'suz, context'siz navigasyon için).
2. `NotificationService.initialize()` içine eklenir:
   ```dart
   FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
   final initial = await _messaging.getInitialMessage(); // soğuk başlatma
   if (initial != null) _handleTap(initial);
   ```
3. `_handleTap(RemoteMessage message)`: `message.data['type']`'a göre
   `showId`/`movieId`'den minimal bir `MediaItem` kurup (TMDB'ye tek bir
   detay çağrısı ile, ya da mevcutsa doğrudan Firestore'daki show/movie
   dokümanından) `navigatorKey.currentState!.push(...)` ile `openMedia`
   benzeri bir yönlendirme yapar. `activity-digest` türü belirli bir
   içeriğe değil `FriendsActivityScreen`'e yönlendirilir (birden fazla
   kaynak olduğu için).

Bu, dört yeni bildirim türünün "kullanıcı dokununca ilgili sayfaya gitsin"
gereksinimini karşılamak için **zorunlu** bir ön koşul — mevcut kodda hiç
yok, sıfırdan eklenmesi lazım.

---

## Özet — Değişecek/Eklenecek Dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/screens/up_next_screen.dart` | `_ShowBundle`'a `nextUnwatched`, filtre+sıralama, `_caughtUp` silinir, "YENİ" vurgusu |
| `lib/services/tv_tracking_service.dart` | `_metadata()`'ya `nextEpisodeAirDate` |
| `lib/screens/settings_screen.dart` | "Bildirimler" bölümü, 4 `SwitchListTile` |
| `lib/services/notification_service.dart` | Tap-through handling (`onMessageOpenedApp`, `getInitialMessage`) |
| `lib/main.dart` | Global `navigatorKey` |
| `functions/src/index.ts` | `notifyEpisodesAiringTomorrow`, `notifyEpisodesAiringToday`, `flushActivityDigests` (yeni); `onNewActivity` (genişletilir) |
| `firestore.indexes.json` | `shows` collection-group, `nextEpisodeAirDate` indeksi |
| `lib/l10n/app_*.arb` | Yeni Sırada/bildirim metinleri |

## Operasyonel ön koşullar

- `functions/` şu an deploy edilmemiş — bu değişiklikler için ilk kez
  `firebase deploy --only functions` gerekecek, bu da **Blaze plan** +
  **Cloud Scheduler API etkin** ister (dosyanın kendi başlık yorumunda zaten
  belirtiliyordu, bildirim sistemi bu ön koşulu daha da gerekli kılıyor).
- Yeni `collectionGroup('shows')` sorgusu için Firestore'da collection-group
  indeksi açılmalı (ilk deploy sonrası konsol otomatik link verir).

---

*Bu doküman bir tasarım/plan dokümanıdır, henüz kod değişikliği
içermiyor — onayınızdan sonra Bölüm 1 (liste düzeni, düşük risk, şema
değişikliği yok) ve Bölüm 2 (bildirimler, Cloud Functions deploy + yeni şema
gerektiriyor) ayrı ayrı uygulanabilir.*

---

## Uygulama durumu (2026-08-05)

Bölüm 1 ve Bölüm 2'nin tamamı uygulandı. Tek fark: proje ücretsiz Spark
planında kaldığı ve Cloud Functions v2 deploy edilemediği için, Bölüm 2'nin
sunucu tarafı bu dokümandaki gibi `functions/src/index.ts` üzerinden değil,
**tamamen ücretsiz bir GitHub Actions cron job** olarak canlıya alındı:

- `scripts/notify/run.js` — aynı mantık (bölüm hatırlatmaları, ortak izleme,
  günlük özet; sonradan eklenen izleme listesi film çıkışları), bağımsız bir
  Node script olarak.
- `.github/workflows/notifications.yml` — günde 4 sabit saat + saatte bir
  (her saat :20) aktivite taraması (2026-10-15'e kadar 30 dakikada birdi;
  ücretsiz Actions dakikaları için seyreltildi).
- Kimlik doğrulama: Firebase servis hesabı anahtarı, GitHub'da şifreli
  `FIREBASE_SERVICE_ACCOUNT` secret'i olarak saklanıyor.
- Tek davranış farkı: `onNewActivity`'nin anlık tetiklenmesi yerine, ortak
  izleme/özet bildirimleri en fazla 30 dakikalık bir gecikmeyle işleniyor
  (bkz. `system/notificationCursor` imleci).

`functions/src/index.ts`'teki kod hâlâ duruyor (gelecekte Blaze'e geçilirse
kullanılabilir) ama şu an devre dışı — ikisinin aynı anda çalışması her
bildirimi iki kez gönderir, bu yüzden `functions/README.md`'de uyarı var.
