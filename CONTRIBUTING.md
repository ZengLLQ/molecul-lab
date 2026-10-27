# Contributing to MolecuLab

We welcome contributions to MolecuLab! As a scientific computing project, we maintain high standards of mathematical correctness, test coverage, and code hygiene.

## 1. Development Principles

1. **Julia-First**: All application logic, domain models, geometry solvers, and interfaces are written in idiomatic Julia.
2. **Type Stability**: Every computational kernel must be type-stable. Verify using `@code_warntype` or `JET.jl`.
3. **No Speculative Claims**: Never claim that a method is general, accurate, or GPU-ready without reproducible benchmarks and analytical reference tests.
4. **Style**: Follow the BlueStyle guide for Julia code formatting.
5. **Testing**: Every new feature or fix must include unit tests in `test/unit/` or scientific tests in `test/scientific/`.

## 2. Setting Up the Development Environment

```bash
git clone https://github.com/moleculab/MolecuLab.jl.git
cd MolecuLab
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## 3. Running the Test Suite

```bash
julia --project=. test/runtests.jl
```

## 4. Submitting Pull Requests

1. Create a feature branch (`git checkout -b feature/my-feature`).
2. Implement your changes following modular boundary rules (UI does not touch domain internals directly; computational adapters implement `AbstractChemistryMethod`).
3. Ensure all tests pass.
4. Submit a clear pull request describing the motivation, implementation, and scientific validation.
