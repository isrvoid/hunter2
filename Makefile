DFLAGS_DEBUG := -debug -g -unittest
DFLAGS_RELEASE := -O -release -boundscheck=off

ifeq ($(RELEASE), 1)
	DFLAGS := $(DFLAGS_RELEASE)
else
	DFLAGS := $(DFLAGS_DEBUG)
endif

BUILDDIR := bin
SRC := src

hunter2: $(SRC)/app.d
	@dmd $(DFLAGS) $^ -of$(BUILDDIR)/$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
