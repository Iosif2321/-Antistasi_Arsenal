params [["_holder", objNull, [objNull]]];
if (isNull _holder) exitWith { [] };

/*
    getItemCargo can also contain the shell class of a uniform/vest container.
    Store every physical subcontainer separately, subtract its shell once from
    the flat item counts, and recurse into its contents. This prevents rollback
    from duplicating a filled shell and allows uniforms, vests and backpacks to
    be recreated with their original nested contents.
*/
private _itemCargo = getItemCargo _holder;
if !(_itemCargo isEqualType [] && {count _itemCargo isEqualTo 2}) exitWith { [] };
private _itemClasses = +(_itemCargo select 0);
private _itemCounts = +(_itemCargo select 1);
if !(_itemClasses isEqualType [] && {_itemCounts isEqualType []} && {count _itemClasses isEqualTo count _itemCounts}) exitWith { [] };

private _subcontainers = [];
{
    _x params ["_className", "_container"];
    if (_className isEqualType "" && {_className isNotEqualTo ""} && {!isNull _container}) then {
        private _flatIndex = _itemClasses find _className;
        if (_flatIndex >= 0) then {
            private _remaining = (_itemCounts select _flatIndex) - 1;
            if (_remaining > 0) then {
                _itemCounts set [_flatIndex, _remaining];
            } else {
                _itemClasses deleteAt _flatIndex;
                _itemCounts deleteAt _flatIndex;
            };
        };
        _subcontainers pushBack [_className, [_container] call A4A_fnc_snapshotCargo];
    };
} forEach everyContainer _holder;

[
    [_itemClasses, _itemCounts],
    +magazinesAmmoCargo _holder,
    +weaponsItemsCargo _holder,
    _subcontainers
]
