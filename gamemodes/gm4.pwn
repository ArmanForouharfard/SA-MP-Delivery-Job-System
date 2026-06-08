#include <a_samp>
#include <a_mysql>

// ========== LOCATIONS ==========
#define START_X 1466.9390
#define START_Y -1010.5936
#define START_Z 26.8438

// ========== VEHICLE SETTINGS ==========
#define JOB_VEHICLE_MODEL 478  // 478 = Delivery Truck (or change to 422 = Bobcat, 456 = Yankee)
#define JOB_VEHICLE_COLOR_1 6  // Yellow
#define JOB_VEHICLE_COLOR_2 6  // Yellow

// ========== TIMER SETTINGS ==========
#define VEHICLE_TIMEOUT 120000  // 120,000 milliseconds = 2 minutes

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
new PlayerVehicle[MAX_PLAYERS];
new PlayerVehicleTimer[MAX_PLAYERS];
new bool:PlayerHasProduct[MAX_PLAYERS];

// ========== FORWARDS ==========
forward LoadProducts();
forward LoadCustomers();
forward OnProductLoad();
forward OnCustomerLoad();
forward VehicleTimerExpired(playerid);
forward ResetPlayerJob(playerid);

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
    // ==============================================

    // ========== PART 2: LOAD DATA ==========
    print("\n[2] Loading data from database...");
    LoadProducts();
    LoadCustomers();
    // ==============================================

    // ========== PART 3: CREATE ACTOR ==========
    print("\n[3] Creating Actor at job location...");
    
    JobStartActor = CreateActor(155, START_X + 1.5, START_Y + 1.5, START_Z, 180.0);
    SetActorInvulnerable(JobStartActor, true);
    SetActorHealth(JobStartActor, 100.0);
    
    Create3DTextLabel(
        "{00FF00}DELIVERY JOB{FFFFFF}\n{FFFF00}Type /deliverprod to start",
        0x00FF00FF, START_X, START_Y + 1.0, START_Z + 1.0, 10.0, 0, 1
    );
    
    CreatePickup(1239, 1, START_X, START_Y, START_Z, 0);
    
    printf("[SUCCESS] Actor created at: %.2f, %.2f, %.2f", START_X + 1.5, START_Y + 1.5, START_Z);
    
    print("\n======================================");
    print("   DELIVERY JOB SYSTEM READY!");
    print("   Commands: /gotodelivery, /deliverprod, /deliveryhelp, /deliveryvehicle");
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
    // Command: /gotodelivery - Teleports you next to job location
    if(strcmp(cmdtext, "/gotodelivery", true) == 0)
    {
        SetPlayerPos(playerid, START_X - 2.0, START_Y - 2.0, START_Z);
        SetPlayerFacingAngle(playerid, 0.0);
        SendClientMessage(playerid, 0x00FF00FF, "You have been teleported to the delivery job location!");
        SendClientMessage(playerid, 0xFFFF00FF, "Look for the green Actor and type /deliverprod");
        return 1;
    }
    
    // Command: /deliveryvehicle - Spawn job vehicle
    if(strcmp(cmdtext, "/deliveryvehicle", true) == 0)
    {
        if(!PlayerOnJob[playerid])
        {
            SendClientMessage(playerid, 0xFF0000FF, "ERROR: You must start a delivery job first! Use /deliverprod");
            return 1;
        }
        
        if(PlayerVehicle[playerid] != 0)
        {
            SendClientMessage(playerid, 0xFFFF00FF, "You already have a delivery vehicle!");
            return 1;
        }
        
        new Float:x, Float:y, Float:z;
        GetPlayerPos(playerid, x, y, z);
        
        PlayerVehicle[playerid] = CreateVehicle(JOB_VEHICLE_MODEL, x + 3, y + 3, z, 0.0, JOB_VEHICLE_COLOR_1, JOB_VEHICLE_COLOR_2, -1);
        
        SendClientMessage(playerid, 0x00FF00FF, "Your delivery vehicle has been spawned!");
        SendClientMessage(playerid, 0xFFFF00FF, "Get in the vehicle to receive the destination checkpoint!");
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
        SendClientMessage(playerid, 0xFFFFFFFF, "/deliverprod - Start a delivery job");
        SendClientMessage(playerid, 0xFFFFFFFF, "/deliveryvehicle - Spawn your delivery vehicle");
        SendClientMessage(playerid, 0xFFFFFFFF, "/deliveryhelp - Shows this help message");
        SendClientMessage(playerid, 0xFFA500FF, "Note: You have 2 minutes if you leave your vehicle!");
        return 1;
    }
    
    return 0;
}

// ========== DIALOG RESPONSES ==========
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == 100 && response)
    {
        PlayerProduct[playerid] = listitem;
        
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
        
        // Calculate price
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
        PlayerHasProduct[playerid] = false;
        
        SendClientMessage(playerid, 0x00FF00FF, "Job accepted! Go to the red checkpoint to pick up the product.");
        SendClientMessage(playerid, 0xFFFF00FF, "Use /deliveryvehicle to spawn your delivery truck!");
        
        // Create pickup checkpoint
        SetPlayerCheckpoint(playerid, START_X, START_Y, START_Z, 3.0);
    }
    
    if(dialogid == 102 && !response)
    {
        SendClientMessage(playerid, 0xFF0000FF, "Delivery cancelled!");
    }
    
    return 1;
}

// ========== PART 4: VEHICLE CALLBACKS ==========
public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
    if(!PlayerOnJob[playerid]) return 1;
    if(!PlayerHasProduct[playerid]) return 1;
    if(vehicleid != PlayerVehicle[playerid]) return 1;
    
    // Player entered the correct vehicle with product
    // Kill any existing timer
    if(PlayerVehicleTimer[playerid] != 0)
    {
        KillTimer(PlayerVehicleTimer[playerid]);
        PlayerVehicleTimer[playerid] = 0;
    }
    
    // Create destination checkpoint
    DisablePlayerCheckpoint(playerid);
    SetPlayerCheckpoint(playerid,
        CustomerX[PlayerCustomer[playerid]],
        CustomerY[PlayerCustomer[playerid]],
        CustomerZ[PlayerCustomer[playerid]], 5.0);
    
    SendClientMessage(playerid, 0x00FF00FF, "Destination checkpoint set! Drive to the customer.");
    SendClientMessage(playerid, 0xFFFF00FF, "WARNING: Don't leave the vehicle for more than 2 minutes!");
    
    return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    if(!PlayerOnJob[playerid]) return 1;
    if(!PlayerHasProduct[playerid]) return 1;
    if(vehicleid != PlayerVehicle[playerid]) return 1;
    
    // Player left the job vehicle - start 2-minute timer
    SendClientMessage(playerid, 0xFF0000FF, "WARNING: You left your delivery vehicle!");
    SendClientMessage(playerid, 0xFFA500FF, "You have 2 minutes to return, or the job will fail!");
    
    PlayerVehicleTimer[playerid] = SetTimerEx("VehicleTimerExpired", VEHICLE_TIMEOUT, false, "i", playerid);
    
    return 1;
}

public VehicleTimerExpired(playerid)
{
    SendClientMessage(playerid, 0xFF0000FF, "TIME'S UP! You failed to return to your vehicle.");
    SendClientMessage(playerid, 0xFF0000FF, "Your delivery job has been cancelled!");
    
    ResetPlayerJob(playerid);
}

public ResetPlayerJob(playerid)
{
    // Reset all job variables
    PlayerOnJob[playerid] = false;
    PlayerHasProduct[playerid] = false;
    
    // Kill timer if active
    if(PlayerVehicleTimer[playerid] != 0)
    {
        KillTimer(PlayerVehicleTimer[playerid]);
        PlayerVehicleTimer[playerid] = 0;
    }
    
    // Destroy vehicle if exists
    if(PlayerVehicle[playerid] != 0)
    {
        DestroyVehicle(PlayerVehicle[playerid]);
        PlayerVehicle[playerid] = 0;
    }
    
    // Remove checkpoint
    DisablePlayerCheckpoint(playerid);
}

// ========== CHECKPOINT HANDLER ==========
public OnPlayerEnterCheckpoint(playerid)
{
    if(!PlayerOnJob[playerid]) return 1;
    
    if(!PlayerHasProduct[playerid])
    {
        // First checkpoint - pickup product
        DisablePlayerCheckpoint(playerid);
        PlayerHasProduct[playerid] = true;
        
        SendClientMessage(playerid, 0x00FF00FF, "Product picked up!");
        SendClientMessage(playerid, 0xFFFF00FF, "Type /deliveryvehicle to spawn your truck, then get in!");
    }
    else
    {
        // Delivery complete!
        DisablePlayerCheckpoint(playerid);
        
        // Give money
        GivePlayerMoney(playerid, PlayerPrice[playerid]);
        
        new msg[128];
        format(msg, sizeof(msg), "Delivery complete! You earned $%d!", PlayerPrice[playerid]);
        SendClientMessage(playerid, 0x00FF00FF, msg);
        
        SendClientMessage(playerid, 0xFFFF00FF, "Thanks for completing the delivery!");
        
        // Reset job
        ResetPlayerJob(playerid);
    }
    
    return 1;
}

// ========== PLAYER CALLBACKS ==========
public OnPlayerConnect(playerid)
{
    new playerName[24];
    GetPlayerName(playerid, playerName, 24);
    printf("[CONNECT] %s has joined the server", playerName);
    
    // Reset player data
    PlayerOnJob[playerid] = false;
    PlayerHasProduct[playerid] = false;
    PlayerVehicle[playerid] = 0;
    PlayerVehicleTimer[playerid] = 0;
    
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    // Clean up
    if(PlayerVehicle[playerid] != 0)
    {
        DestroyVehicle(PlayerVehicle[playerid]);
    }
    
    if(PlayerVehicleTimer[playerid] != 0)
    {
        KillTimer(PlayerVehicleTimer[playerid]);
    }
    
    new playerName[24];
    GetPlayerName(playerid, playerName, 24);
    printf("[DISCONNECT] %s left the server", playerName);
    
    return 1;
}

public OnPlayerSpawn(playerid)
{
    SendClientMessage(playerid, 0x00FF00FF, "Welcome to Delivery Job Server!");
    SendClientMessage(playerid, 0xFFFF00FF, "Type /deliveryhelp to see all commands");
    return 1;
}