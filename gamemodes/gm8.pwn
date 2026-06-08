#include <a_samp>

public OnPlayerConnect(playerid)
{
    if(strcmp(cmdtext, "/Hello", true) == 0)
    {
        SendClientMessage(playerid, 0x00FF00FF, "Hello");
        return 1;
    }

    new string[16];
    string = "4";
    new strval
    strval(strval, string(a))
    // Example: Add two numbers
    new a = 150;
    new b = 27;
    new result = a + b;

    // Format the result as a string
    new message[128];
    format(message, sizeof(message), "Welcome! Calculation: %d + %d = %d", a, b, result);

    // Send to the connecting player
    SendClientMessage(playerid, 0x00FF00FF, message);

    // Also print to server console
    printf("[CONNECT] %d + %d = %d sent to player %d", a, b, result, playerid);

    return 1;
}