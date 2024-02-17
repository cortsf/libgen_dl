## Description
Batch download files from libgen.

**NOTE:** Changes on libgen often cause libgen_dl to fail. If this happens please open an issue and I'll try to fix it.

## Current status (Sat Feb 17 20:02:35 2024 UTC)
libgen.li has been down for a while and libgen.lol cetificates expired. Until this gets fixed, I recommend using this script to generate (libgen.lol) link lists only, which can be downloaded with uget despite the certificate issue (can't find a solution for aria2 yet). Call this script as usual, then open `.libgen_dl/link_lists/libgen_lol.txt` with uget batch download function.

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
