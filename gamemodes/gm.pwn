#include <a_samp>
#include <a_mysql>

new MySQL:g_SQL;

main() {}

public OnGameModeInit()
{
    print("\n======================================");
    print("   Testing MySQL Connection");
    print("======================================\n");
    
    // Connect to your database
    g_SQL = mysql_connect("127.0.0.1", "arman", "pawncourse2", "Arman2002", 3306);
    
    if(g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
    {
        new error[256];
        mysql_error(g_SQL, error, sizeof(error));
        printf("[FAILED] Connection error: %s", error);
        printf("[FAILED] Error code: %d", mysql_errno(g_SQL));
    }
    else
    {
        printf("[SUCCESS] Connected to database 'pawncourse2' as user 'arman'");
        
        // Test query - count products
        mysql_tquery(g_SQL, "SELECT COUNT(*) as total FROM products", "OnTestQuery", "");
    }
    
    return 1;
}

forward OnTestQuery();
public OnTestQuery()
{
    new total;
    cache_get_value_int(0, "total", total);
    printf("[SUCCESS] Found %d products in database", total);
    print("\n======================================");
    print("   MySQL is READY for delivery job!");
    print("======================================\n");
}

public OnGameModeExit()
{
    mysql_close(g_SQL);
    return 1;
}