# Contributing

Thanks for your interest in the SASE Deployment Lab!

## Getting Started

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Install prerequisites: Python 3.12+, Terraform 1.6+, Docker + Docker Compose
4. Install dev dependencies: `pip install pytest`

## Development Workflow

```bash
make test        # Run tests
make lint        # Terraform validation
make run         # Start Docker multi-site environment
make verify      # Verify deployment
make diagram     # Regenerate architecture diagram
```

## Code Style

- Python: Follow PEP 8, use type hints, keep functions focused
- Terraform: Use `terraform fmt` before committing
- Shell: Use `set -euo pipefail` for scripts
- No placeholder code — every function must have a real implementation

## Testing

- All Python code must have unit tests in `tests/`
- Mock external calls (subprocess, network) in unit tests
- Run `make test` before committing

## Pull Request Checklist

- [ ] Tests pass (`make test`)
- [ ] Terraform validates (`make lint`)
- [ ] Docker compose builds cleanly
- [ ] No placeholder keys or example secrets committed
- [ ] README updated if adding features

## Reporting Issues

Open a GitHub issue with:
- What you were trying to do
- What happened
- What you expected
- Steps to reproduce

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
