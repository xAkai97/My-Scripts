import os

def write_file_names_to_txt(directory, output_file):
    """
    This function iterates through the items in a given directory and writes
    the names of all files to a specified text file, with each name on a new line.

    Args:
        directory (str): The path to the directory to be searched.
        output_file (str): The path to the output text file.
    """
    try:
        # Open the output file in write mode ('w'). This will create the file
        # if it doesn't exist or overwrite it if it does.
        with open(output_file, 'w') as f:
            print(f"Writing file names from '{directory}' to '{output_file}'...")
            # Iterate through all items in the directory.
            for item in os.listdir(directory):
                # Construct the full path to the item.
                item_path = os.path.join(directory, item)
                # Check if the item is a file.
                if os.path.isfile(item_path):
                    # If it's a file, write its name followed by a newline character.
                    f.write(item + '\n')
        print("Done!")
    except OSError as e:
        print(f"Error: Could not write to file. Reason: {e}")


# Set the directory path to the current working directory.
directory_path = os.getcwd()
# Define the name of the output file.
output_file_path = 'file_names.txt'

# Call the function to write the file names.
write_file_names_to_txt(directory_path, output_file_path)
