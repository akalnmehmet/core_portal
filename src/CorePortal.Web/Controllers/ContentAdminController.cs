using System.Data;
using CorePortal.Web.Data;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

[Authorize(Roles = "Admin"), Route("admin")]
public class ContentAdminController(ApplicationDbContext db, UserManager<ApplicationUser> users) : Controller
{
    [HttpGet("events")]
    public async Task<IActionResult> Events() => View(await db.Events.AsNoTracking()
        .Include(x => x.Registrations).OrderByDescending(x => x.StartsAt).ToListAsync());

    [HttpGet("events/create")]
    public IActionResult CreateEvent() => View("EventForm", new EventEditForm { StartsAtLocal = DateTime.Now.AddDays(1) });

    [HttpPost("events/create"), ValidateAntiForgeryToken]
    public async Task<IActionResult> CreateEvent(EventEditForm form)
    {
        if (!ModelState.IsValid) return View("EventForm", form);
        var item = new Event();
        Apply(item, form);
        db.Events.Add(item);
        await db.SaveChangesAsync();
        TempData["Message"] = "Etkinlik oluşturuldu.";
        return RedirectToAction(nameof(Events));
    }

    [HttpGet("events/{id:int}/edit")]
    public async Task<IActionResult> EditEvent(int id)
    {
        var item = await db.Events.FindAsync(id);
        if (item is null) return NotFound();
        return View("EventForm", new EventEditForm { Title = item.Title, Description = item.Description,
            StartsAtLocal = item.StartsAt.ToLocalTime(), Location = item.Location, Capacity = item.Capacity, PosterUrl = item.PosterUrl });
    }

    [HttpPost("events/{id:int}/edit"), ValidateAntiForgeryToken]
    public async Task<IActionResult> EditEvent(int id, EventEditForm form)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var item = await db.Events.FindAsync(id);
        if (item is null) return NotFound();
        var occupied = await db.EventRegistrations.CountAsync(x => x.EventId == id && x.Status != ApplicationStatus.Rejected);
        if (form.Capacity < occupied) ModelState.AddModelError(nameof(form.Capacity), "Kontenjan mevcut başvuru sayısından küçük olamaz.");
        if (!ModelState.IsValid) return View("EventForm", form);
        Apply(item, form);
        try
        {
            await db.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch (Exception ex) when (DatabaseErrors.IsConflict(ex))
        {
            TempData["Message"] = "Etkinlik başka bir işlemde değişti. Güncel bilgileri kontrol edip tekrar deneyin.";
            return RedirectToAction(nameof(EditEvent), new { id });
        }
        TempData["Message"] = "Etkinlik güncellendi.";
        return RedirectToAction(nameof(Events));
    }

    [HttpPost("events/{id:int}/delete"), ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteEvent(int id)
    {
        var item = await db.Events.FindAsync(id);
        if (item is null) return NotFound();
        db.Events.Remove(item);
        await db.SaveChangesAsync();
        TempData["Message"] = "Etkinlik ve bağlı başvuruları silindi.";
        return RedirectToAction(nameof(Events));
    }

    [HttpGet("announcements")]
    public async Task<IActionResult> Announcements() => View(await db.Announcements.AsNoTracking()
        .Include(x => x.Author).OrderByDescending(x => x.PublishedAt).ToListAsync());

    [HttpGet("announcements/create")]
    public IActionResult CreateAnnouncement() => View("AnnouncementForm", new AnnouncementForm());

    [HttpPost("announcements/create"), ValidateAntiForgeryToken]
    public async Task<IActionResult> CreateAnnouncement(AnnouncementForm form)
    {
        if (!ModelState.IsValid) return View("AnnouncementForm", form);
        db.Announcements.Add(new Announcement { Title = form.Title.Trim(), Content = form.Content.Trim(),
            AuthorId = users.GetUserId(User)!, PublishedAt = DateTime.UtcNow });
        await db.SaveChangesAsync();
        TempData["Message"] = "Duyuru yayımlandı.";
        return RedirectToAction(nameof(Announcements));
    }

    [HttpGet("announcements/{id:int}/edit")]
    public async Task<IActionResult> EditAnnouncement(int id)
    {
        var item = await db.Announcements.FindAsync(id);
        return item is null ? NotFound() : View("AnnouncementForm", new AnnouncementForm { Title = item.Title, Content = item.Content });
    }

    [HttpPost("announcements/{id:int}/edit"), ValidateAntiForgeryToken]
    public async Task<IActionResult> EditAnnouncement(int id, AnnouncementForm form)
    {
        var item = await db.Announcements.FindAsync(id);
        if (item is null) return NotFound();
        if (!ModelState.IsValid) return View("AnnouncementForm", form);
        item.Title = form.Title.Trim(); item.Content = form.Content.Trim();
        await db.SaveChangesAsync();
        TempData["Message"] = "Duyuru güncellendi.";
        return RedirectToAction(nameof(Announcements));
    }

    [HttpPost("announcements/{id:int}/delete"), ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteAnnouncement(int id)
    {
        var item = await db.Announcements.FindAsync(id);
        if (item is null) return NotFound();
        db.Announcements.Remove(item);
        await db.SaveChangesAsync();
        TempData["Message"] = "Duyuru silindi.";
        return RedirectToAction(nameof(Announcements));
    }

    private static void Apply(Event item, EventEditForm form)
    {
        item.Title = form.Title.Trim(); item.Description = form.Description.Trim();
        item.StartsAt = DateTime.SpecifyKind(form.StartsAtLocal!.Value, DateTimeKind.Unspecified).ToUniversalTime();
        item.Location = form.Location.Trim(); item.Capacity = form.Capacity; item.PosterUrl = form.PosterUrl;
    }
}
