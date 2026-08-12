params [["_holder", objNull, [objNull]]];
if (isNull _holder) exitWith { [] };

private _backpacks = [];
{
    _x params ["_className", "_container"];
    _backpacks pushBack [_className, [_container] call A4A_fnc_snapshotCargo];
} forEach everyContainer _holder;

[
    getItemCargo _holder,
    +magazinesAmmoCargo _holder,
    +weaponsItemsCargo _holder,
    _backpacks
]

