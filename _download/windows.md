Stefan Weil provides binaries and installers for
both [32-bit](https://qemu.weilnetz.de/w32/) and
[64-bit](https://qemu.weilnetz.de/w64/) Windows.

**MSYS2:**

QEMU can be installed using [MSYS2](https://www.msys2.org/) also. MSYS2 uses
[pacman](https://wiki.archlinux.org/title/Pacman) to manage packages. First,
follow the [MSYS2](https://www.msys2.org/) installation procedure. Then update
the packages with `pacman -Syu` command. Now choose the proper command for your
system as following:

* For 64 bit Windows 7 or above (in MINGW64):

```
pacman -S mingw-w64-x86_64-qemu
```

* For 64 bit Windows 8.1 or above (in UCRT64):

```
pacman -S mingw-w64-ucrt-x86_64-qemu
```

32 bit Windows is not supported.

Some QEMU related tools can be found in separate packages. Please see the
MSYS2 [mingw-w64-qemu](https://packages.msys2.org/base/mingw-w64-qemu) page
for more information. Any QEMU package related issues can be found in
[MINGW-packages](https://github.com/msys2/MINGW-packages/issues?q=is%3Aissue+is%3Aopen+qemu)
repository.
