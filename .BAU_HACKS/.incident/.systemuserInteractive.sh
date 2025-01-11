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