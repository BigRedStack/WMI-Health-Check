# Check Windows Service Status External Monitor

This is an External Health Monitor for the F5 BIG-IP system. It is comprised of two different programs:  One runs on the Windows Server that is going to be heath checked, and the other runs on the F5 BIG-IP. The first program is a Node.JS program that runs as an External Health Monitor on the BIG-IP and uses an HTTP REST API call to the second program to find out the status of a Windows Service. The second program is a Windows PowerShell script that runs in the background and uses a WMI program to check on the status of a Windows Service that was passed to it by the first program. It converts the output of the WMI program to a JSON format, and sends it over to the BIG-IP.  If the status is "Running", then the service is considered "Up" by the BIG-IP.  This is very useful for checking on services that might be required by other services also running on the Windows Server.


## Installation

There are two files that are associated with this External Monitor:  *chkWindowsServiceStatus.js* and *WMI_apiserver.ps1*. *chkWindowsServiceStatus.js* is installed on the BIG-IP using the Admin GUI.  There is a way to also install this file using the TMOS CLI, and is discussed at the bottom of this document.  *WMI_apiserver* is copied to the Windows Server(s) being health checked by the F5 BIG-IP.  The instructions assume that the file is copied to the *C:\Users\Administrator* directory.

**chkWindowsServiceStatus.js**: From the BIG-IP Admin webpage, go to the System tab at the bottom of the left-side of the webpage, then select 'File Management' > 'External Monitor Program File List'.  On that page, click on the 'Import...' button on the far right.

On this webpage, click on the 'Choose File' button and select the *chkWindowsServiceStatus.js* file. In the box below the 'Create New' checkbox (which should be selected), enter 'chkWindowsServiceStatus' and click the 'Import' button below that.  The file is now installed and should be available when you go to create the External Health Monitor.

**Auto-Start of WMI API Server**:  To ensure that the API server is running every time the Windows server starts, set up a small batch file that will start it:

startup.bat:

```
powershell -command "C:\Users\Administrator\WMI_apiserver.ps1"
```

Then run this command to add the script to the Auto-Start process of the server:

```
schtasks /create /tn "Start WMI API" /tr C:\Users\Administrator\startup.bat /sc onstart /ru SYSTEM
```


## Configuration

To create a Health Monitor that is going to monitor a specific Windows service, do the following:

Go to 'Local Traffic' tab, then select 'Monitors' and click on the 'Create...' button.

Enter a name for your Monitor... We usually include some kind of reference to the Server or Windows service being monitored.  

Click on the 'Type' dropdown and select the 'External' option (its towards the top).

A 'Configuration' section will appear once the 'Type' is selected. In the 'External Program' dropbox, select the *chkWindowsServiceStatus* name that was entered when you uploaded the file.

In the 'Variables' box, you will need to enter a few items;

1. `WINPORT` is the port where the *WMI_apiserver.ps1* is running on. This variable will default to `8000` if not added.
2. `WINSERVICE` is the WMI name of the Service to check. It needs to match exactly the entire service name, or you will get back an error.
3. `WINDEBUG`(Optional) is used for debugging purposes. See _Troubleshooting_ below.
4. Once all of the Variables have been added, click on the 'Finished' button at the bottom.

Now this Health Monitor will show up in the 'Available' box of the 'Health Monitors' option on Pools.

## Troubleshooting

If you loaded the External Monitor program using the Admin GUI of the BIG-IP, and it's not working, there are a few steps to take to help you figure out what is not working correctly.

1. Trying running it from the BIG-IP command line.  You will need to add the Variables from the Configuration step as environment variables:

   ```
   $ export WINPORT=8000
   $ export WINSERVICE=w3svc
   ```

   Then run the command:

   ```
   $ node chkWindowsServiceStatus.js {ip or fqdn of Windows Server}
   UP
   ```

   If the Windows Service really is Available (IE> Shows a Green Ball), then the word 'UP' should appear. If nothing appears and the command prompt returns, then the program thinks the Windows Service is down or unavailable.

2. Put the program into Debug mode.  Add or change the variable `WINDEBUG` to `On`.  This adds a debug log file that is created and various steps are logged to it.

   1. The log file is `/var/log/monitors/WindowsServiceStatus.log`.

   2. Successful health checks should look like this:

      ```
      Wed Oct 11 2017 12:21:37 : >>Starting
      Wed Oct 11 2017 12:21:37 : Host:: 10.1.1.1
      Wed Oct 11 2017 12:21:37 : UP
      ```

      This will show you what the program is finding and the results of various REST API calls.

   3. Turn on Monitor Logging for one of the Pool members.  Click the 'Enable' checkbox and then click 'Update' down at the bottom of the page.  This will start a log file in ``/var/log/monitors`` with the node name as part of the filename.  Look in the log file associated with your External Monitor and see if there are any errors when running it.

   4. If none of the above has helped, then you want to check:

      1. BIG-IP is VERY picky about the file format. Try running ``vi`` with the ``/config/filestore/files_d/Common_d/extgernal_monitor_d/{monitor name}`` file. Enter the following:  ``:set fileformat=unix`` and then save (``:wq``).  I copied an External Monitor over from a Linux machine and it did not work until I did this!  Github has a nasty habit of converting LF to CRLF, so you may want to do this step anyway!
      2. Connectivity to/from the target Windows Server.
      3. Is the WMI_apiserver.ps1 actually running?
      4. Does the Service name match what is really there?

### Manual Install of an External Health Monitor

Sometimes the install of an External Health Monitor from the Admin GUI does not work quite right for some reason.  I have had this issue on version 11.x and 12.x BIG-IPs in the past, so I keep this procedure handy in case I run into issues.

1.  Copy the External Health Monitor file over to the BIG-IP, in the /config/monitors directory.

2.  Run this command:

    ```
    tmsh create sys file external-monitor {Monitor Name} source-path file:///config/monitors/{real file name}
    ```

    If the file has already been installed once before, you need to change `create` to `modify` in order for this to work correctly.
    Be sure to save the changes!

    ```
    tmsh save sys config
    ```

This command places a copy in _/config/filestore/files_d/Common_d/extgernal_monitor_d_. The monitor should now be available to the BIG-IP.

### Author

John D. Allen

BigRedStack
May, 2018

### License

Apache 2.0
