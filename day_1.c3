import std::io;
import std::io::file;
import std::collections::list;
import std::math;
import libc;

const INPUT_PATH = "day_1_input.txt";

fn int main()
{
	String? input = (String)file::load_temp(INPUT_PATH);
	if (catch err = input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	String[] split = input.tsplit("\n");

	int  current_pos = 50;
	uint counter     = 0;

	// count zero stoppings
	foreach (str : split) {
		if (str.len <= 1) continue;

		String num_str = str[1..];
		int num = num_str.to_int() ?? 0;
		if (str[0] == 'L') {
			num = -num;
		}

		// standard modulo is fine here, we don't care
		// about negative numbers. the only thing that
		// matters is that we end on a zero.
		current_pos = (current_pos + num) % 100;

		if (current_pos == 0) ++counter;
	}

	io::printfn("counter [1]: %d", counter);

	current_pos  = 50;
	counter      = 0;

	// count zero stoppings and zero crossings
	foreach (str : split) {
		if (str.len <= 1) continue;

		String num_str = str[1..];
		int num = num_str.to_int() ?? 0;

		//	my first solution seems a bit too convoluted;
		//	leaving it in the comment, though, since I like it.
        //
        //	if (str[0] == 'L') {
		//		// add one revolution by default when turning left
		//		// to avoid having to separately count sign change
		//		// (e.g. from 1 to -1) as a revolution; this adds
		//		// the missing zero stoppings as well.
		//		num = -num - 100;
        //
        //		// we're counting zero crossings with revolutions,
		//		// but if we start on zero and turn left, that's
		//		// a revolution but not a zero crossing!
		//		// we pre-move by one step to negate this.
		//		if (current_pos == 0) {
		//			num += 1;
		//			current_pos = 99;
		//		}
		//	}
        //	current_pos += num;
        //
		//	counter += math::abs(current_pos) / 100;
		//
		//	overflow from negative to positive numbers
		//	current_pos = ((current_pos % 100) + 100) % 100;

		// but let's not do that. instead, let's treat negative
		// numbers as positive numbers but invert the positions.
		// now we don't have any special cases! :feelsgoodman:
		if (str[0] == 'L' && current_pos != 0) {
			current_pos = 100 - current_pos;
		}

		current_pos += num;

		// we also don't have to use math::abs, we use just one
		// modulo, and we can even use libc::div!
		libc::DivResult div_result = libc::div(current_pos, 100);

		counter += div_result.quot;
		current_pos = div_result.rem;

		// we have to invert the result again, but I feel that's acceptable
		if (str[0] == 'L' && current_pos != 0) {
			current_pos = 100 - current_pos;
		}

		// NOTE: the results seem very close even without position inversion.
		// maybe this could be simplified further?
		// maybe there's something to be done with number inversion as well?
		// handling zero seems tricky with number inversion, though...
	}

	io::printfn("counter [2]: %d", counter);

	return 0;
}
