using CorePortal.Web.Data;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers.Api;

[ApiController, Route("api/projects")]
public class ProjectsApiController(ApplicationDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get() => Ok(await db.Projects.AsNoTracking().OrderBy(x => x.Name)
        .Select(x => new { x.Id, x.Name, x.Summary, x.Status, x.ImageUrl, x.GitHubUrl, x.TeamId }).ToListAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id)
    {
        var x = await db.Projects.AsNoTracking().Where(x => x.Id == id)
            .Select(x => new { x.Id, x.Name, x.Summary, x.Status, x.ImageUrl, x.GitHubUrl, x.TeamId }).FirstOrDefaultAsync();
        return x is null ? NotFound() : Ok(x);
    }

    [Authorize(Roles = "Admin"), HttpPost]
    public async Task<IActionResult> Create(ProjectForm form)
    {
        if (!await db.Teams.AnyAsync(x => x.Id == form.TeamId)) return BadRequest("Geçerli bir takım seçin.");
        var x = new Project { Name = form.Name.Trim(), Summary = form.Summary.Trim(), Status = form.Status.Trim(), ImageUrl = form.ImageUrl, GitHubUrl = form.GitHubUrl, TeamId = form.TeamId };
        db.Projects.Add(x);
        await db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = x.Id }, new { x.Id });
    }

    [Authorize(Roles = "Admin"), HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, ProjectForm form)
    {
        var x = await db.Projects.FindAsync(id);
        if (x is null) return NotFound();
        if (!await db.Teams.AnyAsync(t => t.Id == form.TeamId)) return BadRequest("Geçerli bir takım seçin.");
        x.Name = form.Name.Trim(); x.Summary = form.Summary.Trim(); x.Status = form.Status.Trim();
        x.ImageUrl = form.ImageUrl; x.GitHubUrl = form.GitHubUrl; x.TeamId = form.TeamId;
        await db.SaveChangesAsync();
        return NoContent();
    }

    [Authorize(Roles = "Admin"), HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var x = await db.Projects.FindAsync(id);
        if (x is null) return NotFound();
        db.Projects.Remove(x);
        await db.SaveChangesAsync();
        return NoContent();
    }
}
