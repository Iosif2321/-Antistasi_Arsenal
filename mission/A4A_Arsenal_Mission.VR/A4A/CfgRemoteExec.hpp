class CfgRemoteExec {
    class Functions {
        mode = 1;
        jip = 0;

        class A4A_fnc_requestOpen { allowedTargets = 2; jip = 0; };
        class A4A_fnc_requestClose { allowedTargets = 2; jip = 0; };
        class A4A_fnc_requestWithdraw { allowedTargets = 2; jip = 0; };
        class A4A_fnc_completeWithdraw { allowedTargets = 2; jip = 0; };
        class A4A_fnc_requestReturn { allowedTargets = 2; jip = 0; };
        class A4A_fnc_completeReturn { allowedTargets = 2; jip = 0; };
        class A4A_fnc_saveEditorSnapshot { allowedTargets = 2; jip = 0; };
        class A4A_fnc_requestCargoDeposit { allowedTargets = 2; jip = 0; };
        class A4A_fnc_requestCargoWithdraw { allowedTargets = 2; jip = 0; };

        // Hosted servers execute their local UI in the server process, so
        // callbacks permit any target and authenticate owner 2 in SQF.
        class A4A_fnc_receiveOpen { allowedTargets = 0; jip = 0; };
        class A4A_fnc_receiveInvalidate { allowedTargets = 0; jip = 0; };
        class A4A_fnc_receiveGrant { allowedTargets = 0; jip = 0; };
        class A4A_fnc_receiveTransactionResult { allowedTargets = 0; jip = 0; };
    };

    class Commands {
        mode = 1;
        jip = 0;
    };
};

