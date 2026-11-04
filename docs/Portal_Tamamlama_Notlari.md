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

## Gösterim öncesi akış düzeltmeleri

Takım ve etkinlik detay sayfaları artık oturumdaki kullanıcının başvuru durumunu gösteriyor. Var olan başvuru için tekrar başvuru çağrısı çıkmıyor; profil bağlantısı sunuluyor. Başka kullanıcıya aynı durum gösterilmiyor. Takım başvuru formunu tekrar açmak mevcut başvuruya ait detay sayfasına yönlendiriyor. Etkinlikte başlamış olma, doluluk ve önceki başvuru için ayrı mesajlar var. Ziyaretçinin etkinlik başvurusu giriş sonrası POST adresine değil GET detayına dönüyor. Proje detayından ilgili takıma geçiş ve çok satırlı açıklama gösterimi eklendi. Yönetici kararları sonrasında seçili durum filtresi korunuyor.

`tests/Invoke-LocalAcceptance.ps1` Windows/PowerShell 7 için tekrarlanabilir, mevcut veritabanından bağımsız bir doğrulama ortamı açıp kapatıyor. 4 Kasım 2026 tarihinde bu yardımcıyla .NET 10.0.402 üzerinde 0 derleme hatası, Smoke PASS, genişletilmiş PortalFlows PASS ve geçici PostgreSQL kümesi temizliği doğrulandı. NU1900 ağ erişimi uyarısı devam etti. Bu ek tur HTTP/Razor çıktıları ve veritabanı akışları üzerinden doğrulandı; bu turda yeni bir Chrome görsel kontrolü yapılmadı.

## Yerel gösterim ortamı

`scripts/Start-LocalDemo.ps1` uygulamayı ayrı yayın çıktısı ve ayrı PostgreSQL kümesiyle yalnızca 127.0.0.1 üzerinde açar. Örnek içerikler mevcut MVC/API uç noktalarından oluşturulur; uygulama başlangıcında gerçek veritabanına otomatik örnek veri eklenmez. Demoda 2 takım, 3 proje, 3 etkinlik, 2 duyuru ve onaylı/bekleyen başvuruları bulunan örnek öğrenci vardır. İki hesabın parolaları her açılışta rastgele üretilir; adresle birlikte Git dışı `.localdemo/current.json` dosyasına yazılır.

`tests/Test-LocalDemo.ps1` ile örnek içerik sayıları, geçmiş/yaklaşan dağılımı, yayımlanan CSS/JS dosyaları, Admin/öğrenci girişleri, profil durumları, rol ayrımı ve ikinci kez başlatma koruması doğrulandı. Demo kapatma ve dosya temizleme akışı da çalıştırıldı. Gösterim adımları `Gosterim_Akisi.md`, başlatma/kapatma komutları README içindedir. Demo etiketi sadece Development ve açık Demo ayarında gösterilir. Veri şeması değişmedi.

## Ders teslimine kalan dış işler

Gerçek içeriklerin ve topluluk bilgilerinin gözden geçirilmesi; GitHub görünürlüğü/collaborator erişimi, gerçek Drive bağlantısı, haftalık videolar ve sınıf gösterimi kullanıcı hesabı ve ders süreci üzerinden yürütülür. Yerel kod tamamlanması bu teslimlerin yapıldığını göstermez.
