# CORE Portal

ASP.NET Core MVC tabanlı topluluk, etkinlik ve Ar-Ge proje yönetimi uygulaması. .NET 10, EF Core, PostgreSQL, Identity ve Bootstrap 5 kullanır.

## Özellikler

- Ana sayfada topluluk özeti, son duyurular ve yaklaşan etkinlikler; Hakkımızda sayfası.
- Takım, proje, etkinlik ve duyurular için liste/detay sayfaları ve arama. Takımlarda alan, projelerde takım/durum, etkinliklerde geçmiş/yaklaşan filtresi.
- Kayıt, giriş, çıkış; `Admin` ve `Member` rolleri.
- Takım ve etkinlik başvuruları; kullanıcıya ait başvuru durumlarını gösteren, ad/bölüm bilgilerinin düzenlenebildiği `/profile` ekranı.
- Takım/etkinlik detaylarında kişisel başvuru durumu; mevcut başvuru varsa tekrar başvuru çağrısı yerine profil bağlantısı. Ziyaretçiler girişten sonra uygun detay veya form sayfasına döner.
- Admin panelinde takım, proje, etkinlik ve duyuru CRUD; takım/etkinlik başvurularını onaylama, reddetme veya beklemeye alma.
- Events ve Projects için JSON CRUD API; Development ortamında Swagger UI.
- Ayarlanabilir GitHub REST API bağlantısı ile herkese açık depoların listelenmesi.

## Gerekenler

- .NET 10 SDK ve çalışan PostgreSQL (yerel doğrulamada PostgreSQL 18 kullanıldı).
- İlk paket indirme için NuGet erişimi.
- Test betikleri için PowerShell 7.

## Veritabanı ve yapılandırma

PostgreSQL yönetim aracında, yeterli yetkisi bulunan bir hesapla uygulamaya özel kullanıcı ve boş veritabanı oluşturun. Örnek parolayı değiştirin:

```sql
CREATE ROLE core_portal WITH LOGIN PASSWORD 'YOUR_LOCAL_PASSWORD';
CREATE DATABASE core_portal OWNER core_portal;
```

Proje kökünde PowerShell açın. Gerçek bağlantı bilgilerini veya parolaları kaynak dosyalara yazmayın:

```powershell
$env:ConnectionStrings__DefaultConnection = 'Host=localhost;Port=5432;Database=core_portal;Username=core_portal;Password=YOUR_LOCAL_PASSWORD'
$env:BootstrapAdmin__Email = 'admin@example.test'
$env:BootstrapAdmin__Password = 'CHOOSE_A_LONG_RANDOM_PASSWORD'
dotnet restore src/CorePortal.Web/CorePortal.Web.csproj
dotnet build src/CorePortal.Web/CorePortal.Web.csproj
dotnet run --project src/CorePortal.Web/CorePortal.Web.csproj --launch-profile http
```

Yerel `http` profili `http://localhost:5201` adresini kullanır. Terminaldeki dinleme adresini esas alın. `/account/login` üzerinden başlangıç Admin hesabıyla giriş yapıp `/admin` ekranını açın. Normal kayıtlar `Member` olur. Yeni veritabanı başlangıçta boş iş tabloları içerir; içerikleri Admin panelinden ekleyin.

Uygulama açılırken `DbSeed`, bekleyen EF migration'larını uygular ve rolleri yoksa oluşturur. Dolayısıyla veritabanı erişimi ve migration uygulama yetkisi açılışta gereklidir. BootstrapAdmin ayarları yoksa yönetici oluşturulmaz. Verilen e-posta sıradan bir kullanıcı hesabına aitse o hesap otomatik yükseltilmez; başka başlangıç e-postası seçin. Mevcut Admin'in parolası her açılışta yeniden atanmaz.

Migration'ı elle uygulamak veya yeni migration üretmek için kökteki araç manifestini kullanabilirsiniz:

```powershell
dotnet tool restore --tool-manifest dotnet-tools.json
dotnet tool run dotnet-ef database update --project src/CorePortal.Web --startup-project src/CorePortal.Web
# Bir entity şeması değiştirildiyse:
dotnet tool run dotnet-ef migrations add ChangeName --project src/CorePortal.Web --startup-project src/CorePortal.Web
```

Bu geliştirme mevcut tablolardan yararlanır; yeni migration gerektirmez. Üretimde migration yetkilerini ve dağıtım sırasını ayrıca planlayın. HTTPS kullanın ve gerçek sırları ortam/secret yönetimiyle sağlayın.

## GitHub bağlantısı

```powershell
$env:GitHub__Owner = 'YOUR_PUBLIC_GITHUB_OWNER'
$env:GitHub__OwnerType = 'user' # veya organization
```

Ayar boşsa dış çağrı yapılmaz. Yalnızca kimlik doğrulamasız erişilebilen açık depolar, en fazla 30 kayıt olarak istenir. Ağ hataları/hız sınırı listeyi etkileyebilir. Yerel proje kayıtlarıyla GitHub depoları otomatik senkronize edilmez.

## İş kuralları

- Aynı kullanıcı aynı takım veya etkinliğe yalnızca bir kez başvurabilir; reddedilmiş başvuru da bu kurala dahildir.
- Etkinlikte bekleyen ve onaylı başvurular kontenjana sayılır. Ret kontenjanı boşaltır. Reddedilen başvurunun yeniden etkinleştirilmesi kapasite uygunsa mümkündür.
- Başvuru, başvuru kararı ve etkinlik kapasitesi güncellemeleri kontenjanı korumak için Serializable transaction kullanır. Çakışmada yeniden deneme mesajı/HTTP 409 dönebilir.
- Profil ekranı sadece oturum açan kişinin kayıtlarını yükler. Kullanıcı profil formundan rol veya başvuru durumu değiştiremez.
- Duyurular kaydedildiğinde yayımlanır; yazar ve ilk yayın tarihi sunucuda atanır. Duyuru içeriği HTML olarak çalıştırılmaz, düz metindir.
- Admin etkinlik formundaki tarih sunucunun yerel saatine göre yorumlanır ve UTC saklanır. Sunucu saat dilimini yerel dağıtımda `Türkiye Standard Time`/`Europe/Istanbul` olarak uygun platform üzerinden ayarlayın. API tarihleri UTC `Z` ister.
- Takım silmek bağlı proje ve başvuruları; etkinlik silmek bağlı etkinlik başvurularını siler. Ekranlardaki onay mesajlarını dikkate alın.

## API

| Kaynak | Okuma | Admin yazma |
| --- | --- | --- |
| Events | `GET /api/events`, `GET /api/events/{id}` | `POST /api/events`, `PUT /api/events/{id}`, `DELETE /api/events/{id}` |
| Projects | `GET /api/projects`, `GET /api/projects/{id}` | `POST /api/projects`, `PUT /api/projects/{id}`, `DELETE /api/projects/{id}` |

Development ortamında `/swagger` açılır. Aynı tarayıcı ve aynı sunucu adresinde Admin girişi yaparak yazma işlemlerini deneyin; bağımsız terminal isteği tarayıcı cookie'sini kullanmaz. Ayrı JWT sistemi yoktur. Anonim yazma 401, Member yazma 403 alır. Model doğrulama 400, bulunamayan kayıt 404, kontenjan/işlem çakışması 409 üretebilir.

## Doğrulama

Uygulamayı ayrı bir **deneme veritabanıyla** çalıştırın; betikler veri oluşturur, bütün kayıtları kendileri temizlemez.

```powershell
./tests/Smoke.ps1 -BaseUrl 'http://localhost:5201' -AdminEmail 'admin@example.test' -AdminPassword $env:BootstrapAdmin__Password
./tests/PortalFlows.ps1 -BaseUrl 'http://localhost:5201' -AdminEmail 'admin@example.test' -AdminPassword $env:BootstrapAdmin__Password
```

İlk betik mevcut kimlik, takım/proje, başvuru ve API akışlarını; ikinci betik yeni içerik yönetimi, profil sahipliği, kararlar, kontenjan, filtreler, geçersiz istekler ve yetki korumalarını sınar. Testler yoğun yük veya tüm güvenlik durumlarının kapsamlı değerlendirmesi değildir. Mobil kontrol için tarayıcıda 375/390 piksel genişlikte menü, filtreler, profil ve yönetim tablolarını inceleyin.

### Otomatik geçici test ortamı

Windows ve PowerShell 7'de, .NET SDK ve PostgreSQL araçları PATH'teyse aşağıdaki komut tüm yerel kabul akışını çalıştırır. Öncesinde projedeki paketleri `dotnet restore` ile indirmiş olun:

```powershell
./tests/Invoke-LocalAcceptance.ps1
# Araçlar PATH'te değilse çalıştırılabilir dosya/klasör yollarını belirtin:
./tests/Invoke-LocalAcceptance.ps1 -DotnetPath 'C:\path\to\dotnet.exe' -PostgresBin 'C:\Program Files\PostgreSQL\18\bin'
```

Bu yardımcı projeyi derler, `.localtest/acceptance-...` altında ayrı PostgreSQL kümesi oluşturur, yalnızca 127.0.0.1 üzerinde kullanılabilir portlarla uygulamayı açar, rastgele parolalı geçici Admin oluşturur ve iki betiği çalıştırır. Bitince uygulamayı ve test kümesini kapatır; yalnızca kendisinin oluşturduğu test klasörünü siler. Mevcut veritabanına bağlanmaz. Süreç için değiştirdiği ortam ayarlarını geri yükler. Hata incelemesi için `-KeepArtifacts` verilirse süreçler durdurulur ama loglar ve test kümesi dosyaları korunur. Çalışan gerçek uygulamanız aynı derleme çıktısını kullanıyorsa önce onu durdurun.

PortalFlows; detay sayfalarında Pending/Approved/Rejected durumlarını, başvuru durumunun başka kullanıcıya gösterilmemesini, giriş dönüşünü ve karar sonrası yönetici filtresinin korunmasını da doğrular. Aynı etkinlikteki son yer için iki paralel istek göndererek tek aktif kayıt oluştuğunu kontrol eder.

## Örnek verilerle yerel gösterim

Windows ve PowerShell 7 üzerinde PostgreSQL araçları kuruluysa:

```powershell
./scripts/Start-LocalDemo.ps1
# Gerekirse araç yollarını açıkça verin:
# ./scripts/Start-LocalDemo.ps1 -DotnetPath 'C:\path\to\dotnet.exe' -PostgresBin 'C:\Program Files\PostgreSQL\18\bin'
```

Komut uygulamayı ayrı bir yayın klasörüne hazırlar ve bağımsız PostgreSQL kümesiyle yalnızca `127.0.0.1` üzerinde açar. .NET SDK PATH'te değilse daha önce bu proje için kurulan `%LOCALAPPDATA%/core-portal-dotnet/dotnet.exe` konumunu da kontrol eder. PostgreSQL araçları PATH'te değilse `-PostgresBin` belirtin. Önceki paketler için `dotnet restore` gerekir. Çalışan demonun yayın çıktısı ayrıdır; normal kaynak kodunu derlerken demo dosyaları kilitlemez.

Adres ve rastgele üretilen Admin/öğrenci giriş bilgileri `.localdemo/current.json` içindedir. Bu klasör Git tarafından dışlanır. Sayfada örnek verilerle çalışıldığını belirten bir etiket gösterilir. Etiket yalnızca Development ortamında `Demo__Enabled=true` olduğunda açılır; standart kurulumda kapalıdır. Örnek kayıtlar gerçek topluluk duyurusu veya etkinliği değildir.

Demoda 2 takım, 3 proje, 2 yaklaşan/1 geçmiş etkinlik ve 2 duyuru bulunur. Öğrenci hesabının bir takım başvurusu onaylı, bir etkinlik başvurusu beklemededir. Başlatıcı mevcut veritabanınıza bağlanmaz; ayarladığı süreç ortam değişkenlerini dönüşte geri yükler. İkinci kez başlatma, önceki demo kapatılana kadar engellenir.

```powershell
./tests/Test-LocalDemo.ps1 # Açık demonun içerik ve hesaplarını doğrular
./scripts/Stop-LocalDemo.ps1 # Demo süreçlerini kapatır ve örnek verileri temizler
# Log/veritabanı dosyalarını inceleme amacıyla korumak için:
# ./scripts/Stop-LocalDemo.ps1 -KeepFiles
```

Kapatma komutu normalde demo üzerinde yaptığınız değişiklikleri de siler; tekrar başlatmak yeni örnek ortam oluşturur. `-KeepFiles` bir yeniden başlatma mekanizması değildir; durdurulmuş dosyaları inceleme için saklar. Kısa bir sunum yolu için `docs/Gosterim_Akisi.md` belgesine bakın.

## Kaynak haritası

`Program.cs`: servisler, kimlik, yönlendirme. `Models`: entity, form ve ViewModel sınıfları. `Data`: DbContext, migration, seed ve çakışma tanıma. `Controllers`: MVC/API istekleri. `Views`: Razor HTML şablonları. `Services`: GitHub istemcisi. `wwwroot`: CSS/JavaScript. `docs`: faz belgeleri ve başlangıç öğrenme rehberi.

Önceki faz belgeleri ve öğrenme rehberi, hazırlanma tarihindeki başlangıç sürümünü anlatır. Yeni ekranlar için bu README ve `docs/Portal_Tamamlama_Notlari.md` güncel kaynaktır. Dersin Drive, video, public depo ve her öğrencinin kendi hesabından katkı şartları ayrıca takip edilmelidir.
