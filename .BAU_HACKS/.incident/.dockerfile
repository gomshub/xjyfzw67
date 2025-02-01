Updated Dockerfile with entrypoint.sh and Gunicorn

Using Gunicorn for better performance and entrypoint.sh for flexible container execution.

Dockerfile

# Use a lightweight Python base image
FROM python:3.11.7-slim

# Set the working directory
WORKDIR /app

# Install system dependencies (Java for ojdbc)
RUN apt-get update && apt-get install -y openjdk-11-jre-headless && rm -rf /var/lib/apt/lists/*

# Copy the pip.conf file for Artifactory
COPY ./config/pip.conf /etc/pip.conf

# Install Python dependencies from Artifactory
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY ./app /app

# Copy the Oracle JDBC (ojdbc) driver
COPY ./utils/lib/ojdbc8.jar /app/utils/lib/ojdbc8.jar

# Copy the entrypoint script and provide execution permission
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose the application port
EXPOSE 8080

# Set entrypoint script
ENTRYPOINT ["/entrypoint.sh"]

Entrypoint Script (entrypoint.sh)

#!/bin/sh

# Wait for the database (optional, add logic if needed)
echo "Starting the application..."

# Start Gunicorn with 4 worker processes
exec gunicorn --bind 0.0.0.0:8080 --workers 4 --threads 2 --timeout 120 app.routes:app

Key Improvements
	1.	Gunicorn for Better Performance
	•	Spawns multiple workers for handling concurrent requests.
	•	Uses 4 workers, 2 threads per worker, and a 120-second timeout.
	2.	Entrypoint Script (entrypoint.sh)
	•	Ensures the container starts with Gunicorn.
	•	Makes it easy to change startup behavior without modifying Dockerfile.
	3.	ojdbc8.jar Included
	•	Ensures Java-based Oracle DB connectivity.

Building & Running

1. Build Docker Image

docker build -t my-app:latest .

2. Run the Container

docker run -p 8080:8080 my-app:latest

Now, the Flask app (app.routes:app) runs on Gunicorn inside the container.