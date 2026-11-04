using System.ComponentModel.DataAnnotations;

namespace CorePortal.Web.Models;

public record HomeViewModel(int Teams, int Projects, int UpcomingEvents,
    IReadOnlyList<Announcement> Announcements, IReadOnlyList<Event> Events);

public class ProfileForm
{
    [Required, StringLength(100)] public string FullName { get; set; } = "";
    [StringLength(100)] public string? Department { get; set; }
}

public record ProfileViewModel(ProfileForm Form, string Email,
    IReadOnlyList<EventRegistration> EventRegistrations,
    IReadOnlyList<TeamApplication> TeamApplications);

public class AnnouncementForm
{
    [Required, StringLength(160)] public string Title { get; set; } = "";
    [Required, StringLength(4000)] public string Content { get; set; } = "";
}

public class EventEditForm
{
    [Required, StringLength(160)] public string Title { get; set; } = "";
    [Required, StringLength(4000)] public string Description { get; set; } = "";
    [Required] public DateTime? StartsAtLocal { get; set; }
    [Required, StringLength(200)] public string Location { get; set; } = "";
    [Range(1, 100000)] public int Capacity { get; set; } = 30;
    [Url] public string? PosterUrl { get; set; }
}

public record ApplicationsViewModel(IReadOnlyList<EventRegistration> Events,
    IReadOnlyList<TeamApplication> Teams, ApplicationStatus? Status);

public record EventDetailsViewModel(Event Event, int Occupied, ApplicationStatus? Status);
public record TeamDetailsViewModel(Team Team, ApplicationStatus? Status);

public static class PortalText
{
    public static string Label(this ApplicationStatus status) => status switch
    {
        ApplicationStatus.Pending => "Beklemede",
        ApplicationStatus.Approved => "Onaylandı",
        ApplicationStatus.Rejected => "Reddedildi",
        _ => "Bilinmiyor"
    };

    public static string? Search(string? value) => string.IsNullOrWhiteSpace(value)
        ? null : value.Trim()[..Math.Min(value.Trim().Length, 200)];

    public static string Pattern(string value) => "%" + value.Replace("\\", "\\\\")
        .Replace("%", "\\%").Replace("_", "\\_") + "%";
}
