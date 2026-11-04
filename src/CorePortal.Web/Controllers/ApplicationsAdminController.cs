using System.Data;
using CorePortal.Web.Data;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

[Authorize(Roles = "Admin"), Route("admin/applications")]
public class ApplicationsAdminController(ApplicationDbContext db) : Controller
{
    [HttpGet("")]
    public async Task<IActionResult> Index(ApplicationStatus? status)
    {
        if (!ModelState.IsValid || status.HasValue && !Enum.IsDefined(status.Value)) return BadRequest();
        var events = db.EventRegistrations.AsNoTracking().Include(x => x.Event).Include(x => x.User).AsQueryable();
        var teams = db.TeamApplications.AsNoTracking().Include(x => x.Team).Include(x => x.User).AsQueryable();
        if (status.HasValue)
        {
            events = events.Where(x => x.Status == status.Value);
            teams = teams.Where(x => x.Status == status.Value);
        }
        return View(new ApplicationsViewModel(await events.OrderByDescending(x => x.AppliedAt).ToListAsync(),
            await teams.OrderByDescending(x => x.AppliedAt).ToListAsync(), status));
    }

    [HttpPost("events/{id:int}/status"), ValidateAntiForgeryToken]
    public async Task<IActionResult> EventStatus(int id, ApplicationStatus? status, ApplicationStatus? filterStatus)
    {
        if (!ModelState.IsValid || !status.HasValue || !Enum.IsDefined(status.Value)) return BadRequest();
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var item = await db.EventRegistrations.Include(x => x.Event).FirstOrDefaultAsync(x => x.Id == id);
        if (item is null) return NotFound();
        if (item.Status == ApplicationStatus.Rejected && status != ApplicationStatus.Rejected)
        {
            var occupied = await db.EventRegistrations.CountAsync(x => x.EventId == item.EventId && x.Status != ApplicationStatus.Rejected);
            if (occupied >= item.Event.Capacity)
            {
                TempData["Message"] = "Etkinlik dolu; reddedilen başvuru yeniden etkinleştirilemedi.";
                return ReturnToList(filterStatus);
            }
        }
        item.Status = status.Value;
        try
        {
            await db.SaveChangesAsync();
            await transaction.CommitAsync();
            TempData["Message"] = "Etkinlik başvurusunun durumu güncellendi.";
        }
        catch (Exception ex) when (DatabaseErrors.IsConflict(ex))
        {
            TempData["Message"] = "Başvuru başka bir işlemde değişti. Güncel durumu kontrol edip tekrar deneyin.";
        }
        return ReturnToList(filterStatus);
    }

    [HttpPost("teams/{id:int}/status"), ValidateAntiForgeryToken]
    public async Task<IActionResult> TeamStatus(int id, ApplicationStatus? status, ApplicationStatus? filterStatus)
    {
        if (!ModelState.IsValid || !status.HasValue || !Enum.IsDefined(status.Value)) return BadRequest();
        var item = await db.TeamApplications.FindAsync(id);
        if (item is null) return NotFound();
        item.Status = status.Value;
        await db.SaveChangesAsync();
        TempData["Message"] = "Takım başvurusunun durumu güncellendi.";
        return ReturnToList(filterStatus);
    }

    private RedirectToActionResult ReturnToList(ApplicationStatus? filterStatus) => RedirectToAction(nameof(Index),
        new { status = filterStatus.HasValue && Enum.IsDefined(filterStatus.Value) ? filterStatus : null });
}
