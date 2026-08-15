// The `apps` domain app keeps its name inside the `apps` test module tree, mirroring src/apps/.
#![allow(clippy::module_inception)]

pub mod accounts;
pub mod apps;
pub mod artifacts;
pub mod builds;
pub mod common;
pub mod credentials;
pub mod environments;
pub mod events;
pub mod organizations;
pub mod projects;
pub mod releases;
pub mod secrets;
pub mod signing;
pub mod webhosting;
