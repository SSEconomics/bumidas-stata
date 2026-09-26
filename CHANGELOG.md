# Changelog

All notable changes to this project will be documented in this file.

The project follows [Semantic Versioning](https://semver.org/) where practical.

## [Unreleased]

### Planned

- Additional user testing and documentation refinements.
- Foreign-exchange application.
- Representative simulation comparing BUMIDAS with UMIDAS, RMIDAS, and low-frequency benchmarks.
- Stata package installation files for direct installation from GitHub.

## [0.1.0] - Initial release

### Added

- `bumidas` estimation command for Bottom-Up Mixed-Frequency Data Sampling regressions.
- Full-grid information-criterion model selection.
- Recursive forward block-order selection.
- Fixed-order estimation with `search(none)`.
- Support for required and optional high-frequency blocks.
- Support for multiple high-frequency target and predictor blocks.
- Low-frequency target and predictor lag selection.
- AIC, HQIC, and BIC model-selection criteria.
- Direct multi-step forecast horizons.
- Fixed regression controls.
- Compact estimation output and optional full regression display.
- Replay support.
- `predict` support for fitted values and residuals.
- Stored selected-order and recursive-search-path matrices.

- `mfcollapse` command for converting higher-frequency data to lower-frequency datasets while retaining within-period high-frequency observations.
- Support for daily, weekly, monthly, and quarterly frequency conversions.
- Automatic construction of high-frequency lag variables and within-period averages.
- Automatic inference of the typical number of high-frequency observations per lower-frequency period.
- Optional common observation anchor for multiple variables.

- Stata help files for `bumidas` and `mfcollapse`.
- Self-contained command examples.
- Deterministic certification tests for both commands.
- MIT License.
- Machine-readable `CITATION.cff`.

[Unreleased]: https://github.com/SSEconomics/bumidas-stata/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/SSEconomics/bumidas-stata/releases/tag/v0.1.0
