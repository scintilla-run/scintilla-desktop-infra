set shell := ["sh", "-eu", "-c"]

check:
    python3 tests/manifest-contract/check.py

doctor:
    ./scripts/doctor.sh

bootstrap:
    ./scripts/bootstrap.sh

install:
    ./scripts/install-user-service.sh

uninstall:
    ./scripts/uninstall-user-service.sh
