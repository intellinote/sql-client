#-------------------------------------------------------------------------------
# NOTE: Try `make help` for a list of popular targets
#-------------------------------------------------------------------------------

# CONFIGURATION
################################################################################

# COFFEE & NODE ################################################################
COFFEE_EXE ?= ./node_modules/.bin/coffee
NODE_EXE ?= node
COFFEE_COMPILE ?= $(COFFEE_EXE) -c
COFFEE_COMPILE_ARGS ?=
COFFEE_SRCS ?= $(wildcard lib/*.coffee *.coffee lib/*/*.coffee)
COFFEE_TEST_SRCS ?= $(wildcard test/*.coffee test/*/*.coffee)
COFFEE_JS ?= ${COFFEE_SRCS:.coffee=.js}
COFFEE_TEST_JS ?= ${COFFEE_TEST_SRCS:.coffee=.js}

# NPM ##########################################################################
NPM_EXE ?= npm
PACKAGE_JSON ?= package.json
NODE_MODULES ?= node_modules
NPM_ARGS ?= --silent

# PACKAGING ####################################################################
PACKAGE_VERSION ?= $(shell $(NODE_EXE) -e "console.log(require('./$(PACKAGE_JSON)').version)")
PACKAGE_NAME ?= $(shell $(NODE_EXE) -e "console.log(require('./$(PACKAGE_JSON)').name)")
TMP_PACKAGE_DIR ?= packaging-$(PACKAGE_NAME)-$(PACKAGE_VERSION)-tmp
PACKAGE_DIR ?= $(PACKAGE_NAME)-$(PACKAGE_VERSION)
TEST_MODULE_INSTALL_DIR ?= ../testing-module-install

# MOCHA ########################################################################
MOCHA_EXE ?= ./node_modules/.bin/mocha
TEST ?= $(wildcard test/test-*.coffee)
MOCHA_TESTS ?= $(TEST)
MOCHA_TEST_PATTERN ?=
MOCHA_TIMEOUT ?=-t 3000
MOCHA_TEST_ARGS  ?= -R list --compilers coffee:coffeescript/register $(MOCHA_TIMEOUT) $(MOCHA_TEST_PATTERN)
MOCHA_EXTRA_ARGS ?=

################################################################################
# META-TARGETS AND SIMILAR

# `.SUFFIXES` - reset suffixes in case any were previously defined
.SUFFIXES:

# `.PHONY` - make targets that are not actually files
.PHONY: all coffee clean clean-coverage clean-docco clean-docs clean-js clean-markdown clean-module clean-node-modules clean-test-module-install coverage docco docs fully-clean-node-modules js markdown module targets test test-module-install todo clean-bin bin js-bin coffee-bin

# `all` - the default target
all: help

# `targets` - list targets that are not likely to be "meta" targets like .PHONY or .SUFFIXES
targets:
	@grep -E "^[^ #.$$]+:( |$$)" Makefile | sort | cut -d ":" -f 1

# `todo` - list todo and related comments found in source files
todo:
	@grep -C 0 --exclude-dir=node_modules --exclude-dir=.git --exclude=#*# --exclude=.#* --exclude=*.html  --exclude=Makefile  -IrHE "(TODO)|(FIXME)|(XXX)" *


# `FIND-CHANGE-ME` - list the `CHANGE-ME` markers that indicate places where the repository template needs to be modified when creating a new project
FIND-CHANGE-ME:
	@grep -C 0 --exclude-dir=node_modules --exclude-dir=.git --exclude=#*# --exclude=.#* --exclude=*.html -IrHE "\-[C]HANGE-ME-" *

# @echo " test-module-install - generate an npm module and validate it"
help:
	@echo ""
	@echo "--------------------------------------------------------------------------------"
	@echo "HERE ARE SOME POPULAR AND USEFUL TARGETS IN THIS MAKEFILE."
	@echo "--------------------------------------------------------------------------------"
	@echo ""
	@echo "SET UP"
	@echo " install      - install npm dependencies (i.e., 'npm install')"
	@echo "                (also aliased as 'npm' and 'node_modules')"
	@echo ""
	@echo "AUTOMATED TESTS"
	@echo " test         - run the unit-test suite"
	@echo " coverage     - generate a unit-test coverage report"
	@echo ""
	@echo "DOCUMENTATION"
	@echo " markdown     - generate HTML versions of various *.md and *.litcoffee files"
	@echo " docco        - generate annotated source code view using docco"
	@echo " docs         - generate all of the above"
	@echo ""
	@echo "BUILD"
	@echo " js           - generate JavaScript files from CoffeeScript files"
	@echo " module       - create a packaged npm module for deployment"
	@echo " test-module-install"
	@echo "              - create a packaged npm module for deployment and then"
	@echo "                validate that the module can be installed"
	@echo ""
	@echo "CLEAN UP"
	@echo " clean        - remove generated files and directories (except node_modules)"
	@echo " really-clean - truly remove all generated files and directories"
	@echo ""
	@echo "OTHER"
	@echo " todo         - search source code for TODO items"
	@echo " targets      - generate a list of most available make targets"
	@echo " help         - this listing"
	@echo ""
	@echo "--------------------------------------------------------------------------------"
	@echo ""

################################################################################
# CLEAN UP TARGETS

clean: clean-coverage clean-docco clean-docs clean-js clean-module clean-test-module-install clean-node-modules clean-bin

clean-test-module-install:
	rm -rf $(TEST_MODULE_INSTALL_DIR)

clean-module:
	rm -rf $(PACKAGE_DIR)

clean-node-modules:
	$(NPM_EXE) $(NPM_ARGS) prune &

really-clean: clean really-clean-node-modules

really-clean-node-modules: # deletes rather that simply pruning node_modules
	rm -rf $(NODE_MODULES)

clean-js:
	rm -f $(COFFEE_JS) $(COFFEE_TEST_JS)

clean-docs: clean-markdown clean-docco

clean-docco:
	rm -rf docs/docco
	(rmdir --ignore-fail-on-non-empty docs) || true

clean-markdown:
	rm -rf $(MARKDOWN_HTML)
	rm -rf $(LITCOFFEE_HTML)
	(rmdir --ignore-fail-on-non-empty docs) || true

################################################################################
# NPM TARGETS

db-modules:
	$(NPM_EXE) install --no-save "mysql@^2"
	$(NPM_EXE) install --no-save "pg@^7"
	$(NPM_EXE) install --no-save "sqlite3@^4"

module: db-modules js bin test
	mkdir -p $(PACKAGE_DIR)
	cp $(PACKAGE_JSON) $(PACKAGE_DIR)
	cp -r bin $(PACKAGE_DIR)
	cp README.md $(PACKAGE_DIR)
	cp LICENSE.txt $(PACKAGE_DIR)
	cp -r lib $(PACKAGE_DIR)
	tar -czf $(PACKAGE_DIR).tgz $(PACKAGE_DIR)
	tar -ztf $(PACKAGE_DIR).tgz

test-module-install: clean-test-module-install module
	mkdir $(TEST_MODULE_INSTALL_DIR); cd $(TEST_MODULE_INSTALL_DIR); npm install "$(CURDIR)/$(PACKAGE_DIR).tgz"; node -e "require('assert').ok(require('sql-client').SQLClient);" && (npm install sqlite3 && echo "SELECT 3+5 as FOO" | ./node_modules/.bin/sqlite3-runner --db ":memory:") && cd $(CURDIR) && rm -rf $(TEST_MODULE_INSTALL_DIR) && echo "\n\n\n<<<<<<< It worked! >>>>>>\n\n\n"

$(NODE_MODULES): $(PACKAGE_JSON)
	$(NPM_EXE) $(NPM_ARGS) prune
	$(NPM_EXE) $(NPM_ARGS) install
	touch $(NODE_MODULES) # touch the module dir so it looks younger than `package.json`

npm: $(NODE_MODULES) # an alias
install: $(NODE_MODULES) # an alias

################################################################################
# COFFEE TARGETS

coffee: $(NODE_MODULES)
	rm -rf $(LIB_COV)

js: coffee $(COFFEE_JS) $(COFFEE_TEST_JS)

.SUFFIXES: .js .coffee
.coffee.js:
	$(COFFEE_COMPILE) $(COFFEE_COMPILE_ARGS) $<
$(COFFEE_JS_OBJ): $(NODE_MODULES) $(COFFEE_SRCS) $(COFFEE_TEST_SRCS)

js-bin: js
	$(foreach f,$(shell ls ./lib/bin/*.js 2>/dev/null),chmod a+x "$(f)" && cp bin/.shebang.sh "bin/`basename $(f) | sed 's/...$$//'`";)

coffee-bin:
	$(foreach f,$(shell ls ./lib/bin/*.coffee 2>/dev/null),chmod a+x "$(f)" && cp bin/.shebang.sh "bin/`basename $(f) | sed 's/.......$$//'`";)

bin: coffee-bin

clean-bin:
	$(foreach f,$(shell ls ./lib/bin/*.coffee 2>/dev/null),rm -rf "bin/`basename $(f) | sed 's/.......$$//'`";)

################################################################################
# TEST TARGETS

test: $(MOCHA_TESTS) $(NODE_MODULES)
	$(MOCHA_EXE) $(MOCHA_TEST_ARGS) ${MOCHA_EXTRA_ARGS} $(MOCHA_TESTS)

################################################################################
#### NYC TEST COVERAGE #########################################################
###################################################################### config ##
NYC_COVERAGE_DIR ?= ./docs/coverage
NYC_COVERAGE_TMP_DIR ?= ./.nyc_output
NYC_ARGS ?= --report-dir $(NYC_COVERAGE_DIR) --reporter=html --reporter=text-summary --extension .coffee
NYC_EXE ?= ./node_modules/.bin/nyc
NYC_COVERAGE_MOCHA_ARGS  ?= -R spec --compilers coffee:coffeescript/register $(MOCHA_TIMEOUT) $(MOCHA_TEST_PATTERN)
##################################################################### targets ##
coverage: package.json node_modules $(COFFEE_SRCS) $(COFFEE_TEST_SRCS)
	rm -rf $(NYC_COVERAGE_DIR) $(NYC_COVERAGE_TMP_DIR)
	mkdir -p $(COVERAGE_DIR)
	$(NYC_EXE) $(NYC_ARGS) $(MOCHA_EXE) $(NYC_COVERAGE_MOCHA_ARGS) $(MOCHA_TESTS)
	@echo "Coverage report generated at $(NYC_COVERAGE_DIR)/index.html.\n"
	@echo "USE: open $(NYC_COVERAGE_DIR)/index.html"
#------------------------------------------------------------------------------#
clean-coverage:
	rm -rf $(NYC_COVERAGE_DIR) $(NYC_COVERAGE_TMP_DIR)
	((rmdir docs 2> /dev/null) || true) # remove docs dir if empty
################################################################################

.SUFFIXES: .coffee
.coffee:
	$(COFFEE_EXE) $< >  $@
