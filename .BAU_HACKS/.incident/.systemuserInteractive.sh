Here’s the .bat script to:
	1.	Launch the Interactive Service via POST or GET request using curl.
	2.	Pass system user and filter_id as input variables.
	3.	Open the returned HTML file in the default web browser.

Interactive Service .bat Script

Save this as launch_interactive_service.bat:

@echo off
:: Get system username
set USERNAME=%USERNAME%

:: Input filter_id (you can prompt or hardcode it)
set /p FILTER_ID=Enter Filter ID: 

:: Service URL
set SERVICE_URL=http://localhost:6000/interactive

:: Temp HTML file path (set where you want to save the response)
set OUTPUT_FILE=%TEMP%\interactive_response.html

:: Choose HTTP method: POST or GET
set METHOD=POST

if /I "%METHOD%"=="POST" (
    :: Make POST request with curl
    curl -X POST "%SERVICE_URL" ^
        -H "Content-Type: application/json" ^
        -d "{\"username\": \"%USERNAME%\", \"filter_id\": \"%FILTER_ID%\"}" ^
        -o "%OUTPUT_FILE%"
) else if /I "%METHOD%"=="GET" (
    :: Make GET request with curl
    curl -G "%SERVICE_URL" ^
        -d "username=%USERNAME%" ^
        -d "filter_id=%FILTER_ID%" ^
        -o "%OUTPUT_FILE%"
) else (
    echo Invalid HTTP method. Only POST or GET are allowed.
    exit /b 1
)

:: Check if the file was created
if exist "%OUTPUT_FILE%" (
    echo Interactive HTML file saved to: %OUTPUT_FILE%
    echo Opening in default web browser...

    :: Open the HTML file in the default browser
    start "" "%OUTPUT_FILE%"
) else (
    echo Failed to fetch the interactive HTML page. Please check your input or service availability.
)

How It Works
	1.	Username and Filter ID:
	•	%USERNAME% automatically gets the system user.
	•	%FILTER_ID% is either hardcoded or prompted when you run the script.
	2.	Service URL:
	•	Update set SERVICE_URL with the actual URL of your interactive service.
	3.	HTTP Method:
	•	Default is POST. Set set METHOD=GET if required.
	4.	Output File:
	•	The response from the service is saved to a temporary .html file, which is then opened in the default web browser.

How to Use
	1.	Save the .bat file to your desired location (e.g., C:\scripts\launch_interactive_service.bat).
	2.	Run the script by double-clicking or from the command line:

launch_interactive_service.bat


	3.	Enter the Filter ID when prompted.
	4.	The returned HTML file will open in your default web browser.

Testing with an Example

Assume:
	•	The interactive service URL is http://localhost:6000/interactive.
	•	The username is the system user.
	•	You provide a filter_id like 1234.

The .bat script will:
	1.	Send a POST or GET request to the interactive service.
	2.	Save the response HTML to a temporary file.
	3.	Automatically open the file in your browser for interaction.

#==#
@echo off
REM Get the current username
set "USERNAME=%USERNAME%"

REM Prepare the POST data
set "POST_DATA=username=%USERNAME%"

REM Use curl to send the POST request
curl -X POST http://localhost:6000/interactive -H "Content-Type: application/x-www-form-urlencoded" -d "%POST_DATA%"

REM Pause for user to see the output
pause


To get the system user on a Windows machine using a shell script and pass it to an HTML file for further use, you can achieve this through the following steps:

Step 1: Get the System User in Shell Script

The %USERNAME% environment variable holds the current logged-in user’s name on Windows. You can use a shell script (or batch script) to fetch this value and embed it into an HTML file.

Step 2: Pass System User to HTML

You can use the shell script to dynamically write the system username into a <script> block or as a hidden field in the HTML.

Example Shell Script

@echo off
:: Fetch the current Windows username
set USERNAME=%USERNAME%

:: Create or overwrite the HTML file
echo ^<html^> > interactive.html
echo ^<head^> >> interactive.html
echo ^<title^>Interactive Service^</title^> >> interactive.html
echo ^</head^> >> interactive.html
echo ^<body^> >> interactive.html
echo ^<h1^>Welcome, %USERNAME%^</h1^> >> interactive.html

:: Add the username into a JavaScript variable
echo ^<script^> >> interactive.html
echo const systemUser = "%USERNAME%"; >> interactive.html
echo console.log("System User:", systemUser); >> interactive.html
echo fetch('http://localhost:6000/interactive', { >> interactive.html
echo     method: 'POST', >> interactive.html
echo     headers: { 'Content-Type': 'application/json' }, >> interactive.html
echo     body: JSON.stringify({ username: systemUser }) >> interactive.html
echo }).then(response => response.json()) >> interactive.html
echo .then(data => console.log("Server Response:", data)) >> interactive.html
echo .catch(err => console.error("Error:", err)); >> interactive.html
echo ^</script^> >> interactive.html

:: Close the HTML tags
echo ^</body^> >> interactive.html
echo ^</html^> >> interactive.html

:: Inform the user
echo "HTML file has been generated: interactive.html"

Explanation of the Script
	1.	Fetch the Username:
	•	%USERNAME% is used to get the currently logged-in Windows user.
	•	Stored in the USERNAME variable.
	2.	Generate HTML File:
	•	Dynamically writes HTML content, including the system user as a JavaScript variable (const systemUser).
	3.	Pass the Username via JavaScript:
	•	JavaScript makes a POST request to the /interactive service, sending the systemUser in the request body.
	4.	Fetch Endpoint:
	•	Adjust the http://localhost:6000/interactive URL to the actual API endpoint.

Step 3: Flask Backend to Handle Username

The backend can receive the system user and respond accordingly.

Flask Example:

from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/interactive', methods=['POST'])
def interactive():
    data = request.json
    username = data.get("username")
    if not username:
        return jsonify({"error": "Username not provided"}), 400

    # Handle logic based on username (e.g., fetch API token from secret)
    return jsonify({"message": f"Hello {username}, welcome to the interactive service!"})

Step 4: Run and Test
	1.	Save the shell script as generate_html.bat.
	2.	Run the batch file on a Windows machine to generate the interactive.html.
	3.	Open the interactive.html file in a browser.
	4.	The JavaScript within the HTML will:
	•	Display the system user on the page.
	•	Send the username to the Flask /interactive service.

Optional: Use Hidden Input Fields

If you want to avoid JavaScript for sending the username, you can add a hidden input field with the username.

HTML Example:

<input type="hidden" id="systemUser" value="%USERNAME%">
<form action="http://localhost:6000/interactive" method="POST">
    <input type="hidden" name="username" value="%USERNAME%">
    <button type="submit">Send Username</button>
</form>

Advantages of This Approach
	1.	No manual entry of the username is required—it is fetched automatically.
	2.	HTML dynamically adapts based on the logged-in user.
	3.	The username is securely passed to the backend for further processing.

Let me know if you need additional refinements!