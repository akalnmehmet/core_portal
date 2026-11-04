using CorePortal.Web.Data;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

public class AnnouncementsController(ApplicationDbContext db) : Controller
{
    public async Task<IActionResult> Index(string? q)
    {
        q = PortalText.Search(q);
        ViewBag.Query = q;
        var query = db.Announcements.AsNoTracking().Include(x => x.Author).AsQueryable();
        if (q is not null)
        {
            var pattern = PortalText.Pattern(q);
            query = query.Where(x => EF.Functions.ILike(x.Title, pattern) || EF.Functions.ILike(x.Content, pattern));
        }
        return View(await query.OrderByDescending(x => x.PublishedAt).ThenByDescending(x => x.Id).ToListAsync());
    }

    public async Task<IActionResult> Details(int id)
    {
        var item = await db.Announcements.AsNoTracking().Include(x => x.Author).FirstOrDefaultAsync(x => x.Id == id);
        return item is null ? NotFound() : View(item);
    }
}
