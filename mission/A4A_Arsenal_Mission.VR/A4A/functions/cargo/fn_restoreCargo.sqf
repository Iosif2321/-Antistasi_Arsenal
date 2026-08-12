params [
    ["_holder", objNull, [objNull]],
    ["_snapshot", [], [[]]]
];
if (isNull _holder || {!local _holder} || {count _snapshot isNotEqualTo 4}) exitWith { false };

private _itemCargo = _snapshot select 0;
private _magazineCargo = _snapshot select 1;
private _weaponCargo = _snapshot select 2;
private _subcontainers = _snapshot select 3;
private _valid =
    _itemCargo isEqualType [] && {count _itemCargo isEqualTo 2} &&
    {_magazineCargo isEqualType []} &&
    {_weaponCargo isEqualType []} &&
    {_subcontainers isEqualType []};
if (!_valid) exitWith { false };

private _classes = _itemCargo select 0;
private _counts = _itemCargo select 1;
if !(_classes isEqualType [] && {_counts isEqualType []} && {count _classes isEqualTo count _counts}) exitWith { false };
{
    if !(
        _x isEqualType "" &&
        {_x isNotEqualTo ""} &&
        {(_counts select _forEachIndex) isEqualType 0} &&
        {finite (_counts select _forEachIndex)} &&
        {(_counts select _forEachIndex) isEqualTo floor (_counts select _forEachIndex)} &&
        {(_counts select _forEachIndex) > 0}
    ) exitWith { _valid = false };
} forEach _classes;
{
    if !(
        _x isEqualType [] &&
        {count _x >= 2} &&
        {(_x select 0) isEqualType ""} &&
        {(_x select 0) isNotEqualTo ""} &&
        {(_x select 1) isEqualType 0} &&
        {finite (_x select 1)} &&
        {(_x select 1) >= 0}
    ) exitWith { _valid = false };
} forEach _magazineCargo;
{
    if !(_x isEqualType [] && {count _x >= 1} && {(_x select 0) isEqualType ""} && {(_x select 0) isNotEqualTo ""}) exitWith {
        _valid = false;
    };
} forEach _weaponCargo;
{
    if !(
        _x isEqualType [] &&
        {count _x isEqualTo 2} &&
        {(_x select 0) isEqualType ""} &&
        {(_x select 0) isNotEqualTo ""} &&
        {(_x select 1) isEqualType []} &&
        {count (_x select 1) isEqualTo 4}
    ) exitWith { _valid = false };
} forEach _subcontainers;
if (!_valid) exitWith { false };

clearMagazineCargoGlobal _holder;
clearItemCargoGlobal _holder;
clearWeaponCargoGlobal _holder;
clearBackpackCargoGlobal _holder;

for "_index" from 0 to (count _classes - 1) do {
    _holder addItemCargoGlobal [_classes select _index, _counts select _index];
};
{
    _holder addMagazineAmmoCargo [_x select 0, 1, _x select 1];
} forEach _magazineCargo;
{
    _holder addWeaponWithAttachmentsCargoGlobal [_x, 1];
} forEach _weaponCargo;

{
    _x params ["_containerClass", "_nestedSnapshot"];
    private _before = (everyContainer _holder) apply {_x select 1};
    private _containerType = [_containerClass, false] call A4A_fnc_itemTypeCached;
    if (_containerType isEqualTo 5) then {
        _holder addBackpackCargoGlobal [_containerClass, 1];
    } else {
        _holder addItemCargoGlobal [_containerClass, 1];
    };

    private _created = objNull;
    {
        private _candidate = _x select 1;
        if !(_candidate in _before) exitWith { _created = _candidate };
    } forEach everyContainer _holder;
    if (isNull _created || {!([_created, _nestedSnapshot] call A4A_fnc_restoreCargo)}) exitWith {
        _valid = false;
    };
} forEach _subcontainers;

_valid
