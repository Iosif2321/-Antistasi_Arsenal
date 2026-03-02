params [["_unit", player, [objNull]]];
if (isNull _unit) exitWith {false};

private _curator = getAssignedCuratorLogic _unit;
if (!isNull _curator && {!isNull (getAssignedCuratorUnit _curator)}) exitWith {true};

if (_unit getVariable ["A4A_Arsenal_HasZeus", false]) exitWith {true};

false
