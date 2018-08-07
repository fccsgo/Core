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

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("[\x10CMD\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(false);

    LoadTranslations("common.phrases");
    LoadTranslations("playercommands.phrases");

    RegAdminCmd("sm_slay", Command_Slay, ADMFLAG_SLAY);
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

    g_hTopMenu.AddItem("sm_slay", AdminMenu_Slay, player_commands, "sm_slay", ADMFLAG_SLAY);
}

public Action Command_Slay(int client, int args)
{
    if(args < 1)
    {
        Chat(client, "用法: sm_slay <#userid|name|target type>");
        return Plugin_Handled;
    }

    char arg[32];
    GetCmdArg(1, arg, 32);

    char target_name[32];
    int target_count;
    int[] target_list = new int [MaxClients+1];
    bool tn_is_ml;

    if((target_count = ProcessTargetString(arg, client, target_list, MaxClients+1, COMMAND_FILTER_ALIVE, target_name, 32, tn_is_ml)) <= 0)
    {
        Chat(client, "目标无效!");
        return Plugin_Handled;
    }

    for(int i = 0; i < target_count; i++)
    {
        Util_SlayPlayer(client, target_list[i]);
    }

    return Plugin_Handled;
}

void Util_SlayPlayer(int admin, int target)
{
    ForcePlayerSuicide(target);
    LogAction(admin, target, "\"%L\" 处死了 \"%L\"", admin, target);
    ChatAll("\x0C%N \x07%t \x05%N", admin, "Slay player", target);
}

public void AdminMenu_Slay(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if(action == TopMenuAction_DisplayOption)
        FormatEx(buffer, maxlength, "%T", "Slay player", param);
    else if (action == TopMenuAction_SelectOption)
        Util_ShowSlayMenu(param);
}

void Util_ShowSlayMenu(int client)
{
    Menu menu = new Menu(MenuHandler_SlayMenu);

    menu.SetTitle("%T:", "Slay player", client);
    menu.ExitBackButton = true;
    AddTargetsToMenu(menu, client, true, true);
    menu.Display(client, 30);
}

public int MenuHandler_SlayMenu(Menu menu, MenuAction action, int admin, int slot)
{
    if(action == MenuAction_End)
        delete menu;
    else if(action == MenuAction_Cancel && slot == MenuCancel_ExitBack && g_hTopMenu != null)
            g_hTopMenu.Display(admin, TopMenuPosition_LastCategory);
    else if(action == MenuAction_Select)
    {
        char info[32];

        menu.GetItem(slot, info, 32);
        int userid = StringToInt(info);

        int target = 0;
        if((target = GetClientOfUserId(userid)) == 0)
            Chat(admin, "%T", "Player no longer available", admin);
        else if(!CanUserTarget(admin, target))
            Chat(admin, "%T", "Unable to target", admin);
        else if (!IsPlayerAlive(target))
            Chat(admin, "%T", "Player has since died", admin);
        else
            Util_SlayPlayer(admin, target);

        Util_ShowSlayMenu(admin);
    }
}