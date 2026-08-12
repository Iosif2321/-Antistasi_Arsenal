params [
    ["_arsenalObject", objNull, [objNull]],
    ["_holder", objNull, [objNull]],
    ["_requestId", "", [""]]
];
if (!isServer || {isRemoteExecuted && {canSuspend}} || {_requestId isEqualTo ""} || {count _requestId > 128}) exitWith {};

private _validation = [_arsenalObject, _holder] call A4A_fnc_validateCargoRequest;
_validation params ["_validRequest", "_requestPlayer", "_senderOwner", "_localHostCall", "_canonical", "_holderKey"];
private _sendResult = {
    params ["_success", "_message", ["_revision", -1, [0]]];
    private _payload = [_requestId, _success, _message, _revision];
    if (_localHostCall) then {
        _payload call A4A_fnc_receiveCargoResult;
    } else {
        if (_senderOwner >= 2) then { _payload remoteExecCall ["A4A_fnc_receiveCargoResult", _senderOwner] };
    };
};
if (!_validRequest) exitWith {
    [false, "Cargo deposit rejected by the server."] call _sendResult;
};
_holderKey = netId _holder;

private _lockAcquired = false;
private _locks = localNamespace getVariable ["A4A_ServerCargoLocks", createHashMap];
isNil {
    if !(_locks getOrDefault [_holderKey, false]) then {
        _locks set [_holderKey, true];
        localNamespace setVariable ["A4A_ServerCargoLocks", _locks];
        _lockAcquired = true;
    };
};
if (!_lockAcquired) exitWith {
    [false, "This cargo holder is already being processed."] call _sendResult;
};

private _result = call {
    _canonical params ["_canonicalObject", "_arsenalId", "_threshold"];
    private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
    private _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
    private _currentData = _dataById getOrDefault [_arsenalId, []];
    private _currentRevision = _revisions getOrDefault [_arsenalId, -1];
    if !(count _currentData isEqualTo 27 && {_currentRevision >= 0}) exitWith {
        [false, "Canonical Arsenal data is unavailable.", _currentRevision, [], false]
    };

    private _observedCargo = [_holder, false] call jn_fnc_arsenal_cargoToArray;
    if !(count _observedCargo isEqualTo 27) exitWith {
        [false, "The physical cargo could not be represented safely.", _currentRevision, [], false]
    };

    private _settings = localNamespace getVariable ["A4A_ServerSettings", createHashMap];
    private _maxCargoEntries = _settings getOrDefault ["maxCargoEntries", 2000];
    private _candidate = parseSimpleArray str _currentData;
    private _cargoRows = 0;
    private _hasCargo = false;
    private _sourceValid = true;
    {
        private _reportedIndex = _forEachIndex;
        {
            if (!_sourceValid) exitWith {};
            if !(_x isEqualType [] && {count _x isEqualTo 2}) then {
                _sourceValid = false;
            } else {
                _x params ["_className", "_amount"];
                private _derivedIndex = [_className, false] call A4A_fnc_itemTypeCached;
                if !(
                    _className isEqualType "" &&
                    {_className isNotEqualTo ""} &&
                    {_derivedIndex >= 0} &&
                    {_reportedIndex isEqualTo _derivedIndex} &&
                    {_amount isEqualType 0} &&
                    {finite _amount} &&
                    {_amount isEqualTo floor _amount} &&
                    {_amount > 0}
                ) then {
                    _sourceValid = false;
                } else {
                    _cargoRows = _cargoRows + 1;
                    _hasCargo = true;
                    if (_cargoRows > _maxCargoEntries) then {
                        _sourceValid = false;
                    } else {
                        _candidate set [
                            _derivedIndex,
                            [_candidate select _derivedIndex, [_className, _amount]] call jn_fnc_arsenal_addToArray
                        ];
                    };
                };
            };
        } forEach _x;
        if (!_sourceValid) exitWith {};
    } forEach _observedCargo;
    if (!_sourceValid || {!_hasCargo}) exitWith {
        [false, "Cargo is empty or exceeds the safe transaction limits.", _currentRevision, [], false]
    };

    private _validatedCandidate = [_candidate] call A4A_fnc_validateSnapshot;
    if !(_validatedCandidate select 0) exitWith {
        [false, format ["Cargo deposit rejected: %1", _validatedCandidate select 3], _currentRevision, [], false]
    };
    _candidate = _validatedCandidate select 1;

    private _backup = [_holder] call A4A_fnc_snapshotCargo;
    if (count _backup isNotEqualTo 4) exitWith {
        [false, "The cargo backup could not be created.", _currentRevision, [], false]
    };

    clearMagazineCargoGlobal _holder;
    clearItemCargoGlobal _holder;
    clearWeaponCargoGlobal _holder;
    clearBackpackCargoGlobal _holder;

    private _afterClear = [_holder, false] call jn_fnc_arsenal_cargoToArray;
    private _cleared = count _afterClear isEqualTo 27 && {_afterClear findIf {count _x > 0} < 0};
    if (!_cleared) exitWith {
        private _restored = [_holder, _backup] call A4A_fnc_restoreCargo;
        [false, ["Cargo clear failed; the exact backup was restored.", "Cargo clear failed and exact restoration also failed."] select (!_restored), _currentRevision, [], false]
    };

    _dataById set [_arsenalId, parseSimpleArray str _candidate];
    localNamespace setVariable ["A4A_ServerData", _dataById];
    private _newRevision = _currentRevision + 1;
    _revisions set [_arsenalId, _newRevision];
    localNamespace setVariable ["A4A_ServerRevisions", _revisions];

    private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
    {
        private _session = _sessions get _x;
        if (_session isEqualType createHashMap && {(_session getOrDefault ["arsenalId", ""]) isEqualTo _arsenalId}) then {
            _session set ["saveEligibleRevision", -1];
            _sessions set [_x, _session];
        };
    } forEach keys _sessions;
    localNamespace setVariable ["A4A_ServerSessions", _sessions];

    [true, "Cargo was deposited into the quantitative Arsenal.", _newRevision, _candidate, true]
};

_locks = localNamespace getVariable ["A4A_ServerCargoLocks", createHashMap];
_locks deleteAt _holderKey;
localNamespace setVariable ["A4A_ServerCargoLocks", _locks];

_result params ["_success", "_message", "_revision", "_committedData", "_committed"];
[_success, _message, _revision] call _sendResult;
if (_committed) then {
    private _arsenalId = _canonical select 1;
    [_arsenalId, _revision, _committedData, -1, "Physical cargo deposited into the Arsenal."] call A4A_fnc_publishSnapshot;
    [] call A4A_fnc_schedulePersistence;
};
