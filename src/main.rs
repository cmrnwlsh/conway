use bevy::{
    app::{PluginGroupBuilder, ScheduleRunnerPlugin},
    prelude::*,
    state::app::StatesPlugin,
};
use std::time::Duration;

mod io;
mod sim;
mod ui;

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

struct AppPlugins;

impl PluginGroup for AppPlugins {
    fn build(self) -> PluginGroupBuilder {
        PluginGroupBuilder::start::<Self>()
            .add(io::plugin)
            .add(ui::plugin)
            .add(sim::plugin)
    }
}
