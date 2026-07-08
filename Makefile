.PHONY: all run test lint clean teardown keygen deploy verify diagram demo-tunnel wg-check monitor aws-lab aws-lab-setup aws-lab-teardown

all: test lint

run:
	docker compose up -d

test:
	python -m pytest tests/ -v --tb=short

lint:
	cd terraform && terraform fmt -check && terraform validate

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

demo-tunnel:
	bash scripts/demo-tunnel.sh

wg-check:
	bash scripts/wg-verify.sh

monitor:
	python posture-checks/posture_checker.py --prometheus

# ── AWS Lab (real deployment tier) ───────────────────────────────
# Requires: terraform/aws-lab/terraform.tfvars with valid AWS credentials
# Uses t3.micro (~$0.0104/hr each, ~$0.03/hr total for 3 instances)

aws-lab:
	@echo "=== Provisioning 3 EC2 instances + networking ==="
	cd terraform/aws-lab && terraform init && terraform plan -out=tfplan
	@echo ""
	@echo "Review the plan for 15 resources, then apply:"
	@echo "  make aws-lab-apply"

aws-lab-apply:
	cd terraform/aws-lab && terraform apply tfplan

aws-lab-setup:
	@echo "=== Post-deploy WireGuard configuration ==="
	bash scripts/aws-lab-setup.sh

aws-lab-all: aws-lab aws-lab-setup
	@echo ""
	@echo "=== SASE AWS Lab is LIVE ==="
	@echo "Destroy with: make aws-lab-teardown"

aws-lab-teardown:
	cd terraform/aws-lab && terraform destroy -auto-approve
