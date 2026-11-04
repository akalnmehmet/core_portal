# CORE Portal yerel gösterim akışı

Bu akış, projenin çalışan özelliklerini yaklaşık 6–8 dakikada göstermek için hazırlanmıştır. Örnek içerikler gerçek topluluk bilgisi veya yapılmış etkinlik iddiası taşımaz. Haftalık video hazırlıyorsanız o haftanın liderini, işi yapan kişileri ve sonraki haftanın planını ayrıca kendi gerçek ilerlemenize göre açıklayın.

## Gösterimden önce

PowerShell 7 ile proje kökünde `./scripts/Start-LocalDemo.ps1` çalıştırın. Ekranda yazan yerel adresi açın. `.localdemo/current.json` dosyasındaki `AdminEmail`/`AdminPassword` yönetici, `MemberEmail`/`MemberPassword` öğrenci hesabıdır. Bu dosyayı ekran kaydında açmayın; giriş yaparken parola alanı gizli kalsın. Adres yalnızca demo açıkken çalışır. Kayıt öncesinde `./tests/Test-LocalDemo.ps1` ile içeriklerin hazır olduğunu kontrol edebilirsiniz.

## 1 Ana sayfa ve içerik keşfi

Yaklaşık 1 dakika. CORE Portal'ın öğrenci topluluğu için etkinlik, takım, proje ve başvuru süreçlerini bir araya getirdiğini anlatın. Ana sayfadaki 2 takım, 3 proje ve 2 yaklaşan etkinlik sayısını gösterin. Duyuru detayını açın. Bunların veritabanından yüklendiğini, HTML içine sabit yazılmış kartlar olmadığını belirtin.

Takımlar sayfasında Robotik alanını seçin. Projelerde takım ve durum filtresini birlikte kullanın; örneğin Otonom Sistemler + Geliştiriliyor seçimi Kampüs Robotu kaydını gösterir. Etkinliklerde geçmiş filtresine geçip geçmiş örnek kaydı gösterin. Her filtreyi temizleyerek tüm kayıtların yeniden geldiğini gösterin.

## 2 Öğrenci profili ve başvuru durumu

Yaklaşık 1 dakika. Öğrenci hesabıyla giriş yapıp Profilim ekranını açın. Onaylı Otonom Sistemler başvurusu ile bekleyen ASP.NET Core atölyesi başvurusunu gösterin. Takım detayında tekrar başvuru düğmesi yerine mevcut durumun göründüğünü anlatın. Profilde bölüm bilgisini değiştirip kaydedin. Kullanıcının sadece kendi profil ve başvurularına eriştiğini açıklayın.

## 3 Yeni başvuru

Yaklaşık 1 dakika. Öğrenci hesabıyla Yazılım ve Araştırma takımına başvurun. Önce çok kısa motivasyon girerek doğrulama hatasını gösterin; ardından en az 20 karakterlik bir açıklama ve yetkinliklerle gönderin. Yeni başvurunun Beklemede olduğunu gösterin. Form sınıfının tarayıcıdan gelen alanları sınırlandırdığını, kullanıcı/başvuru durumunun sunucuda belirlendiğini açıklayın.

## 4 Yönetici kararı ve içerik düzenleme

Yaklaşık 1–2 dakika. Öğrenci hesabından çıkıp Admin hesabıyla giriş yapın. Yönetim → Başvuruları yönet ekranında Beklemede filtresini seçin. Yeni takım başvurusunu onaylayın; işlemden sonra filtrenin korunduğunu ve kaydın bekleyen listeden çıktığını gösterin. Tümü filtresinde yeni durumu doğrulayın.

Duyuruları yönet ekranında yeni bir örnek duyuru ekleyin, ardından ana sayfada göründüğünü gösterin. Etkinlik yönetiminde bir tarih veya konum düzenlemesini gösterin. Kontenjanın bekleyen/onaylı başvuruları saydığını ve mevcut sayının altına düşürülemediğini açıklayın. Takım veya etkinlik silmenin bağlı başvuruları da sildiğini unutmayın; sunum için eklediğiniz ayrı bir örnek kayıt üzerinde çalışın.

## 5 Kendi API sistemi

Yaklaşık 1 dakika. Admin oturumunu aynı tarayıcı ve aynı adresle sürdürün; `/swagger` adresini açın. GET `/api/events` ile etkinlikleri listeleyin. GET `/api/projects` ile projeleri gösterin. İsterseniz yeni bir etkinliği POST ile oluşturun; tarih UTC `Z` içermelidir. Sonra GET ile okuyup PUT ve DELETE işlemlerini ayrı örnek kayıt üzerinde gösterin. Swagger'ın API'yi yazmadığını, yazılmış controller'lara istek gönderen arayüz olduğunu belirtin.

## 6 Kod bağlantısı ve kapanış

Yaklaşık 1 dakika. `TeamsController`, `TeamApplicationForm`, `ApplicationDbContext` ve `Views/Teams/Apply.cshtml` dosyalarını açın. Form → Controller → Entity → EF Core → PostgreSQL sırasını kendi cümlelerinizle anlatın. Yorum satırlarını okumak yerine, doğrulama ve benzersiz indeksin hangi problemi çözdüğünü açıklayın. Testlerin rol ayrımı, kontenjan ve iki eşzamanlı başvuru gibi senaryoları kontrol ettiğini; her cihaz/yük/güvenlik durumunu kapsamadığını belirtin.

Gösterimden sonra `./scripts/Stop-LocalDemo.ps1` komutu uygulamayı ve örnek PostgreSQL kümesini kapatır, demo değişikliklerini temizler. Bu demo; public GitHub deposu, haftalık kendi hesabınızla katkı, gerçek Drive bağlantısı veya video tesliminin yapıldığı anlamına gelmez.
