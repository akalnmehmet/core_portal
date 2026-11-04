# CORE Portal tamamlanan modüller

4 Kasım 2026 itibarıyla görev paylaşımından bağımsız olarak projenin kalan yazılım kapsamı birlikte yürütülüyor. Önceki üç faz ve başlangıç rehberi tarihsel başlangıç sürümünü anlatır.

## Yeni akışlar

- `/`: dinamik takım/proje/yaklaşan etkinlik sayıları, son duyurular ve yaklaşan etkinlik listesi.
- `/Home/About`: topluluğun amacı, vizyonu ve katılım yolu.
- `/Announcements`: başlık/içerik arama ve detay; Admin'de `/admin/announcements` CRUD.
- `/admin/events`: yerel tarih girişli etkinlik CRUD, kontenjan azaltma koruması.
- `/admin/applications`: tüm veya duruma göre filtrelenen başvurular; onay/ret/beklemeye alma. Reddedilen etkinlik başvurusunu yeniden etkinleştirmek için boş kontenjan gerekir.
- `/profile`: oturumdaki kişinin ad/bölüm güncellemesi ve sadece kendi etkinlik/takım başvuruları.
- Takımlarda metin/alan, projelerde metin/takım/durum, etkinliklerde metin/geçmiş-yaklaşan filtreleri.

Başvuru durumları veritabanındaki mevcut enum alanıyla yönetiliyor; şema değişikliği yok. Admin kararları sunucuda yetki ve antiforgery doğrulamasıyla korunur. Profil formu e-posta, kullanıcı kimliği veya rol değiştirmez. Duyurular düz metin olarak kodlanarak gösterilir.

## Doğrulama yolu

`tests/Smoke.ps1` temel akışları; `tests/PortalFlows.ps1` yeni özellikleri ve negatif senaryoları çalıştırır. Kurulum, migration, saat dilimi, test verisi ve API oturumu ayrıntıları kökteki README'dedir.

4 Kasım 2026 yerel doğrulaması: .NET 10.0.402 ile derleme 0 hata; NuGet güvenlik verisi kaynağına erişilemediği için NU1900 uyarısı görüldü. Ayrı ve geçici PostgreSQL 18 kümesinde temel Smoke testi ve PortalFlows testi PASS verdi. Yeni test; içerik CRUD, HTML kodlaması, form doğrulama, birleşik filtreler, profil sahipliği, onay/ret, dolu etkinliğe tekrar onay engeli, MVC/API kapasite azaltma engeli, iki eşzamanlı son yer başvurusu, Member yetki sınırı, antiforgery, geçersiz enum ve olmayan kayıt senaryolarını içerdi. PowerShell WebSession'da API çağrısından sonra kalabilen JSON Content-Type nedeniyle form testlerinin içerik türü açıkça sabitlendi.

Chrome'da 390 piksel görünümde ana sayfa, mobil menü ve kullanıcı profili; masaüstünde proje filtreleri görsel olarak incelendi. Menü genişleme eşiği, orta ekranlarda gezinme bağlantılarının sıkışmasını önlemek için lg seviyesine alındı. Bu doğrulama bütün cihazları veya kapsamlı yük/güvenlik testini kapsamaz. Test verileri gerçek uygulama verisinden ayrı tutuldu.

## Ders teslimine kalan dış işler

Gerçek içeriklerin ve topluluk bilgilerinin gözden geçirilmesi; GitHub görünürlüğü/collaborator erişimi, gerçek Drive bağlantısı, haftalık videolar ve sınıf gösterimi kullanıcı hesabı ve ders süreci üzerinden yürütülür. Yerel kod tamamlanması bu teslimlerin yapıldığını göstermez.
