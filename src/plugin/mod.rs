use bevy::app::{PluginGroup, PluginGroupBuilder};

mod io;
mod sim;
mod ui;

pub struct AppPlugins;

impl PluginGroup for AppPlugins {
    fn build(self) -> PluginGroupBuilder {
        PluginGroupBuilder::start::<Self>()
            .add(io::plugin)
            .add(ui::plugin)
            .add(sim::plugin)
    }
}
