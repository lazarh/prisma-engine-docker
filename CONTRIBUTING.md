# Contributing to Prisma Engine Docker

Thank you for your interest in contributing!

## Ways to Contribute

1. **Report Issues** - Found a bug? Create an issue.
2. **Submit Fixes** - Fix bugs or add features via pull requests.
3. **Improve Documentation** - Help make this project more accessible.
4. **Share Builds** - If you've successfully built engines for new versions, share your experience!

## Development Setup

```bash
# Clone the repository
git clone https://github.com/lazarh/prisma-engine-docker.git
cd prisma-engine-docker

# Test the build
./build.sh --clean
```

## Building Different Versions

```bash
# Build specific Prisma version
./build.sh 5.22.0

# Build latest
./build.sh latest
```

## Pull Request Guidelines

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Testing

Before submitting:
- Test the build on your target ARMv7 hardware
- Verify all 4 binaries are present and executable
- Test your application with the new engines

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
