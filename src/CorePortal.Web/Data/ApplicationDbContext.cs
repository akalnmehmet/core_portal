using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

using CorePortal.Web.Models;

namespace CorePortal.Web.Data;

public class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : IdentityDbContext<ApplicationUser>(options)
{
    public DbSet<Event> Events => Set<Event>();
    public DbSet<EventRegistration> EventRegistrations => Set<EventRegistration>();
    public DbSet<Team> Teams => Set<Team>();
    public DbSet<Project> Projects => Set<Project>();
    public DbSet<TeamApplication> TeamApplications => Set<TeamApplication>();
    public DbSet<Announcement> Announcements => Set<Announcement>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);
        builder.Entity<EventRegistration>().HasIndex(x => new { x.EventId, x.UserId }).IsUnique();
        builder.Entity<TeamApplication>().HasIndex(x => new { x.TeamId, x.UserId }).IsUnique();
    }
}
