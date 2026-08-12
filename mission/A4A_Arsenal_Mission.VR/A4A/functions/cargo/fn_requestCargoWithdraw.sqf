params [
    ["_arsenalObject", objNull, [objNull]],
    ["_holder", objNull, [objNull]],
    ["_requestId", "", [""]],
    ["_manifest", [], [[]]]
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
    [false, "Cargo load request rejected by the server."] call _sendResult;
};

private _lockAcquired = false;
private _locks = localNamespace getVariable ["A4A_ServerCargoLocks", createHashMap];
private _lockExpiresAt = diag_tickTime + 30;
isNil {
    private _existingLockUntil = _locks getOrDefault [_holderKey, -1];
    if !(_existingLockUntil isEqualType 0) then { _existingLockUntil = -1 };
    if (_existingLockUntil <= diag_tickTime) then {
        _locks set [_holderKey, _lockExpiresAt];
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

    private _settings = localNamespace getVariable ["A4A_ServerSettings", createHashMap];
    private _maxCargoEntries = _settings getOrDefault ["maxCargoEntries", 2000];
    private _maxAmount = _settings getOrDefault ["maxAmount", 100000000];
    if (count _manifest < 1 || {count _manifest > _maxCargoEntries}) exitWith {
        [false, "The cargo manifest is empty or too large.", _currentRevision, [], false]
    };

    private _aggregated = createHashMap;
    private _manifestValid = true;
    {
        if !(_x isEqualType [] && {count _x isEqualTo 3}) then {
            _manifestValid = false;
        } else {
            _x params ["_claimedIndex", "_claimedClass", "_claimedAmount"];
            if !(
                _claimedIndex isEqualType 0 &&
                {_claimedClass isEqualType ""} &&
                {_claimedClass isNotEqualTo ""} &&
                {count _claimedClass <= 256} &&
                {_claimedAmount isEqualType 0} &&
                {finite _claimedAmount} &&
                {_claimedAmount isEqualTo floor _claimedAmount} &&
                {_claimedAmount > 0} &&
                {_claimedAmount <= _maxAmount}
            ) then {
                _manifestValid = false;
            } else {
                private _canonicalClass = _claimedClass;
                private _derivedIndex = [_canonicalClass, false] call A4A_fnc_itemTypeCached;
                if (_derivedIndex in [0, 1, 2, 9]) then {
                    _canonicalClass = _canonicalClass call BIS_fnc_baseWeapon;
                    _derivedIndex = [_canonicalClass, false] call A4A_fnc_itemTypeCached;
                };
                if (_derivedIndex < 0 || {_derivedIndex isNotEqualTo _claimedIndex}) then {
                    _manifestValid = false;
                } else {
                    private _key = format ["%1|%2", _derivedIndex, toLower _canonicalClass];
                    private _row = _aggregated getOrDefault [_key, [_derivedIndex, _canonicalClass, 0]];
                    private _combinedAmount = (_row select 2) + _claimedAmount;
                    if (!finite _combinedAmount || {_combinedAmount > _maxAmount}) then {
                        _manifestValid = false;
                    } else {
                        _row set [2, _combinedAmount];
                        _aggregated set [_key, _row];
                    };
                };
            };
        };
        if (!_manifestValid) exitWith {};
    } forEach _manifest;
    if (!_manifestValid || {count keys _aggregated < 1}) exitWith {
        [false, "The cargo manifest is malformed or non-canonical.", _currentRevision, [], false]
    };

    private _normalizedManifest = (keys _aggregated) apply {_aggregated get _x};
    private _candidate = parseSimpleArray str _currentData;
    private _stockValid = true;
    {
        _x params ["_index", "_className", "_amount"];
        private _available = [_candidate select _index, _className] call jn_fnc_arsenal_itemCount;
        if (_available isEqualTo 0 || {_available isNotEqualTo -1 && {_available < _amount}}) then {
            _stockValid = false;
        } else {
            _candidate set [_index, [_candidate select _index, [_className, _amount]] call jn_fnc_arsenal_removeFromArray];
        };
        if (!_stockValid) exitWith {};
    } forEach _normalizedManifest;
    if (!_stockValid) exitWith {
        [false, "The Arsenal no longer has enough stock for this cargo manifest.", _currentRevision, [], false]
    };

    private _validatedCandidate = [_candidate] call A4A_fnc_validateSnapshot;
    if !(_validatedCandidate select 0) exitWith {
        [false, format ["Cargo manifest rejected: %1", _validatedCandidate select 3], _currentRevision, [], false]
    };
    _candidate = _validatedCandidate select 1;

    private _backup = [_holder] call A4A_fnc_snapshotCargo;
    if (count _backup isNotEqualTo 4) exitWith {
        [false, "The cargo backup could not be created.", _currentRevision, [], false]
    };
    private _beforeCargo = [_holder, false] call jn_fnc_arsenal_cargoToArray;
    if (count _beforeCargo isNotEqualTo 27) exitWith {
        [false, "The existing physical cargo could not be measured.", _currentRevision, [], false]
    };

    private _expectedPhysicalCargo = parseSimpleArray str _beforeCargo;
    {
        _x params ["_index", "_className", "_amount"];
        _expectedPhysicalCargo set [
            _index,
            [_expectedPhysicalCargo select _index, [_className, _amount]] call jn_fnc_arsenal_addToArray
        ];
    } forEach _normalizedManifest;
    private _validatedPhysicalCargo = [_expectedPhysicalCargo] call A4A_fnc_validateSnapshot;
    if !(_validatedPhysicalCargo select 0) exitWith {
        [false, format ["The resulting physical cargo is unsafe: %1", _validatedPhysicalCargo select 3], _currentRevision, [], false]
    };
    _expectedPhysicalCargo = _validatedPhysicalCargo select 1;

    private _physicalCommandsValid = true;
    {
        _x params ["_index", "_className", "_amount"];
        if (isClass (configFile >> "CfgMagazines" >> _className)) then {
            private _capacity = getNumber (configFile >> "CfgMagazines" >> _className >> "count");
            if (_capacity <= 0) then {
                _physicalCommandsValid = false;
            } else {
                private _remaining = _amount;
                while {_remaining > 0} do {
                    private _rounds = _remaining min _capacity;
                    _holder addMagazineAmmoCargo [_className, 1, _rounds];
                    _remaining = _remaining - _rounds;
                };
            };
        } else {
            if (_index isEqualTo 5) then {
                _holder addBackpackCargoGlobal [_className, _amount];
            } else {
                if (_index in [0, 1, 2, 9]) then {
                    _holder addWeaponCargoGlobal [_className, _amount];
                } else {
                    _holder addItemCargoGlobal [_className, _amount];
                };
            };
        };
        if (!_physicalCommandsValid) exitWith {};
    } forEach _normalizedManifest;

    private _afterCargo = [_holder, false] call jn_fnc_arsenal_cargoToArray;
    private _physicalDeltaValid =
        _physicalCommandsValid &&
        {count _afterCargo isEqualTo 27} &&
        {load _holder <= 1.0001};
    if (_physicalDeltaValid) then {
        for "_index" from 0 to 26 do {
            {
                _x params ["_className", "_expectedAmount"];
                private _actualAmount = [_afterCargo select _index, _className] call jn_fnc_arsenal_itemCount;
                if (_actualAmount isNotEqualTo _expectedAmount) exitWith { _physicalDeltaValid = false };
            } forEach (_expectedPhysicalCargo select _index);
            if (!_physicalDeltaValid) exitWith {};
            {
                _x params ["_className", "_afterAmount"];
                private _expectedAmount = [_expectedPhysicalCargo select _index, _className] call jn_fnc_arsenal_itemCount;
                if (_afterAmount isNotEqualTo _expectedAmount) exitWith { _physicalDeltaValid = false };
            } forEach (_afterCargo select _index);
            if (!_physicalDeltaValid) exitWith {};
        };
    };
    if (!_physicalDeltaValid) exitWith {
        private _restored = [_holder, _backup] call A4A_fnc_restoreCargo;
        [false, ["Cargo capacity was insufficient; the exact backup was restored.", "Cargo capacity was insufficient and exact restoration also failed."] select (!_restored), _currentRevision, [], false]
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

    [true, "The cargo holder was loaded from finite Arsenal stock.", _newRevision, _candidate, true]
};

_locks = localNamespace getVariable ["A4A_ServerCargoLocks", createHashMap];
_locks deleteAt _holderKey;
localNamespace setVariable ["A4A_ServerCargoLocks", _locks];

_result params ["_success", "_message", "_revision", "_committedData", "_committed"];
[_success, _message, _revision] call _sendResult;
if (_committed) then {
    private _arsenalId = _canonical select 1;
    [_arsenalId, _revision, _committedData, -1, "Physical cargo loaded from the Arsenal."] call A4A_fnc_publishSnapshot;
    [] call A4A_fnc_schedulePersistence;
};
