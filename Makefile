SRC := src
BIN := bin
DIST := dist

# All .z files in src
Z_FILES := $(shell find $(SRC) -type f -name "*.z")
Z_PAIRS := $(foreach f,$(Z_FILES), \
	$(f) $(BIN)/$(patsubst $(SRC)/%,%,$(patsubst %.z,%.py,$(f))) \
)

# Zink build command
ZINK := python -m zlang --lang py --pretty --verbose

.PHONY: build clean

all: build

zlang:
	python -m pip install zlang

cwio:
	git submodule update --init

install: zlang

init: micropython install

clean:
	@rm -rf "$(BIN)"
	@rm -rf "$(SRC)/cwio/build-armv6m"
	@find "$(SRC)" -maxdepth 2 -type f -name "*.mpy" -delete

setup: clean
	@find $(SRC) -type d -exec sh -c '\
		rel="$${1#$(SRC)/}"; \
		[ "$$rel" = "$(SRC)" ] && rel=""; \
		mkdir -p "$(BIN)/$$rel"; \
	' _ {} \;

build: setup $(BIN)
	make -C "$(SRC)/cwio"
	@rm -rf "$(SRC)/cwio/build-armv6m"
	@find "$(SRC)" -type f ! -name "*.z" ! -name "*.c" ! -name "*.png" ! -name "*.mp4" ! -name "Makefile" -exec sh -c '\
		src="$$1"; \
		rel="$${src#$(SRC)/}"; \
		cp "$$src" "$(BIN)/$$rel"; \
	' _ {} \;
ifneq ($(Z_FILES),)
	@$(ZINK) $(Z_PAIRS)
endif

$(BIN):
	@mkdir -p "$(BIN)"

flash:

run: flash
	python bin/main.py

release:
	mkdir -p $(DIST)
	cd $(BIN);\
	tar -cvf ../$(DIST)/deimos.tar \
	--exclude user \
	--exclude apps/axios.py \
	--exclude apps/changed.py \
	--exclude conf/axios.txt \
	--exclude conf/wifi.txt \
	$(shell ls $(BIN))
	gh release create "" \
	$(DIST)/deimos.tar