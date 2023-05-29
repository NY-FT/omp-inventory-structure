#define MAX_PLAYERS (2)

#include <open.mp>
#include <sscanf2>
#include <streamer>
#include <pawn.cmd>

#define MAX_ITEMS                       (256)
#define MAX_LOOTS                       (512)

#define MAX_ITEM_NAME                   (32)
#define MAX_ITEM_INFO                   (32)

#define MAX_INVENTORY_ITEMS_PERPAGE     (10)
#define MAX_INVENTORY_PAGES             (5)
#define MAX_INVENTORY_SLOTS             (MAX_INVENTORY_ITEMS_PERPAGE * MAX_INVENTORY_PAGES)

static enum
{
    DIALOG_INVENTORY_MENU
};

static enum E_ITEM_DATA
{
    E_ITEM_NAME[MAX_ITEM_NAME],
    E_ITEM_INFO[MAX_ITEM_INFO],
    E_ITEM_MODEL_ID,
    E_ITEM_MAX_STACKS,
    bool:E_ITEM_VALID
};

static enum E_LOOT_DATA
{
    E_LOOT_ITEM_ID,
    E_LOOT_UNITS,
    bool:E_LOOT_VALID,
    STREAMER_TAG_CP:E_LOOT_CP_ID,
    STREAMER_TAG_3D_TEXT_LABEL:E_LOOT_TEXTLABEL_ID
};

static
    item[MAX_ITEMS][E_ITEM_DATA],
    loot[MAX_LOOTS][E_LOOT_DATA];

static enum E_PLAYER_DATA
{
    E_PLAYER_DATABASE_ID
};

static enum E_INVENTORY_DATA
{
    E_INVENTORY_ITEM_ID[MAX_INVENTORY_SLOTS],
    E_INVENTORY_UNITS[MAX_INVENTORY_SLOTS],
    E_INVENTORY_ITEM_COUNT,
    E_INVENTORY_PAGE_COUNT,
    bool:E_INVENTORY_SHOWN
};

static
    player[MAX_PLAYERS][E_PLAYER_DATA],
    inventory[MAX_PLAYERS][E_INVENTORY_DATA];

static
    playerCurrentLootID[MAX_PLAYERS] = { -1, ... };

main(){}

stock Item_Create(const name[], modelid, maxStack)
{
    new 
        index = -1;

    for (new i; i < MAX_ITEMS; i++)
    {
        if (!item[i][E_ITEM_VALID]) 
        {
            index = i;
            break;
        }
    }

    if (index == -1) {
        return -1;
    }

    strcat(item[index][E_ITEM_NAME], name, MAX_ITEM_NAME);
    item[index][E_ITEM_VALID] = true;
    item[index][E_ITEM_MODEL_ID] = modelid;
    item[index][E_ITEM_MAX_STACKS] = maxStack;

    return index;
}

stock bool:Item_IsValid(itemid) 
{
    if (!(0 <= itemid < MAX_ITEMS)) {
        return false;
    }

    if (!item[itemid][E_ITEM_VALID]) {
        return false;
    }

    return true;
}

stock Loot_Create(const name[], itemid, units, Float:x, Float:y, Float:z, worldid = -1, interiorid = -1, Float:drawdistance = 25.0)
{
    new 
        index = -1;

    for (new i; i < MAX_LOOTS; i++)
    {
        if (!loot[i][E_LOOT_VALID]) 
        {
            index = i;
            break;
        }
    }

    if (index == -1) {
        return -1;
    }

    loot[index][E_LOOT_VALID] = true;
    loot[index][E_LOOT_ITEM_ID] = itemid;
    loot[index][E_LOOT_UNITS] = units;
    loot[index][E_LOOT_CP_ID] = CreateDynamicCP(x, y, z, 0.85, worldid, interiorid);
    loot[index][E_LOOT_TEXTLABEL_ID] = CreateDynamic3DTextLabel(name, -1, x, y, z, drawdistance);

    return index;
}

stock bool:Loot_IsValid(lootid)
{
    if (!(0 <= lootid < MAX_LOOTS)) {
        return false;
    }

    if (!loot[lootid][E_LOOT_VALID]) {
        return false;
    }

    return true;
}

stock Inv_AddItem(playerid, &itemid, &units, &unitsAdded = 0)
{
    if (!Item_IsValid(itemid)) 
    {
        itemid = -1;
        return;
    }

    if (units <= 0) 
    {
        units = -1;
        return;
    }

    unitsAdded = 0;

    new 
        i, addUnits, index = -1;

    for (; i < MAX_INVENTORY_SLOTS; i++)
    {
        if (inventory[playerid][E_INVENTORY_ITEM_ID][i] == itemid) 
        {
            if (inventory[playerid][E_INVENTORY_UNITS][i] < item[itemid][E_ITEM_MAX_STACKS])
            {
                addUnits = min(
                    units, 
                    item[itemid][E_ITEM_MAX_STACKS] - inventory[playerid][E_INVENTORY_UNITS][i]
                );

                inventory[playerid][E_INVENTORY_UNITS][i] += addUnits;
                
                units -= addUnits;
                unitsAdded += addUnits;
            }
        }
    }

    while (units > 0)
    {
        i = 0;
        index = -1;

        for (; i < MAX_INVENTORY_SLOTS; i++)
        {
            if (inventory[playerid][E_INVENTORY_ITEM_ID][i] == -1)
            {
                index = i;
                break;
            }
        }

        if (index == -1) {
            return;
        }

        addUnits = min(
            units, 
            item[itemid][E_ITEM_MAX_STACKS]
        );

        inventory[playerid][E_INVENTORY_ITEM_ID][index] = itemid;
        inventory[playerid][E_INVENTORY_UNITS][index] = addUnits;
        inventory[playerid][E_INVENTORY_ITEM_COUNT]++;

        units -= addUnits;
        unitsAdded += addUnits;
    }
}

stock Inv_RemoveItem(playerid, &index, &units, &itemid = -1, &unitsRemoved = 0)
{
    if (!(0 <= index < MAX_INVENTORY_SLOTS)) 
    {
        index = -1;
        return;
    }

    if (units <= 0) 
    {
        units = -1;
        return;
    }

    if ((itemid = inventory[playerid][E_INVENTORY_ITEM_ID][index]) == -1) 
    {
        itemid = -1;
        return;
    }

    unitsRemoved = (units >= inventory[playerid][E_INVENTORY_UNITS][index]) 
        ? inventory[playerid][E_INVENTORY_UNITS][index] 
        : units;

    if ((inventory[playerid][E_INVENTORY_UNITS][index] -= unitsRemoved) == 0) {
        inventory[playerid][E_INVENTORY_ITEM_ID][index] = -1;
    }

    new
        Float:x, 
        Float:y, 
        Float:z,
        Float:a,
        lootText[MAX_ITEM_NAME + 32];

    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);

    format(lootText, sizeof(lootText), "%s\n(Unidades: %i)", item[itemid][E_ITEM_NAME], unitsRemoved);

    Loot_Create(lootText, itemid, unitsRemoved,
        x + (1.5 * floatsin(-a, degrees)), 
        y + (1.5 * floatcos(-a, degrees)),
        z,
        GetPlayerVirtualWorld(playerid), GetPlayerInterior(playerid)
    );
}

stock Inv_Show(playerid, page = 0)
{
    new 
        menu[(MAX_ITEM_NAME + 32) * MAX_INVENTORY_ITEMS_PERPAGE] = "Item\tUnidades\n",
        last = page ? page * MAX_INVENTORY_ITEMS_PERPAGE : 0,
        next = last;

    for (; next < MAX_INVENTORY_SLOTS; next++) 
    {
        if (next == (last + MAX_INVENTORY_ITEMS_PERPAGE))
        {
            strcat(menu, ">>>\n");
            break;
        }

        if (inventory[playerid][E_INVENTORY_ITEM_ID][next] == -1) 
        {
            strcat(menu, "Vazio\n");
            continue;
        }

        format(menu, sizeof(menu), "%s%s\t%i\n", menu, item[inventory[playerid][E_INVENTORY_ITEM_ID][next]][E_ITEM_NAME], inventory[playerid][E_INVENTORY_UNITS][next]);
    }

    if (page) {
        strcat(menu, "<<<");
    }

    inventory[playerid][E_INVENTORY_SHOWN] = true; 
    inventory[playerid][E_INVENTORY_PAGE_COUNT] = page;

    return ShowPlayerDialog(playerid, DIALOG_INVENTORY_MENU, DIALOG_STYLE_TABLIST_HEADERS, "Inventario", menu, "Selecionar", "Fechar");
}

public OnPlayerConnect(playerid)
{
    for (new i; i < MAX_INVENTORY_SLOTS; i++)
    {
        inventory[playerid][E_INVENTORY_ITEM_ID][i] = -1;
        inventory[playerid][E_INVENTORY_UNITS][i] = -1;
    }

    inventory[playerid][E_INVENTORY_ITEM_COUNT] = 0;
    inventory[playerid][E_INVENTORY_PAGE_COUNT] = 0;
    inventory[playerid][E_INVENTORY_SHOWN] = false;

    /**
     * Test:
     */

    player[playerid][E_PLAYER_DATABASE_ID] = 1;
    return 1;
}

public OnPlayerEnterDynamicCP(playerid, STREAMER_TAG_CP:checkpointid)
{
    if (GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
        for (new i; i < MAX_LOOTS; i++)
        {
            if (loot[i][E_LOOT_VALID])
            {
                if (checkpointid == loot[i][E_LOOT_CP_ID])
                {
                    playerCurrentLootID[playerid] = i;
                    break;
                }
            }
        }
    }
    return 1;
}

public OnPlayerLeaveDynamicCP(playerid, STREAMER_TAG_CP:checkpointid)
{
    if (GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
        new 
            lootid = playerCurrentLootID[playerid];

        if (Loot_IsValid(lootid))
        {
            if (checkpointid == loot[lootid][E_LOOT_CP_ID]) {
                playerCurrentLootID[playerid] = -1;
            }
        }
    }
    return 1;
}

public OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    if (GetPlayerState(playerid) == PLAYER_STATE_ONFOOT)
    {
        if (newkeys & KEY_YES) {
            return Inv_Show(playerid);
        }

        if (newkeys & KEY_WALK)
        {
            new 
                lootid = playerCurrentLootID[playerid];
            
            if (Loot_IsValid(lootid))
            {
                Inv_AddItem(playerid, loot[lootid][E_LOOT_ITEM_ID], loot[lootid][E_LOOT_UNITS]);

                if (loot[lootid][E_LOOT_UNITS] == 0) 
                {
                    playerCurrentLootID[playerid] = -1;

                    loot[lootid][E_LOOT_VALID] = false;

                    DestroyDynamicCP(loot[lootid][E_LOOT_CP_ID]);
                    DestroyDynamic3DTextLabel(loot[lootid][E_LOOT_TEXTLABEL_ID]);
                }
                else 
                {
                    new 
                        lootText[MAX_ITEM_NAME + 32];
                    
                    format(lootText, sizeof(lootText), "%s\n(Unidades: %i)", item[loot[lootid][E_LOOT_ITEM_ID]][E_ITEM_NAME], loot[lootid][E_LOOT_UNITS]);
                    UpdateDynamic3DTextLabelText(loot[lootid][E_LOOT_TEXTLABEL_ID], -1, lootText);
                }
            }
        }
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_INVENTORY_MENU)
    {
        if (response)
        {
            new 
                index = (listitem + (inventory[playerid][E_INVENTORY_PAGE_COUNT] * MAX_INVENTORY_ITEMS_PERPAGE));

            if (listitem < MAX_INVENTORY_ITEMS_PERPAGE) {
                return SendClientMessage(playerid, -1, "* Item %s selecionado com %i unidades.", item[inventory[playerid][E_INVENTORY_ITEM_ID][index]][E_ITEM_NAME], inventory[playerid][E_INVENTORY_UNITS][index]);
            }

            if (listitem == MAX_INVENTORY_ITEMS_PERPAGE && inventory[playerid][E_INVENTORY_PAGE_COUNT] + 1 != MAX_INVENTORY_PAGES) {
                return Inv_Show(playerid, inventory[playerid][E_INVENTORY_PAGE_COUNT] + 1);
            }

            if (listitem == ((inventory[playerid][E_INVENTORY_PAGE_COUNT] + 1) == MAX_INVENTORY_PAGES ? MAX_INVENTORY_ITEMS_PERPAGE : MAX_INVENTORY_ITEMS_PERPAGE + 1)) {
                return Inv_Show(playerid, inventory[playerid][E_INVENTORY_PAGE_COUNT] - 1);
            }
        }
    }
    return 1;
}

CMD:add(playerid, params[])
{
    new 
        itemid, units;

    if (sscanf(params, "ii", itemid, units)) {
        return SendClientMessage(playerid, -1, "* /add <item-id> <units>");
    }

    new 
        unitsAdded;
    
    Inv_AddItem(playerid, itemid, units, unitsAdded);

    if (itemid == -1) {
        return SendClientMessage(playerid, -1, "* Item nao encontrado.");
    }

    if (units == -1) {
        return SendClientMessage(playerid, -1, "* Unidades invalida.");
    }

    SendClientMessage(playerid, -1, "* Item %s adicionado ao seu inventario com %i unidades.", item[itemid][E_ITEM_NAME], unitsAdded);
    return 1;
}
CMD:remove(playerid, params[])
{
    new 
        index, units;

    if (sscanf(params, "ii", index, units)) {
        return SendClientMessage(playerid, -1, "* /remove <slot-id> <units>");
    }

    new 
        itemid,
        unitsRemoved;

    Inv_RemoveItem(playerid, index, units, itemid, unitsRemoved);

    if (index == -1) {
        return SendClientMessage(playerid, -1, "* Slot nao encontrado.");
    }

    if (units == -1) {
        return SendClientMessage(playerid, -1, "* Unidades invalida.");
    }

    if (itemid == -1) {
        return SendClientMessage(playerid, -1, "* Item nao encontrado.");
    }

    SendClientMessage(playerid, -1, "* Item %s largado do seu inventario com %i unidades.", item[itemid][E_ITEM_NAME], unitsRemoved);
    return 1;
}
