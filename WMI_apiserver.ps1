##
##   WMI_apiserver.ps1
##       Queries WMI Objects and Services and converts the output to JSON,
##       then returned to the calling client.
##
##   Currently this is hard-coded for port 8000, but can be changed to
##   whatever will work for your environment.
##
##   Usage:
##      http://{server IP or FQDN}:8000/wmi/{class}
##      http://{server IP or FQDN}:8000/status/{ServiceName}
##      http://{server IP or FQDN}:8000/end
##
##   Based off of code in this Blog Post: http://hkeylocalmachine.com/?p=518
##   Modification were made for error checking and service status checks.
##
##   John D. Allen
##   Copyright (C) 2018 by BigRedStack, All Rights Reserved.
##----------------------------------------------------------------------------
##  Licensed under the Apache License, Version 2.0 (the "License");
##  you may not use this file except in compliance with the License.
##  You may obtain a copy of the License at
##
##  http://www.apache.org/licenses/LICENSE-2.0
##
##  Unless required by applicable law or agreed to in writing, software
##  distributed under the License is distributed on an "AS IS" BASIS,
##  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##  See the License for the specific language governing permissions and
##  limitations under the License.
##----------------------------------------------------------------------------

# Create a listener on port 8000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://+:8000/')
$listener.Start()
'Listening ...'

# Run until you send a GET request to /end
while ($true) {
  $result = "";
  $message = "";
  $context = $listener.GetContext()

  # Capture the details about the request
  $request = $context.Request

  # Setup a place to deliver a response
  $response = $context.Response

  # Break from loop if GET request sent to /end
  if ($request.Url -match '/end$') {
      break
  } else {

    # Split request URL to get command and options
    $requestvars = ([String]$request.Url).split("/");

    # If a request is sent to http:// :8000/wmi/{class}
    if ($requestvars[3] -eq "wmi") {

        # Get the class name from the URL and run get-WMIObject
        Try {
          $result = get-WMIObject $requestvars[4] -ErrorAction Stop
          # $result = get-WMIObject $requestvars[4];
          # $Error[0].exception.GetType().fullname;
          $message = $result | ConvertTo-Json;
        } Catch [System.Management.ManagementException] {
          $message = '{"Status": -1, "error": "' + $Error[0].exception + '"}';
        }
        # Convert the returned data to JSON and set the HTTP content type to JSON
        $response.ContentType = 'application/json'

    } elseif ($requestvars[3] -eq "status") {

        # Get the service name and run the get-Service command to get the service status
        Try {
          $result = get-Service -Name $requestvars[4] -ErrorAction Stop
          $message = $result | ConvertTo-Json;
        } Catch [Microsoft.PowerShell.Commands.ServiceCommandException] {
          $message = '{"Status": -1, "error": "' + $Error[0].exception + '"}';
        }
        # Convert the returned data to JSON and set the HTTP content type to JSON
        $response.ContentType = 'application/json';

    } else {

        # If no matching subdirectory/route is found generate a 404 message
        $message = "This is not the page you're looking for.";
        $response.ContentType = 'text/html' ;
    }

    # Convert the data to UTF8 bytes
    [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($message)

    # Set length of response
    $response.ContentLength64 = $buffer.length

    # Write response out and close
    $output = $response.OutputStream
    $output.Write($buffer, 0, $buffer.length)
    $output.Close()
  }
}

#Terminate the listener
$listener.Stop()
Exit
