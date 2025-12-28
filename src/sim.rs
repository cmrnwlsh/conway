use bevy::{
    math::I64Vec2,
    platform::collections::HashSet,
    prelude::*,
    tasks::{ComputeTaskPool, ParallelSlice},
};

pub fn plugin(app: &mut App) {
    app.add_systems(
        Startup,
        (
            |mut f: ResMut<Time<Fixed>>, mut v: ResMut<Time<Virtual>>| {
                f.set_timestep_seconds(1. / 5.);
                v.pause();
            },
            |world: &mut World| {
                world.insert_resource(Cells(HashSet::from([
                    [0, 1],
                    [2, 2],
                    [2, 0],
                    [2, 1],
                    [1, 0],
                ])))
            },
        ),
    )
    .add_systems(FixedUpdate, |mut cells: ResMut<Cells>| {
        **cells = cells.next_set()
    });
}

#[derive(Resource, Deref, DerefMut)]
pub struct Cells(HashSet<[i64; 2]>);

impl Cells {
    pub fn subset(
        &self,
        [min_x, min_y]: [i64; 2],
        [max_x, max_y]: [i64; 2],
    ) -> impl Iterator<Item = &[i64; 2]> {
        (min_y..=max_y).flat_map(move |y| (min_x..=max_x).filter_map(move |x| self.get(&[x, y])))
    }

    pub fn toggle(&mut self, cell: &I64Vec2) {
        let I64Vec2 { x, y } = *cell;
        if self.contains(&[x, y]) {
            self.remove(&[x, y])
        } else {
            self.insert([x, y])
        };
    }

    pub fn next_set(&self) -> HashSet<[i64; 2]> {
        self.iter()
            .collect::<Vec<_>>()
            .par_splat_map(ComputeTaskPool::get(), None, |_, chunk| {
                let mut candidates = HashSet::new();
                for [x, y] in chunk {
                    for dx in -1..=1 {
                        for dy in -1..=1 {
                            candidates.insert([x + dx, y + dy]);
                        }
                    }
                }
                candidates
                    .into_iter()
                    .filter(|&[x, y]| {
                        let neighbors = (-1i64..=1)
                            .flat_map(|dx| (-1i64..=1).map(move |dy| [x + dx, y + dy]))
                            .filter(|n| *n != [x, y] && self.contains(n))
                            .count();
                        neighbors == 3 || (neighbors == 2 && self.contains(&[x, y]))
                    })
                    .collect::<Vec<_>>()
            })
            .into_iter()
            .flatten()
            .collect()
    }
}
