# SPDX-License-Identifier: MIT

# makefile.include.gnu -- GNU Fortran compiler (gfortran)
#
# Note: Please ensure libgfortran-static and glibc-static are installed on
# your host system, or it gives error.
#
# Math library auto-detection order: MKL (via MKLROOT) > OpenBLAS (via OPENBLAS_ROOT) > error.
# Override with:
#   make MATH=mkl      -j$(nproc)   # force MKL  (MKLROOT must be set)
#   make MATH=openblas  -j$(nproc)   # force OpenBLAS  (OPENBLAS_ROOT must be set)

# Compilers
FC = gfortran
CC = gcc

# SIMD instruction set optimization
# Usage: make ARCH=generic (default) or make ARCH=native
ARCH ?= generic

ifeq ($(ARCH),generic)
  SIMD = -msse3
  ifeq ($(MAKELEVEL),0)
    $(info -- Using generic SSE3 instructions (high compatibility))
  endif
else ifeq ($(ARCH),native)
  SIMD = -march=native
  ifeq ($(MAKELEVEL),0)
    $(info -- Using native instructions (optimized for current CPU))
  endif
else
  $(error Unknown ARCH=$(ARCH). Supported values: generic, native)
endif

# Include search paths (Makefile will append LIBRETAPATH)
INCLUDE = -I./ -I./ext

# Math library auto-detection (skipped for clean targets)
_CLEAN_TARGETS = clean cleanmultiwfn cleanlibreta
ifneq ($(filter-out $(_CLEAN_TARGETS),$(MAKECMDGOALS)),)
  _NEED_MATH = yes
else ifeq ($(MAKECMDGOALS),)
  _NEED_MATH = yes
endif

ifeq ($(_NEED_MATH),yes)

# Probe the system: does MKLROOT point to a real MKL installation?
# Is OpenBLAS visible to the linker?
_MKLROOT_OK  = $(if $(MKLROOT),$(shell [ -d "$(MKLROOT)/lib/intel64" ] && echo yes))
_OPENBLAS_DIR_OK = $(if $(OPENBLAS_ROOT),$(shell [ -d "$(OPENBLAS_ROOT)" ] && echo yes))
_OPENBLAS_STATIC_FILE = $(if $(OPENBLAS_ROOT),$(shell [ -f "$(OPENBLAS_ROOT)/lib/libopenblas.a" ] && echo yes))

# If the user did not say MATH=... on the command line, auto-detect.
ifeq ($(origin MATH),undefined)
  ifneq ($(_MKLROOT_OK),)
    MATH = mkl
    $(info -- Auto-detected Intel MKL at $(MKLROOT))
  else ifneq ($(_OPENBLAS_STATIC_FILE),)
    MATH = openblas
    _OPENBLAS_OK = yes
    $(info -- Auto-detected OpenBLAS at $(OPENBLAS_ROOT))
  else ifneq ($(_OPENBLAS_DIR_OK),)
    $(error MKL is not found, and OpenBLAS is found but there's not a static library)
  else
    $(error No math library found. Please ensure MKLROOT (recommended) or OPENBLAS_ROOT is set)
  endif
endif

# Export MATH so recursive sub-makes inherit it without re-probing.
export MATH

ifeq ($(MATH),mkl)
  # Validate MKLROOT when the user explicitly requested MKL
  ifeq ($(_MKLROOT_OK),)
    $(error MATH=mkl was requested but MKLROOT is not set or \
      $(MKLROOT)/lib/intel64 does not exist. \
      Please set MKLROOT to your MKL installation path, e.g. \
      export MKLROOT=/opt/intel/oneapi/mkl/latest)
  endif
  # MKL static link line for gfortran + GNU OpenMP (LP64, 64-bit OS)
  MKL_LIB   = $(MKLROOT)/lib/intel64
  MKL_INC   = $(MKLROOT)/include
  INCLUDE  += -I$(MKL_INC)
  MATH_LINK = -Wl,--start-group \
              $(MKL_LIB)/libmkl_gf_lp64.a \
              $(MKL_LIB)/libmkl_gnu_thread.a \
              $(MKL_LIB)/libmkl_core.a \
              -Wl,--end-group
  # MKL static linking requires -lpthread and -ldl (per Intel's link advisor).
  # On glibc >= 2.34 these are absorbed into libc, but listing them is harmless.
  MATH_EXTRA = -lm -lpthread -ldl
  MKL_DEF    = -DINTEL_MKL
else ifeq ($(MATH),openblas)
  # OpenBLAS provides both BLAS and LAPACK.
  MATH_LINK  = -L$(OPENBLAS_ROOT)/lib -l:libopenblas.a
  MATH_EXTRA = -lm
  MKL_DEF    =
else
  $(error Unknown MATH=$(MATH). Supported values: mkl, openblas)
endif

endif # _NEED_MATH

# Compilation flags
#   -cpp                      : enable C preprocessor (#if directives)
#   -ffree-line-length-none   : many source lines exceed the 132-char limit
#   -fopenmp                  : OpenMP parallelism
#   -fallow-argument-mismatch : needed for KROUT and other legacy routines
COMMON = -cpp -ffree-line-length-none -fopenmp \
         -fallow-argument-mismatch \
         -fbacktrace \
         -ffpe-summary=none \
         $(SIMD) $(INCLUDE) $(MKL_DEF)

# Build type: Release, Debug
TYPE ?= Release
ifeq ($(TYPE),Release)
  OPT  = -O2 $(COMMON)
  OPT1 = -O1 $(COMMON)
  ifeq ($(MAKELEVEL),0)
    $(info -- Build type: Release)
  endif
else ifeq ($(TYPE),Debug)
  OPT  = -O0 -g -fcheck=all -Wall -Wextra $(COMMON)
  OPT1 = $(OPT)
  ifeq ($(MAKELEVEL),0)
    $(info -- Build type: Debug)
  endif
else
  $(error Unknown TYPE=$(TYPE). Supported values: Release, Debug)
endif

# Extra flags for .F fixed-form files (DFTxclib.F, Lebedev-Laikov.F, sym.F)
#   -std=legacy : accept Fortran 77 syntax without errors
#   -w          : silence the flood of warnings from old-style code
FFLAGS_FIXED = -std=legacy -w

# Warning suppression for third-party code (libreta, dislin stubs, etc.)
FFLAGS_NOWARN       = -w
FFLAGS_DISLIN_EMPTY = -w

# Extra flags for xlib.f90 (gfortran needs nothing special here)
FFLAGS_XLIB =

# blockhrr_012345.f90 is a 3.5 MB file; compile at -O1 to save time/memory
ifeq ($(TYPE),Release)
  BLOCKHRR_OPT = -O1 -w $(SIMD) -fbacktrace -ffree-line-length-none -fno-var-tracking -ffpe-summary=none $(INCLUDE)
else ifeq ($(TYPE),Debug)
  BLOCKHRR_OPT = -O0 -g1 -w $(SIMD) -fbacktrace -ffree-line-length-none -fno-var-tracking -ffpe-summary=none $(INCLUDE)
endif

# Link flags -- full static build
#   -static              : link everything statically
#   -static-libgfortran  : statically link the gfortran runtime
#   -static-libgcc       : statically link libgcc
# LDFLAGS = $(OPT) -static -static-libgfortran -static-libgcc

# Alternative: if static X11/GL/Motif libs are missing, use selective static
# linking (only math libs and Fortran runtime are static, X11/GL stay dynamic):
LDFLAGS = $(OPT) -static-libgfortran -static-libgcc

# Libraries
# LIB_base  = $(MATH_LINK) $(MATH_EXTRA)
LIB_base  = -Wl,-Bstatic $(MATH_LINK) -Wl,-Bdynamic $(MATH_EXTRA)
LIB_GUI   = $(LIB_base) ./dislin_d-11.0.a -lXm -lXt -lX11 -lGL
LIB_noGUI = $(LIB_base)
