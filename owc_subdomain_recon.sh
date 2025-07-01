	#!/bin/bash

	# ASCII Banner
	echo """
	  ██████  ██     ██  ██████      ███████ ██    ██ ██████  
	  ██   ██ ██     ██ ██          ██      ██    ██ ██   ██ 
	  ██████  ██  █  ██ ██   ███     █████   ██    ██ ██████  
	  ██      ██ ███ ██ ██    ██     ██      ██    ██ ██   ██ 
	  ██       ███ ███   ██████      ██       ██████  ██   ██ 
	"""

	# Get domain input
	read -p "Enter the domain name: " domain

	# Create unique folder for the domain
	folder_name="$domain"
	count=1
	while [ -d "$folder_name" ]; do
	    folder_name="${domain}_$(printf "%02d" $count)"
	    ((count++))
	done
	mkdir "$folder_name"
	cd "$folder_name"

	# Run subdomain enumeration tools sequentially
	echo "[+] Running Subfinder..."
	subfinder -silent -d "$domain" -o "${domain}_subfinder.txt"
	subfinder_count=$(wc -l < "${domain}_subfinder.txt")

	echo "[+] Running Assetfinder..."
	assetfinder --subs-only "$domain" | tee "${domain}_assetfinder.txt" > /dev/null
	assetfinder_count=$(wc -l < "${domain}_assetfinder.txt")

	echo "[+] Running Findomain..."
	findomain -t "$domain" -u "${domain}_findomain.txt"
	findomain_count=$(wc -l < "${domain}_findomain.txt")

	echo "[+] Running Sublist3r..."
	sublist3r -d "$domain" -o "${domain}_sublist3r.txt"
	sublist3r_count=$(wc -l < "${domain}_sublist3r.txt")

	# Merge all results, filter unique subdomains
	cat "${domain}_subfinder.txt" "${domain}_assetfinder.txt" "${domain}_findomain.txt" "${domain}_sublist3r.txt" | sort -u > "${domain}_unique_subdomains.txt"
	unique_count=$(wc -l < "${domain}_unique_subdomains.txt")

	echo "[+] Checking for live subdomains using httpx..."
	cat "${domain}_unique_subdomains.txt" | ~/go/bin/httpx -silent -o "${domain}_alive_subdomains.txt"
	live_count=$(wc -l < "${domain}_alive_subdomains.txt")

	echo "[+] Checking for nuclei vulnerability CVE and Redirect"
	~/go/bin/nuclei -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36' -list "${domain}_alive_subdomains.txt" -tags cve,redirect -o "${domain}_nuclie_output.txt" -rate-limit 3

	if [ -s "${domain}_nuclie_output.txt" ]; then
	    ~/go/bin/notify  -data "${domain}_nuclie_output.txt" -bulk -id nucleiscan
	else
	    echo "No vulnerabilities reported from Nuclei with tags cve, redirect  on ${domain}" | ~/go/bin/notify -bulk -id nucleiscan
	fi

	echo "[+] Checking for nuclei vulnerability Misconfiguration "
	~/go/bin/nuclei -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36' -list "${domain}_alive_subdomains.txt" -t misconfiguration/ -o "${domain}_nuclie__misconfiguration_output.txt" -rate-limit 3

	if [ -s "${domain}_nuclie__misconfiguration_output.txt" ]; then
	    ~/go/bin/notify -data "${domain}_nuclie__misconfiguration_output.txt" -bulk -id nucleiscan -rate-limit 3
	else
	    echo "No vulnerabilities reported from Nuclei with tags cve, redirect  on ${domain}" | ~/go/bin/notify -bulk -id nucleiscan
	fi

	# Save analysis report
	echo "Total subdomains in each file:" > "${domain}_analysis.txt"
	printf "  %4d %s_subfinder.txt\n" "$subfinder_count" "$domain" >> "${domain}_analysis.txt"
	printf "  %4d %s_assetfinder.txt\n" "$assetfinder_count" "$domain" >> "${domain}_analysis.txt"
	printf "  %4d %s_findomain.txt\n" "$findomain_count" "$domain" >> "${domain}_analysis.txt"
	printf "  %4d %s_sublist3r.txt\n" "$sublist3r_count" "$domain" >> "${domain}_analysis.txt"
	echo "" >> "${domain}_analysis.txt"
	printf "Total unique subdomains:\n  %4d %s_unique_subdomains.txt\n\n" "$unique_count" "$domain" >> "${domain}_analysis.txt"
	printf "Live subdomains:\n  %4d %s_alive_subdomains.txt\n" "$live_count" "$domain" >> "${domain}_analysis.txt"

	echo "[+] Recon completed. Results saved in $folder_name"
