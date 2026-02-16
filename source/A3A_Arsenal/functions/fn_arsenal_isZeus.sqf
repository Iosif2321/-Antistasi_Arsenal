params [["_unit", player, [objNull]]];
if (isNull _unit) exitWith {false};

// Method 1: standard curator assignment
if (!isNull getAssignedCuratorLogic _unit) exitWith {true};

// Method 2: variable set by fn_assignZeus or server sync loop
if (_unit getVariable ["A3A_Arsenal_HasZeus", false]) exitWith {true};

// Method 3: manual scan of allCurators (for dedicated server where Methods 1-2 may lag)
private _isCurator = false;
private _allCur = allCurators;
private _i = 0;
while {_i < count _allCur && {!_isCurator}} do {
    private _curObj = _allCur select _i;
    private _assignedUnit = curatorUnit _curObj;
    if (!isNull _assignedUnit) then {
        if (_assignedUnit isEqualTo _unit) then {
            _isCurator = true;
        };
    };
    _i = _i + 1;
};

_isCurator
