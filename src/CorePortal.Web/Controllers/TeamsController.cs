using CorePortal.Web.Data;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

public class TeamsController(ApplicationDbContext db, UserManager<ApplicationUser> users) : Controller
{
    public async Task<IActionResult> Index(string? q, string? field)
    {
        q = PortalText.Search(q); field = PortalText.Search(field);
        ViewBag.Query = q; ViewBag.Field = field;
        ViewBag.Fields = await db.Teams.AsNoTracking().Select(x => x.Field).Distinct().OrderBy(x => x).ToListAsync();
        var query = db.Teams.AsNoTracking();
        if (q is not null)
        {
            var pattern = PortalText.Pattern(q);
            query = query.Where(x => EF.Functions.ILike(x.Name, pattern) || EF.Functions.ILike(x.Description, pattern));
        }
        if (field is not null) query = query.Where(x => x.Field == field);
        return View(await query.OrderBy(x => x.Name).ToListAsync());
    }

    public async Task<IActionResult> Details(int id)
    {
        var team = await db.Teams.AsNoTracking().Include(x => x.Projects).FirstOrDefaultAsync(x => x.Id == id);
        if (team is null) return NotFound();
        var userId = users.GetUserId(User);
        var status = await db.TeamApplications.AsNoTracking().Where(x => x.TeamId == id && x.UserId == userId)
            .Select(x => (ApplicationStatus?)x.Status).FirstOrDefaultAsync();
        return View(new TeamDetailsViewModel(team, status));
    }

    [Authorize]
    public async Task<IActionResult> Apply(int id)
    {
        var team = await db.Teams.FindAsync(id);
        if (team is null) return NotFound();
        var userId = users.GetUserId(User)!;
        if (await db.TeamApplications.AnyAsync(x => x.TeamId == id && x.UserId == userId))
        {
            TempData["Message"] = "Bu takıma zaten başvurdunuz. Başvuru durumunuzu aşağıda görebilirsiniz.";
            return RedirectToAction(nameof(Details), new { id });
        }
        ViewBag.Team = team;
        return View(new TeamApplicationForm());
    }

    [Authorize, HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Apply(int id, TeamApplicationForm form)
    {
        var team = await db.Teams.FindAsync(id);
        if (team is null) return NotFound();
        ViewBag.Team = team;
        if (!ModelState.IsValid) return View(form);
        var userId = users.GetUserId(User)!;
        if (await db.TeamApplications.AnyAsync(x => x.TeamId == id && x.UserId == userId))
        {
            ModelState.AddModelError("", "Bu takıma zaten başvurdunuz.");
            return View(form);
        }
        db.TeamApplications.Add(new TeamApplication
        {
            TeamId = id, UserId = userId, Motivation = form.Motivation.Trim(), Skills = form.Skills.Trim()
        });
        try { await db.SaveChangesAsync(); }
        catch (DbUpdateException)
        {
            ModelState.AddModelError("", "Başvuru kaydedilemedi veya zaten mevcut.");
            return View(form);
        }
        TempData["Message"] = "Takım başvurunuz alındı.";
        return RedirectToAction(nameof(Details), new { id });
    }
}
