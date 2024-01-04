# build-zeek

Build [Zeek](https://zeek.org/) for packaging with
[Brimcap](https://github.com/brimdata/brimcap) and
[Zui](https://zui.brimdata.io/).

## Background

Before there was official support for compiling Zeek on Windows, developers
at Brim Data created a [working port](https://github.com/brimdata/zeek) and an
[artifact based on Zeek v3.2.1](https://github.com/brimdata/zeek/releases/tag/v3.2.1-brim10).
Because the effort of keeping the port in sync with ongoing Zeek development
would have been prohibitive, that artifact shipped with Brimcap and Zui for
years.

In late 2022, work began to officially support
[Zeek on Windows](https://zeek.org/2022/11/28/zeek-on-windows/),
and in late 2023 this repo was created to take advantage of that. The minimal
glue found here starts from the official Zeek source code and makes only the
changes necessary to build in GitHub Actions, add some needed
[Zeek Packages](https://packages.zeek.org/), and produce artifacts ready for
use in Brimcap/Zui.
