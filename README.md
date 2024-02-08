## Description
Batch download files from libgen.

**NOTE:** Changes on libgen often cause libgen_dl to fail. If this happens please open an issue and I'll try to fix it.

## Dependecies

- [aria2](https://github.com/aria2/aria2)

## Usage

``` bash
mkdir "hello"
cd hello
libgen_dl.sh "hello world"
```

libgen_dl.sh downloads files by calling aria2c with `--max-tries 20`, it also collects all failed links (after 20 tries) in `./libgen_dl/file_download_failures`. You can use `libgen_dl.sh --retry` to re-try downloading these failed items. After finishing downloading with `--retry`, libgen_dl will update `./libgen_dl/file_download_failures` and report the number of remaining failed downloads. You can re-run with `--retry` multiple times if necessary. This is to avoid using `--max-tries 0` which could cause ligen_dl to run indefinitely.

## Alternatives
- libgen-cli
- libgen-downloader
- Many (mostly python?) others on gh.

## Derivation
Be sure to set the latest rev and sha256.

``` nix
{ lib, stdenv, fetchFromGitHub, pkg-config, aria2}:

stdenv.mkDerivation rec {
  pname = "libgen_dl";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "cortsf";
    repo = "libgen_dl";
    rev = "<rev>";
    sha256 = "<sha256>";
  };

  strictDeps = true;
  nativeBuildInputs = [  ];
  buildInputs = [  ];

  installPhase = ''
    mkdir -p $out/bin
    cp libgen_dl.sh $out/bin
    chmod 755 $out/bin/libgen_dl.sh
  '';

  meta = with lib; {
    homepage = "https://github.com/cortsf/libgen_dl";
    description = "Batch download files from libgen";
    mainProgram = "libgen_dl.sh";
    license = licenses.unlicense;
    platforms = platforms.unix;
    maintainers = with maintainers; [ cortsf ];
  };
}
```

## Troubleshoot


###  Wrong filenames with .php extension
Use this script to attempt fixing filenames with php extension (usually following the pattern: `get.php`, `get.1.php`, `get.2.php`, ..). This seems to be caused by libgen.li, I had the same problem with multiple dl managers. [#1](/../../issues/1) is meant to fix this by seting names based of bibtex titles crawled from libgen webpages. 

This script only needs [exiftool](https://exiftool.org/) to set extensions and names. It fails to get titles in some cases where the following script (using ebook-meta) succeeds.

``` bash
echo "Set extensions (exiftool only):"
for file in *.php 
do
    exifExt=$(exiftool -FileTypeExtension "$file" -S | sed 's/.*: //')
    exifName=$(exiftool -BookName "$file" -S | sed 's/.*: //')
    if [ "$exifExt" == "zip" ]; then # Assumption
	ext="epub";
    else
	ext="$exifExt"
    fi
    if [[ "$exifName" != "" ]]; then 
	newName="$exifName.$ext"
    else
	newName="$(basename "$file" .php).$ext"
    fi
    echo "    $file	-> $newName"
    mv "$file" "$newName"
done
```


This script also needs Calibre's `ebook-meta` to read titles from the document metada. If no metadata is available it will only set the extension.
``` bash
#!/usr/bin/env bash
# This script needs exiftool and calibre's ebook-meta to work.

filesWithExt=()

echo "Set extensions:"
for file in *.php 
do
    exifExt=$(exiftool -FileTypeExtension "$file" -S | sed 's/.*: //')
    if [ "$exifExt" == "zip" ]; then
	ext="epub";
    else
	ext="$exifExt"
    fi
    newName="$(basename "$file" .php).$ext"

    echo "    $file	-> $newName"
    mv "$file" "$newName"
    filesWithExt+=("$newName")
done

echo -e "\nSet names:"
for file in ${filesWithExt[@]}
do
    title="$(ebook-meta "$file" | awk -F "^Title +: " 'NF > 1 {print $2}')"
    if [[ "./$title" == "${file%.*}" || "$title" == "" ]]; then
	newName="$file" 
    else
	newName="$title.${file##*.}"
    fi 
    echo "    $file	-> $newName"
    mv "$file" "$newName"
done
```
