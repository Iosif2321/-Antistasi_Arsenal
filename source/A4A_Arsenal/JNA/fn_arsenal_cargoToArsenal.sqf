/*
Author: Jeroen Notenbomer
    Adds items of passed container directly to JNA.
    Usually called on "To Cargo" button inside the JNA interface.

Arguments:
    <OBJECT> Container to add contents directly to JNA.

Scope: Server, Global Arguments, Global Effect
Environment: Any
Public: Yes

Example:
    private _object = missionNamespace getVariable ["jna_object",objNull];
    [_object] remoteExec ["jn_fnc_arsenal_cargoToArsenal",2];
*/

#include "..\defineCommon.inc"
#include "..\script_component.hpp"

if (!isServer) exitWith {};

params [["_object",objNull,[objNull]], ["_arsenalObj",objNull,[objNull]]];
if (isNull _object) exitWith {["Error: wrong input given '%1'",_object] call BIS_fnc_error;};

if (isNil { // Run in unschedule scope.
    if (_object getVariable ["A4A_JNA_cargoToArsenal_busy",false]) then {
        nil;  // will lead to exit.
    } else {
        _object setVariable ["A4A_JNA_cargoToArsenal_busy",true];
        0;  // not nil, will allow script to continue.
    };
}) exitWith {};  //  // Silent exit, likely due to spamming

// Determine arsenal ID from the arsenal object (NOT from jna_object which points to the crate)
private _arsenalID = if (!isNull _arsenalObj) then {
    _arsenalObj getVariable ["A4A_Arsenal_ID", "Base"]
} else {
    (missionNamespace getVariable ["jna_object", objNull]) getVariable ["A4A_Arsenal_ID", "Base"]
};

// Grab contents before being cleared.
private _array = _object call jn_fnc_arsenal_cargoToArray;
// Clear cargo
clearMagazineCargoGlobal _object;
clearItemCargoGlobal _object;
clearWeaponCargoGlobal _object;
clearBackpackCargoGlobal _object;

// Add items directly to the correct arsenal using explicit arsenal ID
// Instead of swapping jna_object (which is local and doesn't work on server),
// we iterate the array and call UpdateItemAdd with the correct arsenalID.
{
    private _index = _forEachIndex;
    {
        private _item = _x select 0;
        private _amount = _x select 1;
        if (_item isEqualType "" && {!(_item isEqualTo "")} && {_index != -1}) then {
            if (_index == IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG) then { _index = IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL };

            // TFAR fix
            private _radioName = getText(configfile >> "CfgWeapons" >> _item >> "tf_parent");
            if !(_radioName isEqualTo "") then { _item = _radioName };

            // Weapon Stack fix (only for actual weapons with muzzles)
            if (isArray (configfile >> "CfgWeapons" >> _item >> "muzzles")) then {
                private _weaponname = getText(configfile >> "CfgWeapons" >> _item >> "baseWeapon");
                if !(_weaponname isEqualTo "") then { _item = _weaponname };
            };

            // RHS Sight Stack fix
            private _sightname = getText(configfile >> "CfgWeapons" >> _item >> "rhs_optic_base");
            if !(_sightname isEqualTo "") then { _item = _sightname };

            // ACRE fix
            private _radioName2 = getText(configfile >> "CfgVehicles" >> _item >> "acre_baseClass");
            if !(_radioName2 isEqualTo "") then { _item = _radioName2 };

            // Update server storage with explicit arsenalID
            ["UpdateItemAdd", [_index, _item, _amount, true, "CargoToArsenal", "", _arsenalID]] call jn_fnc_arsenal;

            // Broadcast to clients viewing this arsenal
            if (!isNil "server") then {
                private _playersInArsenal = +(server getVariable [format ["jna_playersInArsenal_%1", _arsenalID], []]) - [2];
                if (0 in _playersInArsenal) then { _playersInArsenal = -2 };
                if !(_playersInArsenal isEqualTo []) then {
                    ["UpdateItemAdd", [_index, _item, _amount, true, "CargoToArsenal", "", _arsenalID]] remoteExecCall ["jn_fnc_arsenal", _playersInArsenal];
                };
            };
        };
    } forEach _x;
} forEach _array;

if (!isNull _object) then {
    _object setVariable ["A4A_JNA_cargoToArsenal_busy",false];
};
