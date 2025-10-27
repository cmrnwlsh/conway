use crate::{
  cells::Cells,
  view::{Direction, View},
};
use ahash::{HashSet, HashSetExt};
use anyhow::Result;
use ratatui::{
  Terminal,
  crossterm::event::{Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers, poll, read},
  prelude::CrosstermBackend,
};
use rayon::iter::IntoParallelRefIterator;
use rayon::prelude::*;
use std::{
  io::Stdout,
  ops::ControlFlow,
  thread::sleep,
  time::{Duration, Instant},
};

mod cells;
mod patterns;
mod render;
mod view;

fn main() {
  let mut term = ratatui::init();
  let mut state = State::new();

  let result = state.run(&mut term);
  ratatui::restore();

  if let Err(e) = result {
    eprintln!("Error: {}", e);
  }
}

struct State {
  cells: Cells,
  view: View,
  tick_rate: TickRate,
  frame_time: Duration,
  paused: bool,
}

impl State {
  fn new() -> Self {
    Self {
      cells: Cells::new(),
      view: View::default(),
      tick_rate: TickRate::Normal,
      frame_time: Duration::ZERO,
      paused: true,
    }
  }

  fn run(&mut self, term: &mut Terminal<CrosstermBackend<Stdout>>) -> Result<()> {
    let frame_rate = Duration::from_secs_f64(1. / 60.);
    let mut accumulator = Duration::ZERO;
    let mut last_frame = Instant::now();

    Ok(loop {
      if self.handle_events()?.is_break() {
        break;
      }

      let tick_rate: Duration = self.tick_rate.into();
      let delta = last_frame.elapsed();
      last_frame = Instant::now();

      if !self.paused {
        accumulator += delta;
        while accumulator >= tick_rate {
          self.update();
          accumulator -= tick_rate;
        }
      }

      term.draw(|frame| frame.render_widget(&mut *self, frame.area()))?;

      let elapsed = last_frame.elapsed();
      if elapsed < frame_rate {
        sleep(frame_rate - elapsed);
      }

      self.frame_time = last_frame.elapsed();
    })
  }

  fn handle_events(&mut self) -> Result<ControlFlow<()>> {
    Ok(ControlFlow::Continue(while poll(Duration::default())? {
      let event = read()?;
      if let Event::Key(KeyEvent {
        code,
        modifiers,
        kind: KeyEventKind::Press,
        ..
      }) = event
      {
        match (code, modifiers) {
          (KeyCode::Char('c'), KeyModifiers::CONTROL) => return Ok(ControlFlow::Break(())),
          (KeyCode::Left, KeyModifiers::SHIFT) => self.view.translate.left(),
          (KeyCode::Right, KeyModifiers::SHIFT) => self.view.translate.right(),
          (KeyCode::Up, KeyModifiers::SHIFT) => self.view.translate.up(),
          (KeyCode::Down, KeyModifiers::SHIFT) => self.view.translate.down(),
          (KeyCode::Left, _) => self.view.move_cursor(Direction::Left),
          (KeyCode::Right, _) => self.view.move_cursor(Direction::Right),
          (KeyCode::Up, _) => self.view.move_cursor(Direction::Up),
          (KeyCode::Down, _) => self.view.move_cursor(Direction::Down),
          (KeyCode::Char('w'), _) => self.view.move_cursor(Direction::Up),
          (KeyCode::Char('a'), _) => self.view.move_cursor(Direction::Left),
          (KeyCode::Char('s'), _) => self.view.move_cursor(Direction::Down),          
          (KeyCode::Char('d'), _) => self.view.move_cursor(Direction::Right),
          (KeyCode::Char('h'), _) => self.view.controls = !self.view.controls,
          (KeyCode::Char('p'), _) => self.paused = !self.paused,
          (KeyCode::Char('c'), _) => self.view.cursor.toggle(),
          (KeyCode::Char('z'), _) => self.view.zoom = !self.view.zoom,
          (KeyCode::Char('['), _) => self.view.cursor.pattern.prev(),
          (KeyCode::Char(']'), _) => self.view.cursor.pattern.next(),
          (KeyCode::Char('r'), KeyModifiers::CONTROL) => self.cells.clear(),
          (KeyCode::Char(' '), _) if !self.view.cursor.hidden && self.view.zoom => {
            self.place_pattern()
          }
          _ => {}
        }
      }
    }))
  }

  fn update(&mut self) {
    *self.cells = self
      .cells
      .par_iter()
      .flat_map_iter(|cell| {
        let c = cell.clone();
        (-1..=1).flat_map(move |x| (-1..=1).map(move |y| (c.0 + x, c.1 + y)))
      })
      .collect::<HashSet<(i64, i64)>>()
      .par_iter()
      .filter_map(|c| {
        let live_neighbors = self.cells.count_neighbors(c.0, c.1);
        if self.cells.contains(&*c) {
          if let 2 | 3 = live_neighbors {
            Some(*c)
          } else {
            None
          }
        } else {
          if live_neighbors == 3 { Some(*c) } else { None }
        }
      })
      .collect();
  }

  fn place_pattern(&mut self) {
    let (t_col, t_row) = (
      (self.view.cursor.offset_col + self.view.translate.col).round() as i64,
      (self.view.cursor.offset_row + self.view.translate.row).round() as i64,
    );
    let coords = self
      .view
      .cursor
      .pattern
      .coords()
      .into_iter()
      .map(|(col, row)| (col + t_col, row + t_row));
    for (col, row) in coords {
      self.cells.insert((col, row));
    }
  }
}

#[derive(Clone, Copy)]
enum TickRate {
  Slow,
  Normal,
  Fast,
}

impl TickRate {
  fn increase(&mut self) {
    *self = match *self {
      Self::Slow => Self::Normal,
      Self::Normal => Self::Fast,
      Self::Fast => Self::Slow,
    }
  }

  fn decrease(&mut self) {
    *self = match *self {
      Self::Slow => Self::Fast,
      Self::Normal => Self::Slow,
      Self::Fast => Self::Normal,
    }
  }
}

impl From<TickRate> for Duration {
  fn from(value: TickRate) -> Self {
    Duration::from_secs_f64(match value {
      TickRate::Slow => 1.,
      TickRate::Normal => 1. / 5.,
      TickRate::Fast => 1. / 10.,
    })
  }
}
