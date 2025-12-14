import std::io;
import std::io::file;
import std::collections::list;
import std::collections::set;

const INPUT_PATH = "day_7_input.txt";

alias Diagram = List{List{bool}};
alias XSet = HashSet{usz};

fn int main()
{
	String? raw_input = ((String)file::load_temp(INPUT_PATH));
	if (catch err = raw_input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	String[] raw_lines = raw_input.trim_right().tsplit("\n");

	Diagram diagram;
	diagram.tinit();

	XSet beam_origins;
	foreach (y, &raw_line : raw_lines) {
		List{bool} row;
		row.tinit();

		foreach (x, ch : raw_line) {
			switch (ch) {
				case '^':
					row.push(true);
				case '.':
					row.push(false);
				case 'S':
					beam_origins.add(x);
					row.push(false);
				default:
					unreachable();
			}
		}

		diagram.push(row);
	}

	uint split_count = 0;
	foreach (y, &row : diagram) {
		List{usz} new_origins;
		new_origins.tinit();

		usz i = 0;
		while (i < beam_origins.len()) {
			defer ++i;

			usz origin_x = beam_origins.tvalues()[i];

			if (diagram[y][origin_x]) {
				split_count += 1;

				int left  = (int)origin_x - 1;
				usz right = origin_x + 1;

				if (left >= 0 &&
					!diagram[y][left]) {
					new_origins.push(left);
				}
				if (right <= row.len() - 1 &&
					!diagram[y][right]) {
					new_origins.push(right);
				}

				beam_origins.remove(origin_x);
				i -= 1;
			}
		}

		beam_origins.add_all(new_origins.array_view());
		new_origins.clear();
	}

	io::printfn("[task 1] split count: %d", split_count);

	return 0;
}
