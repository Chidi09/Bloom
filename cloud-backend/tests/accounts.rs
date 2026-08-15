//! Single integration-test binary for the whole crate.
//!
//! Every test module tree must be declared here or it is never compiled: `tests/apps/` and
//! `tests/infra/` both sat unreferenced for several phases, so those suites silently never ran.
mod apps;
mod infra;
mod workers;
