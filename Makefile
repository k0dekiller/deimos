ifneq ($(origin OS), undefined)
WINDOWS := 1
endif

# Enable delayed expansion on Windows
ifdef WINDOWS
SHELL = cmd.exe
.SHELLFLAGS = /V:ON /C
endif

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

ifdef WINDOWS
clean:
	@if exist "$(BIN)" rmdir /s /q "$(BIN)"
else
clean:
	@rm -rf "$(BIN)"
endif

ifdef WINDOWS
setup: clean
	mkdir "$(BIN)"
else
setup: clean
	@find $(SRC) -type d -exec sh -c '\
		rel="$${1#$(SRC)/}"; \
		[ "$$rel" = "$(SRC)" ] && rel=""; \
		mkdir -p "$(BIN)/$$rel"; \
	' _ {} \;
endif

ifdef WINDOWS
build: setup $(BIN)
	@for /r "$(SRC)" %%F in (*.*) do @(
		if /i not "%%~xF"==".z" (
			set "src=%%F"
			set "rel=%%F"
			set "rel=!rel:$(SRC)\=!"
			for %%D in ("$(BIN)\!rel!") do @if not exist "%%~dpD" mkdir "%%~dpD"
			xcopy /y /q "%%F" "$(BIN)\!rel!" >nul
		)
	)
	@set ZARGS=
	@for /r "$(SRC)" %%F in (*.z) do @(
		set "in=%%F"
		set "rel=%%F"
		set "rel=!rel:$(SRC)\=!"
		set "rel=!rel:.z=.py!"
		set "out=$(BIN)\!rel!"
		for %%D in ("!out!") do @if not exist "%%~dpD" mkdir "%%~dpD"
		set ZARGS=!ZARGS! "%%F" "!out!"
		@cmd /c $(ZINK) !ZARGS!
	)
else
build: setup $(BIN)
	@find "$(SRC)" -type f ! -name "*.z" -exec sh -c '\
		src="$$1"; \
		rel="$${src#$(SRC)/}"; \
		cp "$$src" "$(BIN)/$$rel"; \
	' _ {} \;
ifneq ($(Z_FILES),)
	@$(ZINK) $(Z_PAIRS)
endif
endif

ifeq  ($(OS),Windows_NT)
$(BIN):
	mkdir "$(BIN)"
else
$(BIN):
	@mkdir -p "$(BIN)"
endif

install:
	python -m pip install zlang

flash:
	mpremote cp -r bin/* :/

run: flash
	mpremote reset
	sleep 2
	mpremote

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