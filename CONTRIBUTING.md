# Contributing to n8n Production Deployment

Thank you for your interest in contributing to this project! This repository provides a production-ready n8n deployment solution.

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check existing [GitHub Issues](https://github.com/davidnagtzaam/n8nctl/issues) first
2. Create a new issue with:
   - Clear description of the problem/feature
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (OS, Docker version, etc.)
   - Relevant logs or error messages

### Submitting Changes

1. **Fork the Repository**

   ```bash
   git clone https://github.com/davidnagtzaam/n8nctl.git
   cd n8nctl
   ```

2. **Create a Feature Branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Follow the existing code style
   - Test your changes thoroughly
   - Update documentation if needed

4. **Test Your Changes**

   ```bash
   # Run preflight checks
   sudo bash scripts/preflight.sh

   # Test installation (in a VM or test environment)
   sudo bash scripts/init.sh

   # Verify all scripts work
   sudo bash scripts/healthcheck.sh
   ```

5. **Commit Your Changes**

   ```bash
   git add .
   git commit -m "Brief description of your changes"
   ```

6. **Push to Your Fork**

   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your feature branch
   - Describe your changes clearly

## Development Guidelines

### Code Style

- **Shell Scripts**: Follow [ShellCheck](https://www.shellcheck.net/) recommendations
- **YAML**: 2-space indentation
- **Documentation**: Clear, concise, with examples
- **Comments**: Explain "why" not "what"

### Script Standards

All scripts should:

- Use `set -euo pipefail` for safety
- Include error handling
- Provide helpful error messages
- Use colors for better UX
- Include a header with purpose and author

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}
```

### Testing Requirements

Before submitting a PR:

- [ ] All scripts execute without errors
- [ ] Init script completes successfully
- [ ] Services start and pass health checks
- [ ] Backup and restore work correctly
- [ ] Upgrade process completes successfully
- [ ] Documentation is updated

### Documentation

- Update README.md for new features
- Add comments to complex code sections
- Include usage examples
- Update .env.template for new variables

## Priority Areas for Contribution

We especially welcome contributions in these areas:

1. **Additional Cloud Providers**
   - Support for more S3-compatible storage
   - Integration with cloud-specific services

2. **Security Enhancements**
   - Additional hardening options
   - Security scanning integrations
   - Automated security updates

3. **Monitoring & Observability**
   - Additional Grafana dashboards
   - Alert rules
   - Log aggregation integrations

4. **Platform Support**
   - ARM architecture support
   - Additional Linux distributions
   - Windows container support (if feasible)

5. **Documentation**
   - Tutorials and guides
   - Video walkthroughs
   - Troubleshooting sections
   - Translation to other languages

## Questions?

- Open a GitHub Discussion for general questions
- Contact: [davidnagtzaam.com](https://davidnagtzaam.com)

## Code of Conduct

- Be respectful and professional
- Welcome newcomers
- Focus on constructive feedback
- Help others learn and grow

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to making n8n deployment easier for everyone!**

Created by [David Nagtzaam](https://davidnagtzaam.com) - AI & Automation Expert
