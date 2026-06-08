#include <a_samp>
#include <a_mysql>

// ========== LOCATIONS ==========
#define START_X 1466.9390
#define START_Y -1010.5936
#define START_Z 26.8438

// ========== GLOBAL VARIABLES ==========
new MySQL:g_SQL;
new JobStartActor;

// Product storage
new ProductNames[4][50];
new ProductPrices[4];
new ProductSensitivity[4];
new ProductCount;

// Customer storage
new CustomerNames[4][50];
new Float:CustomerX[4];
new Float:CustomerY[4];
new Float:CustomerZ[4];
new CustomerCount;

// ========== FORWARDS ==========
forward LoadProducts();
forward LoadCustomers();
forward OnProductLoad();
forward OnCustomerLoad();

// ========== MAIN ==========
main() {}

// ========== ON GAMEMODE INIT ==========
public OnGameModeInit()
{
    print("\n======================================");
    print("   DELIVERY JOB SYSTEM STARTING");
    print("======================================\n");
    
    // ========== PART 1: MySQL CONNECTION ==========
    print("[1] Testing MySQL Connection...");
    
    // Simple connection - no validation for now
    g_SQL = mysql_connect("127.0.0.1", "arman", "pawncourse2", "Arman2002");
    
    printf("[INFO] MySQL handle: %d", g_SQL);
    print("[INFO] Assuming connection successful (check your MySQL service)");
    
    // ========== PART 2: LOAD DATA ==========
    print("\n[2] Loading data from database...");
    LoadProducts();
    LoadCustomers();
    
    // ========== PART 3: CREATE ACTOR ==========
    print("\n[3] Creating Actor at job location...");
    
    JobStartActor = CreateActor(155, START_X, START_Y, START_Z, 180.0);
    SetActorInvulnerable(JobStartActor, true);
    SetActorHealth(JobStartActor, 100.0);
    
    Create3DTextLabel(
        "{00FF00}DELIVERY JOB{FFFFFF}\n{FFFF00}Type /deliverprod to start",
        0x00FF00FF, START_X, START_Y, START_Z + 1.0, 10.0, 0, 1
    );
    
    CreatePickup(1239, 1, START_X, START_Y, START_Z, 0);
    
    printf("[SUCCESS] Actor created at: %.2f, %.2f, %.2f", START_X, START_Y, START_Z);
    
    print("\n======================================");
    print("   DELIVERY JOB SYSTEM READY!");
    print("   Type /deliverprod when near the Actor");
    print("======================================\n");
    
    return 1;
}

// ========== ON GAMEMODE EXIT ==========
public OnGameModeExit()
{
    mysql_close(g_SQL);
    return 1;
}

// ========== LOAD PRODUCTS ==========
public LoadProducts()
{
    mysql_tquery(g_SQL, "SELECT * FROM products", "OnProductLoad", "");
}

public OnProductLoad()
{
    ProductCount = cache_get_row_count();
    printf("[LOADED] %d products from database", ProductCount);
    
    for(new i = 0; i < ProductCount; i++)
    {
        cache_get_field_content(i, "name", ProductNames[i], g_SQL, 50);
        ProductPrices[i] = cache_get_field_content_int(i, "base_price");
        ProductSensitivity[i] = cache_get_field_content_int(i, "sensitivity");
        
        printf("  Product %d: %s - $%d (Sensitivity: %d)", 
            i + 1, ProductNames[i], ProductPrices[i], ProductSensitivity[i]);
    }
}

// ========== LOAD CUSTOMERS ==========
public LoadCustomers()
{
    mysql_tquery(g_SQL, "SELECT * FROM customers", "OnCustomerLoad", "");
}

public OnCustomerLoad()
{
    CustomerCount = cache_get_row_count();
    printf("[LOADED] %d customers from database", CustomerCount);
    
    for(new i = 0; i < CustomerCount; i++)
    {
        cache_get_field_content(i, "name", CustomerNames[i], g_SQL, 50);
        CustomerX[i] = cache_get_field_content_float(i, "pos_x");
        CustomerY[i] = cache_get_field_content_float(i, "pos_y");
        CustomerZ[i] = cache_get_field_content_float(i, "pos_z");
        
        printf("  Customer %d: %s at (%.2f, %.2f, %.2f)", 
            i + 1, CustomerNames[i], CustomerX[i], CustomerY[i], CustomerZ[i]);
    }
}

// ========== COMMAND: /deliverprod ==========
public OnPlayerCommandText(playerid, cmdtext[])
{
    if(strcmp(cmdtext, "/deliverprod", true) == 0)
    {
        if(!IsPlayerInRangeOfPoint(playerid, 5.0, START_X, START_Y, START_Z))
        {
            SendClientMessage(playerid, 0xFF0000FF, "ERROR: You're not at the delivery job location!");
            SendClientMessage(playerid, 0xFFFF00FF, "Go to the red marker at the warehouse!");
            return 1;
        }
        
        new playerName[24];
        GetPlayerName(playerid, playerName, 24);
        printf("[JOB] %s requested delivery job", playerName);
        
        SendClientMessage(playerid, 0x00FF00FF, "=======================================");
        SendClientMessage(playerid, 0x00FF00FF, "   DELIVERY JOB STARTED!");
        SendClientMessage(playerid, 0x00FF00FF, "=======================================");
        
        // Show products dialog
        new dialogStr[512];
        strcat(dialogStr, "Product\tPrice\tSensitivity\n");
        
        for(new i = 0; i < ProductCount; i++)
        {
            new sens[10];
            if(ProductSensitivity[i] == 1) sens = "Low";
            else if(ProductSensitivity[i] == 2) sens = "Medium";
            else sens = "High";
            
            format(dialogStr, sizeof(dialogStr), "%s%s\t$%d\t%s\n", 
                   dialogStr, ProductNames[i], ProductPrices[i], sens);
        }
        
        ShowPlayerDialog(playerid, 100, DIALOG_STYLE_TABLIST_HEADERS,
                        "Select Product to Deliver", dialogStr, "Next", "Cancel");
        
        return 1;
    }
    return 0;
}

// ========== DIALOG RESPONSES ==========
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == 100 && response)
    {
        new playerName[24];
        GetPlayerName(playerid, playerName, 24);
        
        printf("[DIALOG] Player %s selected product: %s", playerName, ProductNames[listitem]);
        
        new msg[256];
        format(msg, sizeof(msg), 
            "You selected: {00FF00}%s{FFFFFF}\n\nPrice: $%d\nSensitivity: %d\n\nCustomer list coming soon!",
            ProductNames[listitem], ProductPrices[listitem], ProductSensitivity[listitem]);
        
        ShowPlayerDialog(playerid, 101, DIALOG_STYLE_MSGBOX,
                        "Product Selected", msg, "Continue", "Cancel");
    }
    
    if(dialogid == 101 && response)
    {
        SendClientMessage(playerid, 0x00FF00FF, "Customer selection coming next update!");
    }
    
    return 1;
}

// ========== PLAYER CALLBACKS ==========
public OnPlayerConnect(playerid)
{
    new playerName[24];
    GetPlayerName(playerid, playerName, 24);
    printf("[CONNECT] %s has joined the server", playerName);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    new playerName[24];
    GetPlayerName(playerid, playerName, 24);
    printf("[DISCONNECT] %s left the server", playerName);
    return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
    printf("[DEBUG] Player %d entered a checkpoint", playerid);
    return 1;
}