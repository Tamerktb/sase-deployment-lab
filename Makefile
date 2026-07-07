.PHONY: all run test lint clean teardown keygen deploy verify

all: test lint

run:
	docker compose up -d

test:
	python -m pytest tests/ -v --tb=short

lint:
	cd terraform && terraform fmt -check -diff && terraform validate

clean:
	docker compose down --volumes --remove-orphans

teardown: clean
	cd terraform && terraform destroy -auto-approve 2>/dev/null || true

keygen:
	python scripts/key-exchange.py

deploy: keygen run
	python posture-checks/posture_checker.py
	bash scripts/verify.sh

verify:
	bash scripts/verify.sh

diagram:
	python scripts/generate-architecture-diagram.py
