params [["_arsenalId", "", [""]]];
if (!isServer || {isRemoteExecuted} || {_arsenalId isEqualTo ""}) exitWith { [false, [], 0] };

private _profileKey = format ["A4A_MissionArsenal_v2_%1", _arsenalId];
private _legacyKey = format ["A4A_ArsenalData_%1", _arsenalId];
private _missing = "__A4A_MISSION_MISSING__";
private _stored = profileNamespace getVariable [_profileKey, _missing];
private _legacy = false;
if (_stored isEqualTo _missing) then {
    _stored = profileNamespace getVariable [_legacyKey, _missing];
    _legacy = _stored isNotEqualTo _missing;
};
if (_stored isEqualTo _missing) exitWith { [false, [], 0] };

private _revision = 0;
private _candidate = [];
if (
    _stored isEqualType [] &&
    {count _stored isEqualTo 3} &&
    {(_stored select 0) isEqualTo 2} &&
    {(_stored select 1) isEqualType 0} &&
    {finite (_stored select 1)} &&
    {(_stored select 1) isEqualTo floor (_stored select 1)} &&
    {(_stored select 1) >= 0}
) then {
    _revision = _stored select 1;
    _candidate = _stored select 2;
} else {
    if (_legacy && {_stored isEqualType []}) then {
        _candidate = _stored;
    };
};

private _validated = [_candidate] call A4A_fnc_validateSnapshot;
if !(_validated select 0) exitWith {
    diag_log format ["[A4A Mission] Ignored invalid persisted snapshot '%1': %2", _arsenalId, _validated select 3];
    [false, [], 0]
};

private _normalized = _validated select 1;
if (_legacy) then {
    private _normalizedEnvelope = [2, _revision, parseSimpleArray str _normalized];
    profileNamespace setVariable [_profileKey, _normalizedEnvelope];
    diag_log format ["[A4A Mission] Migrated legacy profile data for '%1' to schema 2", _arsenalId];
};
[true, _normalized, _revision]

