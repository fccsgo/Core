#if defined _FC_Bans_Include_
    #endinput
#endif

#define _FC_Bans_Include_

native bool FC_Bans_BanClient(int admin, int target, int ban_type, int ban_length, const char[] ban_reason);
native bool FC_Bans_BanIdentity(int admin, const char[] ban_identity_steamid64, int ban_type, int ban_length, const char[] ban_reason);

public SharedPlugin __pl_FCCSGO_Bans =
{
	name = "FCCSGO-Bans",
	file = "fccsgo_bans.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};