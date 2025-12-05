import std::io;
import std::io::file;

const INPUT_PATH = "day_3_input.txt";

fn int main()
{
	String? input = ((String)file::load_temp(INPUT_PATH)).trim_right();
	if (catch err = input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	String[] lines = input.tsplit("\n");

	uint total = 0;

	foreach (line : lines) {
		uint max = 0;

		foreach (i, num_char : line[..line.len - 2]) {
			uint num = num_char - 48;

			foreach (num_char_2 : line[i + 1..]) {
				uint num_2 = num * 10 + num_char_2 - 48;
				if (num_2 > max) {
					max = num_2;
				}
			}
		}

		total += max;
	}

	io::printfn("total: %d", total);

	return 0;
}
