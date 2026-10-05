.pragma library

// Navigace šipkami po dlaždicích podle jejich skutečné polohy na obrazovce.
// tiles: [{ key, x, y, width, height }], direction: "up" | "down" | "left" | "right".
// Vrací klíč dlaždice, která se má označit (nebo "" pokud nejsou žádné dlaždice).
//
// - Bez výběru: šipka nahoru označí spodní tlačítko, dolů horní, doleva poslední
//   v prvním řádku, doprava první – aby šlo pokračovat ve směru šipky.
// - Doleva/doprava se pohybuje v rámci řádku a na konci přeskočí na jeho začátek.
// - Nahoru/dolů se pohybuje mezi řádky (i přes skupiny) na dlaždici ve stejném
//   sloupci a na konci přeskočí na opačný konec. Sloupec si pamatuje (anchorX),
//   takže průchod širokým tlačítkem neposune výběr do strany.
function rows(tiles) {
    const sorted = tiles.slice().sort((a, b) => a.y - b.y || a.x - b.x);
    const result = [];
    for (const t of sorted) {
        const last = result[result.length - 1];
        if (last && Math.abs(last[0].y - t.y) < Math.min(last[0].height, t.height) / 2) {
            last.push(t);
        } else {
            result.push([t]);
        }
    }
    result.forEach(r => r.sort((a, b) => a.x - b.x));
    return result;
}

// nejbližší dlaždice k ose x (vzdálenost od jejího okraje, uvnitř = 0)
function closestInRow(row, x) {
    const distance = t => Math.max(0, t.x - x, x - (t.x + t.width));
    let best = row[0];
    for (const t of row) {
        if (distance(t) < distance(best)) {
            best = t;
        }
    }
    return best;
}

// Vrací { key, anchorX }. anchorX je svislá osa, kterou si navigace drží při pohybu
// nahoru/dolů (jako sloupec kurzoru v textovém editoru); -1 = žádná.
function navigate(tiles, currentKey, direction, anchorX) {
    const grid = rows(tiles);
    if (grid.length === 0) {
        return { key: "", anchorX: -1 };
    }
    const narrowest = Math.min.apply(null, tiles.map(t => t.width));
    const anchorOf = t => t.x + Math.min(t.width, narrowest) / 2;
    const horizontal = t => ({ key: t.key, anchorX: anchorOf(t) });

    let r = -1;
    let c = -1;
    grid.forEach((row, ri) => row.forEach((t, ci) => {
        if (t.key === currentKey) {
            r = ri;
            c = ci;
        }
    }));

    if (r < 0) {
        switch (direction) {
        case "up": return horizontal(grid[grid.length - 1][0]);
        case "left": return horizontal(grid[0][grid[0].length - 1]);
        default: return horizontal(grid[0][0]);
        }
    }

    const row = grid[r];
    const current = row[c];
    const x = anchorX >= current.x && anchorX <= current.x + current.width ? anchorX : anchorOf(current);
    switch (direction) {
    case "left": return horizontal(row[(c - 1 + row.length) % row.length]);
    case "right": return horizontal(row[(c + 1) % row.length]);
    case "up": return { key: closestInRow(grid[(r - 1 + grid.length) % grid.length], x).key, anchorX: x };
    case "down": return { key: closestInRow(grid[(r + 1) % grid.length], x).key, anchorX: x };
    }
    return { key: currentKey, anchorX: x };
}
