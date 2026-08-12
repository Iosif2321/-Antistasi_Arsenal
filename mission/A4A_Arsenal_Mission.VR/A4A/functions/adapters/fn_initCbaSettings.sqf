if (isRemoteExecuted) exitWith { false };

private _roleFlag = ["A4A_ClientCbaSettingsRegistered", "A4A_ServerCbaSettingsRegistered"] select isServer;
private _alreadyRegistered = localNamespace getVariable [_roleFlag, false];
private _hasCbaSettings = !isNil "CBA_fnc_addSetting";
private _missionDefaults = call compile preprocessFileLineNumbers "A4A\config\settings.sqf";
if !(_missionDefaults isEqualType createHashMap) then {
    _missionDefaults = createHashMap;
};
_missionDefaults = [_missionDefaults] call A4A_fnc_normalizeSettings;

private _defaultCargoAccess = _missionDefaults getOrDefault ["cargoAccess", 0];
if !(_defaultCargoAccess isEqualType 0 && {_defaultCargoAccess in [0, 1, 2]}) then {
    _defaultCargoAccess = 0;
};

private _defaultEditorIds = _missionDefaults getOrDefault ["editorSteamIDs", []];
if !(_defaultEditorIds isEqualType []) then {
    _defaultEditorIds = [];
};
private _defaultEditorText = (_defaultEditorIds select {
    _x isEqualType "" && {_x isNotEqualTo ""}
}) joinString ",";

private _defaultEditAccessMode = _missionDefaults getOrDefault ["editAccessMode", 0];
if !(_defaultEditAccessMode isEqualType 0 && {_defaultEditAccessMode in [0, 1]}) then {
    _defaultEditAccessMode = 0;
};

private _defaultThresholdOverride = _missionDefaults getOrDefault ["unlockThresholdOverride", 0];
if !(
    _defaultThresholdOverride isEqualType 0 &&
    {finite _defaultThresholdOverride} &&
    {_defaultThresholdOverride isEqualTo floor _defaultThresholdOverride} &&
    {_defaultThresholdOverride >= 0} &&
    {_defaultThresholdOverride <= 25000}
) then {
    _defaultThresholdOverride = 0;
};

private _defaultUiStyle = _missionDefaults getOrDefault ["uiStyle", "Legacy"];
private _defaultUiStyleIndex = if (
    (_defaultUiStyle isEqualType 0 && {_defaultUiStyle isEqualTo 1}) ||
    {_defaultUiStyle isEqualType "" && {toUpper _defaultUiStyle isEqualTo "ACE"}}
) then {1} else {0};

if (!_alreadyRegistered && {_hasCbaSettings}) then {
    if !(localNamespace getVariable ["A4A_CbaSettingsRegistered", false]) then {
        [
            "A4A_Mission_CargoAccess",
            "LIST",
            ["Cargo transfer access", "Who may deposit into and load crates or empty vehicles from the quantitative Arsenal."],
            "A4A Mission Arsenal",
            [[0, 1, 2], ["Everyone", "Arsenal editors", "Disabled"], _defaultCargoAccess],
            1,
            {},
            true
        ] call CBA_fnc_addSetting;

        [
            "A4A_Mission_EditorSteamIDs",
            "EDITBOX",
            ["Arsenal editor SteamIDs", "SteamIDs allowed to replace a full Arsenal snapshot. Separate IDs with commas, semicolons, or spaces."],
            "A4A Mission Arsenal",
            _defaultEditorText,
            1,
            {},
            true
        ] call CBA_fnc_addSetting;

        [
            "A4A_Mission_EditAccessMode",
            "LIST",
            ["Arsenal editor access mode", "SteamID only, or SteamID plus an assigned Zeus curator."],
            "A4A Mission Arsenal",
            [[0, 1], ["SteamID only", "SteamID and Zeus"], _defaultEditAccessMode],
            1,
            {},
            true
        ] call CBA_fnc_addSetting;

        [
            "A4A_Mission_UnlockThreshold",
            "SLIDER",
            ["Global unlock threshold override", "0 preserves each value in A4A/config/arsenals.sqf; a positive physical-item count overrides every configured Arsenal after restart. Magazine thresholds are converted to rounds."],
            "A4A Mission Arsenal",
            [0, 25000, _defaultThresholdOverride, 0],
            1,
            {},
            true
        ] call CBA_fnc_addSetting;

        [
            "A4A_Mission_UIStyle",
            "LIST",
            ["Arsenal interface", "Legacy is always supported. ACE preview is client-local and is contained to stock modes that can be represented safely."],
            "A4A Mission Arsenal",
            [[0, 1], ["Legacy quantitative Arsenal", "ACE3 preview when safe"], _defaultUiStyleIndex],
            0,
            {},
            false
        ] call CBA_fnc_addSetting;

        localNamespace setVariable ["A4A_CbaSettingsRegistered", true];
    };
    localNamespace setVariable [_roleFlag, true];
};

if (isServer) then {
    isNil {
        if !(localNamespace getVariable ["A4A_ServerCbaAuthorityCaptured", false]) then {
            private _settings = localNamespace getVariable ["A4A_ServerSettings", createHashMap];
            if !(_settings isEqualType createHashMap) then {
                _settings = call compile preprocessFileLineNumbers "A4A\config\settings.sqf";
            };

            if (_hasCbaSettings) then {
                private _cargoAccess = missionNamespace getVariable ["A4A_Mission_CargoAccess", 0];
                private _editAccessMode = missionNamespace getVariable ["A4A_Mission_EditAccessMode", 0];
                private _thresholdOverride = missionNamespace getVariable ["A4A_Mission_UnlockThreshold", 0];
                private _editorText = missionNamespace getVariable ["A4A_Mission_EditorSteamIDs", ""];

                if (_cargoAccess isEqualType 0 && {_cargoAccess in [0, 1, 2]}) then {
                    _settings set ["cargoAccess", _cargoAccess];
                };
                if (_editAccessMode isEqualType 0 && {_editAccessMode in [0, 1]}) then {
                    _settings set ["editAccessMode", _editAccessMode];
                };
                if (
                    _thresholdOverride isEqualType 0 &&
                    {finite _thresholdOverride} &&
                    {_thresholdOverride isEqualTo floor _thresholdOverride} &&
                    {_thresholdOverride >= 0} &&
                    {_thresholdOverride <= 25000}
                ) then {
                    _settings set ["unlockThresholdOverride", _thresholdOverride];
                };
                if (_editorText isEqualType "") then {
                    private _uids = (_editorText splitString ",; `t`r`n") select {
                        _x isNotEqualTo "" && {count _x >= 8} && {count _x <= 32} && {parseNumber _x > 0}
                    };
                    _settings set ["editorSteamIDs", _uids];
                };
            };

            if (isNil {_settings get "cargoAccess"}) then { _settings set ["cargoAccess", 0] };
            if (isNil {_settings get "unlockThresholdOverride"}) then { _settings set ["unlockThresholdOverride", 0] };
            _settings = [_settings] call A4A_fnc_normalizeSettings;
            localNamespace setVariable ["A4A_ServerSettings", _settings];
            localNamespace setVariable ["A4A_ServerCbaAuthorityCaptured", true];
        };
    };
};

_hasCbaSettings
