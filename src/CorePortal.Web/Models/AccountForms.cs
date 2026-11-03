using System.ComponentModel.DataAnnotations;

namespace CorePortal.Web.Models;

public class RegisterForm
{
    [Required, EmailAddress] public string Email { get; set; } = "";
    [Required, MinLength(8), DataType(DataType.Password)] public string Password { get; set; } = "";
    [Required, Compare(nameof(Password)), DataType(DataType.Password)] public string ConfirmPassword { get; set; } = "";
    [Required, StringLength(100)] public string FullName { get; set; } = "";
    [StringLength(100)] public string? Department { get; set; }
}

public class LoginForm
{
    [Required, EmailAddress] public string Email { get; set; } = "";
    [Required, DataType(DataType.Password)] public string Password { get; set; } = "";
    public bool RememberMe { get; set; }
}
