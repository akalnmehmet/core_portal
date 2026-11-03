# Mehmet Akalın geliştirme notları

Plan belgesinde Mehmet Akalın'a verilen yazılım işlerinin bu klasördeki karşılığı aşağıdadır. Proje .NET 10, ASP.NET Core MVC, EF Core ve PostgreSQL kullanır.

Ayrıntılı teknik dokümanlar: [Faz 1 Altyapı Veritabanı ve Kimlik](Faz_1_Altyapi_Veritabani_Kimlik_Teknik_Dokuman.md), [Faz 2 MVC Başvurular ve Yönetim](Faz_2_MVC_Basvurular_Yonetim_Teknik_Dokuman.md), [Faz 3 API GitHub ve Doğrulama](Faz_3_API_GitHub_Dogrulama_Teknik_Dokuman.md).

| Hafta | Sorumluluk | Kod karşılığı |
| --- | --- | --- |
| 1 | Mimari ve veritabanı bağlantısı | `src/CorePortal.Web`, `ApplicationDbContext`, PostgreSQL bağlantısı ve `InitialPostgres` migration |
| 2 | Identity ve roller | Kayıt, giriş, çıkış, `Admin` ve `Member` rolleri, güvenli admin başlangıç hesabı |
| 3 | Takım ve proje modülü | Liste ve detay sayfaları |
| 4 | Etkinlik başvurusu ve doğrulama | Tekil başvuru, tarih ve kontenjan kontrolü, antiforgery doğrulaması |
| 5 | Admin altyapısı ve takım/proje CRUD | Rol korumalı panel ve takım/proje formları |
| 6 | Takım başvuru akışı | Motivasyon ve yetkinlik formu, tekrar başvuru engeli |
| 7 | Events ve Projects REST API | GET, POST, PUT, DELETE; Swagger UI geliştirme ortamında `/swagger` |
| 8 | GitHub API entegrasyonu | `GitHubRepositoryService`; yapılandırılan hesap depolarını proje sayfasında listeler |
| 9 | Test ve gösterim | `tests/Smoke.ps1` gerçek PostgreSQL üzerinde rol, başvuru, kontenjan ve API yaşam döngüsünü sınar |

## Çalıştırma

1. PostgreSQL'de `core_portal` veritabanını ve erişim sahibi kullanıcıyı oluşturun.
2. Bağlantı dizesini `ConnectionStrings__DefaultConnection` ortam değişkeniyle verin. Depodaki `appsettings.json` yerel geliştirme için örnektir; gerçek parolayı dosyaya yazmayın.
3. İlk Admin hesabı için `BootstrapAdmin__Email` ve `BootstrapAdmin__Password` ortam değişkenlerini ayarlayın. Bu değerler yoksa yalnızca roller oluşturulur. Mevcut sıradan hesap bu yöntemle Admin'e yükseltilmez.
4. Gerekirse GitHub hesap adını `GitHub__Owner`, hesap türünü `GitHub__OwnerType` (`user` veya `organization`) olarak ayarlayın. CORE'un gerçek depo sahibi plan belgesinde belirtilmediği için varsayılan hesap seçilmedi.
5. `dotnet restore src/CorePortal.Web/CorePortal.Web.csproj` ve `dotnet run --project src/CorePortal.Web/CorePortal.Web.csproj` komutlarını çalıştırın. Migration uygulama açılırken uygulanır.

Örnek PowerShell ayarları:

```powershell
$env:ConnectionStrings__DefaultConnection = 'Host=localhost;Port=5432;Database=core_portal;Username=core_portal;Password=YOUR_PASSWORD'
$env:BootstrapAdmin__Email = 'admin@example.com'
$env:BootstrapAdmin__Password = 'CHOOSE_A_LONG_RANDOM_PASSWORD'
$env:GitHub__Owner = 'CORE_GITHUB_OWNER'
$env:GitHub__OwnerType = 'organization'
dotnet run --project src/CorePortal.Web/CorePortal.Web.csproj
```

## Entegrasyon notları

Tarık'ın sorumluluğundaki vitrin, duyuru CRUD, başvuru onay/red, profil, filtreleme ve son README düzenlemesi bu temelin üzerine eklenebilir. Veri tabloları ve ilişkileri hazırdır. Proje klasöründe başlangıçta yalnızca plan belgesi vardı; oluşturulan kaynak kodu plan belgesindeki GitHub deposunun `main` dalına gönderildi.
