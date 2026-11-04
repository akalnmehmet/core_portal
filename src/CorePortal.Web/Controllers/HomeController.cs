using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using CorePortal.Web.Models;
using CorePortal.Web.Data;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

public class HomeController(ApplicationDbContext db) : Controller
{
    public async Task<IActionResult> Index()
    {
        var now = DateTime.UtcNow;
        return View(new HomeViewModel(await db.Teams.CountAsync(), await db.Projects.CountAsync(),
            await db.Events.CountAsync(x => x.StartsAt > now),
            await db.Announcements.AsNoTracking().Include(x => x.Author)
                .OrderByDescending(x => x.PublishedAt).ThenByDescending(x => x.Id).Take(3).ToListAsync(),
            await db.Events.AsNoTracking().Where(x => x.StartsAt > now)
                .OrderBy(x => x.StartsAt).Take(3).ToListAsync()));
    }

    public IActionResult About() => View();

    public IActionResult Privacy()
    {
        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
