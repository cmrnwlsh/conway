use bevy::{ecs::system::SystemParam, math::I64Vec2, prelude::*};
use ratatui::{
    buffer::Buffer,
    crossterm::event::{KeyCode, KeyModifiers},
    layout,
    prelude::Rect,
    style::Color,
    symbols::Marker,
    widgets::{
        Widget,
        canvas::{Canvas, Points},
    },
};

use crate::{
    any_changed,
    io::{Io, KeyPress, Size},
    sim::Cells,
};

pub fn plugin(app: &mut App) {
    app.init_resource::<Cursor>()
        .init_resource::<Translation>()
        .init_resource::<Bounds>()
        .add_systems(Update, (input, wrap_cursor).chain())
        .add_systems(PostUpdate, render);
}

fn input(
    mut cursor: ResMut<Cursor>,
    mut trans: ResMut<Translation>,
    mut cells: ResMut<Cells>,
    mut keys: MessageReader<KeyPress>,
) {
    for key in keys.read() {
        match (key.code, key.modifiers) {
            (KeyCode::Left, KeyModifiers::SHIFT) => trans.x -= 1,
            (KeyCode::Right, KeyModifiers::SHIFT) => trans.x += 1,
            (KeyCode::Up, KeyModifiers::SHIFT) => trans.y += 1,
            (KeyCode::Down, KeyModifiers::SHIFT) => trans.y -= 1,
            (KeyCode::Left, _) => cursor.x -= 1,
            (KeyCode::Right, _) => cursor.x += 1,
            (KeyCode::Up, _) => cursor.y += 1,
            (KeyCode::Down, _) => cursor.y -= 1,
            (KeyCode::Char(' '), _) => cells.toggle(&cursor),
            _ => {}
        }
    }
}

fn render(mut io: ResMut<Io>, view: View) -> Result<()> {
    Ok(if view.is_changed() {
        io.draw(|frame| frame.render_widget(view, frame.area()))
            .map(|_| ())?
    })
}

fn wrap_cursor(mut cursor: ResMut<Cursor>, bounds: Res<Bounds>) {
    let Bounds([x_min, x_max], [y_min, y_max]) = *bounds;
    let (x_min, x_max, y_min, y_max) = (x_min as i64, x_max as i64, y_min as i64, y_max as i64);
    if cursor.x < x_min {
        cursor.x = x_max
    }
    if cursor.x > x_max {
        cursor.x = x_min
    }
    if cursor.y < y_min {
        cursor.y = y_max
    }
    if cursor.y > y_max {
        cursor.y = y_min
    }
}

#[derive(Resource, Default, Deref, DerefMut)]
pub struct Cursor(I64Vec2);

#[derive(Resource, Default, Deref, DerefMut)]
struct Translation(I64Vec2);

#[derive(Resource, Default)]
struct Bounds([f64; 2], [f64; 2]);

#[derive(SystemParam)]
struct View<'w> {
    cursor: Res<'w, Cursor>,
    trans: Res<'w, Translation>,
    cells: Res<'w, Cells>,
    size: Res<'w, Size>,
    bounds: ResMut<'w, Bounds>,
}

impl<'w> View<'w> {
    fn is_changed(&self) -> bool {
        any_changed![self.cursor, self.trans, self.cells, self.size]
    }
}

impl<'w> Widget for View<'w> {
    fn render(mut self, area: Rect, buf: &mut Buffer) {
        let layout::Rect { width, height, .. } = area;
        let x_range = (width - 1) as f64;
        let y_range = (height * 2 - 1) as f64;
        let Bounds([ref mut x_min, ref mut x_max], [ref mut y_min, ref mut y_max]) = *self.bounds;

        [*x_min, *x_max] = [-x_range / 2., x_range / 2.].map(|p| p.floor() + self.trans.x as f64);
        [*y_min, *y_max] = [-y_range / 2., y_range / 2.].map(|p| p.floor() + self.trans.y as f64);

        Canvas::default()
            .marker(Marker::HalfBlock)
            .x_bounds([*x_min, *x_max])
            .y_bounds([*y_min, *y_max])
            .paint(|ctx| {
                ctx.draw(&Points {
                    coords: &self
                        .cells
                        .subset(
                            [*x_min, *y_min].map(|p| p as i64),
                            [*x_max, *y_max].map(|p| p as i64),
                        )
                        .map(|&[x, y]| (x as f64, y as f64))
                        .collect::<Vec<_>>(),
                    color: Color::White,
                });
                ctx.draw(&Points {
                    coords: &[(self.cursor.x as f64, self.cursor.y as f64)],
                    color: Color::Cyan,
                })
            })
            .render(area, buf);
    }
}
