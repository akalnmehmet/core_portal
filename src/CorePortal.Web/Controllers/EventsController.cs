using System.Data;
using CorePortal.Web.Data;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

public class EventsController(ApplicationDbContext db, UserManager<ApplicationUser> users) : Controller
{
    public async Task<IActionResult> Index() => View(await db.Events.AsNoTracking().OrderBy(x => x.StartsAt).ToListAsync());

    public async Task<IActionResult> Details(int id)
    {
        var item = await db.Events.AsNoTracking().Include(x => x.Registrations).FirstOrDefaultAsync(x => x.Id == id);
        return item is null ? NotFound() : View(item);
    }

    [Authorize, HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Register(int id)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var item = await db.Events.Include(x => x.Registrations).FirstOrDefaultAsync(x => x.Id == id);
        if (item is null) return NotFound();
        var userId = users.GetUserId(User)!;
        if (item.StartsAt <= DateTime.UtcNow ||
            item.Registrations.Count(x => x.Status != ApplicationStatus.Rejected) >= item.Capacity ||
            item.Registrations.Any(x => x.UserId == userId))
        {
            TempData["Message"] = "Etkinliğe kayıt yapılamıyor: süre, kontenjan veya önceki başvurunuzu kontrol edin.";
            return RedirectToAction(nameof(Details), new { id });
        }
        db.EventRegistrations.Add(new EventRegistration { EventId = id, UserId = userId });
        try
        {
            await db.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Message"] = "Etkinlik başvurunuz alındı.";
        }
        catch (DbUpdateException)
        {
            TempData["Message"] = "Kayıt tamamlanamadı. Lütfen yeniden deneyin.";
        }
        return RedirectToAction(nameof(Details), new { id });
    }
}
