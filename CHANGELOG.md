# Changelog

All notable changes to this project will be documented in this file.

The project follows [Semantic Versioning](https://semver.org/) where practical.

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

## [0.1.1] - 2026-09-27

### Changed

- Standardized all package files to version 0.1.1.
- Lowered the Stata version requirement from 18.0 to 11.0 to improve backward compatibility.
- Updated examples, tests, help files, and package metadata accordingly.

### Tested

- Verified successful installation and execution under Stata 14 and Stata 16.
- Confirmed continued operation under Stata 19.
