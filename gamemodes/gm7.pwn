// ============================================================
//    PROJECT: Delivery Job System (سیستم تحویل کالا)
// ============================================================
//    Student: Arman Forouharfard
//    Assistant: DeepSeek AI
//    Course: Pawn Class - Arsacia
//    Date: May 2026
// ============================================================
//    Description:
//    A complete delivery job system for SA-MP / open.mp
//    Features:
//    - MySQL database integration (products, customers, history)
//    - Actor at job location with /deliverprod command
//    - Product & Customer selection dialogs
//    - Dynamic price calculation (distance × sensitivity)
//    - Pickup and destination checkpoints
//    - Job vehicle system with /deliveryvehicle command
//    - 2-minute timer when leaving vehicle
//    - Hybrid NO-REPEAT system (1-hour block + auto unlock)
//    - Customer actors at destinations
//    - Object in hand system using SetPlayerAttachedObject
//    - Database tracking with delivery_history table
// ============================================================
//    Special Thanks:
//    - Arsacia for providing the learning platform
//    - Instructor Mr.AmirMahdi and Mr.Toofan  Tootian for guidance
//    - DeepSeek AI for technical assistance and debugging support
// ============================================================

#include <a_samp>
#include <a_mysql>

// ========== LOCATIONS ==========
#define START_X 1466.9390
#define START_Y -1010.5936
#define START_Z 26.8438

// ========== VEHICLE SETTINGS ==========
#define JOB_VEHICLE_MODEL 478
#define JOB_VEHICLE_COLOR_1 6
#define JOB_VEHICLE_COLOR_2 6

// ========== TIMER SETTINGS ==========
#define VEHICLE_TIMEOUT 120000

// ========== ARRAY SIZES ==========
#define MAX_CUSTOMERS 50
#define MAX_PRODUCTS 50

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

// Customer Actors and their 3D text labels
new CustomerActors[MAX_CUSTOMERS];
new Text3D:CustomerLabels[MAX_CUSTOMERS];

// Player job data
new bool:PlayerOnJob[MAX_PLAYERS];
new PlayerProduct[MAX_PLAYERS];
new PlayerCustomer[MAX_PLAYERS];
new PlayerPrice[MAX_PLAYERS];
new PlayerVehicle[MAX_PLAYERS];
new PlayerVehicleTimer[MAX_PLAYERS];
new bool:PlayerHasProduct[MAX_PLAYERS];

// ========== OBJECT IN HAND VARIABLES ==========
new PlayerObject[MAX_PLAYERS];
new bool:PlayerHasObject[MAX_PLAYERS];

// ========== FORWARDS ==========
forward LoadProducts();
forward LoadCustomers();
forward OnProductLoad();
forward OnCustomerLoad();
forward VehicleTimerExpired(playerid);
forward ResetPlayerJob(playerid);
forward CheckDeliveryHistory(playerid, productIndex);
forward CreateCustomerActor(customerId, Float:x, Float:y, Float:z);
forward RemoveCustomerActor(customerId);
forward GiveProductObject(playerid);
forward RemoveProductObject(playerid);
forward RemoveAllCustomerActors();

// ========== MAIN ==========
main() {}

// ========== CREATE CUSTOMER ACTORS ==========
public CreateCustomerActor(customerId, Float:x, Float:y, Float:z)
{
    new skin;
    switch(customerId)
    {
        case 0: skin = 155;  // Alex - normal male
        case 1: skin = 190;  // Maria - female
        case 2: skin = 168;  // Joe - businessman
        case 3: skin = 219;  // Sarah - female
        default: skin = 155;
    }
    
    CustomerActors[customerId] = CreateActor(skin, x, y, z, 0.0);
    SetActorInvulnerable(CustomerActors[customerId], true);
    SetActorHealth(CustomerActors[customerId], 100.0);
    
    new actorName[64];
    format(actorName, sizeof(actorName), "{00FF00}%s{FFFFFF}\n{FFFF00}Waiting for delivery", CustomerNames[customerId]);
    CustomerLabels[customerId] = Create3DTextLabel(actorName, 0x00FF00FF, x, y, z + 1.0, 10.0, 0, 1);
    
    printf("[ACTOR] Created customer actor for %s (ID: %d)", CustomerNames[customerId], customerId);
    return 1;
}

// ========== REMOVE CUSTOMER ACTOR ==========
public RemoveCustomerActor(customerId)
{
    printf("[DEBUG] RemoveCustomerActor called for ID: %d", customerId);
    
    if(CustomerActors[customerId] != 0)
    {
        DestroyActor(CustomerActors[customerId]);
        CustomerActors[customerId] = 0;
        printf("[ACTOR] Destroyed actor for ID %d", customerId);
    }
    
    if(CustomerLabels[customerId] != Text3D:0)
    {
        Delete3DTextLabel(CustomerLabels[customerId]);
        CustomerLabels[customerId] = Text3D:0;
        printf("[ACTOR] Destroyed 3D text label for ID %d", customerId);
    }
    
    return 1;
}

// ========== REMOVE ALL CUSTOMER ACTORS ==========
public RemoveAllCustomerActors()
{
    for(new i = 0; i < CustomerCount; i++)
    {
        if(CustomerActors[i] != 0)
        {
            DestroyActor(CustomerActors[i]);
            CustomerActors[i] = 0;
        }
        if(CustomerLabels[i] != Text3D:0)
        {
            Delete3DTextLabel(CustomerLabels[i]);
            CustomerLabels[i] = Text3D:0;
        }
    }
    printf("[ACTOR] All customer actors removed");
    return 1;
}

// ========== GIVE PRODUCT OBJECT TO PLAYER ==========
public GiveProductObject(playerid)
{
    if(PlayerHasObject[playerid]) return 1;
    
    new objectModel;
    switch(PlayerProduct[playerid])
    {
        case 0: objectModel = 1550;  // Cigarettes
        case 1: objectModel = 1582;  // Pizza box
        case 2: objectModel = 1575;  // Documents/paper
        case 3: objectModel = 1670;  // Electronics/propeller
        default: objectModel = 1270; // Default box
    }
    
    SetPlayerAttachedObject(playerid, 0, objectModel, 6, 0.5, -0.2, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
    PlayerHasObject[playerid] = true;
    
    SendClientMessage(playerid, 0xFFFF00FF, "You are now holding the product!");
    printf("[DEBUG] Object %d attached to player %d", objectModel, playerid);
    
    return 1;
}

// ========== REMOVE PRODUCT OBJECT ==========
public RemoveProductObject(playerid)
{
    if(PlayerHasObject[playerid])
    {
        RemovePlayerAttachedObject(playerid, 0);
        PlayerHasObject[playerid] = false;
        SendClientMessage(playerid, 0xFFFF00FF, "Product stored in vehicle!");
        printf("[DEBUG] Object removed from player %d", playerid);
    }
    return 1;
}

// ========== ON GAMEMODE INIT ==========
public OnGameModeInit()
{
    print("\n======================================");
    print("   DELIVERY JOB SYSTEM STARTING");
    print("======================================\n");
    
    print("[1] Testing MySQL Connection...");
    g_SQL = mysql_connect("127.0.0.1", "arman", "pawncourse2", "Arman2002");
    printf("[INFO] MySQL handle: %d", g_SQL);
    
    print("\n[2] Loading data from database...");
    LoadProducts();
    LoadCustomers();
    
    print("\n[3] Creating Actor at job location...");
    JobStartActor = CreateActor(155, START_X + 1.5, START_Y + 1.5, START_Z, 180.0);
    SetActorInvulnerable(JobStartActor, true);
    SetActorHealth(JobStartActor, 100.0);
    
    Create3DTextLabel("{00FF00}DELIVERY JOB{FFFFFF}\n{FFFF00}Type /deliverprod to start",
        0x00FF00FF, START_X, START_Y + 1.0, START_Z + 1.0, 10.0, 0, 1);
    
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
    RemoveAllCustomerActors();
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
        printf("  Product %d: %s - $%d (Sensitivity: %d)", i+1, ProductNames[i], ProductPrices[i], ProductSensitivity[i]);
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
        printf("  Customer %d: %s at (%.2f, %.2f, %.2f)", i+1, CustomerNames[i], CustomerX[i], CustomerY[i], CustomerZ[i]);
    }
}

// ========== COMMAND HANDLER ==========
public OnPlayerCommandText(playerid, cmdtext[])
{
    if(strcmp(cmdtext, "/gotodelivery", true) == 0)
    {
        SetPlayerPos(playerid, START_X - 2.0, START_Y - 2.0, START_Z);
        SendClientMessage(playerid, 0x00FF00FF, "Teleported to delivery job location!");
        return 1;
    }
    
    if(strcmp(cmdtext, "/deliveryvehicle", true) == 0)
    {
        if(!PlayerOnJob[playerid])
        {
            SendClientMessage(playerid, 0xFF0000FF, "ERROR: Start a job first! Use /deliverprod");
            return 1;
        }
        
        if(!PlayerHasProduct[playerid])
        {
            SendClientMessage(playerid, 0xFF0000FF, "ERROR: Pick up the product first!");
            return 1;
        }
        
        if(PlayerVehicle[playerid] != 0)
        {
            SendClientMessage(playerid, 0xFFFF00FF, "You already have a delivery vehicle!");
            return 1;
        }
        
        new Float:x, Float:y, Float:z;
        GetPlayerPos(playerid, x, y, z);
        PlayerVehicle[playerid] = CreateVehicle(JOB_VEHICLE_MODEL, x + 3, y, z + 1, 0.0, JOB_VEHICLE_COLOR_1, JOB_VEHICLE_COLOR_2, -1);
        
        SendClientMessage(playerid, 0x00FF00FF, "Delivery vehicle spawned! Get in!");
        return 1;
    }
    
    if(strcmp(cmdtext, "/deliverprod", true) == 0)
    {
        if(!IsPlayerInRangeOfPoint(playerid, 15.0, START_X, START_Y, START_Z))
        {
            SendClientMessage(playerid, 0xFF0000FF, "ERROR: Go to job location first! Use /gotodelivery");
            return 1;
        }
        
        if(PlayerOnJob[playerid])
        {
            SendClientMessage(playerid, 0xFF0000FF, "ERROR: You're already on a job!");
            return 1;
        }
        
        new dialogStr[512];
        strcat(dialogStr, "Product\tPrice\tSensitivity\n");
        for(new i = 0; i < ProductCount; i++)
        {
            new sens[10];
            if(ProductSensitivity[i] == 1) sens = "Low";
            else if(ProductSensitivity[i] == 2) sens = "Medium";
            else sens = "High";
            format(dialogStr, sizeof(dialogStr), "%s%s\t$%d\t%s\n", dialogStr, ProductNames[i], ProductPrices[i], sens);
        }
        ShowPlayerDialog(playerid, 100, DIALOG_STYLE_TABLIST_HEADERS, "Select Product", dialogStr, "Next", "Cancel");
        return 1;
    }
    
    if(strcmp(cmdtext, "/deliveryhelp", true) == 0)
    {
        SendClientMessage(playerid, 0xFFFF00FF, "=== DELIVERY JOB HELP ===");
        SendClientMessage(playerid, 0xFFFFFFFF, "/gotodelivery - Teleport to job");
        SendClientMessage(playerid, 0xFFFFFFFF, "/deliverprod - Start delivery");
        SendClientMessage(playerid, 0xFFFFFFFF, "/deliveryvehicle - Spawn truck");
        SendClientMessage(playerid, 0xFFA500FF, "Note: 2-minute timer if you leave vehicle!");
        SendClientMessage(playerid, 0xFFA500FF, "Note: Customers unlock after 1 hour!");
        return 1;
    }
    
    // Debug command to manually remove actors
    if(strcmp(cmdtext, "/removeactors", true) == 0)
    {
        RemoveAllCustomerActors();
        SendClientMessage(playerid, 0x00FF00FF, "All customer actors removed!");
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
        
        new playerName[24];
        GetPlayerName(playerid, playerName, 24);
        
        new query[256];
        mysql_format(g_SQL, query, sizeof(query), "SELECT customer_id FROM delivery_history WHERE player_name = '%e' AND product_id = %d AND delivered_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)", playerName, PlayerProduct[playerid] + 1);
        
        mysql_tquery(g_SQL, query, "CheckDeliveryHistory", "ii", playerid, PlayerProduct[playerid]);
        return 1;
    }
    
    if(dialogid == 101 && response)
    {
        PlayerCustomer[playerid] = listitem;
        
        new Float:distance = floatsqroot(
            floatpower(START_X - CustomerX[listitem], 2) +
            floatpower(START_Y - CustomerY[listitem], 2) +
            floatpower(START_Z - CustomerZ[listitem], 2)
        );
        
        new price = ProductPrices[PlayerProduct[playerid]];
        price = price + floatround(distance / 100.0) * ProductSensitivity[PlayerProduct[playerid]];
        PlayerPrice[playerid] = price;
        
        new msg[512];
        format(msg, sizeof(msg), "{00FF00}Product:{FFFFFF} %s\n{00FF00}Customer:{FFFFFF} %s\n{00FF00}Distance:{FFFFFF} %.0f meters\n{00FF00}Base Price:{FFFFFF} $%d\n{00FF00}Sensitivity:{FFFFFF} %d\n\n{FFD700}Total Payment: $%d{FFFFFF}\n\nAccept?", ProductNames[PlayerProduct[playerid]], CustomerNames[PlayerCustomer[playerid]], distance, ProductPrices[PlayerProduct[playerid]], ProductSensitivity[PlayerProduct[playerid]], price);
        
        ShowPlayerDialog(playerid, 102, DIALOG_STYLE_MSGBOX, "Confirm Delivery", msg, "Accept", "Cancel");
    }
    
    if(dialogid == 102 && response)
    {
        PlayerOnJob[playerid] = true;
        PlayerHasProduct[playerid] = false;
        SendClientMessage(playerid, 0x00FF00FF, "Job accepted! Go to red checkpoint.");
        SetPlayerCheckpoint(playerid, START_X, START_Y, START_Z, 3.0);

        for(new i = 0; i < CustomerCount; i++)
        {
            CreateCustomerActor(i, CustomerX[i], CustomerY[i], CustomerZ[i]);
        }
    }
    
    return 1;
}

// ========== CHECK DELIVERY HISTORY ==========
public CheckDeliveryHistory(playerid, productIndex)
{
    new deliveredCount = cache_get_row_count();
    new bool:AlreadyDelivered[50];
    
    for(new i = 0; i < deliveredCount; i++)
    {
        new customerId = cache_get_field_content_int(i, "customer_id");
        if(customerId >= 1 && customerId <= CustomerCount)
        {
            AlreadyDelivered[customerId - 1] = true;
        }
    }
    
    new dialogStr[512];
    new availableCount = 0;
    
    for(new i = 0; i < CustomerCount; i++)
    {
        if(!AlreadyDelivered[i])
        {
            format(dialogStr, sizeof(dialogStr), "%s%s\n", dialogStr, CustomerNames[i]);
            availableCount++;
        }
    }
    
    if(availableCount == 0)
    {
        for(new i = 0; i < CustomerCount; i++)
        {
            format(dialogStr, sizeof(dialogStr), "%s%s\n", dialogStr, CustomerNames[i]);
        }
        SendClientMessage(playerid, 0xFFFF00FF, "All customers available (1 hour has passed)!");
    }
    
    ShowPlayerDialog(playerid, 101, DIALOG_STYLE_LIST, "Select Customer", dialogStr, "Next", "Cancel");
    return 1;
}

// ========== VEHICLE CALLBACKS ==========
public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
    if(!PlayerOnJob[playerid] || !PlayerHasProduct[playerid]) return 1;
    if(vehicleid != PlayerVehicle[playerid]) return 1;
    
    RemoveProductObject(playerid);
    
    if(PlayerVehicleTimer[playerid] != 0)
    {
        KillTimer(PlayerVehicleTimer[playerid]);
        PlayerVehicleTimer[playerid] = 0;
    }
    
    DisablePlayerCheckpoint(playerid);
    SetPlayerCheckpoint(playerid, CustomerX[PlayerCustomer[playerid]], CustomerY[PlayerCustomer[playerid]], CustomerZ[PlayerCustomer[playerid]], 5.0);
    SendClientMessage(playerid, 0x00FF00FF, "Destination set! Drive to customer.");
    SendClientMessage(playerid, 0xFFFF00FF, "WARNING: 2-minute timer if you leave vehicle!");
    return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    if(!PlayerOnJob[playerid] || !PlayerHasProduct[playerid]) return 1;
    if(vehicleid != PlayerVehicle[playerid]) return 1;
    
    SendClientMessage(playerid, 0xFF0000FF, "WARNING: You left your vehicle! 2 minutes to return!");
    PlayerVehicleTimer[playerid] = SetTimerEx("VehicleTimerExpired", VEHICLE_TIMEOUT, false, "i", playerid);
    return 1;
}

public VehicleTimerExpired(playerid)
{
    SendClientMessage(playerid, 0xFF0000FF, "TIME'S UP! Job failed!");
    ResetPlayerJob(playerid);
}

public ResetPlayerJob(playerid)
{
    PlayerOnJob[playerid] = false;
    PlayerHasProduct[playerid] = false;
    
    RemoveProductObject(playerid);
    
    if(PlayerVehicleTimer[playerid] != 0)
    {
        KillTimer(PlayerVehicleTimer[playerid]);
        PlayerVehicleTimer[playerid] = 0;
    }
    
    if(PlayerVehicle[playerid] != 0)
    {
        DestroyVehicle(PlayerVehicle[playerid]);
        PlayerVehicle[playerid] = 0;
    }
    
    DisablePlayerCheckpoint(playerid);
    
    // DO NOT remove all actors here - they are removed individually per delivery
    // Only remove all actors if the job fails OR all deliveries are complete
    // For now, we only remove the specific actor during delivery
}

// ========== CHECKPOINT HANDLER ==========
public OnPlayerEnterCheckpoint(playerid)
{
    if(!PlayerOnJob[playerid]) return 1;
    
    if(!PlayerHasProduct[playerid])
    {
        DisablePlayerCheckpoint(playerid);
        PlayerHasProduct[playerid] = true;
        GiveProductObject(playerid);
        SendClientMessage(playerid, 0x00FF00FF, "Product picked up! Use /deliveryvehicle to get a truck!");
    }
    else
    {
        DisablePlayerCheckpoint(playerid);
        GivePlayerMoney(playerid, PlayerPrice[playerid]);

        // Remove the customer actor at destination (ONLY this one)
        printf("[DELIVERY] Removing actor for customer ID: %d (%s)", PlayerCustomer[playerid], CustomerNames[PlayerCustomer[playerid]]);
        RemoveCustomerActor(PlayerCustomer[playerid]);
        
        new msg[128];
        format(msg, sizeof(msg), "Delivery complete! +$%d!", PlayerPrice[playerid]);
        SendClientMessage(playerid, 0x00FF00FF, msg);
        
        new playerName[24];
        GetPlayerName(playerid, playerName, 24);
        
        new query[256];
        mysql_format(g_SQL, query, sizeof(query), "INSERT INTO delivery_history (player_name, product_id, customer_id) VALUES ('%e', %d, %d)", playerName, PlayerProduct[playerid] + 1, PlayerCustomer[playerid] + 1);
        mysql_tquery(g_SQL, query);
        
        printf("[DELIVERY] %s delivered %s to %s", playerName, ProductNames[PlayerProduct[playerid]], CustomerNames[PlayerCustomer[playerid]]);
        
        SendClientMessage(playerid, 0xFFFF00FF, "Thanks for completing the delivery!");
        ResetPlayerJob(playerid);
    }
    return 1;
}

// ========== PLAYER CALLBACKS ==========
public OnPlayerConnect(playerid)
{
    new playerName[24];
    GetPlayerName(playerid, playerName, 24);
    printf("[CONNECT] %s joined", playerName);
    
    PlayerOnJob[playerid] = false;
    PlayerHasProduct[playerid] = false;
    PlayerVehicle[playerid] = 0;
    PlayerVehicleTimer[playerid] = 0;
    PlayerHasObject[playerid] = false;
    PlayerObject[playerid] = 0;
    
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if(PlayerVehicle[playerid] != 0) DestroyVehicle(PlayerVehicle[playerid]);
    if(PlayerVehicleTimer[playerid] != 0) KillTimer(PlayerVehicleTimer[playerid]);
    if(PlayerHasObject[playerid]) RemoveProductObject(playerid);
    
    new playerName[24];
    GetPlayerName(playerid, playerName, 24);
    printf("[DISCONNECT] %s left", playerName);
    return 1;
}

public OnPlayerSpawn(playerid)
{
    SendClientMessage(playerid, 0x00FF00FF, "Welcome! Type /deliveryhelp for commands");
    return 1;
}