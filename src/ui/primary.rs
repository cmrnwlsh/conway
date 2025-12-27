use bevy::prelude::*;
use ratatui::{
    crossterm::event::KeyCode,
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
        let [x_min, x_max] = [-x_range / 2., x_range / 2.];
        let [y_min, y_max] = [-y_range / 2., y_range / 2.];
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
        match key.code {
            KeyCode::Left => cursor.pos.x -= 1,
            KeyCode::Right => cursor.pos.x += 1,
            KeyCode::Up => cursor.pos.y += 1,
            KeyCode::Down => cursor.pos.y -= 1,
            _ => {}
        }
    }
}

#[derive(Resource, Debug, Default)]
pub struct Cursor {
    pos: IVec2,
    trans: IVec2,
}
