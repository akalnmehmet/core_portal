using System.Net.Http.Json;
using System.Text.Json.Serialization;

namespace CorePortal.Web.Services;

public sealed class GitHubRepositoryService(HttpClient client, IConfiguration configuration, ILogger<GitHubRepositoryService> logger)
{
    public async Task<IReadOnlyList<GitHubRepository>> GetRepositoriesAsync(CancellationToken cancellationToken)
    {
        var owner = configuration["GitHub:Owner"];
        if (string.IsNullOrWhiteSpace(owner) || !System.Text.RegularExpressions.Regex.IsMatch(owner, "^[A-Za-z0-9-]{1,39}$")) return [];
        var ownerType = string.Equals(configuration["GitHub:OwnerType"], "organization", StringComparison.OrdinalIgnoreCase) ? "orgs" : "users";
        try
        {
            var repos = await client.GetFromJsonAsync<List<GitHubRepository>>(
                $"{ownerType}/{Uri.EscapeDataString(owner)}/repos?per_page=30&sort=updated", cancellationToken);
            return repos ?? [];
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex, "GitHub depoları alınamadı");
            return [];
        }
        catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(ex, "GitHub isteği zaman aşımına uğradı");
            return [];
        }
    }
}

public sealed class GitHubRepository
{
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    [JsonPropertyName("html_url")] public string HtmlUrl { get; set; } = "";
}
