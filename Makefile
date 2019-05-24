CC := gcc
ROOT := .

GRAPHENE_DIR := /opt/graphene
RUNTIME_DIR := $(GRAPHENE_DIR)/Runtime
SGX_DIR := $(GRAPHENE_DIR)/Pal/src/host/Linux-SGX
MANIFEST_TEMPLATE = ./manifest_template

SRC := $(ROOT)
OBJ := $(ROOT)
SOURCES := $(wildcard $(SRC)/*.c)
OBJECTS := $(patsubst $(SRC)/%.c, $(OBJ)/%, $(SOURCES))
MANIFEST_SGXS := $(patsubst $(SRC)/%.c, $(OBJ)/%.manifest.sgx, $(SOURCES))
MANIFESTS := $(patsubst $(SRC)/%.c, $(OBJ)/%.manifest, $(SOURCES))
TOKENS := $(patsubst $(SRC)/%.c, $(OBJ)/%.token, $(SOURCES))
SIGS := $(patsubst $(SRC)/%.c, $(OBJ)/%.sig, $(SOURCES))
RUNS := $(patsubst $(OBJ)/%, run-%, $(OBJECTS))

LIBPAL := $(RUNTIME_DIR)/libpal-Linux-SGX.so
SGX_SIGNER_KEY ?= $(SGX_DIR)/signer/enclave-key.pem
SGX_SIGN = $(SGX_DIR)/signer/pal-sgx-sign -libpal $(LIBPAL) -key $(SGX_SIGNER_KEY)
SGX_GET_TOKEN = $(SGX_DIR)/signer/pal-sgx-get-token

.PHONY: all clean run

all: build sgx-manifest tokens run


$(SGX_SIGNER_KEY):
	$(error "Cannot find any enclave key. Generate $(abspath $(SGX_SIGNER_KEY)) or specify 'SGX_SIGNER_KEY=' with make")


build: $(OBJECTS)

manifest: $(MANIFESTS)

sgx-manifest: $(MANIFEST_SGXS)

tokens: $(TOKENS)

run: $(RUNS)

clean:
	rm -f $(OBJECTS)
	rm -f $(TOKENS)
	rm -f $(MANIFESTS)
	rm -f $(MANIFEST_SGXS)
	rm -f $(SIGS)

$(OBJ)/%: $(SRC)/%.c
	$(CC) -I$(ROOT) $< -o $@

$(OBJ)/%.manifest: $(MANIFEST_TEMPLATE)
	sed 's/%GRAPHENE_PATH%/$(subst /,\/,$(GRAPHENE_DIR))/g' $< > $@

$(OBJ)/%.manifest.sgx: $(OBJ)/%.manifest $(LIBPAL) $(SGX_SIGNER_KEY)
	$(SGX_SIGN) -output $@ -exec $* -manifest $<

$(OBJ)/%.token: $(OBJ)/%.manifest.sgx
	$(SGX_GET_TOKEN) -output $@ -sig $(OBJ)/$*.sig

run-%: $(OBJ)/% $(OBJ)/%.token
	SGX=1 /opt/graphene/Runtime/pal_loader $(OBJ)/$*
