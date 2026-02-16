params [["_unit", player, [objNull]]];
if (isNull _unit) exitWith {false};

if (!isNull getAssignedCuratorLogic _unit) exitWith {true};

if (_unit getVariable ["A3A_Arsenal_HasZeus", false]) exitWith {true};

false
