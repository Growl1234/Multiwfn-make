# Multiwfn-make

Self-made Makefile and makefile.include.* for [Multiwfn](http://sobereva.com/multiwfn/) which enable compiling on Linux with GNU or Intel Fortran compilers.

This repository will be kept up to date with new Multiwfn releases. It is currently compatible with version 2026.3.11.

## How to Use

1. Copy `Makefile` and `config` directory to the path of Multiwfn source code.
2. Run `make -jN` directly.

For extra options available, run `make help` to see details.

## Notes

1. The Makefile will auto-detect the compiler in your system environment. If you have Intel Fortran compiler, it will be used; if you use an old version of oneAPI with both ifx and ifort, then ifort will be used. If Intel Fortran compilers are not detected, then gfortran will be used. You can also force the compiler by adding `COMPILER=gnu` or `COMPILER=intel`. Note that the C compiler is always GCC (as in the original Makefile which uses gcc as C compiler and ifort as Fortran compiler).
2. To ensure a static build without errors when using gfortran, please ensure `libgfortran-static` and `glibc-static` are installed via `dnf` (assuming you're using RHEL/CentOS Stream/Rocky Linux).
3. Ensure that you have installed `motif-devel`, because `libXm.a` in this package is necessary in compilation of Multiwfn. The two packages, `mesa-libGL-devel` and `mesa-libGLU-devel`, are also needed.
4. If you are using GNU Fortran compiler, the Makefile is supported to use Intel MKL or OpenBLAS **(it's strongly recommended to use MKL because OpenBLAS is currently not tested by me)**. You must manually set `MKLROOT` or `OPENBLAS_ROOT` before running `make`, and if both exist then MKL will be used by default. You can also force the math libraries by adding `MATH=mkl` or `MATH=openblas`.
5. By default, the build uses `ARCH=generic`, which targets the SSE3 instruction set (as in the original Makefile) to maintain binary compatibility and portability. If you would like to compile with the maximum instruction set supported by your local CPU, you can use `ARCH=native`.
6. Multiwfn can be built in either Release or Debug mode, both of which correspond to compilation options already present in the original Makefile. In practice, the Debug mode is mainly useful only for development and debugging purposes (e.g., by the developer, Tian Lu). In this Makefile system, you can specify the desired build type using `TYPE=Releas`e or `TYPE=Debug`.

## 中文说明

这里是我自己尝试性为[Multiwfn](http://sobereva.com/multiwfn/)程序做的一个Makefile系统，包含主Makefile和arch目录下的两个makefile.include，分别使用gfortran和ifort/ifx编译器。这一尝试旨在使得Multiwfn能够顺利利用gfortran进行编译。如果你想尝试利用这里的Makefile自行编译Multiwfn，直接将Makefile和config目录复制到源代码目录下，然后运行`make -jN`即可。具体可用选项可以通过`make help`看到。

关于`make`的具体使用，有以下几点：
1. Makefile默认自动检测编译器，规则如下：如果存在Intel Fortran编译器，优先使用Intel的；如果同时存在ifort和ifx（较老版本的oneAPI），优先使用ifort；如果不存在Intel编译器，则使用gfortran。你也可以通过在`make`命令后添加`COMPILER=gnu`或`COMPILER=intel`强行指定你想要的编译器。请注意，由于原本开发者提供的的Makefile使用GCC作C编译器、ifort作Fortran编译器，因此`makefile.include.intel`中仍然使用了gcc（本人不喜欢Intel编译器，因此也没有对icx/icc的情况做任何测试）。
2. 使用gfortran编译时，请确保`libgfortran-static`和`glibc-static`已经通过`dnf`安装（假设你使用RHEL/CentOS Stream/Rocky Linux系统）。
3. 编译前，确保安装了`motif-devel`，`mesa-libGL-devel`和`mesa-libGLU-devel`，因为它们包含了编译Multiwfn所必需的一些库（例如`linXm.a`）。
4. 在使用gfortran时，`makefile.include.gnu`中可以选用MKL和OpenBLAS两种数学库； **但鉴于OpenBLAS数学库未经测试（以后会测试；但根据这一[mac-build仓库](https://github.com/digital-chemistry-laboratory/multiwfn-mac-build)，OpenBLAS应该可以用于Multiwfn），目前我强烈推荐总是使用MKL。** 注意，你必须手动指定`MKLROOT`或`OPENBLAS_ROOT`才能让Makefile检测到相应数学库。你也可以通过添加`MATH=mkl`或`MATH=openblas`强行指定你想要的数学库。
5. 默认编译使用`ARCH=generic`，即使用SSE3指令集（与原始Makefile一致），以保持二进制文件的兼容性和可移植性。想要利用本地CPU支持的最大指令集进行编译，你可以加`ARCH=native`。
6. Multiwfn可以分为Release和Debug两种编译模式，这两种对应的编译选项在原始Makefile中都有；通常Debug模式仅在开发人员（卢天）调试时才有意义。在这里的Makefile系统中，你可以使用`TYPE=Release`或`TYPE=Debug`来指定想编译哪种类型的Multiwfn。
