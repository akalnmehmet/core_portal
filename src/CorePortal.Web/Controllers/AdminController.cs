using CorePortal.Web.Data;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers;

[Authorize(Roles = "Admin")]
[Route("admin")]
public class AdminController(ApplicationDbContext db) : Controller
{
    [HttpGet("")]
    public async Task<IActionResult> Index() => View(new AdminDashboard(
        await db.Teams.CountAsync(), await db.Projects.CountAsync(),
        await db.EventRegistrations.CountAsync(x => x.Status == ApplicationStatus.Pending),
        await db.TeamApplications.CountAsync(x => x.Status == ApplicationStatus.Pending)));

    [HttpGet("teams")]
    public async Task<IActionResult> Teams() => View(await db.Teams.AsNoTracking().OrderBy(x => x.Name).ToListAsync());

    [HttpGet("teams/create")]
    public IActionResult CreateTeam() => View("TeamForm", new TeamForm { FoundedYear = DateTime.UtcNow.Year });

    [HttpPost("teams/create"), ValidateAntiForgeryToken]
    public async Task<IActionResult> CreateTeam(TeamForm form)
    {
        if (!ModelState.IsValid) return View("TeamForm", form);
        db.Teams.Add(new Team { Name = form.Name.Trim(), Field = form.Field.Trim(), FoundedYear = form.FoundedYear, Description = form.Description.Trim() });
        await db.SaveChangesAsync();
        return RedirectToAction(nameof(Teams));
    }

    [HttpGet("teams/{id:int}/edit")]
    public async Task<IActionResult> EditTeam(int id)
    {
        var x = await db.Teams.FindAsync(id);
        if (x is null) return NotFound();
        ViewBag.Id = id;
        return View("TeamForm", new TeamForm { Name = x.Name, Field = x.Field, FoundedYear = x.FoundedYear, Description = x.Description });
    }

    [HttpPost("teams/{id:int}/edit"), ValidateAntiForgeryToken]
    public async Task<IActionResult> EditTeam(int id, TeamForm form)
    {
        var x = await db.Teams.FindAsync(id);
        if (x is null) return NotFound();
        ViewBag.Id = id;
        if (!ModelState.IsValid) return View("TeamForm", form);
        x.Name = form.Name.Trim(); x.Field = form.Field.Trim(); x.FoundedYear = form.FoundedYear; x.Description = form.Description.Trim();
        await db.SaveChangesAsync();
        return RedirectToAction(nameof(Teams));
    }

    [HttpPost("teams/{id:int}/delete"), ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteTeam(int id)
    {
        var x = await db.Teams.FindAsync(id);
        if (x is null) return NotFound();
        db.Teams.Remove(x);
        await db.SaveChangesAsync();
        return RedirectToAction(nameof(Teams));
    }

    [HttpGet("projects")]
    public async Task<IActionResult> Projects() => View(await db.Projects.AsNoTracking().Include(x => x.Team).OrderBy(x => x.Name).ToListAsync());

    [HttpGet("projects/create")]
    public async Task<IActionResult> CreateProject()
    {
        await SetTeams();
        return View("ProjectForm", new ProjectForm());
    }

    [HttpPost("projects/create"), ValidateAntiForgeryToken]
    public async Task<IActionResult> CreateProject(ProjectForm form)
    {
        if (!await db.Teams.AnyAsync(x => x.Id == form.TeamId)) ModelState.AddModelError(nameof(form.TeamId), "Geçerli bir takım seçin.");
        if (!ModelState.IsValid) { await SetTeams(); return View("ProjectForm", form); }
        db.Projects.Add(new Project { Name = form.Name.Trim(), Summary = form.Summary.Trim(), Status = form.Status.Trim(), ImageUrl = form.ImageUrl, GitHubUrl = form.GitHubUrl, TeamId = form.TeamId });
        await db.SaveChangesAsync();
        return RedirectToAction(nameof(Projects));
    }

    [HttpGet("projects/{id:int}/edit")]
    public async Task<IActionResult> EditProject(int id)
    {
        var x = await db.Projects.FindAsync(id);
        if (x is null) return NotFound();
        ViewBag.Id = id;
        await SetTeams();
        return View("ProjectForm", new ProjectForm { Name = x.Name, Summary = x.Summary, Status = x.Status, ImageUrl = x.ImageUrl, GitHubUrl = x.GitHubUrl, TeamId = x.TeamId });
    }

    [HttpPost("projects/{id:int}/edit"), ValidateAntiForgeryToken]
    public async Task<IActionResult> EditProject(int id, ProjectForm form)
    {
        var x = await db.Projects.FindAsync(id);
        if (x is null) return NotFound();
        if (!await db.Teams.AnyAsync(t => t.Id == form.TeamId)) ModelState.AddModelError(nameof(form.TeamId), "Geçerli bir takım seçin.");
        ViewBag.Id = id;
        if (!ModelState.IsValid) { await SetTeams(); return View("ProjectForm", form); }
        x.Name = form.Name.Trim(); x.Summary = form.Summary.Trim(); x.Status = form.Status.Trim(); x.ImageUrl = form.ImageUrl; x.GitHubUrl = form.GitHubUrl; x.TeamId = form.TeamId;
        await db.SaveChangesAsync();
        return RedirectToAction(nameof(Projects));
    }

    [HttpPost("projects/{id:int}/delete"), ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteProject(int id)
    {
        var x = await db.Projects.FindAsync(id);
        if (x is null) return NotFound();
        db.Projects.Remove(x);
        await db.SaveChangesAsync();
        return RedirectToAction(nameof(Projects));
    }

    private async Task SetTeams() => ViewBag.Teams = new SelectList(await db.Teams.AsNoTracking().OrderBy(x => x.Name).ToListAsync(), "Id", "Name");
}

public record AdminDashboard(int Teams, int Projects, int PendingEventRegistrations, int PendingTeamApplications);
