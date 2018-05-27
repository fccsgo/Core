public Plugin myinfo = 
{
    name        = "FC - Core",
    author      = "Kyle \"Kxnrl\" Frankiss",
    description = "Core framwork of FC community",
    version     = "1.0",
    url         = "https://kxnrl.com"
};

#pragma semicolon 1
#pragma newdecls required

#include <smutils>
#include <fc_core>


int g_Client[MAXPLAYERS+1][Client_t];

int g_iServerId; // Server Id
int g_iSrvModId; // Server Mod Id

Database g_MySQL;

char g_szHostName[128];

Handle g_fwdServerLoaded;
Handle g_fwdClientLoaded;
Handle g_fwdClientSigned;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("FCCSGO-Core");

    CreateNative("FC_Core_GetMySQL",        Native_GetMySQL);
    CreateNative("FC_Core_GetServerId",     Native_GetServerId);
    CreateNative("FC_Core_GetSrvModId",     Native_GetSrvModId);

    // Clients
    CreateNative("FC_Core_GetClientUId",    Native_GetUniqueId);
    CreateNative("FC_Core_GetClientData",   Native_GetDataArray);

    return APLRes_Success;
}

public int Native_GetMySQL(Handle plugin, int numParams)
{
    return view_as<int>(g_MySQL);
}

public int Native_GetServerId(Handle plugin, int numParams)
{
    return g_iServerId;
}

public int Native_GetSrvModId(Handle plugin, int numParams)
{
    return g_iSrvModId;
}

public int Native_GetUniqueId(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if(!ClientIsValid(client, true))
        ThrowNativeError(SP_ERROR_PARAM, "client index %d in invalid.", client);
    
    return g_Client[client][iUniqueId];
}

public int Native_GetDataArray(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if(!ClientIsValid(client, true))
        ThrowNativeError(SP_ERROR_PARAM, "client index %d in invalid.", client);
    
    if(g_Client[client][iUniqueId] <= 0)
        return false;
    
    int data[Client_t];
    for(int i = 1; i < view_as<int>(Client_t); ++i)
        data[view_as<Client_t>(i)] = g_Client[client][view_as<Client_t>(i)];

    SetNativeArray(2, data[0], sizeof(data));
    
    return true;
}

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("\x0CFCCSGO");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(true);

    g_fwdServerLoaded = CreateGlobalForward("FC_OnServerLoaded",  ET_Ignore, Param_Cell, Param_Cell);
    g_fwdClientLoaded = CreateGlobalForward("FC_OnClientLoaded",  ET_Ignore, Param_Cell);
    g_fwdClientSigned = CreateGlobalForward("FC_OnClientSigned",  ET_Ignore, Param_Cell, Param_Cell);

    Timer_ReconnectToDatabase(INVALID_HANDLE, 0);
    
    RegConsoleCmd("sm_sign",    Command_Sign);
    RegConsoleCmd("sm_qiandao", Command_Sign);
}

public Action Timer_ReconnectToDatabase(Handle timer, int retry)
{
    if(g_MySQL != null)
    {
        PrintToServer("Database connected!");
        return Plugin_Stop;
    }

    Database.Connect(MySQL_OnConnected, "default", retry);

    return Plugin_Stop;
}

public void MySQL_OnConnected(Database db, const char[] error, int retry)
{
    if(db == null)
    {
        LogError("Connect failed -> %s", error);
        if(++retry <= 10)
            CreateTimer(5.0, Timer_ReconnectToDatabase, retry);
        else
            SetFailState("connect to database failed! -> %s", error);
        return;
    }

    g_MySQL = db;
    g_MySQL.SetCharset("utf8mb4");

    PrintToServer("Database connected!");
    
    ConVar cvar = FindConVar("sv_hibernate_when_empty");
    if(cvar != null)
        cvar.IntValue = 0;

    cvar = FindConVar("hostip");
    if(cvar == null)
        SetFailState("hostip is invalid CVar");

    char ip[24];
    FormatEx(ip, 24, "%d.%d.%d.%d", ((cvar.IntValue & 0xFF000000) >> 24) & 0xFF, ((cvar.IntValue & 0x00FF0000) >> 16) & 0xFF, ((cvar.IntValue & 0x0000FF00) >>  8) & 0xFF, ((cvar.IntValue & 0x000000FF) >>  0) & 0xFF);

    cvar = FindConVar("hostport");
    if(cvar == null)
        SetFailState("hostport is invalid CVar");

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "SELECT * FROM `dxg_servers` WHERE `ip`='%s' AND `port`='%d';", ip, cvar.IntValue);
    g_MySQL.Query(MySQL_ServerDataCallback, m_szQuery, _, DBPrio_High);
}

public void MySQL_ServerDataCallback(Database db, DBResultSet results, const char[] error, any unuse)
{
    if(results == null || error[0])
    {
        if(StrContains(error, "lost connection", false) == -1)
        {
            SetFailState("Query Server Info: %s", error);
            return;
        }
        
        ConVar cvar = null;

        cvar = FindConVar("hostip");
        if(cvar == null)
            SetFailState("hostip is invalid CVar");

        char ip[24];
        FormatEx(ip, 24, "%d.%d.%d.%d", ((cvar.IntValue & 0xFF000000) >> 24) & 0xFF, ((cvar.IntValue & 0x00FF0000) >> 16) & 0xFF, ((cvar.IntValue & 0x0000FF00) >>  8) & 0xFF, ((cvar.IntValue & 0x000000FF) >>  0) & 0xFF);

        cvar = FindConVar("hostport");
        if(cvar == null)
            SetFailState("hostport is invalid CVar");

        char m_szQuery[128];
        FormatEx(m_szQuery, 128, "SELECT * FROM `dxg_servers` WHERE `ip`='%s' AND `port`='%d';", ip, cvar.IntValue);

        DataPack pack = new DataPack();
        pack.WriteFunction(MySQL_ServerDataCallback);
        pack.WriteCell(strlen(m_szQuery)+1);
        pack.WriteString(m_szQuery);
        pack.WriteCell(unuse);
        pack.WriteCell(DBPrio_High);
        CreateTimer(1.0, Timer_SQLQueryDelay, pack);
        return;
    }

    if(!results.FetchRow())
    {
        SetFailState("Not Found this server in database");
        return;
    }

    g_iServerId = results.FetchInt(0);
    g_iSrvModId = results.FetchInt(1);
    results.FetchString(2, g_szHostName, 128);

    char password[24];
    RandomString(password, 24);

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "UPDATE `dxg_servers` SET `rcon`='%s' WHERE `sid`='%d';", password, g_iServerId);
    g_MySQL.Query(MySQL_UpdatePasswordCallback, m_szQuery, _, DBPrio_High);
}

public void MySQL_UpdatePasswordCallback(Database db, DBResultSet results, const char[] error, any unuse)
{
    if(results == null || error[0])
        LogError("Update RCon password: %s", error);

    // server loaded
    Call_StartForward(g_fwdServerLoaded);
    Call_PushCell(g_iServerId);
    Call_PushCell(g_iSrvModId);
    Call_Finish();
}

public Action Timer_SQLQueryDelay(Handle timer, DataPack pack)
{
    pack.Reset();
    SQLQueryCallback callback = view_as<SQLQueryCallback>(pack.ReadFunction());
    int strsize = pack.ReadCell();
    char[] m_szQuery = new char[strsize];
    pack.ReadString(m_szQuery, strsize);
    any cell = pack.ReadCell();
    DBPriority prio = pack.ReadCell();
    delete pack;

    if(g_MySQL == null)
    {
        LogError("Timer_SQLQueryDelay -> [%s]", m_szQuery);
        return Plugin_Stop;
    }

    g_MySQL.Query(callback, m_szQuery, cell, prio);

    return Plugin_Stop;
}

public void OnClientConnected(int client)
{
    for(int i = 0; i < view_as<int>(Client_t); ++i)
        g_Client[client][view_as<Client_t>(i)] = -1;
}

public void OnClientPutInServer(int client)
{
    if(!ClientIsValid(client))
        return;
    
    int steam = GetSteamAccountID(client, true);
    if(steam == 0 && !IsClientInKickQueue(client))
    {
        KickClient(client, "Invalid Steam Account!");
        return;
    }
    
    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "SELECT * FROM `dxg_players` WHERE steamid = '%d';", steam);
    g_MySQL.Query(MySQL_LoadClientDataCallback, m_szQuery, steam, DBPrio_Normal);
}

public void MySQL_LoadClientDataCallback(Database db, DBResultSet results, const char[] error, int steam)
{
    int client = FindClientByAccount(steam);
    
    if(!ClientIsValid(client))
        return;

    if(results == null || error[0])
    {
        if(StrContains(error, "lost connection", false) == -1)
        {
            LogError("MySQL_LoadClientDataCallback -> %L -> %s", client, error);
            
            if(!IsClientInKickQueue(client))
                KickClient(client, "SteamId is not allow!");
            
            return;
        }
        
        char m_szQuery[128];
        FormatEx(m_szQuery, 128, "SELECT * FROM `dxg_players` WHERE steamid = '%d';", steam);

        DataPack pack = new DataPack();
        pack.WriteFunction(MySQL_LoadClientDataCallback);
        pack.WriteCell(strlen(m_szQuery)+1);
        pack.WriteString(m_szQuery);
        pack.WriteCell(steam);
        pack.WriteCell(DBPrio_High);
        CreateTimer(1.0, Timer_SQLQueryDelay, pack);
        return;
    }
    
    if(results.RowCount < 1 || !results.FetchRow())
    {
        char m_szQuery[128];
        FormatEx(m_szQuery, 128, "INSERT INTO `dxg_servers` (`firstjoin`, `steamid`) VALUES ('%d', '%d');", GetTime(), steam);
        g_MySQL.Query(MySQL_InsertClientDataCallback, m_szQuery, steam, DBPrio_Normal);
        return;
    }
    
    g_Client[client][iUniqueId] = results.FetchInt(0);

    for(int i = 1; i < view_as<int>(Client_t); ++i)
        g_Client[client][view_as<Client_t>(i)] = results.FetchInt(i+1);
    
    Call_StartForward(g_fwdClientLoaded);
    Call_PushCell(client);
    Call_Finish();
}

public void MySQL_InsertClientDataCallback(Database db, DBResultSet results, const char[] error, int steam)
{
    int client = FindClientByAccount(steam);
    
    if(!ClientIsValid(client))
        return;

    if(results == null || error[0])
        LogError("MySQL_InsertClientDataCallback -> %L -> %s", client, error);

    OnClientPutInServer(client);
}

public void OnClientDisconnect(int client)
{
    if(g_Client[client][iUniqueId] <= 0)
        return;
    
    char m_szQuery[2048];
    FormatEx(m_szQuery, 2048,  "UPDATE `dxg_players` SET            \
                                `lastseen` = %d,                    \
                                `connections` = `connections` + 1,  \
                                `onlinetimes` = `onlinetimes` + %d, \
                                WHERE                               \
                                    `uid` = %d,                     \
                                  AND                               \
                                    `steamid` = %d                  \
                               ",
                                GetTime(),
                                RoundToFloor(GetClientTime(client)),
                                g_Client[client][iUniqueId],
                                GetSteamAccountID(client)
            );

    g_MySQL.Query(MySQL_SaveClientCallback, m_szQuery, _, DBPrio_Low);
    
    OnClientConnected(client);
}

public void MySQL_SaveClientCallback(Database db, DBResultSet results, const char[] error, any unuse)
{
    if(results == null || error[0])
        LogError("MySQL_InsertClientDataCallback -> %s", error);
}

public Action Command_Sign(int client, int args)
{
    if(!(g_Client[client][iUniqueId] > 0))
    {
        Chat(client, "Your data haven't beed loaded yet.");
        return Plugin_Handled;
    }
    
    if(g_Client[client][iSignDate] >= GetToday())
    {
        Chat(client, "You've already signed.");
        return Plugin_Handled;
    }
    
    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "UPDATE `dxg_players` SET `signtimes` = `signtimes` + 1, `signdate` = %d WHERE uid = %d", GetToday(), g_Client[client][iUniqueId]);
    g_MySQL.Query(MySQL_SignClientCallback, m_szQuery, GetClientUserId(client), DBPrio_High);
    
    Chat(client, "Processing your request.");

    return Plugin_Handled;
}

public void MySQL_SignClientCallback(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    
    if(!ClientIsValid(client))
        return;

    if(results == null || error[0])
    {
        LogError("MySQL_SignClientCallback -> %L -> %s", client, error);
        return;
    }

    g_Client[client][iSignDate]  = GetToday();
    g_Client[client][iSignTimes]++;
    
    Chat(client, "\x04", "Sign was successful.");
    
    Call_StartForward(g_fwdClientSigned);
    Call_PushCell(client);
    Call_PushCell(g_Client[client][iSignTimes]);
    Call_Finish();
}