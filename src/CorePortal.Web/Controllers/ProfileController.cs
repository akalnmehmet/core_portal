using CorePortal.Web.Data;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

[Authorize, Route("profile")]
public class ProfileController(ApplicationDbContext db, UserManager<ApplicationUser> users) : Controller
{
    [HttpGet("")]
    public async Task<IActionResult> Index()
    {
        var user = await users.GetUserAsync(User);
        if (user is null) return Challenge();
        return View(await Load(user, new ProfileForm { FullName = user.FullName ?? "", Department = user.Department }));
    }

    [HttpPost(""), ValidateAntiForgeryToken]
    public async Task<IActionResult> Index([Bind(Prefix = "Form")] ProfileForm form)
    {
        var user = await users.GetUserAsync(User);
        if (user is null) return Challenge();
        if (ModelState.IsValid)
        {
            user.FullName = form.FullName.Trim();
            user.Department = form.Department?.Trim();
            var result = await users.UpdateAsync(user);
            if (result.Succeeded)
            {
                TempData["Message"] = "Profil bilgileriniz güncellendi.";
                return RedirectToAction(nameof(Index));
            }
            foreach (var error in result.Errors) ModelState.AddModelError("", error.Description);
        }
        return View(await Load(user, form));
    }

    private async Task<ProfileViewModel> Load(ApplicationUser user, ProfileForm form) => new(form,
        user.Email ?? "", await db.EventRegistrations.AsNoTracking().Include(x => x.Event)
            .Where(x => x.UserId == user.Id).OrderByDescending(x => x.AppliedAt).ToListAsync(),
        await db.TeamApplications.AsNoTracking().Include(x => x.Team)
            .Where(x => x.UserId == user.Id).OrderByDescending(x => x.AppliedAt).ToListAsync());
}
