#!/usr/bin/env bash

# fftabs - Open URLs from a file in Firefox, 15 tabs per new browser instance.
# Each instance uses a temporary Firefox profile to avoid conflicts.

# Global list of URLs
declare -g UrlList

# Function to open a new Firefox instance with a unique profile
runff()
{
    profile_dir=$(mktemp -d)  # Create a temporary profile directory
    ffcmd="firefox --no-remote --profile \"$profile_dir\" --new-window"
    
    for (( i=$1; i<$2; i++ )); do
        [[ -n "${UrlList[$i]}" ]] && ffcmd+=" -new-tab -url \"${UrlList[$i]}\""
    done

    echo -e "${ffcmd}\n"
    eval "$ffcmd" &>/dev/null &

    # Give Firefox some time to start before launching another instance
    sleep 3
}

# Check if a valid file is provided
if [[ -f "$1" ]]; then
    readarray -t UrlList < "$1"
    numUrls=${#UrlList[@]}
    echo "Read $numUrls URLs from file $1."

    if [[ $numUrls -gt 0 ]]; then
        numSets=$((numUrls / 15))
        remainder=$((numUrls % 15))
        
        start=0
        end=15

        for (( set=0; set<numSets; set++ )); do
            runff "$start" "$end"
            start=$end
            end=$((end + 15))

            if (( set < numSets - 1 || remainder > 0 )); then
                read -p "Press any key to load the next 15 tabs in a new browser..." -n1 -s
                echo -e "\n"
            fi
        done

        if [[ $remainder -ne 0 ]]; then
            runff "$start" "$((start + remainder))"
        fi

        echo "Finished!"
        exit 0
    fi

    echo "The file does not contain any URLs."
fi

# Display usage instructions if no valid file is provided
echo -e "Usage:\n    fftabs.sh /path/to/file\n"
echo -e "Where the file contains URLs on separate lines."
exit 1
