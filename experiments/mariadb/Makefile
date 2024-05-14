.PHONY: all
all: install imports format lint type

PYTHON_EXEC=pipenv run

.PHONY: install
install:
	pipenv sync

.PHONY: imports
imports:
	${PYTHON_EXEC} pycln beder patch-benchmark duckdb-utils
	${PYTHON_EXEC} isort beder patch-benchmark duckdb-utils

.PHONY: format
format:
	${PYTHON_EXEC} black beder patch-benchmark duckdb-utils

.PHONY: lint
lint:
	${PYTHON_EXEC} flake8 beder patch-benchmark duckdb-utils

.PHONY: type
type:
	${PYTHON_EXEC} mypy beder
	${PYTHON_EXEC} mypy patch-benchmark
	${PYTHON_EXEC} mypy duckdb-utils

