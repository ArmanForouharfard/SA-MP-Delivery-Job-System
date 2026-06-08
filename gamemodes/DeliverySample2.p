#include <a_samp>
#include <a_mysql>

// Variables
new MySQL:handle;
new PlayerProduct[MAX_PLAYERS];
new PlayerCustomer[MAX_PLAYERS];
new PlayerPrice[MAX_PLAYERS];
new bool:OnJob[MAX_PLAYERS];

// Product data
new ProductNames[][] = {"Cigarettes", "Pizza", "Documents"};
new ProductPrices[] = {200, 150, 500};

// Customer data (just 3 for now)
new CustomerNames[][] = {"Alex", "Maria", "Joe"};
new Float:CustomerX[] = {-1846.35, 2314.82, 648.55};
new Float:CustomerY[] = {453.92, -1481.90, -613.66};
new Float:CustomerZ[] = {37.30, 23.99, 16.33};

public OnGameModeInit()
{
    // Connect to MySQL (adjust these!)
    handle = mysql_connect("127.0.0.1", "root", "pawncourse", "", 3306);
    
    // Create Actor at start point
    CreateActor(155, 1466.9390, -1010.5936, 26.8438, 0.0);
    Create3DTextLabel("Delivery Job\n{FFFFFF}Type /deliverprod", 0x00FF00FF, 
                      1466.9390, -1010.5936, 27.8438, 10.0, 0, 0);
    
    print("Server started - Delivery Job Ready!");
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    // Simple command system (no zcmd needed)
    if(strcmp(cmdtext, "/deliverprod", true) == 0)
    {
        if(IsPlayerInRangeOfPoint(playerid, 3.0, 1466.9390, -1010.5936, 26.8438))
        {
            // Show products dialog
            ShowPlayerDialog(playerid, 100, DIALOG_STYLE_LIST, 
                "Select Product", 
                "Cigarettes ($200)\nPizza ($150)\nDocuments ($500)",
                "Select", "Cancel");
        }
        else
        {
            SendClientMessage(playerid, 0xFF0000FF, "Go to the job marker first!");
        }
        return 1;
    }
    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == 100 && response) // Products
    {
        PlayerProduct[playerid] = listitem;
        
        // Show customers dialog
        ShowPlayerDialog(playerid, 101, DIALOG_STYLE_LIST,
            "Select Customer",
            "Alex (San Fierro)\nMaria (Los Santos)\nJoe (Flint County)",
            "Select", "Cancel");
    }
    else if(dialogid == 101 && response) // Customers
    {
        PlayerCustomer[playerid] = listitem;
        
        // Calculate price
        PlayerPrice[playerid] = ProductPrices[PlayerProduct[playerid]];
        
        // Show confirmation
        new msg[256];
        format(msg, sizeof(msg), 
            "Product: %s\nCustomer: %s\nPrice: $%d\n\nAccept this job?",
            ProductNames[PlayerProduct[playerid]],
            CustomerNames[PlayerCustomer[playerid]],
            PlayerPrice[playerid]);
        
        ShowPlayerDialog(playerid, 102, DIALOG_STYLE_MSGBOX,
            "Confirm Delivery", msg, "Accept", "Cancel");
    }
    else if(dialogid == 102 && response) // Confirm
    {
        OnJob[playerid] = true;
        
        // Give checkpoint to customer location
        SetPlayerCheckpoint(playerid, 
            CustomerX[PlayerCustomer[playerid]],
            CustomerY[PlayerCustomer[playerid]],
            CustomerZ[PlayerCustomer[playerid]], 3.0);
        
        SendClientMessage(playerid, 0x00FF00FF, "Go to the checkpoint to deliver!");
    }
    return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
    if(OnJob[playerid])
    {
        // Give money
        GivePlayerMoney(playerid, PlayerPrice[playerid]);
        
        // Success message
        new msg[128];
        format(msg, sizeof(msg), "You delivered %s! +$%d", 
            ProductNames[PlayerProduct[playerid]], PlayerPrice[playerid]);
        SendClientMessage(playerid, 0x00FF00FF, msg);
        
        // Clean up
        DisablePlayerCheckpoint(playerid);
        OnJob[playerid] = false;
    }
    return 1;
}