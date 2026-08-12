if (!hasInterface || isRemoteExecuted) exitWith {};

private _runClientInit = false;
isNil {
    if !(localNamespace getVariable ["A4A_ClientInitDone", false]) then {
        localNamespace setVariable ["A4A_ClientInitDone", true];
        _runClientInit = true;
    };
};
if (!_runClientInit) exitWith {};

private _defaultThreshold = 25;
private _clientSettings = call compile preprocessFileLineNumbers "A4A\config\settings.sqf";
if (_clientSettings isEqualType createHashMap) then {
    _clientSettings = [_clientSettings] call A4A_fnc_normalizeSettings;
    _defaultThreshold = _clientSettings getOrDefault ["unlockThreshold", 25];
} else {
    _clientSettings = [createHashMap] call A4A_fnc_normalizeSettings;
};
localNamespace setVariable ["A4A_ClientSettings", _clientSettings];
A4A_guestItemLimit = _defaultThreshold;
jna_minItemMember = [];
jna_minItemMember resize 27;
for "_index" from 0 to 26 do { jna_minItemMember set [_index, 0] };

[missionNamespace, "arsenalOpened", {
    disableSerialization;
    private _session = localNamespace getVariable ["A4A_ClientSession", []];
    if !(_session isEqualType createHashMap) exitWith {};
    private _display = _this param [0, displayNull, [displayNull]];
    if (isNull _display) exitWith {};
    uiNamespace setVariable ["arsenalDisplay", _display];
    ["CustomInit", [_display]] call jn_fnc_arsenal;
}] call BIS_fnc_addScriptedEventHandler;

[missionNamespace, "arsenalClosed", {
    private _session = localNamespace getVariable ["A4A_ClientSession", []];
    if !(_session isEqualType createHashMap) exitWith {};
    private _object = _session getOrDefault ["object", objNull];
    private _requestNonce = _session getOrDefault ["requestNonce", ""];
    private _generation = _session getOrDefault ["generation", -1];
    uiNamespace setVariable ["jn_type", ""];

    private _pending = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
    private _generationPending = (keys _pending) select {
        private _transaction = _pending get _x;
        _transaction isEqualType createHashMap &&
        {(_transaction getOrDefault ["generation", -1]) isEqualTo _generation}
    };
    if (count _generationPending > 0) exitWith {
        private _existingClose = localNamespace getVariable ["A4A_ClientClosePending", []];
        if (_existingClose isEqualType [] && {count _existingClose > 0}) exitWith {};
        localNamespace setVariable ["A4A_ClientClosePending", [_object, _requestNonce, _generation]];

        [_object, _requestNonce, _generation] spawn {
            params ["_pendingObject", "_pendingNonce", "_pendingGeneration"];
            private _deadline = diag_tickTime + 20;
            private _drained = false;
            waitUntil {
                uiSleep 0.25;
                private _pendingTransactions = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
                _drained = (keys _pendingTransactions) findIf {
                    private _transaction = _pendingTransactions get _x;
                    _transaction isEqualType createHashMap &&
                    {(_transaction getOrDefault ["generation", -1]) isEqualTo _pendingGeneration}
                } < 0;
                _drained || {diag_tickTime >= _deadline}
            };

            private _closeState = localNamespace getVariable ["A4A_ClientClosePending", []];
            if !(
                _closeState isEqualType [] &&
                {count _closeState isEqualTo 3} &&
                {(_closeState select 2) isEqualTo _pendingGeneration}
            ) exitWith {};

            if (!_drained) then {
                private _pendingTransactions = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
                {
                    private _transaction = _pendingTransactions get _x;
                    if (
                        _transaction isEqualType createHashMap &&
                        {(_transaction getOrDefault ["generation", -1]) isEqualTo _pendingGeneration}
                    ) then {
                        _pendingTransactions deleteAt _x;
                    };
                } forEach +(keys _pendingTransactions);
                localNamespace setVariable ["A4A_ClientPendingTransactions", _pendingTransactions];
                systemChat "A4A closed after waiting for transaction results; reopen to resync the canonical stock.";
            };

            [_pendingObject, _pendingNonce, _pendingGeneration] remoteExecCall ["A4A_fnc_requestClose", 2];
            private _currentSession = localNamespace getVariable ["A4A_ClientSession", []];
            if (
                _currentSession isEqualType createHashMap &&
                {(_currentSession getOrDefault ["generation", -1]) isEqualTo _pendingGeneration}
            ) then {
                localNamespace setVariable ["A4A_ClientSession", []];
            };
            localNamespace setVariable ["A4A_ClientClosePending", []];
            localNamespace setVariable ["A4A_ClientTransactionBusy", ""];
            localNamespace setVariable ["A4A_ClientOperationBatch", ""];
            localNamespace setVariable ["A4A_ClientOperationBaseline", []];
            localNamespace setVariable ["A4A_ClientScheduledBatches", createHashMap];
            localNamespace setVariable ["A4A_ClientCancelledBatches", createHashMap];
        };
    };

    localNamespace setVariable ["A4A_ClientSession", []];
    localNamespace setVariable ["A4A_ClientClosePending", []];
    if (!isNull _object && {_requestNonce isNotEqualTo ""} && {_generation >= 0}) then {
        [_object, _requestNonce, _generation] remoteExecCall ["A4A_fnc_requestClose", 2];
    };
}] call BIS_fnc_addScriptedEventHandler;

arsenalInit = true;

[] spawn {
    waitUntil { !isNull player && {time >= 0} };

    private _rows = call compile preprocessFileLineNumbers "A4A\config\arsenals.sqf";
    if !(_rows isEqualType []) exitWith {
        diag_log "[A4A Mission] Client arsenal configuration is not an array";
    };

    {
        if (_x isEqualType [] && {count _x isEqualTo 3}) then {
            _x params ["_variableName", "_arsenalId", "_threshold"];
            if (_variableName isEqualType "" && {_variableName isNotEqualTo ""}) then {
                private _object = missionNamespace getVariable [_variableName, objNull];
                if (!isNull _object) then {
                    if (!isNil "A4A_fnc_openAction") then {
                        [_object, _arsenalId] call A4A_fnc_openAction;
                    };
                    if (!isNil "A4A_fnc_addCargoActions") then {
                        [_object, _arsenalId] call A4A_fnc_addCargoActions;
                    };
                };
            };
        };
    } forEach _rows;

    if (!isNil "A4A_fnc_initCbaSettings") then {
        [] call A4A_fnc_initCbaSettings;
    };
};
