if (!isServer || isRemoteExecuted) exitWith {
    diag_log "[A4A Mission] Rejected remote arsenal registration";
};

private _rows = call compile preprocessFileLineNumbers "A4A\config\arsenals.sqf";
if !(_rows isEqualType []) exitWith {
    diag_log "[A4A Mission] Arsenal configuration must return an array";
};

private _registry = localNamespace getVariable ["A4A_ServerRegistry", createHashMap];
private _ids = localNamespace getVariable ["A4A_ServerIdRegistry", createHashMap];
private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
private _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
private _ready = localNamespace getVariable ["A4A_ServerReady", createHashMap];
private _serverSettings = localNamespace getVariable ["A4A_ServerSettings", createHashMap];
private _unlockThresholdOverride = _serverSettings getOrDefault ["unlockThresholdOverride", 0];

{
    private _row = _x;
    if !(_row isEqualType [] && {count _row isEqualTo 3}) then {
        diag_log format ["[A4A Mission] Ignored malformed arsenal row %1", _forEachIndex];
        continue;
    };

    _row params [
        ["_variableName", "", [""]],
        ["_arsenalId", "", [""]],
        ["_threshold", -1, [0]]
    ];

    if (
        _variableName isEqualTo "" ||
        {count _variableName > 128} ||
        {_arsenalId isEqualTo ""} ||
        {count _arsenalId > 64} ||
        {!finite _threshold} ||
        {_threshold isNotEqualTo floor _threshold} ||
        {_threshold < 0} ||
        {_threshold > 100000000}
    ) then {
        diag_log format ["[A4A Mission] Ignored invalid arsenal row %1", _forEachIndex];
        continue;
    };
    if (_unlockThresholdOverride > 0) then { _threshold = _unlockThresholdOverride };

    private _object = missionNamespace getVariable [_variableName, objNull];
    if (isNull _object) then {
        diag_log format ["[A4A Mission] Object variable '%1' does not resolve", _variableName];
        continue;
    };

    private _objectKey = netId _object;
    if (_objectKey isEqualTo "" || {_objectKey isEqualTo "0:0"}) then {
        diag_log format ["[A4A Mission] Arsenal '%1' is not networked", _variableName];
        continue;
    };
    if (!isNil {_registry get _objectKey} || {!isNil {_ids get _arsenalId}}) then {
        diag_log format ["[A4A Mission] Duplicate arsenal object or ID '%1'", _arsenalId];
        continue;
    };

    _ready set [_arsenalId, false];
    _registry set [_objectKey, [_object, _arsenalId, _threshold]];
    _ids set [_arsenalId, _objectKey];

    private _data = [];
    _data resize 27;
    for "_index" from 0 to 26 do {
        _data set [_index, []];
    };
    private _revision = 0;

    if (!isNil "A4A_fnc_loadPersistence") then {
        private _loaded = [_arsenalId] call A4A_fnc_loadPersistence;
        if (
            _loaded isEqualType [] &&
            {count _loaded isEqualTo 3} &&
            {_loaded select 0} &&
            {(_loaded select 1) isEqualType []} &&
            {(_loaded select 2) isEqualType 0}
        ) then {
            _data = +(_loaded select 1);
            _revision = _loaded select 2;
        };
    };

    _dataById set [_arsenalId, _data];
    _revisions set [_arsenalId, _revision];
    _object setVariable ["A4A_Arsenal_MissionMeta", [_arsenalId, _threshold], true];
    _ready set [_arsenalId, true];
    diag_log format ["[A4A Mission] Registered arsenal '%1' on %2", _arsenalId, _object];
} forEach _rows;

localNamespace setVariable ["A4A_ServerRegistry", _registry];
localNamespace setVariable ["A4A_ServerIdRegistry", _ids];
localNamespace setVariable ["A4A_ServerData", _dataById];
localNamespace setVariable ["A4A_ServerRevisions", _revisions];
localNamespace setVariable ["A4A_ServerReady", _ready];
