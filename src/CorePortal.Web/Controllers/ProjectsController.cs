using CorePortal.Web.Data;
using CorePortal.Web.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

public class ProjectsController(ApplicationDbContext db, GitHubRepositoryService gitHub) : Controller
{
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        ViewBag.Repositories = await gitHub.GetRepositoriesAsync(cancellationToken);
        return View(await db.Projects.AsNoTracking().Include(x => x.Team).OrderBy(x => x.Name).ToListAsync(cancellationToken));
    }

    public async Task<IActionResult> Details(int id)
    {
        var project = await db.Projects.AsNoTracking().Include(x => x.Team).FirstOrDefaultAsync(x => x.Id == id);
        return project is null ? NotFound() : View(project);
    }
}
