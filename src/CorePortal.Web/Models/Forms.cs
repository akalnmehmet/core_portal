using System.ComponentModel.DataAnnotations;

namespace CorePortal.Web.Models;

public class TeamApplicationForm
{
    [Required, StringLength(2000, MinimumLength = 20)] public string Motivation { get; set; } = "";
    [Required, StringLength(1000)] public string Skills { get; set; } = "";
}

public class TeamForm
{
    [Required, StringLength(120)] public string Name { get; set; } = "";
    [Required, StringLength(120)] public string Field { get; set; } = "";
    [Range(1900, 2200)] public int FoundedYear { get; set; }
    [Required, StringLength(4000)] public string Description { get; set; } = "";
}

public class ProjectForm
{
    [Required, StringLength(160)] public string Name { get; set; } = "";
    [Required, StringLength(2000)] public string Summary { get; set; } = "";
    [Required, StringLength(50)] public string Status { get; set; } = "Planlandı";
    [Url] public string? ImageUrl { get; set; }
    [Url] public string? GitHubUrl { get; set; }
    [Range(1, int.MaxValue)] public int TeamId { get; set; }
}

public class EventForm
{
    [Required, StringLength(160)] public string Title { get; set; } = "";
    [Required, StringLength(4000)] public string Description { get; set; } = "";
    [Required] public DateTime StartsAt { get; set; }
    [Required, StringLength(200)] public string Location { get; set; } = "";
    [Range(1, 100000)] public int Capacity { get; set; }
    [Url] public string? PosterUrl { get; set; }
}
