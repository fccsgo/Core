#if defined _FC_Core_Include_
    #endinput
#endif

#define _FC_Core_Include_

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

native int  FC_Core_GetClientUId(int client, int uid);
native bool FC_Core_GetClientData(int client, int[] data); // Client_t

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