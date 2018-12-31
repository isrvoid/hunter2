DFLAGS_DEBUG := -debug -g -unittest
DFLAGS_RELEASE := -O -release -boundscheck=off

ifeq ($(RELEASE), 1)
	DFLAGS := $(DFLAGS_RELEASE)
else
	DFLAGS := $(DFLAGS_DEBUG)
endif

BUILDDIR := bin
SRC := src

passwise: $(BUILDDIR)/passwise

$(BUILDDIR)/passwise: $(SRC)/app.d
	@dmd $(DFLAGS) $^ -of$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
