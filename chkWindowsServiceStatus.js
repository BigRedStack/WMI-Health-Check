#!/usr/bin/node
//
//  chkWindowsServiceStatus.js  --  Check the specified Windows Service Status on a remote
//    Windows Server for 'Running' Status.  If 'Running', "UP" is printed out on the
//    console.  If not, nothing is printed out (thus signaling a "DOWN" state to BIGIP.)
//
//  https://support.f5.com/csp/article/K13423
//
//  Please Note: This script is part of a two-component solution -- a client and
//  a server.  This is the client part.  The server part (WMI_apiserver.ps1) is a
//  Windows PowerShell script that needs to be running on the target Windows
//  Server in order to respond to thos client.  If the server is not running,
//  then the service on the BIG-IP will always be marked down.
//
//  John D. Allen
//  Copyright (C) 2018, BigRedStack, All Rights Reserved.
//----------------------------------------------------------------------------
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//----------------------------------------------------------------------------

var http = require('http');

var DEBUG = process.env.WINDEBUG || "Off";
if(process.env.WINDEBUG == "OFF" || process.env.WINDEBUG == "off") {
  DEBUG = "Off";
}

//--------------[  Set up external log file  ]----------------
var fs;
var log_file;
if (DEBUG != "Off") {
  fs = require('fs');
  log_file = fs.createWriteStream("/var/log/monitors/WindowsServiceStatus.log", {flags: 'a'});
}

function debugLog(txt) {
  if (DEBUG != "Off") {
    var dt = Date().replace(/G.+/,'');
    log_file.write(dt + ": " + txt + "\n");
  }
}

debugLog(">>Starting");

var node = process.env.WINNODE;
var port = process.env.WINPORT || 8000;
var svcs = process.env.WINSERVICE;
var url = "http://" + node + ":" + port + "/status/" + svcs;

http.get(url, function(resp) {
  var data = "";

  resp.on("data", function(d) {
    data += d.toString();
  });

  resp.on("end", function() {
    var rr = JSON.parse(data);
    if(rr.Status == 4) {        // 4 = Running
      sendStatus(true);
    } else {
      sendStatus(false);
    }
  });

  resp.on("error", function(e) {
    debugLog("Error on REST Call:" + e);
    sendStatus(false);
  });
});

process.on('uncaughtException', function(err) {
  debugLog("Process Error:" + err);
  sendStatus(false);
})

//----------------------------------------------------------------------------
function sendStatus(bool) {
  if(bool) {
    console.log("UP");
    debugLog("UP");
    process.exit();
  } else {
    // No output means DOWN
    debugLog("DOWN");
    process.exit();
  }
}
