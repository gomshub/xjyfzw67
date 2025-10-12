
Thanks! Here’s exactly what you asked for: both a Python script and a Shell script using jq that:

⸻

✅ GOAL
	•	Compare JIRA issues between two versions (e.g., 2024.12.01.Release and 2025.03.15.Release)
	•	Filter issues whose fixVersion falls strictly between those two
	•	Generate a clean HTML report
	•	Run inside a Bamboo plan

⸻

🅰️ PYTHON VERSION (with HTML output)

✅ jira_release_report.py

import requests
import os
from datetime import datetime
from html import escape

JIRA_DOMAIN = os.environ['JIRA_DOMAIN']
JIRA_USER = os.environ['JIRA_USER']
JIRA_TOKEN = os.environ['JIRA_TOKEN']
JIRA_PROJECT = os.environ.get('JIRA_PROJECT', 'CTLQ')
VERSION_LOWER = os.environ['VERSION_LOWER']  # e.g., 2024.12.01.Release
VERSION_UPPER = os.environ['VERSION_UPPER']  # e.g., 2025.03.15.Release

auth = (JIRA_USER, JIRA_TOKEN)
headers = {"Accept": "application/json"}

# 1. Get all versions
ver_url = f"https://{JIRA_DOMAIN}/rest/api/2/project/{JIRA_PROJECT}/versions"
res = requests.get(ver_url, auth=auth, headers=headers)
versions = sorted(
    [v["name"] for v in res.json() if "Release" in v["name"]],
    key=lambda v: datetime.strptime(v, "%Y.%m.%d.Release")
)

# 2. Filter versions strictly between
between_versions = [
    v for v in versions
    if VERSION_LOWER < v < VERSION_UPPER
]

# 3. Build JQL for all relevant versions
jql_versions = ','.join(f'"{v}"' for v in between_versions)
jql = f'project = {JIRA_PROJECT} AND fixVersion in ({jql_versions}) ORDER BY fixVersion ASC'

# 4. Search JIRA
search_url = f"https://{JIRA_DOMAIN}/rest/api/2/search"
params = {
    "jql": jql,
    "fields": "key,summary,fixVersions",
    "maxResults": 1000
}
res = requests.get(search_url, auth=auth, headers=headers, params=params)
issues = res.json().get("issues", [])

# 5. Build HTML report
rows = []
for issue in issues:
    key = issue["key"]
    summary = escape(issue["fields"]["summary"])
    versions = [v['name'] for v in issue['fields']['fixVersions']]
    rows.append(f"<tr><td><a href='https://{JIRA_DOMAIN}/browse/{key}'>{key}</a></td><td>{summary}</td><td>{', '.join(versions)}</td></tr>")

html = f"""
<html><body>
<h2>Release Report: {VERSION_LOWER} → {VERSION_UPPER}</h2>
<table border="1" cellspacing="0" cellpadding="5">
<tr><th>JIRA Key</th><th>Summary</th><th>Fix Versions</th></tr>
{''.join(rows)}
</table>
</body></html>
"""

with open("release_report.html", "w") as f:
    f.write(html)

print("✅ Report generated: release_report.html")


⸻

🅱️ SHELL + jq VERSION (HTML output)

✅ release_report.sh

#!/bin/bash
set -e

JIRA_DOMAIN="${JIRA_DOMAIN}"
JIRA_USER="${JIRA_USER}"
JIRA_TOKEN="${JIRA_TOKEN}"
JIRA_PROJECT="${JIRA_PROJECT:-CTLQ}"
VERSION_LOWER="${VERSION_LOWER}"
VERSION_UPPER="${VERSION_UPPER}"

AUTH=$(echo -n "${JIRA_USER}:${JIRA_TOKEN}" | base64)

# Get all versions
VERSIONS=$(curl -s -H "Authorization: Basic $AUTH" \
  -H "Accept: application/json" \
  "https://${JIRA_DOMAIN}/rest/api/2/project/${JIRA_PROJECT}/versions" | jq -r '.[] | select(.name | contains("Release")) | .name')

# Sort and filter versions strictly between bounds
BETWEEN=$(echo "$VERSIONS" | sort | awk -v low="$VERSION_LOWER" -v up="$VERSION_UPPER" '$0 > low && $0 < up')

# Build JQL
JQL_VERSIONS=$(echo "$BETWEEN" | sed 's/.*/"&"/' | paste -sd "," -)
JQL="project = $JIRA_PROJECT AND fixVersion in ($JQL_VERSIONS) ORDER BY fixVersion ASC"

# Search issues
RESULT=$(curl -s -H "Authorization: Basic $AUTH" \
  -G --data-urlencode "jql=$JQL" \
  "https://${JIRA_DOMAIN}/rest/api/2/search?fields=key,summary,fixVersions&maxResults=1000")

# Generate HTML
echo "<html><body><h2>Release Report: $VERSION_LOWER → $VERSION_UPPER</h2>" > release_report.html
echo "<table border='1' cellspacing='0' cellpadding='5'>" >> release_report.html
echo "<tr><th>JIRA Key</th><th>Summary</th><th>Fix Versions</th></tr>" >> release_report.html

echo "$RESULT" | jq -r --arg domain "$JIRA_DOMAIN" '
  .issues[] | 
  "<tr><td><a href=\"https://\($domain)/browse/" + .key + "\">" + .key + "</a></td><td>" + (.fields.summary | gsub("<";"&lt;") | gsub(">";"&gt;")) + "</td><td>" + 
  ([.fields.fixVersions[].name] | join(", ")) + "</td></tr>"' >> release_report.html

echo "</table></body></html>" >> release_report.html

echo "✅ release_report.html generated."

✅ Make it executable: chmod +x release_report.sh

⸻

✅ How to Run in Bamboo

➤ Plan Variables

Set these in Bamboo:

Variable	Value
JIRA_USER	your@email.com
JIRA_TOKEN	your JIRA API token
JIRA_DOMAIN	your-domain.atlassian.net
JIRA_PROJECT	CTLQ
VERSION_LOWER	2024.12.01.Release
VERSION_UPPER	2025.03.15.Release

Mask JIRA_TOKEN.

⸻

➤ Add a Script Task

Choose one of:

Option A: Python

python3 -m venv venv
source venv/bin/activate
pip install requests
python jira_release_report.py

Option B: Shell + jq

if ! command -v jq >/dev/null 2>&1; then
  curl -L -o jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x jq
  export PATH="$PWD:$PATH"
fi

chmod +x release_report.sh
./release_report.sh


⸻

➤ Artifact (Optional)

Add release_report.html as a build artifact to archive it in Bamboo.

⸻

Would you like to:
	•	Send the HTML via email from Python or shell?
	•	Include Bamboo YAML spec instead of manual UI setup?


Got it! Here’s the full setup:

⸻

1️⃣ Upload release_report.html as Bamboo Artifact

In your Bamboo Plan Job:
	•	Go to Artifacts tab
	•	Click Create artifact
	•	Name: jira-release-report
	•	Location: (leave blank or . if report is in working dir)
	•	Copy pattern: release_report.html

This will save the report for download/view after the build.

⸻

2️⃣ Send Email with HTML Report in Bamboo

You can send email from Bamboo using a script step.

Option A: Python Email Sender (add after report generation)

Add this to your Python script (requires SMTP info):

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

SMTP_SERVER = os.environ.get('SMTP_SERVER')
SMTP_PORT = int(os.environ.get('SMTP_PORT', 587))
SMTP_USER = os.environ.get('SMTP_USER')
SMTP_PASS = os.environ.get('SMTP_PASS')
EMAIL_FROM = os.environ.get('EMAIL_FROM')
EMAIL_TO = os.environ.get('EMAIL_TO')

with open("release_report.html", "r") as f:
    html_content = f.read()

msg = MIMEMultipart('alternative')
msg['Subject'] = f"JIRA Release Report: {VERSION_LOWER} to {VERSION_UPPER}"
msg['From'] = EMAIL_FROM
msg['To'] = EMAIL_TO
part = MIMEText(html_content, 'html')
msg.attach(part)

with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
    server.starttls()
    server.login(SMTP_USER, SMTP_PASS)
    server.sendmail(EMAIL_FROM, EMAIL_TO.split(','), msg.as_string())

print("✅ Email sent.")

Set Bamboo plan variables for SMTP_SERVER, SMTP_PORT, SMTP_USER, SMTP_PASS, EMAIL_FROM, EMAIL_TO accordingly.

⸻

Option B: Shell Email Sender (send with mail or sendmail)

Assuming sendmail or mailx is available in Bamboo agent, add this after report generation:

cat release_report.html | mail -a "Content-Type: text/html" -s "JIRA Release Report: $VERSION_LOWER to $VERSION_UPPER" "$EMAIL_TO"

Make sure environment variable EMAIL_TO is set in Bamboo.

⸻

3️⃣ Bamboo YAML Specs for both Python and Shell

⸻

➤ Python Bamboo Specs (bamboo-specs.yml)

version: 2

plan:
  project-key: YOURPROJECT
  key: JIRAREL
  name: JIRA Release Report Python

stages:
  - Stage:
      jobs:
        - Job:
            key: JOB1
            name: Generate & Email Report
            tasks:
              - script:
                  description: Setup Python and run report
                  interpreter: BINSH_OR_CMDEXE
                  script: |
                    python3 -m venv venv
                    source venv/bin/activate
                    pip install requests
                    python jira_release_report.py
              - script:
                  description: Send Email (Python SMTP inside jira_release_report.py)
                  interpreter: BINSH_OR_CMDEXE
                  script: |
                    echo "Email sent inside Python script"
artifacts:
  - artifact:
      name: jira-release-report
      copyPattern: release_report.html
      location: .


⸻

➤ Shell Bamboo Specs (bamboo-specs.yml)

version: 2

plan:
  project-key: YOURPROJECT
  key: JIRARELSH
  name: JIRA Release Report Shell

stages:
  - Stage:
      jobs:
        - Job:
            key: JOB1
            name: Generate & Email Report Shell
            tasks:
              - script:
                  description: Install jq if missing and run shell report
                  interpreter: BINSH_OR_CMDEXE
                  script: |
                    if ! command -v jq >/dev/null 2>&1; then
                      curl -L -o jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
                      chmod +x jq
                      export PATH="$PWD:$PATH"
                    fi
                    chmod +x release_report.sh
                    ./release_report.sh
              - script:
                  description: Send HTML email with sendmail/mailx
                  interpreter: BINSH_OR_CMDEXE
                  script: |
                    cat release_report.html | mail -a "Content-Type: text/html" -s "JIRA Release Report: $VERSION_LOWER to $VERSION_UPPER" "$EMAIL_TO"

artifacts:
  - artifact:
      name: jira-release-report
      copyPattern: release_report.html
      location: .


⸻

4️⃣ Bamboo Variables Needed for Both

Variable	Example Value	Notes
JIRA_USER	your-email@example.com	JIRA login/email
JIRA_TOKEN	your-jira-api-token	Masked
JIRA_DOMAIN	your-domain.atlassian.net	
JIRA_PROJECT	CTLQ	Default if missing
VERSION_LOWER	2024.12.01.Release	
VERSION_UPPER	2025.03.15.Release	
EMAIL_TO	business-team@example.com	For email sending
SMTP_SERVER	smtp.example.com	For Python SMTP (optional)
SMTP_PORT	587	For Python SMTP
SMTP_USER	smtp-user@example.com	For Python SMTP
SMTP_PASS	smtp-password	Masked
EMAIL_FROM	noreply@example.com	For Python SMTP


⸻

Summary
	•	Python: Generates report, sends email via SMTP, artifacts saved
	•	Shell: Generates report with jq, sends email via mail/sendmail, artifacts saved
	•	Bamboo YAML specs: Configure plan jobs, tasks, artifacts
	•	Variables: Injected securely into Bamboo environment

⸻

If you want, I can help with:
	•	Full working Python script with email included
	•	Full working shell script with email included
	•	How to upload this Bamboo YAML spec to your Bamboo server step-by-step

⸻

Just let me know!