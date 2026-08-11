params [["_unit", player, [objNull]]];
if (isNull _unit) exitWith {false};

private _curator = getAssignedCuratorLogic _unit;
private _hasAssignedCurator = !isNull _curator && {!isNull (getAssignedCuratorUnit _curator)};

// The replicated flag is a client-side display cache, never server authority.
if (isServer) exitWith {_hasAssignedCurator};

if (_hasAssignedCurator) exitWith {true};

if (_unit getVariable ["A4A_Arsenal_HasZeus", false]) exitWith {true};

false
