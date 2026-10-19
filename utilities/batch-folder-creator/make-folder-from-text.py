import os
import sys

def make_folders_from_text_file(file_path):
    """
    Reads a text file line by line and creates a folder with the name of each line if it doesn't already exist.
    :param file_path: The path of the text file.
    """
    invalid_chars = r'\/:*?"<>|'  # Invalid characters for folder names
    with open(file_path) as f:
        for line in f:
            folder_name = line.strip()
            # Replace invalid characters in folder name with spaces
            for char in invalid_chars:
                folder_name = folder_name.replace(char, ' ')
            if not os.path.exists(folder_name):
                os.mkdir(folder_name)
                print(f"Created folder {folder_name}")
            else:
                print(f"Folder {folder_name} already exists, skipping.")
    print("Complete")

# Get the filename from command line arguments.
def main():
    current_directory = os.getcwd()
    text_files = [file for file in os.listdir(current_directory) if file.endswith('.txt')]
    if len(text_files) == 0:
        print("No text files found in the current directory.")
        return
    elif len(text_files) > 1:
        print("Multiple text files found in the current directory. Please specify which one to use.")
        return
    else:
        file_path = os.path.join(current_directory, text_files[0])
        make_folders_from_text_file(file_path)

if __name__ == "__main__":
    main()
