## Description
Batch download files from libgen.

## Notes
- Changes on library genesis often cause libgen_dl to fail. If this happens please open an issue and I'll try to fix it.

## Current status (Sat Feb 17 20:02:35 2024 UTC)
libgen.lol certificates expired, for this reason aria2c has to be called with `--disable-ipv6 --check-certificate=false`.

## Dependecies

- aria2c (provided by [aria2](https://github.com/aria2/aria2))

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
