use bevy::{math::I64Vec2, prelude::*};
use ratatui::{
    crossterm::event::{KeyCode, KeyModifiers},
    layout,
    style::Color,
    symbols::Marker,
    widgets::canvas::{Canvas, Points},
};

use crate::{
    io::{Io, KeyPress},
    sim::Cells,
};

pub fn plugin(app: &mut App) {
    app.init_resource::<Cursor>()
        .add_systems(PostUpdate, render)
        .add_systems(Update, input);
}

fn render(mut io: ResMut<Io>, cursor: Res<Cursor>, cells: Res<Cells>) -> Result<()> {
    Ok(io.draw(|frame| {
        let layout::Rect { width, height, .. } = frame.area();
        let x_range = (width - 1) as f64;
        let y_range = (height * 2 - 1) as f64;
        let [x_min, x_max] = [-x_range / 2., x_range / 2.].map(|p| p + cursor.trans.x as f64);
        let [y_min, y_max] = [-y_range / 2., y_range / 2.].map(|p| p + cursor.trans.y as f64);
        frame.render_widget(
            Canvas::default()
                .marker(Marker::HalfBlock)
                .x_bounds([x_min, x_max])
                .y_bounds([y_min, y_max])
                .paint(|ctx| {
                    ctx.draw(&Points {
                        coords: &cells
                            .subset(
                                [x_min, y_min].map(|p| p as i64),
                                [x_max, y_max].map(|p| p as i64),
                            )
                            .map(|&[x, y]| (x as f64, y as f64))
                            .collect::<Vec<_>>(),
                        color: Color::White,
                    });
                    ctx.draw(&Points {
                        coords: &[(cursor.pos.x as f64, cursor.pos.y as f64)],
                        color: Color::Cyan,
                    })
                }),
            frame.area(),
        )
    })?)
    .map(|_| ())
}

fn input(mut cursor: ResMut<Cursor>, mut keys: MessageReader<KeyPress>) {
    for key in keys.read() {
        match (key.code, key.modifiers) {
            (KeyCode::Left, KeyModifiers::SHIFT) => cursor.trans.x -= 1,
            (KeyCode::Right, KeyModifiers::SHIFT) => cursor.trans.x += 1,
            (KeyCode::Up, KeyModifiers::SHIFT) => cursor.trans.y += 1,
            (KeyCode::Down, KeyModifiers::SHIFT) => cursor.trans.y -= 1,
            (KeyCode::Left, _) => cursor.pos.x -= 1,
            (KeyCode::Right, _) => cursor.pos.x += 1,
            (KeyCode::Up, _) => cursor.pos.y += 1,
            (KeyCode::Down, _) => cursor.pos.y -= 1,
            _ => {}
        }
    }
}

#[derive(Resource, Debug, Default)]
pub struct Cursor {
    pos: I64Vec2,
    trans: I64Vec2,
}
