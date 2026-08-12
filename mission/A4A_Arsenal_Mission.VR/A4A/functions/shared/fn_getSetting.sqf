params [
    ["_key", "", [""]],
    ["_default", nil]
];

private _defaults = call compile preprocessFileLineNumbers "A4A\config\settings.sqf";
private _fallback = _default;
if (isNil "_fallback" && {_defaults isEqualType createHashMap}) then {
    _fallback = _defaults getOrDefault [_key, nil];
};

switch (toLower _key) do {
    case "uistyle": {
        private _rawStyle = missionNamespace getVariable ["A4A_Mission_UIStyle", 0];
        if (_rawStyle isEqualType 0) then {
            ["Legacy", "ACE"] select (_rawStyle isEqualTo 1)
        } else {
            if (_rawStyle in ["Legacy", "ACE"]) then {_rawStyle} else {_fallback}
        }
    };
    case "cargoaccess": { missionNamespace getVariable ["A4A_Mission_CargoAccess", _fallback] };
    case "editaccessmode": { missionNamespace getVariable ["A4A_Mission_EditAccessMode", _fallback] };
    case "unlockthresholdoverride": { missionNamespace getVariable ["A4A_Mission_UnlockThreshold", _fallback] };
    case "editorsteamids": { missionNamespace getVariable ["A4A_Mission_EditorSteamIDs", _fallback] };
    default { _fallback };
}
