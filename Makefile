# Makefile for Multiwfn (http://sobereva.com/multiwfn/)
#
# Usage:
#   make -j24                 (Auto-detect compiler, generic SIMD)
#   make TYPE=native -j24     (Optimized for current CPU)
#   make V=1                  (Show full commands)
#   make COMPILER=intel       (Force Intel compiler)

# ==============================================================
# 1. Compiler Auto-Detection
# ==============================================================
_EXTRA_TARGETS = clean cleanmultiwfn cleanlibreta help
_IS_EXTRA =
ifneq ($(MAKECMDGOALS),)
  ifeq ($(filter-out $(_EXTRA_TARGETS),$(MAKECMDGOALS)),)
    _IS_EXTRA = yes
  endif
endif

ifeq ($(_IS_EXTRA),yes)
  COMPILER = skip_for_clean
else
  _HAS_IFORT := $(shell command -v ifort 2>/dev/null)
  _HAS_IFX   := $(shell command -v ifx 2>/dev/null)
  ifneq ($(_HAS_IFORT),)
    _AUTO_COMPILER := intel
  else ifneq ($(_HAS_IFX),)
    _AUTO_COMPILER := intel
  else
    _AUTO_COMPILER := gnu
  endif

  COMPILER ?= $(_AUTO_COMPILER)

  ifeq ($(COMPILER),intel)
    ifeq ($(MAKELEVEL),0)
      $(info [COMPILER] Using Intel Fortran compiler)
    endif
    include arch/makefile.include.intel
  else ifeq ($(COMPILER),gnu)
    ifeq ($(MAKELEVEL),0)
      $(info [COMPILER] Using GNU Fortran compiler)
    endif
    include arch/makefile.include.gnu
  else
    $(error Unknown COMPILER=$(COMPILER). Use 'gnu' or 'intel')
  endif
endif

.DEFAULT_GOAL := default
OBJDIR = obj
EXEDIR = exe

# ==============================================================
# 2. Flag Adjustments & Verbosity
# ==============================================================
# Force MODFLAG based on the actual FC set by include files
ifeq ($(findstring gfortran,$(FC)),gfortran)
  MODFLAG = -J$(OBJDIR)
else
  MODFLAG = -module $(OBJDIR)
endif

# Support both V=1 and VERBOSE=1
ifneq ($(filter 1,$(V) $(VERBOSE)),)
  _v =
else
  _v = @
endif

# Paths & Flags
LIBRETAPATH = libreta_hybrid
INCLUDE    += -I$(LIBRETAPATH) -I$(OBJDIR)
OPT        += $(MODFLAG)
OPT1       += $(MODFLAG)
BLOCKHRR_OPT += $(MODFLAG)

# Executables
EXE       = $(EXEDIR)/Multiwfn
EXE_noGUI = $(EXEDIR)/Multiwfn_noGUI

# ==============================================================
# 3. Objects & Progress Logic
# ==============================================================
objects_list = define.o util.o plot.o Bspline.o sym.o libreta.o function.o GUI.o \
          sub.o integral.o Lebedev-Laikov.o DFTxclib.o edflib.o fparser.o \
          fileIO.o spectrum.o DOS.o Multiwfn.o 0123dim.o LSB.o population.o \
          frj.o orbcomp.o bondorder.o topology.o excittrans.o otherfunc.o \
          otherfunc2.o otherfunc3.o O1.o surfana.o procgriddata.o AdNDP.o \
          fuzzy.o CDA.o basin.o orbloc.o visweak.o EDA.o CDFT.o ETS_NOCV.o \
          atmraddens.o NAONBO.o grid.o PBC.o hyper_polar.o deloc_aromat.o \
          cp2kmate.o minpack.o \
          blockhrr_012345.o ean.o hrr_012345.o eanvrr_012345.o boysfunc.o \
          naiveeri.o ryspoly.o 2F2.f90.o

objects = $(addprefix $(OBJDIR)/, $(objects_list))
objects_noGUI = $(addprefix $(OBJDIR)/, dislin_d_empty.o mouse_rotate_empty.o)

ifeq ($(WITH_FD),1)
  objects += $(OBJDIR)/2F2.c.o
  ifeq ($(OS),Ubuntu) # for Ubuntu
    LIB_base += -lflint -lflint-arb
  else ifeq ($(OS),RHEL) # for Fedora, CentOS, RHEL
    INCLUDE += -I/usr/include/arb
    LIB_base += -lflint -larb
  endif
else
  objects += $(OBJDIR)/no2F2.c.o
endif

modules = $(addprefix $(OBJDIR)/, define.o util.o function.o plot.o GUI.o libreta.o 2F2.f90.o)

C_GREEN = \033[1;32m
C_CYAN  = \033[1;36m
C_RESET = \033[0m

_PROGRESS := .build_progress
_ALL_OBJS  = $(OBJDIR)/dislin_d.o $(objects) $(objects_noGUI) $(OBJDIR)/mouse_rotate.o $(OBJDIR)/xlib.o
_TOTAL     = $(words $(_ALL_OBJS))
_MAKE      = $(MAKE) --no-print-directory

define init_progress
@rm -f $(_PROGRESS); touch $(_PROGRESS); \
_c=0; \
for obj in $(_ALL_OBJS); do \
    if [ -f "$$obj" ]; then \
        _c=$$((_c + 1)); echo 1 >> $(_PROGRESS); \
        _p=$$((_c * 100 / $(_TOTAL))); \
        [ $$_p -gt 100 ] && _p=100; \
        printf "[%3d%%] Built %s\n" $$_p "$$obj"; \
    fi; \
done
endef

define brief
@echo 1 >> $(_PROGRESS); \
 _c=$$(wc -l < $(_PROGRESS)); \
 _p=$$((_c * 100 / $(_TOTAL))); \
 [ $$_p -gt 100 ] && _p=100; \
 printf "[%3d%%] $(C_GREEN)Building %s$(C_RESET)\n" $$_p $(1);
endef

define brief_ld
@printf "[100%%] $(C_CYAN)Linking %s$(C_RESET)\n" $(1);
endef

# ==============================================================
# 4. Targets & Rules
# ==============================================================
.PHONY: default GUI noGUI clean cleanmultiwfn cleanlibreta _build_all _build_noGUI _build_GUI help

$(OBJDIR) $(EXEDIR):
	@mkdir -p $@

help:
	@echo ""
	@echo "  Multiwfn Build System"
	@echo ""
	@echo "  Targets:"
	@echo "    make                 Build both GUI and noGUI (default)"
	@echo "    make noGUI           Build noGUI version only"
	@echo "    make GUI             Build GUI version only"
	@echo "    make clean           Remove all build artefacts"
	@echo "    make cleanmultiwfn   Clean Multiwfn objects (keep libreta)"
	@echo "    make cleanlibreta    Clean libreta objects (keep Multiwfn)"
	@echo "    make help            Show this message"
	@echo ""
	@echo "  Options:"
	@echo "    COMPILER=intel|gnu   Force compiler (default: auto-detect, Intel first)"
	@echo "    TYPE=generic|native  SIMD instruction set (default: generic)"
	@echo "    MATH=mkl|openblas    Math library, gfortran only (default: auto-detect, MKL first)"
	@echo "    V=1 / VERBOSE=1      Show full compiler commands during compilation"
	@echo "    WITH_FD=1            Enable fractional-derivative support"
	@echo "    OS=Ubuntu|RHEL       Select arb/flint layout (with WITH_FD=1)"
	@echo ""
	@echo "  Examples:"
	@echo "    make -j\$$(nproc)"
	@echo "    make COMPILER=gnu MATH=mkl TYPE=native -j\$$(nproc)"
	@echo "    make noGUI V=1 -j8"
	@echo "    make noGUI WITH_FD=1 OS=RHEL -j8"
	@echo ""

default: | $(OBJDIR) $(EXEDIR)
	$(init_progress)
	@$(_MAKE) _build_all

_build_all: $(objects)
	@$(_MAKE) _build_noGUI
	@$(_MAKE) _build_GUI
	@echo " ------------------------------------------------------ "
	@echo "          Multiwfn has been successfully built!"
	@echo " ------------------------------------------------------ "

noGUI: | $(OBJDIR) $(EXEDIR)
	$(init_progress)
	@$(_MAKE) _build_noGUI

_build_noGUI: $(objects) $(objects_noGUI) | $(EXEDIR)
	$(call brief_ld,$(EXE_noGUI))
	$(_v)$(FC) $(LDFLAGS) -o $(EXE_noGUI) $(objects) $(objects_noGUI) $(LIB_noGUI)

GUI: | $(OBJDIR) $(EXEDIR)
	$(init_progress)
	@$(_MAKE) _build_GUI

_build_GUI: $(objects) $(OBJDIR)/mouse_rotate.o $(OBJDIR)/xlib.o | $(EXEDIR)
	$(call brief_ld,$(EXE))
	$(_v)$(FC) $(LDFLAGS) -o $(EXE) $(objects) $(OBJDIR)/mouse_rotate.o $(OBJDIR)/xlib.o $(LIB_GUI)

clean:
	@rm -rf $(OBJDIR) $(EXEDIR) $(_PROGRESS)

# Only clean Multiwfn files, compiled libreta files are not affected
_LIBRETA_OBJS = libreta.o ean.o hrr_012345.o blockhrr_012345.o \
                eanvrr_012345.o boysfunc.o naiveeri.o ryspoly.o
_LIBRETA_MODS = libreta.mod hrr.mod blockhrr.mod ean.mod eanvrr.mod boysfunc.mod
cleanmultiwfn:
	@mkdir -p $(OBJDIR)/_keep
	@for f in $(_LIBRETA_OBJS) $(_LIBRETA_MODS); do \
	    [ -f $(OBJDIR)/$$f ] && mv $(OBJDIR)/$$f $(OBJDIR)/_keep/ ; \
	done 2>/dev/null; true
	@rm -f $(OBJDIR)/*.o $(OBJDIR)/*.mod
	@mv $(OBJDIR)/_keep/* $(OBJDIR)/ 2>/dev/null; true
	@rm -rf $(OBJDIR)/_keep $(EXEDIR) $(_PROGRESS)

# Only clean libreta files, Multiwfn files are not affected
cleanlibreta:
	@for f in $(_LIBRETA_OBJS) $(_LIBRETA_MODS); do \
	    rm -f $(OBJDIR)/$$f ; \
	done
	@rm -rf $(EXEDIR) $(_PROGRESS)

# --- Compilation Rules ---

$(OBJDIR)/dislin.mod: dislin_d.f90 | $(OBJDIR)
	$(call brief,dislin_d.f90)
	$(_v)$(FC) $(OPT) -c dislin_d.f90 -o $(OBJDIR)/dislin_d.o

$(OBJDIR)/define.o: define.f90 $(OBJDIR)/dislin.mod | $(OBJDIR)
	$(call brief,define.f90)
	$(_v)$(FC) $(OPT) -c define.f90 -o $@

$(OBJDIR)/Bspline.o: Bspline.f90 | $(OBJDIR)
	$(call brief,Bspline.f90)
	$(_v)$(FC) $(OPT) -c Bspline.f90 -o $@

$(OBJDIR)/util.o: util.f90 $(OBJDIR)/define.o | $(OBJDIR)
	$(call brief,util.f90)
	$(_v)$(FC) $(OPT) -c util.f90 -o $@

$(OBJDIR)/function.o: function.f90 $(OBJDIR)/define.o $(OBJDIR)/util.o $(OBJDIR)/Bspline.o $(OBJDIR)/libreta.o $(OBJDIR)/2F2.f90.o | $(OBJDIR)
	$(call brief,function.f90)
	$(_v)$(FC) $(OPT) -c function.f90 -o $@

$(OBJDIR)/plot.o: plot.f90 $(OBJDIR)/function.o $(OBJDIR)/define.o $(OBJDIR)/util.o | $(OBJDIR)
	$(call brief,plot.f90)
	$(_v)$(FC) $(OPT) -c plot.f90 -o $@

$(OBJDIR)/GUI.o: GUI.f90 $(OBJDIR)/define.o $(OBJDIR)/plot.o $(OBJDIR)/function.o $(OBJDIR)/mouse_rotate.o | $(OBJDIR)
	$(call brief,GUI.f90)
	$(_v)$(FC) $(OPT) -c GUI.f90 -o $@

$(OBJDIR)/mouse_rotate.o: mouse_rotate.f90 $(OBJDIR)/xlib.o $(OBJDIR)/define.o $(OBJDIR)/plot.o | $(OBJDIR)
	$(call brief,mouse_rotate.f90)
	$(_v)$(FC) $(OPT) -c mouse_rotate.f90 -o $@

$(OBJDIR)/mouse_rotate_empty.o: noGUI/mouse_rotate_empty.f90 | $(OBJDIR)
	$(call brief,noGUI/mouse_rotate_empty.f90)
	$(_v)$(FC) $(OPT) -c noGUI/mouse_rotate_empty.f90 -o $@

$(OBJDIR)/2F2.f90.o: ext/2F2.f90 $(OBJDIR)/util.o $(OBJDIR)/Bspline.o | $(OBJDIR)
	$(call brief,ext/2F2.f90)
	$(_v)$(FC) $(OPT) -c ext/2F2.f90 -o $@


# Third-party / library codes

$(OBJDIR)/DFTxclib.o: DFTxclib.F | $(OBJDIR)
	$(call brief,DFTxclib.F)
	$(_v)$(FC) $(OPT) $(FFLAGS_FIXED) -c DFTxclib.F -o $@

$(OBJDIR)/Lebedev-Laikov.o: Lebedev-Laikov.F | $(OBJDIR)
	$(call brief,Lebedev-Laikov.F)
	$(_v)$(FC) $(OPT) $(FFLAGS_FIXED) -c Lebedev-Laikov.F -o $@

$(OBJDIR)/sym.o: sym.F | $(OBJDIR)
	$(call brief,sym.F)
	$(_v)$(FC) $(OPT) $(FFLAGS_FIXED) -c sym.F -o $@

$(OBJDIR)/edflib.o: edflib.f90 | $(OBJDIR)
	$(call brief,edflib.f90)
	$(_v)$(FC) $(OPT) -c edflib.f90 -o $@

$(OBJDIR)/atmraddens.o: atmraddens.f90 | $(OBJDIR)
	$(call brief,atmraddens.f90)
	$(_v)$(FC) $(OPT) -c atmraddens.f90 -o $@

$(OBJDIR)/minpack.o: minpack.f90 | $(OBJDIR)
	$(call brief,minpack.f90)
	$(_v)$(FC) $(OPT) -c minpack.f90 -o $@

$(OBJDIR)/fparser.o: fparser.f90 | $(OBJDIR)
	$(call brief,fparser.f90)
	$(_v)$(FC) $(OPT) -c fparser.f90 -o $@

$(OBJDIR)/2F2.c.o: ext/2F2.c | $(OBJDIR)
	$(call brief,ext/2F2.c)
	$(_v)$(CC) $(INCLUDE) -c ext/2F2.c -o $@

$(OBJDIR)/no2F2.c.o: ext/no2F2.c | $(OBJDIR)
	$(call brief,ext/no2F2.c)
	$(_v)$(CC) $(INCLUDE) -c ext/no2F2.c -o $@

$(OBJDIR)/dislin_d_empty.o: noGUI/dislin_d_empty.f90 | $(OBJDIR)
	$(call brief,noGUI/dislin_d_empty.f90)
	$(_v)$(FC) $(OPT) $(FFLAGS_DISLIN_EMPTY) -c noGUI/dislin_d_empty.f90 -o $@


# Multiwfn source files (all depend on the core modules)

$(OBJDIR)/sub.o: sub.f90 $(modules) | $(OBJDIR)
	$(call brief,sub.f90)
	$(_v)$(FC) $(OPT) -c sub.f90 -o $@

$(OBJDIR)/integral.o: integral.f90 $(modules) | $(OBJDIR)
	$(call brief,integral.f90)
	$(_v)$(FC) $(OPT) -c integral.f90 -o $@

$(OBJDIR)/fileIO.o: fileIO.f90 $(modules) | $(OBJDIR)
	$(call brief,fileIO.f90)
	$(_v)$(FC) $(OPT) -c fileIO.f90 -o $@

$(OBJDIR)/spectrum.o: spectrum.f90 $(modules) | $(OBJDIR)
	$(call brief,spectrum.f90)
	$(_v)$(FC) $(OPT) -c spectrum.f90 -o $@

$(OBJDIR)/DOS.o: DOS.f90 $(modules) | $(OBJDIR)
	$(call brief,DOS.f90)
	$(_v)$(FC) $(OPT) -c DOS.f90 -o $@

$(OBJDIR)/Multiwfn.o: Multiwfn.f90 $(modules) | $(OBJDIR)
	$(call brief,Multiwfn.f90)
	$(_v)$(FC) $(OPT) -c Multiwfn.f90 -o $@

$(OBJDIR)/0123dim.o: 0123dim.f90 $(modules) | $(OBJDIR)
	$(call brief,0123dim.f90)
	$(_v)$(FC) $(OPT) -c 0123dim.f90 -o $@

$(OBJDIR)/LSB.o: LSB.f90 $(modules) | $(OBJDIR)
	$(call brief,LSB.f90)
	$(_v)$(FC) $(OPT) -c LSB.f90 -o $@

$(OBJDIR)/population.o: population.f90 $(modules) | $(OBJDIR)
	$(call brief,population.f90)
	$(_v)$(FC) $(OPT) -c population.f90 -o $@

$(OBJDIR)/frj.o: ext/frj.f90 $(modules) | $(OBJDIR)
	$(call brief,ext/frj.f90)
	$(_v)$(FC) $(OPT) -c ext/frj.f90 -o $@

$(OBJDIR)/orbcomp.o: orbcomp.f90 $(modules) | $(OBJDIR)
	$(call brief,orbcomp.f90)
	$(_v)$(FC) $(OPT) -c orbcomp.f90 -o $@

$(OBJDIR)/bondorder.o: bondorder.f90 $(modules) | $(OBJDIR)
	$(call brief,bondorder.f90)
	$(_v)$(FC) $(OPT) -c bondorder.f90 -o $@

$(OBJDIR)/topology.o: topology.f90 $(modules) | $(OBJDIR)
	$(call brief,topology.f90)
	$(_v)$(FC) $(OPT) -c topology.f90 -o $@

$(OBJDIR)/excittrans.o: excittrans.f90 $(modules) | $(OBJDIR)
	$(call brief,excittrans.f90)
	$(_v)$(FC) $(OPT) -c excittrans.f90 -o $@

$(OBJDIR)/otherfunc.o: otherfunc.f90 $(modules) | $(OBJDIR)
	$(call brief,otherfunc.f90)
	$(_v)$(FC) $(OPT) -c otherfunc.f90 -o $@

$(OBJDIR)/otherfunc2.o: otherfunc2.f90 $(modules) | $(OBJDIR)
	$(call brief,otherfunc2.f90)
	$(_v)$(FC) $(OPT) -c otherfunc2.f90 -o $@

$(OBJDIR)/otherfunc3.o: otherfunc3.f90 $(modules) | $(OBJDIR)
	$(call brief,otherfunc3.f90)
	$(_v)$(FC) $(OPT) -c otherfunc3.f90 -o $@

$(OBJDIR)/O1.o: O1.f90 $(modules) | $(OBJDIR)
	$(call brief,O1.f90)
	$(_v)$(FC) $(OPT1) -c O1.f90 -o $@

$(OBJDIR)/surfana.o: surfana.f90 $(modules) | $(OBJDIR)
	$(call brief,surfana.f90)
	$(_v)$(FC) $(OPT) -c surfana.f90 -o $@

$(OBJDIR)/procgriddata.o: procgriddata.f90 $(modules) | $(OBJDIR)
	$(call brief,procgriddata.f90)
	$(_v)$(FC) $(OPT) -c procgriddata.f90 -o $@

$(OBJDIR)/AdNDP.o: AdNDP.f90 $(modules) | $(OBJDIR)
	$(call brief,AdNDP.f90)
	$(_v)$(FC) $(OPT) -c AdNDP.f90 -o $@

$(OBJDIR)/fuzzy.o: fuzzy.f90 $(modules) | $(OBJDIR)
	$(call brief,fuzzy.f90)
	$(_v)$(FC) $(OPT) -c fuzzy.f90 -o $@

$(OBJDIR)/CDA.o: CDA.f90 $(modules) | $(OBJDIR)
	$(call brief,CDA.f90)
	$(_v)$(FC) $(OPT) -c CDA.f90 -o $@

$(OBJDIR)/basin.o: basin.f90 $(modules) | $(OBJDIR)
	$(call brief,basin.f90)
	$(_v)$(FC) $(OPT) -c basin.f90 -o $@

$(OBJDIR)/orbloc.o: orbloc.f90 $(modules) | $(OBJDIR)
	$(call brief,orbloc.f90)
	$(_v)$(FC) $(OPT) -c orbloc.f90 -o $@

$(OBJDIR)/visweak.o: visweak.f90 $(modules) | $(OBJDIR)
	$(call brief,visweak.f90)
	$(_v)$(FC) $(OPT) -c visweak.f90 -o $@

$(OBJDIR)/EDA.o: EDA.f90 $(modules) | $(OBJDIR)
	$(call brief,EDA.f90)
	$(_v)$(FC) $(OPT) -c EDA.f90 -o $@

$(OBJDIR)/CDFT.o: CDFT.f90 $(modules) | $(OBJDIR)
	$(call brief,CDFT.f90)
	$(_v)$(FC) $(OPT) -c CDFT.f90 -o $@

$(OBJDIR)/ETS_NOCV.o: ETS_NOCV.f90 $(modules) | $(OBJDIR)
	$(call brief,ETS_NOCV.f90)
	$(_v)$(FC) $(OPT) -c ETS_NOCV.f90 -o $@

$(OBJDIR)/NAONBO.o: NAONBO.f90 $(modules) | $(OBJDIR)
	$(call brief,NAONBO.f90)
	$(_v)$(FC) $(OPT) -c NAONBO.f90 -o $@

$(OBJDIR)/grid.o: grid.f90 $(modules) | $(OBJDIR)
	$(call brief,grid.f90)
	$(_v)$(FC) $(OPT) -c grid.f90 -o $@

$(OBJDIR)/PBC.o: PBC.f90 $(modules) | $(OBJDIR)
	$(call brief,PBC.f90)
	$(_v)$(FC) $(OPT) -c PBC.f90 -o $@

$(OBJDIR)/hyper_polar.o: hyper_polar.f90 $(modules) | $(OBJDIR)
	$(call brief,hyper_polar.f90)
	$(_v)$(FC) $(OPT) -c hyper_polar.f90 -o $@

$(OBJDIR)/deloc_aromat.o: deloc_aromat.f90 $(modules) | $(OBJDIR)
	$(call brief,deloc_aromat.f90)
	$(_v)$(FC) $(OPT) -c deloc_aromat.f90 -o $@

$(OBJDIR)/cp2kmate.o: cp2kmate.f90 $(modules) | $(OBJDIR)
	$(call brief,cp2kmate.f90)
	$(_v)$(FC) $(OPT) -c cp2kmate.f90 -o $@


# LIBRETA electron integral library

$(OBJDIR)/libreta.o: $(LIBRETAPATH)/libreta.f90 $(OBJDIR)/hrr_012345.o $(OBJDIR)/blockhrr_012345.o \
           $(OBJDIR)/ean.o $(OBJDIR)/eanvrr_012345.o $(OBJDIR)/boysfunc.o | $(OBJDIR)
	$(call brief,$(LIBRETAPATH)/libreta.f90)
	$(_v)$(FC) $(OPT) -c $(LIBRETAPATH)/libreta.f90 -o $@

$(OBJDIR)/hrr_012345.o: $(LIBRETAPATH)/hrr_012345.f90 | $(OBJDIR)
	$(call brief,$(LIBRETAPATH)/hrr_012345.f90)
	$(_v)$(FC) $(OPT) $(FFLAGS_NOWARN) -c $(LIBRETAPATH)/hrr_012345.f90 -o $@

$(OBJDIR)/blockhrr_012345.o: $(LIBRETAPATH)/blockhrr_012345.f90 | $(OBJDIR)
	$(call brief,$(LIBRETAPATH)/blockhrr_012345.f90)
	$(_v)$(FC) $(BLOCKHRR_OPT) -c $(LIBRETAPATH)/blockhrr_012345.f90 -o $@

$(OBJDIR)/ean.o: $(LIBRETAPATH)/ean.f90 $(OBJDIR)/hrr_012345.o $(OBJDIR)/eanvrr_012345.o $(OBJDIR)/boysfunc.o \
       $(LIBRETAPATH)/ean_data1.h $(LIBRETAPATH)/ean_data2.h | $(OBJDIR)
	$(call brief,$(LIBRETAPATH)/ean.f90)
	$(_v)$(FC) $(OPT) -c $(LIBRETAPATH)/ean.f90 -o $@

$(OBJDIR)/eanvrr_012345.o: $(LIBRETAPATH)/eanvrr_012345.f90 $(OBJDIR)/boysfunc.o | $(OBJDIR)
	$(call brief,$(LIBRETAPATH)/eanvrr_012345.f90)
	$(_v)$(FC) $(OPT) -c $(LIBRETAPATH)/eanvrr_012345.f90 -o $@

$(OBJDIR)/boysfunc.o: $(LIBRETAPATH)/boysfunc.f90 $(LIBRETAPATH)/boysfunc_data1.h \
            $(LIBRETAPATH)/boysfunc_data2.h | $(OBJDIR)
	$(call brief,$(LIBRETAPATH)/boysfunc.f90)
	$(_v)$(FC) $(OPT) -c $(LIBRETAPATH)/boysfunc.f90 -o $@

$(OBJDIR)/naiveeri.o: $(LIBRETAPATH)/naiveeri.f90 $(OBJDIR)/ryspoly.o | $(OBJDIR)
	$(call brief,$(LIBRETAPATH)/naiveeri.f90)
	$(_v)$(FC) $(OPT) -c $(LIBRETAPATH)/naiveeri.f90 -o $@

$(OBJDIR)/ryspoly.o: $(LIBRETAPATH)/ryspoly.f90 | $(OBJDIR)
	$(call brief,$(LIBRETAPATH)/ryspoly.f90)
	$(_v)$(FC) $(OPT) -c $(LIBRETAPATH)/ryspoly.f90 -o $@


# Fortran-Xlib interface (GUI only)

$(OBJDIR)/xlib.o: ext/xlib.f90 | $(OBJDIR)
	$(call brief,ext/xlib.f90)
	$(_v)$(FC) $(OPT) $(FFLAGS_XLIB) -c ext/xlib.f90 -o $@
