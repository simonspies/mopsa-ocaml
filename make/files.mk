# OCaml sources (except temporary files starting and ending with '#')
ML = $(shell find $(SRC) -name "*.ml" | grep -v "\#*\#")
MLI = $(shell find $(SRC) -name "*.mli")

MLL = $(shell find $(SRC) -name "*.mll")
ML_OF_MLL = $(MLL:$(SRC)/%.mll=$(BUILD)/%.ml)

MLY = $(shell find $(SRC) -name "*.mly")
ML_OF_MLY = $(MLY:$(SRC)/%.mly=$(BUILD)/%.ml)
MLI_OF_MLY = $(MLY:$(SRC)/%.mly=$(BUILD)/%.mli)

PACKS = $(patsubst $(SRC)/%,%,$(shell find $(SRC)/* -type d))
ML_OF_PACKS = $(PACKS:%=$(BUILD)/%.ml)

TOPML = $(shell $(OCAMLFIND) ocamldep -sort $(SRC)/*.ml)
TOPPACKS = $(patsubst $(SRC)/%,%,$(shell find $(SRC)/* -maxdepth 0 -type d))

# Dependencies
DEPS_ML = $(ML:$(SRC)/%.ml=$(BUILD)/%.dep)
DEPS_MLI = $(MLI:$(SRC)/%.mli=$(BUILD)/%.idep)
DEPS_MLL = $(MLL:$(SRC)/%.mll=$(BUILD)/%.dep)
DEPS_MLY = $(MLY:$(SRC)/%.mly=$(BUILD)/%.dep)

# Objects
CMI = $(MLI:$(SRC)/%.mli=$(BUILD)/%.cmi)
CMO = $(filter-out $(CMO_FROM_CMI), $(ML:$(SRC)/%.ml=$(BUILD)/%.cmo))
CMX = $(CMO:%.cmo=%.cmx)

CMO_FROM_CMI = $(CMI:%.cmi=%.cmo)
CMX_FROM_CMI = $(CMI:%.cmi=%.cmx)

CMO_FROM_PACK = $(PACKS:%=$(BUILD)/%.cmo)
CMX_FROM_PACK = $(PACKS:%=$(BUILD)/%.cmx)

CMX_FROM_MLL = $(MLL:$(SRC)/%.mll=$(BUILD)/%.cmx)
CMO_FROM_MLL = $(MLL:$(SRC)/%.mll=$(BUILD)/%.cmo)

CMX_FROM_MLY = $(MLY:$(SRC)/%.mly=$(BUILD)/%.cmx)
CMO_FROM_MLY = $(MLY:$(SRC)/%.mly=$(BUILD)/%.cmo)
CMI_FROM_MLY = $(MLY:$(SRC)/%.mly=$(BUILD)/%.cmi)


TOPCMX = $(TOPML:$(SRC)/%.ml=$(BUILD)/%.cmx) $(TOPPACKS:%=$(BUILD)/%.cmx)
TOPCMO = $(TOPML:$(SRC)/%.ml=$(BUILD)/%.cmo) $(TOPPACKS:%=$(BUILD)/%.cmo)

## Libraries
LIBCMXA = $(LIBS:%=%.cmxa) $(foreach lib,$(MOPSALIBS),$(call lib_file,$(lib)).cmxa)
LIBCMA = $(LIBS:%=%.cma) $(foreach lib,$(MOPSALIBS),$(call lib_file,$(lib)).cma)


## Merlin
MERLIN = $(SRC)/.merlin $(PACKS:%=$(SRC)/%/.merlin)

## C/C++ stubs
C_OBJ = $(C_SRC:%.c=$(BUILD)/%.o)
CC_OBJ = $(CC_SRC:%.cc=$(BUILD)/%.o)
