using Npgsql;

namespace CorePortal.Web.Data;

public static class DatabaseErrors
{
    public static bool IsConflict(Exception exception)
    {
        for (Exception? current = exception; current is not null; current = current.InnerException)
            if (current is PostgresException { SqlState: "40001" or "40P01" or "23505" }) return true;
        return false;
    }
}
