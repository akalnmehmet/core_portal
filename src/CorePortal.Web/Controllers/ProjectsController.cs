using CorePortal.Web.Data;
using CorePortal.Web.Services;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

public class ProjectsController(ApplicationDbContext db, GitHubRepositoryService gitHub) : Controller
{
    public async Task<IActionResult> Index(CancellationToken cancellationToken, string? q, int? teamId, string? status)
    {
        q = PortalText.Search(q); status = PortalText.Search(status);
        ViewBag.Query = q; ViewBag.TeamId = teamId; ViewBag.Status = status;
        ViewBag.Teams = await db.Teams.AsNoTracking().OrderBy(x => x.Name).ToListAsync(cancellationToken);
        ViewBag.Statuses = await db.Projects.AsNoTracking().Select(x => x.Status).Distinct().OrderBy(x => x).ToListAsync(cancellationToken);
        ViewBag.Repositories = await gitHub.GetRepositoriesAsync(cancellationToken);
        var query = db.Projects.AsNoTracking().Include(x => x.Team).AsQueryable();
        if (q is not null)
        {
            var pattern = PortalText.Pattern(q);
            query = query.Where(x => EF.Functions.ILike(x.Name, pattern) || EF.Functions.ILike(x.Summary, pattern));
        }
        if (teamId.HasValue) query = query.Where(x => x.TeamId == teamId.Value);
        if (status is not null) query = query.Where(x => x.Status == status);
        return View(await query.OrderBy(x => x.Name).ToListAsync(cancellationToken));
    }

    public async Task<IActionResult> Details(int id)
    {
        var project = await db.Projects.AsNoTracking().Include(x => x.Team).FirstOrDefaultAsync(x => x.Id == id);
        return project is null ? NotFound() : View(project);
    }
}
