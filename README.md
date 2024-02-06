## Description
Batch download files from libgen.

**NOTE:** Changes on libgen often cause libgen_dl to fail. If this happens please open an issue and I'll try to fix it.

## Dependecies

- [pup](https://github.com/ericchiang/pup)
- [aria2](https://github.com/aria2/aria2)

## Usage

``` bash
mkdir "hello"
cd hello
libgen_dl.sh "hello world"
```

Use `libgen_dl.sh --retry` to retry downloading previously failed items. After finishing running with `--retry`, libgen_dl will report the number of remaining failed downloads. Re-run if necessary (I'll probably add a loop).

## Alternatives
- libgen-cli
- libgen-downloader
- Many (mostly python?) others on gh.
