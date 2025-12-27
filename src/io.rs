use std::{io::Stdout, time::Duration};

use bevy::prelude::*;
use ratatui::{
    Terminal,
    crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers},
    layout,
    prelude::CrosstermBackend,
};

pub fn plugin(app: &mut App) {
    app.init_resource::<Io>()
        .init_resource::<Size>()
        .add_message::<KeyPress>()
        .add_systems(PreUpdate, poll);
}

fn poll(
    mut keys: MessageWriter<KeyPress>,
    mut exit: MessageWriter<AppExit>,
    mut size: ResMut<Size>,
) -> Result<()> {
    Ok(while event::poll(Duration::ZERO)? {
        let ev = event::read()?;
        if let Event::Resize(width, height) = ev {
            *size = Size { width, height }
        }
        let Event::Key(KeyEvent {
            code,
            modifiers,
            kind: KeyEventKind::Press,
            ..
        }) = ev
        else {
            continue;
        };
        if let (KeyCode::Char('c'), KeyModifiers::CONTROL) = (code, modifiers) {
            exit.write(AppExit::Success);
        } else {
            keys.write(KeyPress { code, modifiers });
        }
    })
}

#[derive(Resource, Deref, DerefMut)]
pub struct Io(Terminal<CrosstermBackend<Stdout>>);

#[derive(Message)]
pub struct KeyPress {
    pub code: KeyCode,
    pub modifiers: KeyModifiers,
}

#[derive(Resource)]
pub struct Size {
    pub width: u16,
    pub height: u16,
}

impl FromWorld for Size {
    fn from_world(world: &mut World) -> Self {
        let layout::Size { width, height } = world.get_resource::<Io>().unwrap().size().unwrap();
        Self { width, height }
    }
}

impl From<layout::Size> for Size {
    fn from(layout::Size { width, height }: layout::Size) -> Self {
        Self { width, height }
    }
}

impl Default for Io {
    fn default() -> Self {
        Self(ratatui::init())
    }
}

impl Drop for Io {
    fn drop(&mut self) {
        ratatui::restore()
    }
}
