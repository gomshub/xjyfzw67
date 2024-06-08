#!/bin/bash

Certainly! Here's an example of a shell script that uses `grep` to search for a specific word in a text file and prints the matched words alone, consolidating the list:

```bash
#!/bin/bash

# Input file path
file="file.txt"

# Word to search for
search_word="example"

# Output file path
matched_words="matched_words.txt"

# Search for the word in the file and store the matched words
grep -o "\b$search_word\b" "$file" | sort | uniq > "$matched_words"

# Print the consolidated list of matched words
echo "Consolidated list of matched words:"
cat "$matched_words"
```

Replace `file.txt` with the actual path to your input file, and `example` with the word you want to search for. The script uses `grep` with the `-o` option to only print the matched word, rather than the whole line. The words are then sorted and duplicates are removed using `sort` and `uniq`. The consolidated list of matched words is stored in the `matched_words.txt` file.

Remember to save the script with a `.sh` extension, for example, `grep_words.sh`. To execute the script, open a terminal, navigate to the directory where the script is saved, and run the command `bash grep_words.sh`.


Certainly! Here's an example of a shell script that compares two text files and prints the matched and unmatched words into separate files:

```bash
#!/bin/bash

# Input file paths
file1="file1.txt"
file2="file2.txt"

# Output file paths
matched_words="matched_words.txt"
unmatched_words="unmatched_words.txt"

# Compare the two files and store the matched and unmatched words
comm -12 <(tr '[:upper:]' '[:lower:]' < "$file1" | tr -s ' ' '\n' | sort) <(tr '[:upper:]' '[:lower:]' < "$file2" | tr -s ' ' '\n' | sort) > "$matched_words"
comm -3 <(tr '[:upper:]' '[:lower:]' < "$file1" | tr -s ' ' '\n' | sort) <(tr '[:upper:]' '[:lower:]' < "$file2" | tr -s ' ' '\n' | sort) > "$unmatched_words"

# Print the results
echo "Matched words:"
cat "$matched_words"
echo
echo "Unmatched words:"
cat "$unmatched_words"
```

Make sure to replace the file paths (`file1.txt` and `file2.txt`) with the actual paths to your input files. The script converts the text to lowercase, splits it into separate words, sorts the words, and then uses the `comm` command to compare the sorted word lists. The matched words are stored in the `matched_words.txt` file, and the unmatched words are stored in the `unmatched_words.txt` file.

Remember to save the script with a `.sh` extension, for example, `compare_files.sh`. To execute the script, open a terminal, navigate to the directory where the script is saved, and run the command `bash compare_files.sh`.




# Set your AWS access key and secret access key
AWS_ACCESS_KEY_ID="your-access-key"
AWS_SECRET_ACCESS_KEY="your-secret-access-key"

# Set the name of your S3 bucket
BUCKET_NAME="your-bucket-name"

# Set the path where you want to download the files
DOWNLOAD_PATH="./downloads"

# Configure your AWS CLI
aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY

# List the files in the S3 bucket
aws s3 ls s3://$BUCKET_NAME

# Download all files from the S3 bucket
aws s3 sync s3://$BUCKET_NAME $DOWNLOAD_PATH

python
import boto3
from datetime import datetime

def get_file_by_date(bucket_name, desired_date):
    s3 = boto3.client('s3')
    response = s3.list_objects_v2(Bucket=bucket_name)

    desired_date = datetime.strptime(desired_date, '%Y-%m-%d').date()

    for object in response['Contents']:
        last_modified = object['LastModified'].date()
        if last_modified == desired_date:
            file_key = object['Key']
            s3.download_file(bucket_name, file_key, 'downloaded_file.txt')
            print(f"File '{file_key}' downloaded successfully.")
            break
    else:
        print("No file found for the specified date.")

# Usage example
bucket_name = 'your_bucket_name'
desired_date = '2023-09-01'
get_file_by_date(bucket_name, desired_date)


python
import boto3
from datetime import datetime

def download_and_sort_s3_files(bucket_name, file_pattern):
    # Create an S3 client
    s3 = boto3.client('s3')

    # List objects in the bucket
    response = s3.list_objects_v2(Bucket=bucket_name)

    # Filter and sort the objects based on last modified date
    files = []
    for obj in response['Contents']:
        if obj['Key'].endswith(file_pattern):
            files.append(obj)

    files.sort(key=lambda x: x['LastModified'])

    # Download the selected files
    for file in files:
        file_name = file['Key']
        s3.download_file(bucket_name, file_name, file_name)
        last_modified = file['LastModified'].strftime("%Y-%m-%d %H:%M:%S")
        print(f"Downloaded file: {file_name}, Last Modified: {last_modified}")

    print("Files downloaded and sorted successfully.")

# Provide your S3 bucket name and file pattern
bucket_name = 'your_bucket_name'
file_pattern = '.txt'  # File pattern to filter files, e.g., '.txt' for text files

download_and_sort_s3_files(bucket_name, file_pattern)




python
import boto3
import fnmatch

bucket_name = 'your_bucket_name'
prefix_pattern = 'Abc*'

# Create an S3 client
s3 = boto3.client('s3')

# Set the initial parameters for pagination
paginator = s3.get_paginator('list_objects_v2')
page_iterator = paginator.paginate(Bucket=bucket_name)

# Retrieve the files matching the pattern prefix
for page in page_iterator:
    if 'Contents' in page:
        for obj in page['Contents']:
            # Get the object key
            object_key = obj['Key']
            # Check if the key matches the pattern prefix
            if fnmatch.fnmatch(object_key, prefix_pattern):
                # Download the file
                s3.download_file(bucket_name, object_key, object_key)
                print(f"Downloaded file: {object_key}")
    else:
        print("No files found with the specified pattern prefix.")


dockerfile
FROM ubuntu:latest

# Install SSH server
RUN apt-get update && apt-get install -y openssh-server

# Enable copy-paste functionality
RUN echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config
RUN echo "X11UseLocalhost no" >> /etc/ssh/sshd_config
RUN echo "X11Forwarding yes" >> /etc/ssh/sshd_config

# Set up user for SSH access
RUN useradd -m testuser && echo "testuser:testpassword" | chpasswd
RUN usermod --shell /bin/bash testuser

# Expose SSH port
EXPOSE 22

# Start SSH server
CMD ["/usr/sbin/sshd", "-D"]



Sure, here's a brief introduction to CI/CD (Continuous Integration/Continuous Deployment) that you can include in a slide presentation:

Slide Title: Introduction to CI/CD

Slide Content:
- CI/CD stands for Continuous Integration/Continuous Deployment.
- It is a software development practice that aims to automate the build, test, and deployment of applications.
- The primary goal of CI/CD is to deliver software changes to production quickly and reliably.
- Continuous Integration focuses on merging code changes from multiple developers into a shared repository frequently.
- It involves automating the process of building and testing the application to catch integration issues early.
- Continuous Deployment takes CI a step further by automatically deploying the application to production after successful testing.
- With CI/CD, teams can release new features, bug fixes, and improvements more frequently, reducing time-to-market.
- It enhances collaboration, as developers can work on different features simultaneously, knowing that their changes will integrate smoothly.
- CI/CD also promotes a culture of automation, quality assurance, and rapid feedback loops.
- It relies on the use of various tools and technologies such as version control systems, build servers, and deployment pipelines.
- By adopting CI/CD, organizations can achieve faster development cycles, improved software quality, and increased customer satisfaction.

Feel free to customize the content and design of the slide according to your needs.


python
import gzip
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import boto3

def unzip_and_convert_to_parquet(gz_file_path, s3_bucket, s3_key):
    # Unzip .gz file and read contents as text
    with gzip.open(gz_file_path, 'rb') as gz_file:
        text_data = gz_file.read().decode('utf-8')

    # Create a DataFrame from the text data
    df = pd.DataFrame({'data': [text_data]})

    # Convert DataFrame to Parquet file
    table = pa.Table.from_pandas(df)
    pq.write_table(table, 'temp.parquet')

    # Upload Parquet file to S3
    s3_client = boto3.client('s3')
    s3_client.upload_file('temp.parquet', s3_bucket, s3_key)

    # Remove the temporary Parquet file
    os.remove('temp.parquet')

# Example usage
gz_file_path = 'your-file.gz'
s3_bucket = 'your-s3-bucket'
s3_key = 'your-s3-key.parquet'

unzip_and_convert_to_parquet(gz_file_path, s3_bucket, s3_key)


python
import boto3

def create_subfolders(bucket_name, subfolder_path):
    s3_client = boto3.client('s3')
    
    # Append a trailing slash to the subfolder path if it doesn't exist
    if not subfolder_path.endswith('/'):
        subfolder_path += '/'
    
    # Create a placeholder object to represent the subfolder
    s3_client.put_object(Bucket=bucket_name, Key=subfolder_path)
    
# Example usage
bucket_name = 'your-bucket-name'
subfolder_path = 'your/subfolder/path/'

create_subfolders(bucket_name, subfolder_path)



python
import boto3

def create_subfolders(bucket_name, subfolder_paths):
    s3_client = boto3.client('s3')
    
    for subfolder_path in subfolder_paths:
        # Append a trailing slash to the subfolder path if it doesn't exist
        if not subfolder_path.endswith('/'):
            subfolder_path += '/'
        
        # Create a placeholder object to represent the subfolder
        s3_client.put_object(Bucket=bucket_name, Key=subfolder_path)
    
# Example usage
bucket_name = 'your-bucket-name'
subfolder_paths = ['subfolder1/', 'subfolder2/', 'subfolder3/']

create_subfolders(bucket_name, subfolder_paths)

python
import os
import boto3

def upload_files_to_s3(bucket_name, directory_path):
    s3_client = boto3.client('s3')

    for root, dirs, files in os.walk(directory_path):
        for file in files:
            file_path = os.path.join(root, file)
            s3_key = os.path.relpath(file_path, directory_path)
            s3_client.upload_file(file_path, bucket_name, s3_key)

# Example usage
bucket_name = 'your-bucket-name'
directory_path = '/path/to/your/directory'

upload_files_to_s3(bucket_name, directory_path)

