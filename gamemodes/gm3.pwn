#include <a_samp>
#include <a_mysql>

// ========== LOCATIONS ==========
#define START_X 1466.9390
#define START_Y -1010.5936
#define START_Z 26.8438

// ========== PLAYER SPAWN OFFSET (to avoid stuck in Actor) ==========
#define SPAWN_OFFSET_X 2.0  // Spawn 2 meters to the side
#define SPAWN_OFFSET_Y 2.0

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

// Player job data
new bool:PlayerOnJob[MAX_PLAYERS];
new PlayerProduct[MAX_PLAYERS];
new PlayerCustomer[MAX_PLAYERS];
new PlayerPrice[MAX_PLAYERS];

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
    
    g_SQL = mysql_connect("127.0.0.1", "arman", "pawncourse2", "Arman2002");
    
    printf("[INFO] MySQL handle: %d", g_SQL);
    print("[INFO] Assuming connection successful (check your MySQL service)");
    
    // ========== PART 2: LOAD DATA ==========
    print("\n[2] Loading data from database...");
    LoadProducts();
    LoadCustomers();
    
    // ========== PART 3: CREATE ACTOR (moved slightly to avoid blocking) ==========
    print("\n[3] Creating Actor at job location...");
    
    // Create Actor slightly away from the exact spawn point
    JobStartActor = CreateActor(155, START_X + 1.5, START_Y + 1.5, START_Z, 180.0);
    SetActorInvulnerable(JobStartActor, true);
    SetActorHealth(JobStartActor, 100.0);
    
    Create3DTextLabel(
        "{00FF00}DELIVERY JOB{FFFFFF}\n{FFFF00}Type /deliverprod to start",
        0x00FF00FF, START_X, START_Y + 1.0, START_Z + 1.0, 10.0, 0, 1
    );
    
    CreatePickup(1239, 1, START_X, START_Y, START_Z, 0);
    
    printf("[SUCCESS] Actor created at: %.2f, %.2f, %.2f", START_X + 1.5, START_Y + 1.5, START_Z);
    
    // Allow players to move through the Actor (so they don't get stuck)
    SetActorInvulnerable(JobStartActor, true);
    
    print("\n======================================");
    print("   DELIVERY JOB SYSTEM READY!");
    print("   Commands: /gotodelivery, /deliverprod, /deliveryhelp");
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

// ========== COMMAND HANDLER ==========
public OnPlayerCommandText(playerid, cmdtext[])
{
    // Command: /gotodelivery - Teleports you NEXT TO the job location (not inside Actor)
    if(strcmp(cmdtext, "/gotodelivery", true) == 0)
    {
        // Teleport player to a spot NEXT TO the Actor, not inside it
        SetPlayerPos(playerid, START_X - 1.0, START_Y - 1.0, START_Z);
        SetPlayerFacingAngle(playerid, 0.0);
        SendClientMessage(playerid, 0x00FF00FF, "You have been teleported to the delivery job location!");
        SendClientMessage(playerid, 0xFFFF00FF, "Look for the green Actor and type /deliverprod");
        printf("[DEBUG] Player %d teleported to job location", playerid);
        return 1;
    }
    
    // Command: /deliverprod - Start delivery job
    if(strcmp(cmdtext, "/deliverprod", true) == 0)
    {
        if(!IsPlayerInRangeOfPoint(playerid, 15.0, START_X, START_Y, START_Z))
        {
            SendClientMessage(playerid, 0xFF0000FF, "ERROR: You're not at the delivery job location!");
            SendClientMessage(playerid, 0xFFFF00FF, "Use /gotodelivery to teleport there!");
            return 1;
        }
        
        if(PlayerOnJob[playerid] == true)
        {
            SendClientMessage(playerid, 0xFF0000FF, "ERROR: You're already on a delivery job!");
            return 1;
        }
        
        new playerName[24];
        GetPlayerName(playerid, playerName, 24);
        printf("[JOB] %s started a delivery job", playerName);
        
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
    
    // Command: /deliveryhelp - Shows help
    if(strcmp(cmdtext, "/deliveryhelp", true) == 0)
    {
        SendClientMessage(playerid, 0xFFFF00FF, "=== DELIVERY JOB HELP ===");
        SendClientMessage(playerid, 0xFFFFFFFF, "/gotodelivery - Teleports you to the job location");
        SendClientMessage(playerid, 0xFFFFFFFF, "/deliverprod - Start a delivery job (must be at location)");
        SendClientMessage(playerid, 0xFFFFFFFF, "/deliveryhelp - Shows this help message");
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
        
        PlayerProduct[playerid] = listitem;
        
        printf("[DIALOG] Player %s selected product: %s", playerName, ProductNames[listitem]);
        
        // Show customers dialog
        new dialogStr[512];
        strcat(dialogStr, "Customer\tLocation\n");
        
        for(new i = 0; i < CustomerCount; i++)
        {
            format(dialogStr, sizeof(dialogStr), "%s%s\tCustomer %d\n", 
                   dialogStr, CustomerNames[i], i + 1);
        }
        
        ShowPlayerDialog(playerid, 101, DIALOG_STYLE_TABLIST_HEADERS,
                        "Select Customer", dialogStr, "Next", "Cancel");
    }
    
    if(dialogid == 101 && response)
    {
        PlayerCustomer[playerid] = listitem;
        
        // Calculate distance
        new Float:distance = floatsqroot(
            floatpower(START_X - CustomerX[listitem], 2) +
            floatpower(START_Y - CustomerY[listitem], 2) +
            floatpower(START_Z - CustomerZ[listitem], 2)
        );
        
        // Calculate price: base_price * (distance/100) * sensitivity
        new price = ProductPrices[PlayerProduct[playerid]];
        price = price + floatround(distance / 100.0) * ProductSensitivity[PlayerProduct[playerid]];
        PlayerPrice[playerid] = price;
        
        // Show confirmation dialog
        new msg[512];
        format(msg, sizeof(msg),
            "{00FF00}Product:{FFFFFF} %s\n\
            {00FF00}Customer:{FFFFFF} %s\n\
            {00FF00}Distance:{FFFFFF} %.0f meters\n\
            {00FF00}Base Price:{FFFFFF} $%d\n\
            {00FF00}Sensitivity:{FFFFFF} %d\n\
            \n{FFD700}Total Payment: $%d{FFFFFF}\n\n\
            Do you accept this delivery?",
            ProductNames[PlayerProduct[playerid]],
            CustomerNames[PlayerCustomer[playerid]],
            distance,
            ProductPrices[PlayerProduct[playerid]],
            ProductSensitivity[PlayerProduct[playerid]],
            price);
        
        ShowPlayerDialog(playerid, 102, DIALOG_STYLE_MSGBOX,
                        "Confirm Delivery", msg, "Accept", "Cancel");
    }
    
    if(dialogid == 102 && response)
    {
        PlayerOnJob[playerid] = true;
        
        SendClientMessage(playerid, 0x00FF00FF, "Job accepted! Go to the checkpoint to pick up the product.");
        
        // Create checkpoint at start location
        SetPlayerCheckpoint(playerid, START_X, START_Y, START_Z, 3.0);
    }
    
    if(dialogid == 102 && !response)
    {
        SendClientMessage(playerid, 0xFF0000FF, "Delivery cancelled!");
    }
    
    return 1;
}

// ========== CHECKPOINT HANDLER ==========
public OnPlayerEnterCheckpoint(playerid)
{
    if(PlayerOnJob[playerid] == true)
    {
        // First checkpoint - pickup product
        DisablePlayerCheckpoint(playerid);
        
        SendClientMessage(playerid, 0x00FF00FF, "Product picked up! Now deliver it to the customer!");
        
        // Create destination checkpoint at customer location
        SetPlayerCheckpoint(playerid, 
            CustomerX[PlayerCustomer[playerid]],
            CustomerY[PlayerCustomer[playerid]],
            CustomerZ[PlayerCustomer[playerid]], 3.0);
    }
    else
    {
        // Delivery complete
        DisablePlayerCheckpoint(playerid);
        
        // Give money
        GivePlayerMoney(playerid, PlayerPrice[playerid]);
        
        new msg[128];
        format(msg, sizeof(msg), "Delivery complete! You earned $%d!", PlayerPrice[playerid]);
        SendClientMessage(playerid, 0x00FF00FF, msg);
        
        // Reset job
        PlayerOnJob[playerid] = false;
        
        SendClientMessage(playerid, 0xFFFF00FF, "Thanks for completing the delivery! Come back for more jobs!");
    }
    
    return 1;
}

// ========== PLAYER CALLBACKS ==========
public OnPlayerConnect(playerid)
{
    new playerName[24];
    GetPlayerName(playerid, playerName, 24);
    printf("[CONNECT] %s has joined the server", playerName);
    
    // Reset player job data
    PlayerOnJob[playerid] = false;
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    new playerName[24];
    GetPlayerName(playerid, playerName, 24);
    printf("[DISCONNECT] %s left the server", playerName);
    
    // Clean up checkpoints
    DisablePlayerCheckpoint(playerid);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    SendClientMessage(playerid, 0x00FF00FF, "Welcome to Delivery Job Server!");
    SendClientMessage(playerid, 0xFFFF00FF, "Type /deliveryhelp to see available commands");
    return 1;
}