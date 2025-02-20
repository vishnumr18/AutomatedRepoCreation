#!/bin/bash

# Organization name
ORG_NAME="HackZion"

# CSV file containing team names and GitHub usernames/emails of team leads
INPUT_FILE=$1
if [ -z "$INPUT_FILE" ]; then
    echo "❌ Error: No input file provided. Usage: ./create_repos.sh [csv_file]"
    exit 1
fi

# Log file to store the output
LOG_FILE="/Users/vishnumr/My Files/Vishnu/Hackzion 2025/GitHub Repos/Log Files/repo_creation_log_$(date +'%Y-%m-%d_%H-%M-%S').csv"

# Initialize log file with header
echo "Team Name,Collaborator Account,Repo Creation Status,Collaborator Addition Status" > "$LOG_FILE"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is authenticated with GitHub CLI
if ! gh auth status &> /dev/null; then
    echo "❌ You are not authenticated with GitHub CLI. Please run 'gh auth login' first."
    exit 1
fi

echo "🚀 Starting Repository Creation Process - $(date)"
echo "Log File: $LOG_FILE"
echo "---------------------------------------------"

# Process each line in the CSV file
while IFS=',' read -r team_name collaborator || [ -n "$team_name" ]; do
    # Remove any whitespace
    team_name=$(echo "$team_name" | tr -d '[:space:]')
    collaborator=$(echo "$collaborator" | tr -d '[:space:]')
    
    # Sanitize repository name for GitHub
    # Replace parentheses and other special characters with hyphens
    repo_name=$(echo "$team_name" | sed 's/[():]/-/g' | sed 's/-\+/-/g' | sed 's/-$//g')
    
    echo "📦 Processing: Team=$team_name, Collaborator=$collaborator"
    
    # Extract username from email (if email is provided)
    if [[ "$collaborator" == *"@"* ]]; then
        collaborator_username=${collaborator%@*}
    else
        collaborator_username=$collaborator
    fi
    
    # Check if collaborator account exists
    if gh api users/$collaborator_username &> /dev/null; then
        collaborator_exists="Yes"
        
        # Create repository under the organization
        if gh repo create "$ORG_NAME/$repo_name" --private; then
            repo_status="Created"
            echo "✅ Repository $ORG_NAME/$repo_name created successfully."
            
            # Sleep for a moment to let GitHub process the repository creation
            sleep 2
            
            # Add collaborator to the repository using the API - Fixed to use repo_name instead of team_name
            if gh api "repos/$ORG_NAME/$repo_name/collaborators/$collaborator_username" -X PUT -f permission=push &> /dev/null; then
                collab_status="Added"
                echo "🔑 Access granted to $collaborator_username for $ORG_NAME/$repo_name."
            else
                collab_status="Failed to add"
                echo "❌ Failed to add $collaborator_username as a collaborator for $ORG_NAME/$repo_name."
            fi
        else
            repo_status="Failed to create"
            collab_status="Not attempted"
            echo "❌ Failed to create repository: $ORG_NAME/$repo_name."
        fi
    else
        collaborator_exists="No"
        repo_status="Not attempted"
        collab_status="Account doesn't exist"
        echo "❌ GitHub account for $collaborator_username doesn't exist."
    fi
    
    # Log the results
    echo "$team_name,$collaborator,$repo_status,$collab_status" >> "$LOG_FILE"
    echo "---------------------------------------------"
done < "$INPUT_FILE"

echo "✅ All processes completed - $(date)"
echo "Results saved to $LOG_FILE"