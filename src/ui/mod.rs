use bevy::prelude::*;

mod primary;

pub fn plugin(app: &mut App) {
    app.init_state::<Ui>().add_plugins(primary::plugin);
}

#[derive(States, Default, Debug, Hash, PartialEq, Eq, Clone)]
pub enum Ui {
    #[default]
    Primary,
    Menu,
}
