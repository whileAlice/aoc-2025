import std::io;
import std::io::file;
import std::collections::list;
import std::math;

const INPUT_PATH = "day_4_input.txt";

fn int main()
{
	String? raw_input = ((String)file::load_temp(INPUT_PATH));
	if (catch err = raw_input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	String[] raw_rows = raw_input.trim_right().tsplit("\n");
	Rolls    diagram  = get_diagram_from_raw_rows(&raw_rows);

	usz accessible_count = 0;
	foreach (y, &row : diagram) {
		foreach (x, is_roll : row) {
			if (!is_roll) continue;

			usz neighbor_count = 0;
			usz start_x = math::clamp(x - 1, 0, row.len()     - 1);
			usz start_y = math::clamp(y - 1, 0, diagram.len() - 1);
			usz end_x   = math::clamp(x + 1, 0, row.len()     - 1);
			usz end_y   = math::clamp(y + 1, 0, diagram.len() - 1);

			for (usz i = start_x; i <= end_x; ++i) {
				for (usz j = start_y; j <= end_y; ++j) {
					if (i == x && j == y) continue;

					if (diagram[j][i] == true) {
						neighbor_count += 1;
					}
				}
			}

			if (neighbor_count < 4) {
				accessible_count += 1;
			}
		}
	}

	io::printfn("[task 1] accessible roll count: %d", accessible_count);

	usz  removable_count = 0;
	bool no_more         = false;
	while (no_more == false) {
		no_more = true;
		foreach (y, &row : diagram) {
			foreach (x, &is_roll : row) {
				if (!*is_roll) continue;

				usz neighbor_count = 0;
				usz start_x = math::clamp(x - 1, 0, row.len()     - 1);
				usz start_y = math::clamp(y - 1, 0, diagram.len() - 1);
				usz end_x   = math::clamp(x + 1, 0, row.len()     - 1);
				usz end_y   = math::clamp(y + 1, 0, diagram.len() - 1);

				for (usz i = start_x; i <= end_x; ++i) {
					for (usz j = start_y; j <= end_y; ++j) {
						if (i == x && j == y) continue;

						if (diagram[j][i] == true) {
							neighbor_count += 1;
						}
					}
				}

				if (neighbor_count < 4) {
					no_more = false;

					removable_count += 1;
					*is_roll = false;
				}
			}
		}
	}

	io::printfn("[task 2] removable roll count: %d", removable_count);

	return 0;
}

alias Rolls = List{List{bool}};

fn Rolls get_diagram_from_raw_rows(String[]* raw_rows)
{
	Rolls rolls;
	rolls.init(mem, raw_rows.len);

	foreach (y, &raw_row : raw_rows) {
		List{bool} row;
		row.init(mem, raw_row.len);
		rolls.push(row);

		foreach (x, ch : raw_row) {
			if (ch == '@') {
				rolls[y].push(true);
			} else {
				rolls[y].push(false);
			}
		}
	}

	return rolls;
}
