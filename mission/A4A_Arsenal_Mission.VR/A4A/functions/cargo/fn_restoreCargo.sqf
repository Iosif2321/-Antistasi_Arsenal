params [
    ["_holder", objNull, [objNull]],
    ["_snapshot", [], [[]]]
];
if (isNull _holder || {!local _holder} || {count _snapshot isNotEqualTo 4}) exitWith { false };

clearMagazineCargoGlobal _holder;
clearItemCargoGlobal _holder;
clearWeaponCargoGlobal _holder;
clearBackpackCargoGlobal _holder;

private _valid = true;
private _itemCargo = _snapshot select 0;
if !(_itemCargo isEqualType [] && {count _itemCargo isEqualTo 2}) then {
    _valid = false;
} else {
    private _classes = _itemCargo select 0;
    private _counts = _itemCargo select 1;
    if !(_classes isEqualType [] && {_counts isEqualType []} && {count _classes isEqualTo count _counts}) then {
        _valid = false;
    } else {
        for "_index" from 0 to (count _classes - 1) do {
            _holder addItemCargoGlobal [_classes select _index, _counts select _index];
        };
    };
};

if (_valid) then {
    {
        if !(_x isEqualType [] && {count _x >= 2}) exitWith { _valid = false };
        _holder addMagazineAmmoCargo [_x select 0, 1, _x select 1];
    } forEach (_snapshot select 1);
};

if (_valid) then {
    {
        if !(_x isEqualType [] && {count _x >= 1}) exitWith { _valid = false };
        _holder addWeaponWithAttachmentsCargoGlobal [_x, 1];
    } forEach (_snapshot select 2);
};

if (_valid) then {
    {
        if !(_x isEqualType [] && {count _x isEqualTo 2}) exitWith { _valid = false };
        _x params ["_backpackClass", "_backpackSnapshot"];
        private _before = (everyContainer _holder) apply {_x select 1};
        _holder addBackpackCargoGlobal [_backpackClass, 1];
        private _created = objNull;
        {
            private _candidate = _x select 1;
            if !(_candidate in _before) exitWith { _created = _candidate };
        } forEach everyContainer _holder;
        if (isNull _created || {!([_created, _backpackSnapshot] call A4A_fnc_restoreCargo)}) exitWith {
            _valid = false;
        };
    } forEach (_snapshot select 3);
};

_valid

