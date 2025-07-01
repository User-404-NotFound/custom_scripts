#!/bin/bash

# Ask for the file containing domains
read -p "Enter the path to the file containing domains: " file_path

# Validate the file
if [[ ! -f "$file_path" ]]; then
    echo "Error: File not found!"
    exit 1
fi

# Create an output directory if it doesn't exist
output_dir="output"
mkdir -p "$output_dir"

# Log file to track completed domains
progress_log="progress.log"
touch "$progress_log"

# Read total domains for progress tracking
total_domains=$(wc -l < "$file_path")
processed_count=0

echo "Total domains to process: $total_domains"
echo "Resuming from the last checkpoint..."

while read -r website_input; do
    # Skip if the domain is already processed
    if grep -Fxq "$website_input" "$progress_log"; then
        ((processed_count++))
        continue
    fi

    # Normalize input (ensure it has https://)
    if [[ ! $website_input =~ ^https?:// ]]; then
        website_url="https://$website_input"
    else
        website_url="$website_input"
    fi

    echo "Processing ($processed_count/$total_domains): $website_url"

    # Generate timestamped filenames
    timestamp=$(date +%Y-%m-%d)
    passive_output="${output_dir}/${website_input}_${timestamp}_ktana_passive.txt"
    active_output="${output_dir}/${website_input}_${timestamp}_katana_active.txt"
    wayback_output="${output_dir}/${website_input}_${timestamp}_wayback.txt"
    gau_output="${output_dir}/${website_input}_${timestamp}_gau.txt"
    final_output="${output_dir}/${website_input}_${timestamp}_final_output.txt"

    # Step 1: Run katana with passive sources
    #echo "Running katana passive scan..."
   # echo "$website_url" | ~/go/bin/katana -ps -pss waybackarchive,commoncrawl,alienvault -f qurl | uro > "$passive_output"

    # Step 2: Run katana actively
    #echo "Running katana active scan..."
    #echo "$website_url" | ~/go/bin/katana -u "$website_url" -d 5 -f qurl --scope subdomains --no-scope | uro > "$active_output"


    # Step 3: Run waybackurls and gau
    echo "Fetching URLs from wayback and gau..."
    echo "$website_input" | /home/kali/go/bin/waybackurls | /home/kali/.local/share/pipx/venvs/uro/bin/uro > "$wayback_output"
    echo "$website_input" | /home/kali/go/bin/gau | /home/kali/.local/share/pipx/venvs/uro/bin/uro > "$gau_output"

    # Step 4: Merge all outputs and remove duplicates
    echo "Merging results..."
    cat "$passive_output" "$active_output" "$wayback_output" "$gau_output" | /home/kali/.local/share/pipx/venvs/uro/bin/uro > "$final_output"

    # Step 5: Filter for vulnerabilities
    echo "Filtering vulnerabilities..."
    
    xss_file="${output_dir}/${website_input}_${timestamp}_xss_output.txt"
    open_redirect_file="${output_dir}/${website_input}_${timestamp}_open_redirect_output.txt"
    lfi_file="${output_dir}/${website_input}_${timestamp}_lfi_output.txt"
    sqli_file="${output_dir}/${website_input}_${timestamp}_sqli_output.txt"

    #timeout 30s cat "$final_output" | ~/go/bin/Gxss | ~/go/bin/kxss | grep -oP '^URL: \K\S+' | sed 's/=.*/=/' | uro > "$xss_file"
    timeout 5s cat "$final_output" | /home/kali/go/bin/gf or | sed 's/=.*/=/' | /home/kali/.local/share/pipx/venvs/uro/bin/uro > "$open_redirect_file"
    timeout 5s cat "$final_output" | /home/kali/go/bin/gf lfi | sed 's/=.*/=/' | /home/kali/.local/share/pipx/venvs/uro/bin/uro > "$lfi_file"
    timeout 5s cat "$final_output" | /home/kali/go/bin/gf sqli | sed 's/=.*/=/' | /home/kali/.local/share/pipx/venvs/uro/bin/uro > "$sqli_file"

    # Mark as completed
    echo "$website_input" >> "$progress_log"
    ((processed_count++))

    # Print summary
    echo "Completed ($processed_count/$total_domains): $website_url"
    echo "  - XSS: $xss_file"
    echo "  - Open Redirect: $open_redirect_file"
    echo "  - LFI: $lfi_file"
    echo "  - SQLi: $sqli_file"
    echo "-------------------------------------"

done < "$file_path"

echo "All domains processed successfully!"
