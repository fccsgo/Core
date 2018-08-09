#if defined _FC_Core_Include_
    #endinput
#endif

#define _FC_Core_Include_

#define PI_VERSION "1.0.6"

enum Client_t
{
    iUniqueId,
    iFirstJoin,
    iLastSeen,
    iConnections,
    iOnlineTime,
    iSignTimes,
    iSignDate
}

native Database FC_Core_GetMySQL();
native int FC_Core_GetServerId();
native int FC_Core_GetSrvModId();

native int  FC_Core_GetClientUId(int client);
native bool FC_Core_GetClientData(int client, int[] data); // Client_t

forward void FC_OnServerLoaded(int sid, int mod);
forward void FC_OnClientLoaded(int client, int uid);
forward void FC_OnClientSigned(int client, int signtimes);

public SharedPlugin __pl_FCCSGO_Core =
{
	name = "FCCSGO-Core",
	file = "fccsgo_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};