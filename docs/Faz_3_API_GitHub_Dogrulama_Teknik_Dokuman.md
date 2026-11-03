# CORE Portal Faz 3 Teknik Dokümanı

## REST API GitHub Bağlantısı ve Sistem Doğrulaması

**Kapsam:** Plan belgesinin 7–9. haftasında Mehmet Akalın'a verilen Events ve Projects REST API geliştirme, GitHub REST API bağlantısı, sistem testleri ve gösterim hazırlığı. Bu doküman 3 Kasım 2026 tarihindeki kod durumunu açıklar.

## 1. Fazın çıktısı

Etkinlikler ve projeler için JSON tabanlı CRUD uç noktaları eklendi. Okuma işlemleri herkese açıktır; yazma işlemleri `Admin` rolü ister. Swagger UI yalnızca geliştirme ortamında etkinleştirilmiştir. Proje listesi, yapılandırılmış bir GitHub kullanıcı veya kuruluş hesabının herkese açık depolarını harici API'den alabilir. Gerçek PostgreSQL üzerinde tekrar edilebilir bir uçtan uca smoke test hazırlandı.

## 2. REST API sözleşmesi

| Kaynak | Yöntem ve yol | Yetki | Başarılı yanıt |
| --- | --- | --- | --- |
| Etkinlik listesi | `GET /api/events` | Herkes | `200` ve JSON dizi |
| Etkinlik detayı | `GET /api/events/{id}` | Herkes | `200` veya `404` |
| Etkinlik oluşturma | `POST /api/events` | Admin | `201 Created` |
| Etkinlik güncelleme | `PUT /api/events/{id}` | Admin | `204 No Content` |
| Etkinlik silme | `DELETE /api/events/{id}` | Admin | `204 No Content` |
| Proje listesi | `GET /api/projects` | Herkes | `200` ve JSON dizi |
| Proje detayı | `GET /api/projects/{id}` | Herkes | `200` veya `404` |
| Proje oluşturma | `POST /api/projects` | Admin | `201 Created` |
| Proje güncelleme | `PUT /api/projects/{id}` | Admin | `204 No Content` |
| Proje silme | `DELETE /api/projects/{id}` | Admin | `204 No Content` |

Kaynaklar `src/CorePortal.Web/Controllers/Api/EventsApiController.cs` ve `ProjectsApiController.cs` dosyalarındadır. `[ApiController]` ve form modellerindeki Data Annotations geçersiz JSON girdisi için model doğrulaması uygular. Kimlik doğrulaması olmayan API yazma isteği `401`, oturum açmış fakat Admin olmayan kullanıcının isteği `403` alır. Bu davranış cookie olaylarında `Program.cs` içinde tanımlanmıştır.

### Etkinlik girdisi

`EventForm` başlık, açıklama, `startsAt`, konum, kontenjan ve isteğe bağlı afiş URL içerir. API, `startsAt` değerinin UTC (`Z`) olmasını ayrıca ister. Kontenjan 1–100000 aralığında olmalıdır. Güncellemede yeni kontenjan mevcut ve reddedilmemiş başvuru sayısından azsa `409 Conflict` döner.

```json
{
  "title": "Teknik Atölye",
  "description": "Uygulamalı çalışma",
  "startsAt": "2026-12-01T10:00:00Z",
  "location": "Kampüs",
  "capacity": 40,
  "posterUrl": null
}
```

### Proje girdisi

`ProjectForm` ad, özet, durum, takım kimliği ve isteğe bağlı görsel/GitHub URL içerir. Oluşturma ve güncellemede `teamId` için veritabanında takım bulunduğu doğrulanır. Liste ve detay yanıtları yalnızca tanımlanan alanları seçer; EF gezinme nesneleri JSON'a doğrudan verilmez.

```json
{
  "name": "Otonom Araç",
  "summary": "Görüntü işleme projesi",
  "status": "Active",
  "teamId": 1,
  "imageUrl": null,
  "gitHubUrl": null
}
```

Swagger dokümantasyonu geliştirme ortamında `/swagger` adresindedir. API yazma işlemleri mevcut uygulamada Identity cookie oturumuyla çalışır; ayrı token tabanlı dış istemci kimlik doğrulaması uygulanmadı. Swagger'a erişim tek başına Admin yetkisi vermez.

## 3. GitHub REST API bağlantısı

`GitHubRepositoryService`, `GitHub:Owner` ve `GitHub:OwnerType` yapılandırmasını okur. Tür `organization` ise `orgs/{owner}/repos`, diğer durumda `users/{owner}/repos` çağrılır. İstek `per_page=30&sort=updated` kullanır; istemcinin zaman aşımı 10 saniyedir. Hesap adı basit GitHub ad biçimine göre doğrulanır. Bağlantı hatası veya zaman aşımında sayfa boş harici depo listesiyle açılır ve uyarı loglanır.

`ProjectsController.Index`, bu servisin yanıtını `Views/Projects/Index.cshtml` görünümüne aktarır. `GitHub:Owner` boşsa harici depo çağrısı yapılmaz. Örnek yapılandırma:

```powershell
$env:GitHub__Owner = 'PUBLIC_CORE_OWNER'
$env:GitHub__OwnerType = 'organization' # veya user
```

Kod deposu `https://github.com/akalnmehmet/core_portal` Chrome'da **Private** olarak doğrulandı. Anonim GitHub REST API bu depoya `404` döndürdüğü için mevcut entegrasyon onu herkese açık depolar arasında gösteremez. Depoyu görünür kılmak amacıyla gizlilik ayarı değiştirilmedi ve kaynak koduna erişim anahtarı eklenmedi. CORE'un herkese açık depo hesabı verilirse yapılandırma ile kullanılabilir.

## 4. Doğrulama yöntemi ve sonuç

`tests/Smoke.ps1`, ayrı ve geçici bir PostgreSQL veritabanı üzerinde aşağıdaki akışları çalıştırdı:

1. Admin hesabıyla giriş ve `/admin` paneline erişim.
2. Admin arayüzünden takım ve proje oluşturma.
3. Yeni Member hesabı oluşturma ve takıma başvurma.
4. Anonim API yazma isteğinde `401`, Member yazma isteğinde `403`.
5. Admin API isteğiyle etkinlik oluşturma; Member başvurusu sonrası `1 / 1` doluluk.
6. Events ve Projects API için oluşturma, okuma, güncelleme ve silme yaşam döngüsü.

Test komutu çalışan ve disposable bir veritabanına bağlanmış uygulama gerektirir:

```powershell
./tests/Smoke.ps1 -BaseUrl 'http://127.0.0.1:5088' -AdminEmail 'admin@example.com' -AdminPassword 'YOUR_TEST_ADMIN_PASSWORD'
```

Smoke testi kayıt oluşturur ve özellikle test veritabanında çalıştırılmalıdır. Test sırasında kullanılan geçici PostgreSQL kümesi kapatılıp kaldırıldı. `dotnet build` sıfır derleme hatasıyla tamamlandı; ağ kısıtı nedeniyle NuGet güvenlik açığı verisi sorgusunda `NU1900` uyarısı görüldü. Mobil düzen için Bootstrap ve yatay tablo kaydırması eklendi, ancak cihaz matrisiyle görsel test veya yük testi yapılmadı.

## 5. Depo ve sonraki entegrasyon

Kaynak kodu `https://github.com/akalnmehmet/core_portal` deposunun `main` dalına gönderildi. Bu dokümanın temel aldığı son uygulama commit'i `79c7061` idi. Sıradaki entegrasyon alanları plan belgesinde Mehmet Tarık Özcan'a atanan duyuru ve etkinlik Admin ekranları, başvuru onay/red ekranları, kullanıcı profili, arama/filtreleme ve son README düzenlemesidir. Bu alanların henüz uygulandığı varsayılmamalıdır.
