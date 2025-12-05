<?php
// header lines for information
define("HEADER_CAT","FM-Repeater");
define("HEADER_QTH","");
define("HEADER_QRG","");
define("HEADER_SYSOP","");
define("FMNETWORK_EXTRA","");
define("EL_NODE_NR","");
define("FULLACCESS_OUTSIDE", 0);
define("ADD_BUTTONS", 1);
//
// Button keys define: description button, DTMF command or command, color of button
//
// DTMF keys
// syntax: 'KEY number,'Description','DTMF code','color button'.
//
define("KEY1", array(' TG4 ','914#','green'));
define("KEY2", array(' TG6 ','916#','green'));
define("KEY3", array(' TG8 ','918#','green'));
define("KEY4", array(' TG23 ','9123#','green'));
define("KEY5", array(' TG50 ','9150#','orange'));
define("KEY6", array(' TG51 ','9151#','orange'));
define("KEY7", array(' TG52', '9152#','orange'));
define("KEY8", array(' TG53 ','9153#','orange'));
define("KEY9", array(' TG54 ','9154#','orange'));
define("KEY10", array(' TG55 ','9155#','orange'));
define("KEY11", array(' TG1745 ','911745#','purple'));
define("KEY12", array(' TG8400 ','918400#','blue'));
define("KEY13", array(' TG8401 ','918401#','purple'));
define("KEY14", array(' TG9000 ','919000#','purple'));
define("KEY15", array(' -- ','*D15#','purple'));
define("KEY16", array(' -- ','*D16#','purple'));
define("KEY17", array(' TALKGROUP ','9*#','red'));
define("KEY18", array(' STATUS ','*#','red'));
define("KEY19", array(' IPADDR ','D911#','red'));
define("KEY20", array(' PARROT ','D1#','red'));
define("SVXCONFPATH", "/etc/svxlink/");
define("SVXCONFIG", "svxlink.conf");
define("SVXLOGPATH", "/var/log/");
define("SVXLOGPREFIX","svxlink");
define("CALLSIGN","");
define("LOGICS","");
define("REPORT_CTCSS","");
define("DTMF_CTRL_PTY","");
define("API","");
define("FMNET","SVXLink Flanders");
define("TG_URI","");
define("NODE_INFO_FILE","");
define("RF_MODULE","");
?>
