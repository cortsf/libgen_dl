#!/usr/bin/env bash

echo -e "\n\n###########################################################"
echo -e "#### Dependencies: pup, aria2c"
echo -e "#### Usage: 'libgen_dl.sh <search_keywords>'."
echo -e "#### See ./html/log after running. Manually inspect temp files under ./html if needed."
echo -e "#### Optionally comment last line to use uget or any other dl manager to download link list (./html/file_link_list.txt)"
echo -e "###########################################################\n\n"

if [ "$1" == "" ]; then exit; fi


######### 0. Create directories and log search keyword/s
mkdir -p "html"
mkdir -p "html/get"
mkdir -p "html/pages"
echo "======================================== SEARCH KEYWORD: $1" >> "html/log"

######## 1. Download all "search" pages.
search=$(echo "$1" | sed 's/\ /%20/g')
aria2c -d "html/pages" "https://libgen.rs/search.php?&req=$search&phrase=0&view=simple&column=def&sort=def&sortmode=ASC&page=1"
crawl_page_count="$(cat "html/pages/search.php" | pup 'script:nth-of-type(2)' | sed '4q;d' | sed 's/,.*//' | sed 's/\ *//')"
if [ "$crawl_page_count" == "" ]; then page_count=1; else page_count="$crawl_page_count"; fi
echo "Number of pages: $page_count" >> "html/log"
for i in $(seq 2 "$page_count"); do
    aria2c -d "./html/pages" "http://libgen.rs/search.php?&req=$search&phrase=0&view=simple&column=def&sort=def&sortmode=ASC&page=$i"
done

######## 2. For each "search" page, collect every individual "get" link into `html/get_page_link_list.txt`.
for page_file in ./html/pages/*; do 
    link="$(cat "$page_file" | pup 'a[title="Libgen.lc"] attr{href}')"
    echo "$link" >> "html/get_page_link_list.txt"
done

######## 3. Download every "get" page and store it under `html/get/`
aria2c -j3 -d "html/get" -i ./html/get_page_link_list.txt -l ./html/get_page_log


######## 4. For each individual "get" page collect the direct (document) link into `html/file_link_list.txt`.
for file in ./html/get/*; do 
    if [ -f "$file" ]; then 
	link="https://libgen.rocks/$(cat "$file" | pup ':parent-of(h2:contains("GET")) attr{href}' | sed 's/\&amp;/\&/g')"
	if [ "$link" != "https://libgen.rocks/" ]; 
	then echo "$link" >> "html/file_link_list.txt"
	fi
    fi 
done

# Comment this line if you only want to collect links (For example to use another dl manager such as uget)
aria2c -j3 -i ./html/file_link_list.txt -l ./html/file_download_log

echo "======================================== FINISHED DOWNLOADING" >> "html/log"
