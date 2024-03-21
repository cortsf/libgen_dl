#!/usr/bin/env bash

[[ "$#" != 1 || "${#1}" -lt 3 ]] && { echo "Invalid arguments. Call with '--help' to see usage instructions."; exit 1; }

case "$1" in
    "--help")
	echo -e "#### Dependencies: aria2c"
	echo -e "#### Usage: 'mkdir <blah> && cd <blah> && libgen_dl.sh <keywords>' with length of <keywords> > 2 characters."
	echo -e "#### After finishing, libgen_dl will inform you of all failed downloads, if any. If necessary you can use 'libgen_dl --retry' to re-attempt failed links collected in 'libgen_dl/file_download_failures'"
	echo -e "#### You can call 'libgen_dl.sh --log'. After running and manually inspect temp files under ./libgen_dl if needed."
	echo -e "#### Optionally comment block #5 in this script to use uget or any other dl manager to download any of the link lists (./libgen_dl/link_lists/)"
	exit 0
	;;
    "--log")
	cat libgen_dl/libgen_dl.log && exit 0 || exit 1
	;;
    "--first")
	echo "First search page link:"
	grep -o 'https://.*' ./libgen_dl/libgen_dl.log && exit 0 || exit 1
	;;
    "--show-remaining-links")
	it=0
	grep '^https://.*$' ./libgen_dl/file_download_failures | while read line; do 
	    hash_lower="$(echo "$line" | grep -Po "https://cdn[23]\.booksdl\.org/get\.php\?md5=\K([^&])*|https://download\.library\.lol/main/[0-9]*/\K([^/])*" | head -1)"
	    hash="$(echo "$hash_lower" | tr '[:lower:]' '[:upper:]')"
	    # FIX: [^@] works here but it's not safe. metadata="$(cat ./libgen_dl/metadata.bib | grep -Pzo "\@book{book:([^@])*   url =       {libgen\.li/file\.php\?md5=$hash_lower}}")"
	    echo -e "$it: $hash\n    libgen_lol: http://library.lol/main/$hash\n    libgen.li: http://libgen.li/ads.php?md5=$hash\n    libgen.is: http://libgen.is/book/index.php?md5=$hash\n    libgen.rs: http://libgen.rs/book/index.php?md5=$hash\n"
	    it=$(($it+1))
	done
	exit 0
	;;
    "--show-remaining-hashes")
	it=0
	while read hash_upper; do 
            hash="$(echo "$hash_upper" | tr '[:upper:]' '[:lower:]')"
            grep -q "$hash" ./libgen_dl/link_lists/combined.txt || {
		echo -e "$it: $hash\n    libgen_lol: http://library.lol/main/$hash\n    libgen.li: http://libgen.li/ads.php?md5=$hash\n    libgen.is: http://libgen.is/book/index.php?md5=$hash\n    libgen.rs: http://libgen.rs/book/index.php?md5=$hash\n";
		it=$(($it+1));
	    }
	done < <(cat ./libgen_dl/md5_list.txt)
	echo -e "Number of hashes for which there is no direct (file/document) link: $it"
	exit 0
	;;
    "--count-remaining")
	echo "Number of remaining (or failed) downloads:"
	grep -c "^https.*$" ./libgen_dl/file_download_failures && exit 0 || exit 1
	;;
    "--retry")
	[ -f ./libgen_dl/file_download_failures ]  || { echo "Can't find 'libgen_dl/file_download_failures'"; exit 1; }
	echo "Retrying $(grep -c "https" libgen_dl/file_download_failures) failed downloads"
	echo "$(date +"%Y-%m-%d %T" ) Retrying $(grep -c "https" libgen_dl/file_download_failures) failed downloads"  >> "libgen_dl/libgen_dl.log"
	aria2c --disable-ipv6 --check-certificate=false --console-log-level warn -j3 --max-tries 20 --retry-wait 5 -i ./libgen_dl/file_download_failures --log-level notice -l ./libgen_dl/file_download.log --save-session "libgen_dl/file_download_failures" --save-session-interval 2 --allow-overwrite true --remove-control-file --content-disposition-default-utf8
	rem="$(grep -c "https" libgen_dl/file_download_failures)"
	echo -e "\033[31mRemaining (failed) downloads: $rem. Call again with --retry or --show-remaining-links"
	echo "$(date +"%Y-%m-%d %T" ) Remaining (failed) downloads: $rem"  >> "libgen_dl/libgen_dl.log"
	[[ "$rem" == "0" ]] && echo "$(date +"%Y-%m-%d %T" ) ======================================== END" >> "libgen_dl/libgen_dl.log"
	exit 0 
	;;
esac

mkSearchLink () {
    echo "https://libgen.rs/search.php?res=100&req=$(echo "$1" | sed 's/\ /%20/g')&phrase=0&view=simple&column=def&sort=def&sortmode=ASC&page=$2"
    }

######### 0. Create directories, log stuff
mkdir "libgen_dl" || { echo -e "\nRemove the existing './libgen_dl' directory before using this program in a preferably empty directory."; exit; }
mkdir -p "libgen_dl/get_li"
mkdir -p "libgen_dl/get_lol"
mkdir -p "libgen_dl/search_pages"
mkdir -p "libgen_dl/link_lists"
echo "$(date +"%Y-%m-%d %T" ) ======================================== START " >> "libgen_dl/libgen_dl.log"
echo "$(date +"%Y-%m-%d %T" ) Search keywords: $1" >> "libgen_dl/libgen_dl.log"
echo "$(date +"%Y-%m-%d %T" ) First search page link: $(mkSearchLink "$1" 1)" >> "libgen_dl/libgen_dl.log"

######## 1. Download all "search" pages.
aria2c --console-log-level warn --max-tries 3 --retry-wait 3 -d "libgen_dl/search_pages" "$(mkSearchLink "$1" 1)" 
page_count="$(grep -m 1 "[0-9]*, // общее число страниц" libgen_dl/search_pages/search.php | grep -o "[0-9]*")"
page_count=${page_count:-1}
echo "$(date +"%Y-%m-%d %T" ) Number of search pages (100 max items per page): $page_count" >> "libgen_dl/libgen_dl.log"
for i in $(seq 2 "$page_count"); do
    aria2c --console-log-level warn --max-tries 3 --retry-wait 3 -d "./libgen_dl/search_pages" "$(mkSearchLink "$1" "$i")"
done

######## 2. For each "search" page, collect every individual "get" link into `libgen_dl/get_page_link_list.txt`.
for search_page in ./libgen_dl/search_pages/*; do 
    echo "$(grep -o "http://library.lol/main/[A-Z0-9]*" $search_page)" >> "libgen_dl/get_page_link_list_lol.txt"
done
echo "$(cat libgen_dl/get_page_link_list_lol.txt | sed 's/http:\/\/library.lol\/main\///')" >> "libgen_dl/md5_list.txt"
echo "$(cat libgen_dl/md5_list.txt | sed 's/^/http:\/\/libgen.li\/ads.php\?md5=/')" >> "libgen_dl/get_page_link_list_li.txt"
echo "$(date +"%Y-%m-%d %T" ) Total number of detected items: $(cat libgen_dl/md5_list.txt | wc -l)" >> "libgen_dl/libgen_dl.log"

# ######## 3. Download every "get" page. 
aria2c --console-log-level warn -j3 --max-tries 3 --retry-wait 3 -d "libgen_dl/get_lol" -i ./libgen_dl/get_page_link_list_lol.txt -l ./libgen_dl/get_page_lol.log
echo "$(date +"%Y-%m-%d %T" ) Total number of 'get' pages (libgen.lol): $(ls -1 ./libgen_dl/get_lol/* | wc -l)" >> "libgen_dl/libgen_dl.log"
aria2c --console-log-level warn -j3 --max-tries 3 --retry-wait 3 -d "libgen_dl/get_li" -i ./libgen_dl/get_page_link_list_li.txt -l ./libgen_dl/get_page_li.log
echo "$(date +"%Y-%m-%d %T" ) Total number of 'get' pages (libgen.li): $(ls -1 ./libgen_dl/get_li/* | wc -l)" >> "libgen_dl/libgen_dl.log"


########## 4. For each individual "get" page collect the direct (document) link/s into `libgen_dl/file_link_list.txt`. Collect metadata.
cat ./libgen_dl/md5_list.txt | while read hash; do 
    hash_downcase="$(echo $hash | tr '[:upper:]' '[:lower:]')"
    [ -f "./libgen_dl/get_lol/$hash" ] && { echo "$(grep -o "https://download.library.lol/main/[0-9]*/$hash_downcase/[^\"]*" "./libgen_dl/get_lol/$hash" )" >> "libgen_dl/link_lists/libgen_lol.txt"; } || { echo "" >> "libgen_dl/link_lists/libgen_lol.txt"; }
    file_li="$(grep -Rl "$hash" ./libgen_dl/get_li)"
    [ -z "$file_li" ] || {
	link_libgen_li_chunk="$(grep -o "$hash_downcase&key=[A-Z0-9]*" "$file_li")"
	link_libgen_li_cdn2="https://cdn2.booksdl.org/get.php?md5=$link_libgen_li_chunk"
	link_libgen_li_cdn3="https://cdn3.booksdl.org/get.php?md5=$link_libgen_li_chunk"
	echo "$link_libgen_li_cdn2" >> "libgen_dl/link_lists/libgen_li_cdn2.txt";
	echo "$link_libgen_li_cdn3" >> "libgen_dl/link_lists/libgen_li_cdn3.txt";
	echo -e "$(grep '\@book{book:(.*\n)*.*}}' -Pzo $file_li | sed 's/\r//')" >> "libgen_dl/metadata.bib"
    }
done
echo "$(paste libgen_dl/link_lists/*)" >> libgen_dl/link_lists/combined.txt

######## 5. Download files. Comment this block if you only want to collect links (For example to use another dl manager such as uget)
aria2c --disable-ipv6 --check-certificate=false --console-log-level warn -j3 --max-tries 20 --retry-wait 5 -i ./libgen_dl/link_lists/combined.txt --log-level notice -l ./libgen_dl/file_download.log --save-session "libgen_dl/file_download_failures" --save-session-interval 2  --allow-overwrite true --content-disposition-default-utf8
fails="$(grep -c "^https.*$" ./libgen_dl/file_download_failures)"
[[ $fails -gt 0 ]] && { 
    msg="$fails failed downloads. Check 'libgen_dl/file_download_failures' and/or retry with 'libgen_dl --retry'.";
    echo -e "\033[31mERROR: $msg";
    echo "$(date +"%Y-%m-%d %T" ) $msg" >> "libgen_dl/libgen_dl.log";
    exit 1; 
}

######## 6. Bye.
echo "$(date +"%Y-%m-%d %T" ) ======================================== END" >> "libgen_dl/libgen_dl.log"

