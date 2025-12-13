import std::io;
import std::io::file;
import std::math;

const INPUT_PATH         = "day_3_input.txt";
const INPUT_NUMBER_LEN   = 100;
// const INPUT_NUMBER_LEN   = 15; // test
const TASK_2_JOLTAGE_LEN = 12;

faultdef NO_INDEX;

fn int main()
{
	String? raw_input = ((String)file::load_temp(INPUT_PATH));
	if (catch err = raw_input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	String[] raw_numbers = raw_input.trim_right().tsplit("\n");

	ulong task_1_total_joltage = 0;

	foreach (raw_number : raw_numbers) {
		uint max_joltage = 0;

		foreach (i, tens_raw : raw_number[..raw_number.len - 2]) {
			uint tens = parse_digit(tens_raw)!!;

			foreach (ones_raw : raw_number[i + 1..]) {
				uint ones = parse_digit(ones_raw)!!;
				uint joltage = tens * 10 + ones;

				if (joltage > max_joltage) {
					max_joltage = joltage;
				}
			}
		}

		task_1_total_joltage += max_joltage;
	}

	io::printfn("[task 1] total joltage: %d", task_1_total_joltage);

	ulong task_2_total_joltage = 0;

	char[INPUT_NUMBER_LEN] digits;
	foreach (raw_number : raw_numbers) {
		digits = raw_number_to_digit_array(raw_number);

		ulong max_joltage           = 0;
		usz   offset                = 0;
		usz?  first_max_digit_index = NO_INDEX?;
		while (offset < TASK_2_JOLTAGE_LEN) {
			defer offset += 1;

			usz start = (first_max_digit_index ?? -1) + 1;
			usz end   = digits.len - TASK_2_JOLTAGE_LEN + offset;
			char[] allowed_digits = digits[start..end];

			char current_max_digit = 0;
			foreach (i, digit : allowed_digits) {
				if (digit > current_max_digit) {
					current_max_digit     = digit;
					first_max_digit_index = i + start;
				}
			}

			int exponent = TASK_2_JOLTAGE_LEN - (int)offset - 1;
			max_joltage += (ulong)math::pow(10, exponent) *
					       current_max_digit;
		}

		task_2_total_joltage += max_joltage;
	}

	io::printfn("[task 2] total joltage: %d", task_2_total_joltage);

	return 0;
}

faultdef NOT_A_DIGIT;

fn char? parse_digit(char ch)
{
	if (ch >= '0' && ch <= '9') {
		return ch - '0';
	} else {
		return NOT_A_DIGIT?;
	}
}

fn char[INPUT_NUMBER_LEN] raw_number_to_digit_array(String raw_number)
{
	char[INPUT_NUMBER_LEN] digits;

	foreach (i, raw_digit : raw_number) {
		digits[i] = parse_digit(raw_digit)!!;
	}

	return digits;
}
