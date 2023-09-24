#!/usr/bin/env bash

echo -e "\n\n###########################################################"
echo -e "#### Dependencies: pup, aria2c"
echo -e "#### Usage: 'mkdir <this> && cd <this> && libgen_dl.sh <keywords>' where the <keywords> string contains more than 2 characters."
echo -e "#### See ./libgen_dl/log after running. Manually inspect temp files under ./libgen_dl if needed."
echo -e "#### Optionally comment last line to use uget or any other dl manager to download link list (./libgen_dl/file_link_list.txt)"
echo -e "###########################################################\n\n"

[[ "$#" != 1 || "${#1}" -lt 3 ]] && { echo "Invalid arguments. See 'Usage'."; exit 1; }

results=100 # Number of items per search page (Use either 25, 50 or 100).

mkSearchLink () {
    echo "https://libgen.rs/search.php?res=$results&req=$(echo "$1" | sed 's/\ /%20/g')&phrase=0&view=simple&column=def&sort=def&sortmode=ASC&page=$2"
    }

######### 0. Create directories, log stuff
mkdir "libgen_dl" || { echo -e "\nRemove the existing './libgen_dl' directory before using this program in a preferably empty directory."; exit; }
mkdir -p "libgen_dl/get"
mkdir -p "libgen_dl/pages"
echo "$(date +"%Y-%m-%d %T" ) ======================================== START " >> "libgen_dl/log"
echo "$(date +"%Y-%m-%d %T" ) Search keywords: $1" >> "libgen_dl/log"
echo "$(date +"%Y-%m-%d %T" ) First page link: $(mkSearchLink "$1" 1)" >> "libgen_dl/log"

######## 1. Download all "search" pages.
aria2c -d "libgen_dl/pages" "$(mkSearchLink "$1" 1)" 
page_count="$(cat "libgen_dl/pages/search.php" | pup 'script:nth-of-type(2)' | sed '4q;d' | sed 's/,.*//' | sed 's/\ *//')"
page_count=${page_count:-1}
echo "$(date +"%Y-%m-%d %T" ) Number of pages ($results items per page): $page_count" >> "libgen_dl/log"
for i in $(seq 2 "$page_count"); do
    aria2c -d "./libgen_dl/pages" "$(mkSearchLink "$1" "$i")"
done

######## 2. For each "search" page, collect every individual "get" link into `libgen_dl/get_page_link_list.txt`.
for page_file in ./libgen_dl/pages/*; do 
    link="$(cat "$page_file" | pup 'a[title="Libgen.li"] attr{href}')"
    echo "$link" >> "libgen_dl/get_page_link_list.txt"
done
echo "$(date +"%Y-%m-%d %T" ) Total number of detected items: $(cat libgen_dl/get_page_link_list.txt | wc -l)" >> "libgen_dl/log"

######## 3. Download every "get" page and store it under `libgen_dl/get/`
aria2c -j3 -d "libgen_dl/get" -i ./libgen_dl/get_page_link_list.txt -l ./libgen_dl/get_page_log


######## 4. For each individual "get" page collect the direct (document) link into `libgen_dl/file_link_list.txt`.
for file in ./libgen_dl/get/*; do 
    if [ -f "$file" ]; then 
	link="https://libgen.rocks/$(cat "$file" | pup ':parent-of(h2:contains("GET")) attr{href}' | sed 's/\&amp;/\&/g')"
	if [ "$link" != "https://libgen.rocks/" ]; 
	then echo "$link" >> "libgen_dl/file_link_list.txt"
	fi
    fi 
done

######## 4. Download files. Comment this line if you only want to collect links (For example to use another dl manager such as uget)
aria2c -j3 -i ./libgen_dl/file_link_list.txt -l ./libgen_dl/file_download_log

echo "$(date +"%Y-%m-%d %T" ) ======================================== End" >> "libgen_dl/log"
