DFLAGS_DEBUG := -debug -g -unittest
DFLAGS_RELEASE := -O -release -boundscheck=off

ifeq ($(RELEASE), 1)
	DFLAGS := $(DFLAGS_RELEASE)
else
	DFLAGS := $(DFLAGS_DEBUG)
endif

BUILDDIR := bin
SRCDIR := src
SRCNAMES := util.d shovelnode.d dnode.d node.d store.d app.d
SRC := $(addprefix $(SRCDIR)/passwise/, $(SRCNAMES))

passwise: $(BUILDDIR)/passwise

test: $(BUILDDIR)/passwise
	@$? --DRT-testmode=test-only

$(BUILDDIR)/passwise: $(SRC)
	@dmd $(DFLAGS) $^ -of$@

clean:
	-@$(RM) $(wildcard $(BUILDDIR)/*)

.PHONY: clean
