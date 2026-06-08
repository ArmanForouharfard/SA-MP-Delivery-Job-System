//=== delivery_job.pwn ===

#include <a_samp>
#include <a_mysql>
#include <zcmd>  // برای دستورات
#include <sscanf2> // برای پردازش ورودی

//======================= تعاریف ثابت =======================
#define MAX_PLAYER_JOB 50
#define JOB_START_X 1466.9390
#define JOB_START_Y -1010.5936
#define JOB_START_Z 26.8438

//======================= Enums =======================
enum E_PLAYER_JOB_DATA
{
    bool:OnJob,
    currentProduct[50],
    currentCustomer[50],
    currentPrice,
    currentProductId,
    currentCustomerId,
    hasProduct,  // 0=no, 1=in hand, 2=in trunk
    vehicleId,
    productObject,
    leaveTimer
}

enum E_PRODUCT_DATA
{
    productId,
    productName[50],
    sensitivity,
    basePrice
}

enum E_CUSTOMER_DATA
{
    customerId,
    customerName[50],
    Float:cx,
    Float:cy,
    Float:cz
}

//======================= متغیرهای سراسری =======================
new MySQL:dbHandle;
new PlayerJobData[MAX_PLAYERS][E_PLAYER_JOB_DATA];
new Products[MAX_PRODUCTS][E_PRODUCT_DATA];
new Customers[MAX_CUSTOMERS][E_CUSTOMER_DATA];
new TotalProducts, TotalCustomers;

// Actor برای شروع شغل
new JobStartActor;

//======================= توابع اصلی =======================

public OnGameModeInit()
{
    // اتصال به دیتابیس
    dbHandle = mysql_connect("127.0.0.1", "arman", "pawncourse", "Arman2002", 3306);
    
    if(mysql_errno(dbHandle) != 0)
    {
        print("خطا در اتصال به دیتابیس!");
        return 1;
    }
    
    print("سیستم شغلی با موفقیت بارگذاری شد!");
    
    // ایجاد Actor در نقطه شروع
    JobStartActor = CreateActor(155, JOB_START_X, JOB_START_Y, JOB_START_Z, 0.0);
    SetActorInvulnerable(JobStartActor, true);
    
    // ایجاد 3D Text بالای سر Actor
    Create3DTextLabel("{00FF00}Job: Delivery Worker\n{FFFFFF}Type /deliverprod to start", 
        0x00FF00FF, JOB_START_X, JOB_START_Y, JOB_START_Z+1.0, 5.0, 0, 0);
    
    // بارگذاری محصولات و مشتریان از دیتابیس
    LoadProductsFromDB();
    LoadCustomersFromDB();
    
    return 1;
}

//======================= بارگذاری اطلاعات از دیتابیس =======================

forward LoadProductsFromDB();
public LoadProductsFromDB()
{
    mysql_tquery(dbHandle, "SELECT * FROM products", "OnProductsLoaded", "");
}

forward OnProductsLoaded();
public OnProductsLoaded()
{
    TotalProducts = cache_num_rows();
    for(new i = 0; i < TotalProducts; i++)
    {
        cache_get_value_int(i, "id", Products[i][productId]);
        cache_get_value(i, "name", Products[i][productName], 50);
        cache_get_value_int(i, "sensitivity", Products[i][sensitivity]);
        cache_get_value_int(i, "base_price", Products[i][basePrice]);
    }
    printf("%d محصول بارگذاری شد.", TotalProducts);
}

forward LoadCustomersFromDB();
public LoadCustomersFromDB()
{
    mysql_tquery(dbHandle, "SELECT * FROM customers", "OnCustomersLoaded", "");
}

forward OnCustomersLoaded();
public OnCustomersLoaded()
{
    TotalCustomers = cache_num_rows();
    for(new i = 0; i < TotalCustomers; i++)
    {
        cache_get_value_int(i, "id", Customers[i][customerId]);
        cache_get_value(i, "name", Customers[i][customerName], 50);
        cache_get_value_float(i, "pos_x", Customers[i][cx]);
        cache_get_value_float(i, "pos_y", Customers[i][cy]);
        cache_get_value_float(i, "pos_z", Customers[i][cz]);
    }
    printf("%d مشتری بارگذاری شد.", TotalCustomers);
}

//======================= توابع کمکی =======================

// محاسبه فاصله بین دو نقطه
Float:GetDistanceBetweenPoints(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2)
{
    return floatsqroot(floatpower(floatabs(x1 - x2), 2) + 
                       floatpower(floatabs(y1 - y2), 2) + 
                       floatpower(floatabs(z1 - z2), 2));
}

// محاسبه قیمت بر اساس فاصله و حساسیت
CalculatePrice(Float:distance, sensitivity, basePrice)
{
    new price = basePrice + floatround(distance / 10.0) * sensitivity;
    return price;
}

// بررسی اینکه بازیکن قبلاً این محصول را به این مشتری تحویل داده
bool:HasDeliveredBefore(playerid, productId, customerId)
{
    new playerName[MAX_PLAYER_NAME];
    GetPlayerName(playerid, playerName, sizeof(playerName));
    
    new query[256];
    mysql_format(dbHandle, query, sizeof(query), 
        "SELECT COUNT(*) FROM jobs_delivery WHERE player_name = '%e' AND product_id = %d AND customer_id = %d",
        playerName, productId, customerId);
    
    mysql_tquery(dbHandle, query, "OnCheckDelivery", "iii", playerid, productId, customerId);
    return false; // این تابع به صورت Async باید مدیریت بشه
}

//======================= نمایش دیالوگ محصولات =======================

CMD:deliverprod(playerid, params[])
{
    if(IsPlayerInRangeOfPoint(playerid, 3.0, JOB_START_X, JOB_START_Y, JOB_START_Z))
    {
        ShowProductsDialog(playerid);
    }
    else
    {
        SendClientMessage(playerid, 0xFF0000FF, "! شما نزدیک Actor شغل نیستید!");
    }
    return 1;
}

ShowProductsDialog(playerid)
{
    new dialogStr[1024];
    strcat(dialogStr, "محصول\tقیمت پایه\tحساسیت\n");
    
    for(new i = 0; i < TotalProducts; i++)
    {
        new sensitivityText[20];
        switch(Products[i][sensitivity])
        {
            case 1: sensitivityText = "کم";
            case 2: sensitivityText = "متوسط";
            case 3: sensitivityText = "زیاد";
        }
        
        format(dialogStr, sizeof(dialogStr), "%s%s\t%d\t%s\n", 
            dialogStr, Products[i][productName], Products[i][basePrice], sensitivityText);
    }
    
    ShowPlayerDialog(playerid, DIALOG_PRODUCTS, DIALOG_STYLE_TABLIST_HEADERS,
        "انتخاب محصول برای تحویل", dialogStr, "انتخاب", "انصراف");
}

//======================= دیالوگ‌ها =======================

#define DIALOG_PRODUCTS 100
#define DIALOG_CUSTOMERS 101
#define DIALOG_CONFIRM 102

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_PRODUCTS && response)
    {
        // ذخیره محصول انتخاب شده
        PlayerJobData[playerid][currentProductId] = Products[listitem][productId];
        strcat(PlayerJobData[playerid][currentProductProduct], Products[listitem][productName], 50);
        
        // نمایش لیست مشتریانی که قبلاً این محصول بهشون تحویل داده نشده
        ShowAvailableCustomers(playerid, PlayerJobData[playerid][currentProductId]);
    }
    else if(dialogid == DIALOG_CUSTOMERS && response)
    {
        // ذخیره مشتری انتخاب شده
        PlayerJobData[playerid][currentCustomerId] = Customers[listitem][customerId];
        strcat(PlayerJobData[playerid][currentCustomerName], Customers[listitem][customerName], 50);
        
        // محاسبه فاصله از نقطه شروع
        new Float:distance = GetDistanceBetweenPoints(JOB_START_X, JOB_START_Y, JOB_START_Z,
            Customers[listitem][cx], Customers[listitem][cy], Customers[listitem][cz]);
        
        // محاسبه قیمت
        new price = CalculatePrice(distance, 
            Products[PlayerJobData[playerid][currentProductId]][sensitivity],
            Products[PlayerJobData[playerid][currentProductId]][basePrice]);
        
        PlayerJobData[playerid][currentPrice] = price;
        
        // نمایش دیالوگ تایید
        new dialogStr[512];
        format(dialogStr, sizeof(dialogStr),
            "محصول: %s\n\
            مشتری: %s\n\
            فاصله: %.0f متر\n\
            قیمت پایه: $%d\n\
            حساسیت بار: %d\n\
            \n{00FF00}مبلغ قابل دریافت: $%d{FFFFFF}\n\
            \nآیا این سفارش را قبول می‌کنید؟",
            Products[PlayerJobData[playerid][currentProductId]][productName],
            Customers[listitem][customerName],
            distance,
            Products[PlayerJobData[playerid][currentProductId]][basePrice],
            Products[PlayerJobData[playerid][currentProductId]][sensitivity],
            price);
        
        ShowPlayerDialog(playerid, DIALOG_CONFIRM, DIALOG_STYLE_MSGBOX,
            "تایید سفارش", dialogStr, "قبول می‌کنم", "انصراف");
    }
    else if(dialogid == DIALOG_CONFIRM && response)
    {
        StartDeliveryJob(playerid);
    }
    return 1;
}

//======================= توابع اصلی شغل =======================

StartDeliveryJob(playerid)
{
    PlayerJobData[playerid][OnJob] = true;
    PlayerJobData[playerid][hasProduct] = 0;
    
    SendClientMessage(playerid, 0x00FF00FF, "شغل شروع شد! به چک‌پوینت بروید تا محصول را دریافت کنید.");
    
    // ایجاد چک‌پوینت برای دریافت محصول
    SetPlayerCheckpoint(playerid, JOB_START_X, JOB_START_Y, JOB_START_Z, 3.0);
    
    // ذخیره در دیتابیس که این سفارش گرفته شده
    new playerName[MAX_PLAYER_NAME];
    GetPlayerName(playerid, playerName, sizeof(playerName));
    
    new query[256];
    mysql_format(dbHandle, query, sizeof(query),
        "INSERT INTO jobs_delivery (player_name, product_id, customer_id) VALUES ('%e', %d, %d)",
        playerName, PlayerJobData[playerid][currentProductId], PlayerJobData[playerid][currentCustomerId]);
    mysql_tquery(dbHandle, query);
}

//======================= ادامه در پاسخ بعدی... =======================