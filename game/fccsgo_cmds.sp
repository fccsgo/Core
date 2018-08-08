#pragma semicolon 1
#pragma newdecls required

#include <smutils>
#include <fc_core>

public Plugin myinfo = 
{
    name        = "FC - Cmds",
    author      = "Kyle \"Kxnrl\" Frankiss",
    description = "Commands of FC community",
    version     = PI_VERSION,
    url         = "https://kxnrl.com"
};


#include <adminmenu>

TopMenu g_hTopMenu;

#include "cmds/slay.sp"
#include "cmds/teleport.sp"

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("[\x10CMD\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(false);

    LoadTranslations("common.phrases");
    LoadTranslations("playercommands.phrases");

    RegAdminCmd("sm_slay",      Command_Slay,       ADMFLAG_SLAY);
    RegAdminCmd("sm_teleport",  Command_Teleport,   ADMFLAG_SLAY);
}

public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

    if(topmenu == g_hTopMenu)
        return;

    g_hTopMenu = topmenu;

    TopMenuObject player_commands = g_hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

    if(player_commands == INVALID_TOPMENUOBJECT)
        return;

    g_hTopMenu.AddItem("sm_slay",       AdminMenu_Slay,     player_commands, "sm_slay",     ADMFLAG_SLAY);
    g_hTopMenu.AddItem("sm_teleport",   AdminMenu_Teleport, player_commands, "sm_teleport", ADMFLAG_SLAY);
}

