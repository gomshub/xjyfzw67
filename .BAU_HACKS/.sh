To generate an HTML table with sortable columns, you can include JavaScript to enable sorting functionality. Below is an updated shell script that fetches JIRA issues, generates an HTML report, and includes JavaScript for column sorting.

### Shell Script

```sh
#!/bin/bash

# Configuration
JIRA_URL="https://your-jira-instance"
JIRA_API="/rest/api/2/search?jql=filter=YOUR_FILTER_ID"
JIRA_ISSUE_API="/rest/api/2/issue"
USERNAME="your-jira-username"
PASSWORD="your-jira-password"
RECIPIENT="recipient@example.com"
SUBJECT="JIRA Issues Report"
TEMP_JSON_FILE="/tmp/jira_issues.json"
TEMP_HTML_FILE="/tmp/jira_issues.html"
TEMP_COMMENT_FILE="/tmp/jira_comments.json"

# Fetch JIRA issues
response=$(curl -s -w "%{http_code}" -u $USERNAME:$PASSWORD -X GET -H "Content-Type: application/json" "$JIRA_URL$JIRA_API" -o $TEMP_JSON_FILE)
http_code=$(tail -n1 <<< "$response")

if [ "$http_code" -ne 200 ]; then
  echo "Error: Failed to fetch JIRA issues. HTTP Status: $http_code"
  exit 1
fi

# Check if there are issues
if [ ! -s $TEMP_JSON_FILE ] || [ "$(jq '.total' $TEMP_JSON_FILE)" -eq 0 ]; then
  echo "No JIRA issues found in the filter."
  exit 0
fi

# Generate HTML content
cat <<EOF > $TEMP_HTML_FILE
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>JIRA Issues Report</title>
<style>
  body, html {
    margin: 0;
    padding: 0;
    font-family: Arial, sans-serif;
    font-size: 14px;
    line-height: 1.6;
  }
  img {
    max-width: 100%;
    height: auto;
  }
  .container {
    width: 100%;
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
    box-sizing: border-box;
  }
  .header {
    text-align: center;
    margin-bottom: 20px;
  }
  .header h1 {
    color: #333;
  }
  .issue-table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 20px;
  }
  .issue-table th, .issue-table td {
    border: 1px solid #ddd;
    padding: 8px;
    text-align: left;
  }
  .issue-table th {
    background-color: #f2f2f2;
    cursor: pointer;
  }
  .issue-table th:hover {
    background-color: #ddd;
  }
  .footer {
    text-align: center;
    color: #666;
    margin-top: 20px;
  }
</style>
<script>
function sortTable(n) {
  var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
  table = document.getElementById("issueTable");
  switching = true;
  dir = "asc"; 
  while (switching) {
    switching = false;
    rows = table.rows;
    for (i = 1; i < (rows.length - 1); i++) {
      shouldSwitch = false;
      x = rows[i].getElementsByTagName("TD")[n];
      y = rows[i + 1].getElementsByTagName("TD")[n];
      if (dir == "asc") {
        if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {
          shouldSwitch = true;
          break;
        }
      } else if (dir == "desc") {
        if (x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) {
          shouldSwitch = true;
          break;
        }
      }
    }
    if (shouldSwitch) {
      rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
      switching = true;
      switchcount ++;
    } else {
      if (switchcount == 0 && dir == "asc") {
        dir = "desc";
        switching = true;
      }
    }
  }
}
</script>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>JIRA Issues Report</h1>
  </div>
  <table class="issue-table" id="issueTable">
    <thead>
      <tr>
        <th onclick="sortTable(0)">JIRA Number</th>
        <th onclick="sortTable(1)">Status</th>
        <th onclick="sortTable(2)">Summary</th>
        <th onclick="sortTable(3)">Created Date</th>
        <th onclick="sortTable(4)">Assignee</th>
        <th onclick="sortTable(5)">Description</th>
        <th onclick="sortTable(6)">Comments</th>
      </tr>
    </thead>
    <tbody>
EOF

# Iterate through issues to fetch comments and append to HTML
jq -r '.issues[] | .key' $TEMP_JSON_FILE | while read -r key; do
  # Fetch comments for each issue
  comments_response=$(curl -s -u $USERNAME:$PASSWORD -X GET -H "Content-Type: application/json" "$JIRA_URL$JIRA_ISSUE_API/$key/comment" -o $TEMP_COMMENT_FILE)
  comment_http_code=$(tail -n1 <<< "$comments_response")

  if [ "$comment_http_code" -ne 200 ]; then
    echo "Error: Failed to fetch comments for issue $key. HTTP Status: $comment_http_code"
    continue
  fi

  # Extract all comments and the first comment
  all_comments=$(jq -r '.comments | map(.body) | join("<br><br>") | gsub("\n"; "<br>")' $TEMP_COMMENT_FILE)
  first_comment=$(jq -r '.comments[0].body // "No comments"' $TEMP_COMMENT_FILE | sed ':a;N;$!ba;s/\n/<br>/g')

  # Extract other fields and convert multi-line description to HTML format
  issue_data=$(jq -r --arg key "$key" --arg all_comments "$all_comments" --arg first_comment "$first_comment" '
    .issues[] | select(.key == $key) | 
    "<tr><td><a href=\"'$JIRA_URL'/browse/\($key)\">\($key)</a></td>
    <td>\(.fields.status.name)</td>
    <td>\(.fields.summary)</td>
    <td>\(.fields.created)</td>
    <td>\(.fields.assignee.displayName // "Unassigned")</td>
    <td>\(.fields.description // "" | gsub("\n|\r"; "<br>"))</td>
    <td>All Comments: <br>\($all_comments)<br><br>First Comment: <br>\($first_comment)</td></tr>"' $TEMP_JSON_FILE)

  echo "$issue_data" >> $TEMP_HTML_FILE
done

# Close HTML tags
cat <<EOF >> $TEMP_HTML_FILE
    </tbody>
  </table>
  <div class="footer">
    <p>&copy; 2024 Your Company</p>
  </div>
</div>
</body>
</html>
EOF

# Send email if there are issues
if [ -s $TEMP_HTML_FILE ]; then
  cat $TEMP_HTML_FILE | mailx -a 'Content-Type: text/html' -s "$SUBJECT" $RECIPIENT
fi

# Clean up
rm -f $TEMP_JSON_FILE $TEMP_HTML_FILE $TEMP_COMMENT_FILE
```

### Explanation:

1. **HTML and CSS Setup**:
   - The HTML and CSS define a responsive table and include basic styles to enhance readability and aesthetics.
   - Added a `cursor: pointer` to the table headers to indicate they are clickable for sorting.

2. **JavaScript for Sorting**:
   - The `sortTable` function sorts the table rows based on the clicked column. The sorting direction toggles between ascending and descending with each click.

3. **Shell Script Logic**:
   - The script fetches JIRA issues, retrieves comments, and generates HTML content dynamically.
   - It uses `jq` to parse JSON and extracts necessary details.
   - Adds each issue's data into the HTML table and includes a JavaScript call for sorting.

4. **Email Sending**:
   - If issues are present, the generated HTML file is sent via email using `mailx`.

### Requirements:

- Ensure `jq` is installed (`sudo apt-get install jq`).
- Ensure `mailx` is installed and configured (`sudo apt-get install mailx`).

This setup allows you to have a dynamic, sortable HTML table that displays JIRA issues and their details, making it easier to manage and view large datasets.