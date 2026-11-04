using CorePortal.Web.Data;
using CorePortal.Web.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CorePortal.Web.Controllers.Api;

[ApiController, Route("api/events")]
public class EventsApiController(ApplicationDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get() => Ok(await db.Events.AsNoTracking().OrderBy(x => x.StartsAt)
        .Select(x => new { x.Id, x.Title, x.Description, x.StartsAt, x.Location, x.Capacity, x.PosterUrl }).ToListAsync());

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id)
    {
        var x = await db.Events.AsNoTracking().Where(x => x.Id == id)
            .Select(x => new { x.Id, x.Title, x.Description, x.StartsAt, x.Location, x.Capacity, x.PosterUrl }).FirstOrDefaultAsync();
        return x is null ? NotFound() : Ok(x);
    }

    [Authorize(Roles = "Admin"), HttpPost]
    public async Task<IActionResult> Create(EventForm form)
    {
        if (form.StartsAt.Kind != DateTimeKind.Utc) return BadRequest("startsAt UTC olmalıdır.");
        var x = new Event { Title = form.Title.Trim(), Description = form.Description.Trim(), StartsAt = form.StartsAt, Location = form.Location.Trim(), Capacity = form.Capacity, PosterUrl = form.PosterUrl };
        db.Events.Add(x);
        await db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = x.Id }, new { x.Id });
    }

    [Authorize(Roles = "Admin"), HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, EventForm form)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        var x = await db.Events.FindAsync(id);
        if (x is null) return NotFound();
        if (form.StartsAt.Kind != DateTimeKind.Utc) return BadRequest("startsAt UTC olmalıdır.");
        var registrations = await db.EventRegistrations.CountAsync(r => r.EventId == id && r.Status != ApplicationStatus.Rejected);
        if (form.Capacity < registrations) return Conflict("Kontenjan mevcut başvuru sayısından küçük olamaz.");
        x.Title = form.Title.Trim(); x.Description = form.Description.Trim(); x.StartsAt = form.StartsAt;
        x.Location = form.Location.Trim(); x.Capacity = form.Capacity; x.PosterUrl = form.PosterUrl;
        try
        {
            await db.SaveChangesAsync();
            await transaction.CommitAsync();
            return NoContent();
        }
        catch (Exception ex) when (DatabaseErrors.IsConflict(ex))
        {
            return Conflict("Etkinlik başka bir işlemde değişti. Güncel bilgileri okuyup tekrar deneyin.");
        }
    }

    [Authorize(Roles = "Admin"), HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var x = await db.Events.FindAsync(id);
        if (x is null) return NotFound();
        db.Events.Remove(x);
        await db.SaveChangesAsync();
        return NoContent();
    }
}
