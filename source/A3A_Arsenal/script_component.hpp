#define COMPONENT jeroen_arsenal
#define PREFIX A3A_Arsenal

#define MAJOR 0
#define MINOR 4
#define PATCHLVL 3

#define VERSION MAJOR.MINOR.PATCHLVL

// Минимальные макросы для автономного использования
#define QUOTE(var) #var
#define QPATHTOFOLDER(var) QUOTE(\A3A_Arsenal\var)
#define FIX_LINE_NUMBERS() 
#define TRACE_1(msg,arg1) diag_log format [msg, arg1]
#define INFO(msg) diag_log format ["INFO: %1", msg]
#define ERROR(msg) diag_log format ["ERROR: %1", msg]
#define LOG(msg) diag_log format ["LOG: %1", msg]

// NOTE: IDC_RSCDISPLAYARSENAL_TAB_* constants are provided by
// \A3\Ui_f\hpp\defineResinclDesign.inc (included via defineCommon.inc)
// Do NOT redefine them here - it would override correct vanilla values.

// Compatibility macros for JNA (case-sensitive)
#define Info(msg) diag_log format ["INFO: %1", msg]
#define Info_1(msg,arg1) diag_log format ["INFO: " + msg + "%1", arg1]
#define Info_2(msg,arg1,arg2) diag_log format ["INFO: " + msg + "%1, %2", arg1, arg2]
#define Error(msg) diag_log format ["ERROR: %1", msg]
#define Error_1(msg,arg1) diag_log format ["ERROR: " + msg + "%1", arg1]
#define Log(msg) diag_log format ["LOG: %1", msg]
#define Verbose(msg) diag_log format ["VERBOSE: %1", msg]
#define Debug(msg) diag_log format ["DEBUG: %1", msg]

// Faction data access macros (from Antistasi core/Includes/common.inc)
#define FactionGet(FAC, VAR) (A3A_faction_##FAC get VAR)
#define FactionGetOrDefault(FAC, VAR, DEF) (A3A_faction_##FAC getOrDefault [VAR, DEF])
