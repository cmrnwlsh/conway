use bevy::{app::ScheduleRunnerPlugin, prelude::*, state::app::StatesPlugin};
use std::time::Duration;

use crate::plugin::AppPlugins;

mod plugin;

fn main() {
    App::new()
        .add_plugins((
            MinimalPlugins.set(ScheduleRunnerPlugin::run_loop(Duration::from_secs_f64(
                1. / 60.,
            ))),
            StatesPlugin,
            AppPlugins,
        ))
        .run();
}
