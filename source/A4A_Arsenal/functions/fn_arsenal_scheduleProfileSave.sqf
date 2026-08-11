/*
 * Coalesces profileNamespace flushes without delaying the in-memory namespace
 * update itself. Every mutation/close/full-save within the 250 ms window shares
 * one disk flush; a process crash inside that bounded window remains possible.
 */

if (!isServer) exitWith {};
// Internal server helper: nested calls retain the parent remoteExec context, so
// authorization uses a private, unscheduled call-site capability rather than
// isRemoteExecuted. Network clients cannot write the server localNamespace.
if !(localNamespace getVariable ["A4A_Arsenal_ProfileSaveAuthorized", false]) exitWith {
    diag_log format ["A4A_Arsenal: rejected remote profile-save scheduler call from owner %1", remoteExecutedOwner];
};
// Every authorized mutation advances a private generation, including calls
// that arrive while a flush worker already exists.
private _generation = (localNamespace getVariable ["A4A_Arsenal_ProfileSaveGeneration", 0]) + 1;
localNamespace setVariable ["A4A_Arsenal_ProfileSaveGeneration", _generation];
if (localNamespace getVariable ["A4A_Arsenal_ProfileSaveScheduled", false]) exitWith {};

localNamespace setVariable ["A4A_Arsenal_ProfileSaveScheduled", true];
[] spawn {
    while {true} do {
        // uiSleep keeps the bounded persistence timer moving while SP is paused.
        uiSleep 0.25;
        private _flushGeneration = localNamespace getVariable ["A4A_Arsenal_ProfileSaveGeneration", 0];
        saveProfileNamespace;

        // Atomically compare the flushed generation and release ownership. If
        // a mutation landed during the disk write, keep the worker and flush
        // again; if it lands after release, that caller starts a new worker.
        private _repeat = false;
        isNil {
            if ((localNamespace getVariable ["A4A_Arsenal_ProfileSaveGeneration", 0]) isEqualTo _flushGeneration) then {
                localNamespace setVariable ["A4A_Arsenal_ProfileSaveScheduled", false];
            } else {
                _repeat = true;
            };
        };
        if (!_repeat) exitWith {};
    };
};
