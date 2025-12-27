use bevy::{math::I64Vec2, platform::collections::HashSet, prelude::*};

pub fn plugin(app: &mut App) {
    app.add_systems(Startup, |world: &mut World| {
        world.insert_resource(Cells(HashSet::from([
            [-1, -1],
            [1, 1],
            [-1, 1],
            [1, -1],
            [-10, -10],
            [10, 10],
            [-10, 10],
            [10, -10],
        ])))
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
        todo!()
    }
}
