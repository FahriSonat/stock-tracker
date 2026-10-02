# Stok Pilot

Türkçe Flutter stok takip uygulaması. Android, iOS, Windows ve web proje dosyaları dahildir. Flutter 3.47.5 / Dart 3.13.4 ile geliştirilmiş ve web release derlemesi alınmıştır.

## Başlatma

```sh
flutter pub get
flutter run -d chrome
```

Telefon için `flutter devices` ile cihazı bulun ve `flutter run -d CIHAZ_ID` çalıştırın. Android için Android SDK, iOS için macOS ve Xcode, Windows derlemesi için Visual Studio C++ araçları gerekir.

İlk açılışta kendi yönetici hesabınızı oluşturun. Hazır veya sabit parola yoktur. Genel bakış ekranındaki **Örnek ürünlerle keşfet**, yalnızca boş yerel çalışma alanına açıkça etiketlenmiş örnek veriler ekler. Gerçek stok için **Yeni ürün** ardından ürün detayındaki **Giriş / çıkış** ile başlayın. Ayarlar > Çalışan ekle ile yerel personel hesapları oluşturulur.

## Özellikler

- Ürün adı, stok kodu, kategori, birim, alış maliyeti ve düşük stok eşiği.
- Kim, ne zaman, ne kadar bilgisiyle kalıcı stok giriş/çıkış ve ürün düzenleme geçmişi. Eksi stok ve geçersiz miktarlar engellenir.
- Eşik dahil düşük stok uyarısı, uygulama içi liste ve izin verildiğinde Android/iOS/Windows cihaz bildirimi. Stok yeniden yükselip eşiği geçene kadar aynı ürün için bildirim tekrarlanmaz.
- `fl_chart` ile stok değeri zaman grafiği ve en çok tüketilen ilk beş ürün.
- Seçilen ayın açılış/kapanış stok değeri, giriş/çıkış maliyeti, hareket listesi ve tüketim özeti.
- Gerçek `.xlsx` çalışma kitabı: aylık özet, güncel ürünler, dönem hareketleri ve dönem tüketimi sayfaları. UTF-8 BOM ve noktalı virgüllü CSV; metinlerde formül enjeksiyonu önlemi. Rapor ekranındaki indirme düğmeleri dosya kaydetme akışını açar.
- Hive ile çevrimdışı stoklar, hesaplar, tercihler ve kalıcı senkronizasyon kuyruğu.
- Ürün/stok kodu/kategori araması; Enter ile son sekiz arama kaydedilir. Kullanıcıya özel arama geçmişi ve son eklenen ürünler.
- Yönetici: ürün/maliyet/eşik ve yerel çalışan yönetimi. Çalışan: görüntüleme, yalnızca stok çıkışı ve rapor dışa aktarma. Stok girişini yalnızca admin yapar. Servis katmanında da yetki kontrolü vardır.
- Son 30 günlük çıkış / gözlenen gün sayısı ile tüketim ortalaması ve tahmini tükenme tarihi. Tüketim yoksa veya tahmin 100 yılı aşıyorsa tarih gösterilmez.
- Kalıcı açık/koyu tema; telefonlarda alt menü, geniş ekranlarda yan menü.

Değerler TL alış maliyetidir; ciro, satış fiyatı veya kâr hesabı yapılmaz. Farklı birimlerdeki ürünler kendi birimleriyle gösterilir. Ürün maliyeti değişince eldeki stok yeniden değerlenir ve fark tarihçeye kaydedilir. Ürün silme yerine hareketlerle düzeltme yaklaşımı kullanılır.

## Supabase bağlantısı

Yerel mod herhangi bir bulut hesabı gerektirmez. Bulut modunu açmak için:

1. Kendi Supabase projenizde SQL Editor üzerinden `supabase/schema.sql` dosyasını bir kez çalıştırın.
2. Authentication > Users üzerinden yönetici ve çalışan hesaplarını oluşturun. Parolaları kullanıcılarınız belirlesin; e-posta doğrulama ayarınızı tamamlayın.
3. SQL Editor üzerinden bir çalışma alanı ve bu hesapların profillerini ekleyin. Aşağıdaki UUID alanlarını gerçek değerlerle değiştirin:

```sql
insert into public.workspaces(name) values ('İşletmem') returning id;

insert into public.profiles(id, workspace_id, name, role)
values ('AUTH_KULLANICI_UUID', 'CALISMA_ALANI_UUID', 'Yönetici adı', 'admin');

-- Diğer kullanıcılar için role = 'staff' kullanın.
```

4. `config.example.json` dosyasını `config.json` olarak kopyalayıp proje URL ve publishable/anon anahtarını ekleyin. **Service-role anahtarını istemciye koymayın.**

```sh
flutter run -d chrome --dart-define-from-file=config.json
flutter build apk --dart-define-from-file=config.json
```

Yerel çalışma alanı ile bulut verileri ayrı Hive kutularındadır. Yerel örnek veriler otomatik olarak buluta taşınmaz. Bulut kullanıcı yönetimi Supabase panelinden yapılır; uygulama kullanıcıların kendi rolünü değiştirmesine izin vermez.

## Senkronizasyon davranışı

- İlk bulut girişi çevrimiçi olmalıdır. Son başarılı çevrimiçi girişten itibaren yedi gün boyunca aynı cihazda parolayla çevrimdışı giriş yapılabilir. Giriş ekranında Çevrimdışı giriş seçilir.
- Açık uygulamada 30 saniyede bir, uygulamaya dönüldüğünde ve yerel kayıt sonrası senkronizasyon denenir. Ayarlardan elle de başlatılabilir. Uygulama kapalıyken arka plan sync/push servisi yoktur.
- Her işlem benzersiz UUID taşır. Kuyruk stokla birlikte tek Hive kaydında saklanır; HTTP cevabı kaybolsa da tekrar gönderim sunucuda mükerrer stok oluşturmaz.
- Sunucu aktörü oturumdan, rolü aktif profilden ve maliyeti kendi verisinden alır. RLS ve yalnızca yetkili RPC erişimi uygulanır. Çalışma alanı bazında işlem kilidi eksi stok yarışını engeller.
- Ürün düzenlemeleri sürüm kimliği ile kontrol edilir. Çakışan değişiklikler sessizce üzerine yazılmaz. Başarısız işlem kuyrukta görünür ve stoklar sunucu onayına kadar geçicidir.
- Çakışmada Ayarlar ekranından bekleyen kayıtları inceleyin. **Bekleyenleri iptal et ve sunucu verisini al** onayından sonra kabul edilmiş sunucu kayıtları alınır; iptal edilen öneriler cihazda `rejected_*` anahtarları altında arşivlenir. Gerekli hareketleri güncel stok üzerinden yeniden girin. Bağlantı başarısızsa kuyruk korunur.
- Kuyruktaki işlemleri yalnızca işlemi yapan kullanıcı gönderir veya iptal eder. Paylaşılan cihazlarda kullanıcı değiştirmeden önce senkronizasyonu tamamlayın.
- Bulut geçmişindeki tarih sunucunun kabul zamanıdır. Cihazın özgün zamanı `stock_events.doc.deviceAt` içinde korunur; gecikmiş çevrimdışı işlemler kabul edildikleri ayın raporuna girer.
- Bir RPC ile tutarlı tam çalışma alanı anlık görüntüsü alınır; REST varsayılan satır sınırı nedeniyle tarihçe kesilmez. Büyük veri hacimleri için sayfalı artımlı senkronizasyon ayrıca tasarlanmalıdır.

## Veri ve platform sınırları

Yerel parolalar rastgele tuz ve 210.000 turlu PBKDF2-HMAC-SHA256 ile özetlenir. Yerel Hive stok dosyaları şifreli değildir; yerel rol sistemi cihaz dosyalarına erişebilen bir saldırgana karşı güvenlik sınırı değildir. Bulut yazma yetkileri sunucuda doğrulanır. Çevrimdışıyken bir rol iptalini cihaz anında öğrenemez; bağlantı kurulunca sunucu işlemi reddeder.

Native uygulamalar internet olmadan açılıp çalışır. Web'de veriler tarayıcının IndexedDB alanındadır; tarayıcı verilerini temizlemek yerel kayıtları siler. Web sayfasının ağsız ilk açılışı desteklenmez. Web'de işletim sistemi bildirimi yerine uygulama içi düşük stok uyarıları kullanılır. Cihaz bildirimleri stok işlemleri ve uygulama açıkken sync sırasında üretilir; işletim sistemi izni gerektirir.

Android bildirim izni, simgesi, internet izni ve desugaring yapılandırması eklenmiştir. iOS bildirim delegesi ve Windows başlatma ayarları eklenmiştir. Fiziksel Android/iOS/Windows cihaz bildirimi ve native release derlemeleri bu ortamda doğrulanmamıştır. Android release imzası Flutter başlangıç yapılandırmasında debug anahtarıdır; mağazaya çıkmadan önce kendi imzanızı yapılandırın.

Bu teslimde gerçek bir Supabase hesabına bağlanılmadı. SQL işlevleri PGlite üzerinde PostgreSQL davranışıyla test edildi; kendi projenizde iki kullanıcı/iki cihazla bağlantı kesme, tekrar bağlanma, yetki iptali ve çakışma kabul testlerini tamamlayın.

## Kod yapısı ve doğrulama

- `lib/domain.dart`: ürün/hareket modeli, değerleme, tüketim ve tahmin.
- `lib/store.dart`: Hive, hesaplar, işlem doğrulama ve sync kuyruğu.
- `lib/ui.dart`: Türkçe ekranlar ve formlar.
- `lib/notifications.dart`: cihaz bildirim adaptörü.
- `lib/export.dart`: Excel/CSV rapor üretimi.
- `supabase/schema.sql`: tablolar, RLS, yetkili ve tekrar gönderime dayanıklı RPC.
- `test/`: hesaplama, kalıcılık, roller, parolalar, bildirim eşikleri, CSV, arama ve 390/1440 piksel ekran testleri.

```sh
flutter analyze
flutter test
flutter build web --release
```

Paket sürümleri `pubspec.lock` ile sabitlenmiştir. Kullanılan API belgeleri: [fl_chart](https://pub.dev/packages/fl_chart), [yerel bildirimler 19.5](https://pub.dev/packages/flutter_local_notifications/versions/19.5.0), [dosya kaydetme](https://pub.dev/packages/file_saver), [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).

SQL testlerini tekrar çalıştırmak için:

```sh
cd supabase/tests
npm ci
npm test
```

Güncel teslim kontrolleri: 16 Flutter testi geçti; `flutter analyze` hata/uyarı üretmedi; web release derlemesi başarılı. SQL testleri tekrar gönderim, çalışan yetkileri, sunucuda aktör/maliyet doğrulama, yetersiz stok, sürüm çakışması, çalışma alanı ayrımı ve üyelik iptalini kapsar.


## 29 Eylül güncellemesi: kritik sınır, admin mesajı ve dondurma

Admin, Yeni ürün / Ürünü düzenle ekranından her ürünün stok birimini (adet, kg, lt, gram; eski kayıtlardaki birimler de korunur) ve kritik sınırını belirler. Ondalık değerler desteklenir. Kritik sınır seçilen stok birimindedir: örneğin 2,5 kg veya 500 gram. Kritik sınır uyarı üretir; otomatik işlem kilidi değildir. Stok miktarı sıfır değilken birim değiştirilemez; otomatik kg/gram dönüşümü yapılmaz.

- Stok girişini yalnızca admin yapar. Çalışan yalnızca çıkış yapabilir; ürün, birim, maliyet, kritik sınır, mesaj veya kilit ayarını değiştiremez.
- Admin ürün başına tüm kullanıcılara görünen bir mesaj bırakabilir: örneğin “Bu ürünü kullanmayın; kalite kontrol bekleniyor.” Mesaj tek başına işlemi engellemez.
- **Stok işlemlerini dondur** seçeneği admin dahil herkes için ürünün giriş ve çıkışını kapatır. Admin önce Ürünü düzenle ekranından kilidi kaldırmalıdır. Stok miktarı, ürün bilgisi ve mesaj görünür kalır.
- Dondurma listede, detayda ve işlem penceresinde belirgin gösterilir. Dondurulanlar filtresi eklendi. Açık işlem pencereleri de güncel kilide tepki verir; ayrıca kayıt anında güncel üründen yeniden doğrulama yapılır.
- Mesaj, dondurma, yeniden açma ve kritik sınır değişiklikleri yerel hareket geçmişine kaydedilir. Excel/CSV güncel ürün tablosunda mesaj ve işlem durumu bulunur.
- Eski Hive kayıtları mesaj yok / dondurulmamış olarak açılır. Kullanıcı verileri sıfırlanmaz.

### Mevcut Supabase kurulumunu güncelleme

Mevcut veritabanında `supabase/migrations/20260929_product_controls.sql` dosyasını SQL Editor üzerinden çalıştırın. Bu dosya tabloları silmeden işlem fonksiyonunu günceller; tekrar çalıştırılabilir. İlk kurulumda güncel `supabase/schema.sql` yeterlidir. Uygulama ve sunucu güncellemesi birlikte uygulanmalıdır; eski sunucu yeni yetki kurallarını bilmez.

Sunucu giriş yetkisini ve güncel ürün kilidini kontrol eder. Eski uygulama sürümü de sunucu kurallarını aşamaz; kontrol alanlarını göndermeyen eski bir admin istemcisi mevcut kilidi/mesajı sessizce kaldıramaz.

Çevrimdışı bir cihaz başka cihazdaki yeni dondurmayı anında öğrenemez. Bağlantı geldiğinde önce güncel kilit ve mesajlar alınır; dondurulmuş ürüne ait bekleyen hareket sunucuda reddedilir. Öneri kuyrukta görünür, sunucu stoğunu değiştirmez. Ürün fiziksel olarak kullanılmadan önce tüm cihazların senkronize olması gerekir. Cihazlar arasındaki bu sınır yerel kilit kontrollerinden bağımsızdır.

29 Eylül doğrulaması: admin giriş yetkisi, her iki rol için dondurma, eski istemci uyumluluğu, mesajların aktarılması, stok varken birim değişikliği engeli ve adminin kilidi kaldırması SQL testlerinde doğrulandı. Açık çalışan işlem penceresinin yeni kilide tepki vermesi de widget testiyle kontrol edildi.
