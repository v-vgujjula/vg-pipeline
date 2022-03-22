import pytest


# Function to append logs from the test run into a result file
def append_result_output(message, result_file_path):
    try:
        with open(result_file_path, "a") as result_file:
            result_file.write(message)
    except Exception as e:
        pytest.fail("Error while appending message '{}' to results file: ".format(message) + str(e))
