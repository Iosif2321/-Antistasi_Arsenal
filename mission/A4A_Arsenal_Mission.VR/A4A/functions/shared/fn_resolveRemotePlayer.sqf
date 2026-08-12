params [
    ["_senderOwner", -1, [0]],
    ["_allowLocalHost", false, [false]]
];

if (
    _allowLocalHost &&
    {!isRemoteExecuted} &&
    {isServer} &&
    {hasInterface} &&
    {!isNull player}
) exitWith { player };

if (_senderOwner < 2) exitWith { objNull };

private _resolved = objNull;
{
    if (
        owner _x isEqualTo _senderOwner &&
        {!(_x isKindOf "VirtualMan_F")} &&
        {getPlayerUID _x isNotEqualTo ""}
    ) exitWith {
        _resolved = _x;
    };
} forEach allPlayers;

_resolved

