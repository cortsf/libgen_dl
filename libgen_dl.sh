#!/usr/bin/env bash

echo -e "\n\n###########################################################"
echo -e "#### Dependencies: aria2c"
echo -e "#### Usage: 'mkdir <blah> && cd <blah> && libgen_dl.sh <keywords>' with length of <keywords> > 2 characters."
echo -e "#### See ./libgen_dl/log after running. Manually inspect temp files under ./libgen_dl if needed."
echo -e "#### Optionally comment last line to use uget or any other dl manager to download link list (./libgen_dl/file_link_list.txt)"
echo -e "#### Alternativelly, use 'libgen_dl --retry' to download links stored in 'libgen_dl/file_download_failures'"
echo -e "###########################################################\n\n"

[[ "$#" != 1 || "${#1}" -lt 3 ]] && { echo "Invalid arguments. See 'Usage'."; exit 1; }

[[ "$1" == "--retry" ]] && { 
    echo "Retrying $(grep -c "https" libgen_dl/file_download_failures) failed downloads";
    echo "$(date +"%Y-%m-%d %T" ) Retrying $(grep -c "https" libgen_dl/file_download_failures) failed downloads"  >> "libgen_dl/log";
    aria2c --console-log-level info -j3 --max-tries 20 --retry-wait 5 -i ./libgen_dl/file_download_failures --log-level notice -l ./libgen_dl/file_download_log --save-session "libgen_dl/file_download_failures" --save-session-interval 2 --allow-overwrite true --remove-control-file --content-disposition-default-utf8; 
    rem="$(grep -c "https" libgen_dl/file_download_failures)"
    echo "Remaining failed downloads: $rem";
    echo "$(date +"%Y-%m-%d %T" ) Remaining failed downloads: $rem"  >> "libgen_dl/log";
    [[ "$rem" == "0" ]] && echo "$(date +"%Y-%m-%d %T" ) ======================================== END" >> "libgen_dl/log"
    exit 0; 
}

mkSearchLink () {
    echo "https://libgen.rs/search.php?res=100&req=$(echo "$1" | sed 's/\ /%20/g')&phrase=0&view=simple&column=def&sort=def&sortmode=ASC&page=$2"
    }

######### 0. Create directories, log stuff
mkdir "libgen_dl" || { echo -e "\nRemove the existing './libgen_dl' directory before using this program in a preferably empty directory."; exit; }
mkdir -p "libgen_dl/get"
mkdir -p "libgen_dl/pages"
echo "$(date +"%Y-%m-%d %T" ) ======================================== START " >> "libgen_dl/log"
echo "$(date +"%Y-%m-%d %T" ) Search keywords: $1" >> "libgen_dl/log"
echo "$(date +"%Y-%m-%d %T" ) First search page link: $(mkSearchLink "$1" 1)" >> "libgen_dl/log"

######## 1. Download all "search" pages.
aria2c --console-log-level warn -d "libgen_dl/pages" "$(mkSearchLink "$1" 1)" 
page_count="$(grep -m 1 "[0-9]*, // общее число страниц" libgen_dl/pages/search.php | grep -o "[0-9]*")"
page_count=${page_count:-1}
echo "$(date +"%Y-%m-%d %T" ) Number of search pages (100 items per page): $page_count" >> "libgen_dl/log"
for i in $(seq 2 "$page_count"); do
    aria2c --console-log-level warn -d "./libgen_dl/pages" "$(mkSearchLink "$1" "$i")"
done

######## 2. For each "search" page, collect every individual "get" link into `libgen_dl/get_page_link_list.txt`.
for page_file in ./libgen_dl/pages/*; do 
    link="$(grep -o "http://libgen.li/ads.php?md5=[A-Z0-9]*" $page_file)"
    echo "$link" >> "libgen_dl/get_page_link_list.txt"
done
echo "$(date +"%Y-%m-%d %T" ) Total number of crawled 'get' page links: $(cat libgen_dl/get_page_link_list.txt | wc -l)" >> "libgen_dl/log"

######## 3. Download every "get" page and store it under `libgen_dl/get/`. 
aria2c --console-log-level warn -j3 -d "libgen_dl/get" -i ./libgen_dl/get_page_link_list.txt -l ./libgen_dl/get_page_log

######## 4. For each individual "get" page collect the direct (document) link/s into `libgen_dl/file_link_list.txt`. Collect metadata.
for file in ./libgen_dl/get/*; do 
    pseudolink="$(grep -o "booksdl.org\\\get.php?md5=[a-z0-9]*&key=[A-Z0-9]*" $file | sed 's/\\/\//')"
    [[ "$pseudolink" == "" ]] || echo "https://cdn3.$pseudolink	https://cdn2.$pseudolink" >> "libgen_dl/file_link_list.txt"
    echo -e "$(grep '\@book{book:(.*\n)*.*}}' -Pzo $file | sed 's/\r//')" >> "libgen_dl/metadata.bib"
done
echo "$(date +"%Y-%m-%d %T" ) Total number of direct (document) links: $(cat libgen_dl/file_link_list.txt | wc -l)" >> "libgen_dl/log"

######## 5. Download files. Comment this block if you only want to collect links (For example to use another dl manager such as uget)
aria2c --console-log-level info -j3 --max-tries 20 --retry-wait 5 -i ./libgen_dl/file_link_list.txt --log-level notice -l ./libgen_dl/file_download_log --save-session "libgen_dl/file_download_failures" --save-session-interval 2  --allow-overwrite true --content-disposition-default-utf8
fails="$(grep -c "https" ./libgen_dl/file_download_failures)"
[[ $fails -gt 0 ]] && { 
    msg="$fails failed downloads. Check 'libgen_dl/file_download_failures' and/or retry with 'libgen_dl --retry'.";
    echo -e "\033[31mERROR: $msg";
    echo "$(date +"%Y-%m-%d %T" ) $msg" >> "libgen_dl/log";
    exit 1; 
}

######## 6. Bye.
echo "$(date +"%Y-%m-%d %T" ) ======================================== END" >> "libgen_dl/log"

