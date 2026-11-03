using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Identity;

namespace CorePortal.Web.Models;

public class ApplicationUser : IdentityUser
{
    [StringLength(100)] public string? FullName { get; set; }
    [StringLength(100)] public string? Department { get; set; }
}

public class Event
{
    public int Id { get; set; }
    [Required, StringLength(160)] public string Title { get; set; } = "";
    [Required, StringLength(4000)] public string Description { get; set; } = "";
    [DataType(DataType.DateTime)] public DateTime StartsAt { get; set; }
    [Required, StringLength(200)] public string Location { get; set; } = "";
    [Range(1, 100000)] public int Capacity { get; set; }
    [Url] public string? PosterUrl { get; set; }
    public ICollection<EventRegistration> Registrations { get; set; } = new List<EventRegistration>();
}

public enum ApplicationStatus { Pending, Approved, Rejected }

public class EventRegistration
{
    public int Id { get; set; }
    public int EventId { get; set; }
    public Event Event { get; set; } = null!;
    public string UserId { get; set; } = "";
    public ApplicationUser User { get; set; } = null!;
    public DateTime AppliedAt { get; set; } = DateTime.UtcNow;
    public ApplicationStatus Status { get; set; } = ApplicationStatus.Pending;
}

public class Team
{
    public int Id { get; set; }
    [Required, StringLength(120)] public string Name { get; set; } = "";
    [Required, StringLength(120)] public string Field { get; set; } = "";
    [Range(1900, 2200)] public int FoundedYear { get; set; }
    [Required, StringLength(4000)] public string Description { get; set; } = "";
    public ICollection<Project> Projects { get; set; } = new List<Project>();
    public ICollection<TeamApplication> Applications { get; set; } = new List<TeamApplication>();
}

public class Project
{
    public int Id { get; set; }
    [Required, StringLength(160)] public string Name { get; set; } = "";
    [Required, StringLength(2000)] public string Summary { get; set; } = "";
    [Required, StringLength(50)] public string Status { get; set; } = "Planlandı";
    [Url] public string? ImageUrl { get; set; }
    [Url] public string? GitHubUrl { get; set; }
    [Range(1, int.MaxValue)] public int TeamId { get; set; }
    public Team Team { get; set; } = null!;
}

public class TeamApplication
{
    public int Id { get; set; }
    public int TeamId { get; set; }
    public Team Team { get; set; } = null!;
    public string UserId { get; set; } = "";
    public ApplicationUser User { get; set; } = null!;
    [Required, StringLength(2000, MinimumLength = 20)] public string Motivation { get; set; } = "";
    [Required, StringLength(1000)] public string Skills { get; set; } = "";
    public DateTime AppliedAt { get; set; } = DateTime.UtcNow;
    public ApplicationStatus Status { get; set; } = ApplicationStatus.Pending;
}

public class Announcement
{
    public int Id { get; set; }
    [Required, StringLength(160)] public string Title { get; set; } = "";
    [Required, StringLength(4000)] public string Content { get; set; } = "";
    public DateTime PublishedAt { get; set; } = DateTime.UtcNow;
    public string AuthorId { get; set; } = "";
    public ApplicationUser Author { get; set; } = null!;
}
